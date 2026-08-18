#
# tests/test_loader.rb — loader idempotency + real-host boot path.
# Per CodeX Round 018 BLOCK-002 (rework per Round 019 BLOCK-002-R2).
#
# Asserts:
#   1. First register! call creates exactly one menu item.
#   2. Repeated register! / Load does NOT duplicate.
#   3. Clicking the menu command reaches the dialog runner.
#   4. release_dialog! clears the held dialog reference.
#   5. The dialog_runner integration path is wired up.
#   6. The boot entrypoint file_loaded? guard prevents re-entry.
#   7. **FAITHFUL BOOT** (Round 019 BLOCK-002-R2):
#      - Load `extension/su_ai_plugin.rb` twice (with file_unloaded
#        simulation between loads) — assert exactly ONE menu item.
#      - Invoke the created command handler through to the dialog
#        boundary — assert one HtmlDialog was created.
#      - The FakeMenu mirrors the real Sketchup::Menu add_submenu
#        behavior (always creates a NEW submenu; does NOT
#        find-or-return by name) so the test would FAIL on a real
#        duplicate.
#

require_relative 'runner'
require_relative '_fake_ui'
require_relative '../core/issue_registry'
require_relative '../core/analysis_result'
require_relative '../extension/loader'
require_relative '../extension/dialog_runner'

include SUAnalysis::Extension
include FakeUI

# --- top-level file_loaded?/file_loaded/file_unloaded stubs --------
#
# Ruby's `instance_eval`-based test runner means the `self` inside a
# test is a Tests::TestCase, NOT the main object. The entrypoint
# extension/su_ai_plugin.rb calls `file_loaded?` as a top-level method
# (resolving through `self`'s class), so we define the stubs at the
# top level of this file (not inside a test) — they become private
# instance methods on Object, callable from anywhere.
#
# They share a single $__file_loaded_set global. Tests reset it
# in their bodies to start fresh.

$__file_loaded_set = {}

def file_loaded?(name)
  $__file_loaded_set.key?(name)
end

def file_loaded(name)
  $__file_loaded_set[name] = true
end

def file_unloaded(name)
  $__file_loaded_set.delete(name)
end

# --- helpers ----------------------------------------------------------

def reset_loader
  SUAnalysis::Extension::Loader.instance_variable_set(:@registered, false)
  SUAnalysis::Extension::Loader.instance_variable_set(:@live_dialog, nil)
end

# Stub Sketchup.active_model with a non-empty selection so
# Loader.on_analyze_selection drives through to DialogRunner.show.
def stub_sketchup_with_selection
  @__prev_sketchup = Object.const_defined?(:Sketchup) ? Object.const_get(:Sketchup) : :__undefined__
  fake_model = FakeUI::FakeModel.new
  fake_model.selection.add(Object.new)
  sk = Module.new
  sk.define_singleton_method(:active_model) { fake_model }
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
  Object.const_set(:Sketchup, sk)
end

def unstub_sketchup
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
  case @__prev_sketchup
  when :__undefined__ then nil
  when Module, Class  then Object.const_set(:Sketchup, @__prev_sketchup)
  end
  @__prev_sketchup = nil
end

# --- tests ----------------------------------------------------------

test 'test_loader: first register! creates exactly one menu item' do
  FakeUI.install!
  reset_loader
  cmd = SUAnalysis::Extension::Loader.register!
  refute_nil cmd
  assert_equal 'Analyze selection', cmd.name
  plugins = UI.menu('Plugins')
  refute_nil plugins
  sub = plugins.submenus.find { |s| s.name == 'SU-AI-Plugin' }
  refute_nil sub
  assert_equal 1, sub.items.length
ensure
  FakeUI.uninstall!
end

test 'test_loader: repeated register! does NOT duplicate' do
  FakeUI.install!
  reset_loader
  SUAnalysis::Extension::Loader.register!
  SUAnalysis::Extension::Loader.register!
  SUAnalysis::Extension::Loader.register!
  plugins = UI.menu('Plugins')
  # After three register! calls, there is exactly ONE submenu
  # (the @registered sentinel prevents re-registration). Even with
  # the honest FakeMenu (no create-or-return), only the first
  # register! ever reaches add_submenu.
  submenus = plugins.submenus.select { |s| s.name == 'SU-AI-Plugin' }
  assert_equal 1, submenus.length
  assert_equal 1, submenus.first.items.length
ensure
  FakeUI.uninstall!
end

test 'test_loader: held dialog reference cleared on release' do
  FakeUI.install!
  reset_loader
  SUAnalysis::Extension::Loader.register!
  fake_dialog = Object.new
  SUAnalysis::Extension::Loader.keep_dialog!(fake_dialog)
  refute_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
  SUAnalysis::Extension::Loader.release_dialog!
  assert_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
ensure
  FakeUI.uninstall!
end

test 'test_loader: dialog_runner wired up via find' do
  FakeUI.install!
  reset_loader
  SUAnalysis::Extension::Loader.register!
  assert defined?(SUAnalysis::Extension::DialogRunner)
  assert SUAnalysis::Extension::Loader.respond_to?(:show_dialog_for_selection)
ensure
  FakeUI.uninstall!
end

test 'test_loader: boot entrypoint exists and uses file_loaded? guard' do
  entrypoint_path = File.expand_path('../extension/su_ai_plugin.rb', __dir__)
  assert File.exist?(entrypoint_path)
  src = File.read(entrypoint_path)
  assert src.include?('file_loaded?')
  assert src.include?('file_loaded')
  assert src.include?('SUAnalysis::Boot.boot!')
  # The file_loaded mark must be inside the success branch (after
  # boot), not before boot. Per CodeX Round 019 BLOCK-002-R2: a
  # transient boot failure should leave the loaded state unset.
  boot_idx = src.index('Boot.boot!')
  loaded_idx = src.index('file_loaded(')
  refute_nil boot_idx, 'Boot.boot! must be present in the entrypoint'
  refute_nil loaded_idx, 'file_loaded( must be present in the entrypoint'
  # Per the production logic, the literal call to `file_loaded` is
  # inside the `begin` block, AFTER the literal `Boot.boot!` call.
  assert loaded_idx > boot_idx,
         'file_loaded must be called AFTER Boot.boot! (per CodeX Round 019 BLOCK-002-R2)'
end

test 'test_loader: menu command handler is wired AND clicking it reaches the dialog' do
  # Round 019 BLOCK-002-R2: the previous version only checked the
  # command NAME; this test actually invokes the handler and asserts
  # the dialog was created.
  FakeUI.install!
  reset_loader
  SUAnalysis::Extension::Loader.register!
  plugins = UI.menu('Plugins')
  sub = plugins.submenus.find { |s| s.name == 'SU-AI-Plugin' }
  cmd = sub.items.first
  refute_nil cmd
  assert_equal 'Analyze selection', cmd.name
  stub_sketchup_with_selection
  begin
    cmd.call_handler
    assert_equal 1, FakeUI.state.dialogs.length,
                 'handler must create exactly one HtmlDialog'
    refute_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
  ensure
    unstub_sketchup
  end
ensure
  FakeUI.uninstall!
end

# --------------------------------------------------------------------------
# Round 019 BLOCK-002-R2: faithful boot test.
# - Loads extension/su_ai_plugin.rb twice (via `load`) with a
#   file_unloaded simulation between loads.
# - Asserts exactly ONE menu entry across the two loads.
# - Invokes the created command handler through to the dialog boundary.
# - The FakeMenu does NOT do create-or-return; the test would fail on
#   a real duplicate.
# --------------------------------------------------------------------------

ENTRYPOINT_PATH = File.expand_path('../extension/su_ai_plugin.rb', __dir__).freeze
ENTRY_NAME      = 'SU-AI-Plugin/extension/su_ai_plugin'.freeze

test 'test_loader: faithful boot — load entrypoint twice, one menu item, handler reaches dialog' do
  FakeUI.install!
  reset_loader
  $__file_loaded_set.clear
  stub_sketchup_with_selection
  begin
    # First load — registers the menu + command.
    load ENTRYPOINT_PATH
    plugins = UI.menu('Plugins')
    submenus = plugins.submenus.select { |s| s.name == 'SU-AI-Plugin' }
    assert_equal 1, submenus.length, "expected one submenu, got #{submenus.length}"
    assert_equal 1, submenus.first.items.length
    assert_equal true, SUAnalysis::Extension::Loader.instance_variable_get(:@registered)
    assert $__file_loaded_set[ENTRY_NAME],
           'file_loaded should be set after successful boot'

    # Invoke the command handler — must reach the dialog boundary.
    cmd = submenus.first.items.first
    cmd.call_handler
    assert_equal 1, FakeUI.state.dialogs.length,
                 'handler should create exactly one dialog'

    # Second load — entrypoint should see file_loaded? == true and
    # short-circuit. No NEW menu entry, no NEW dialog.
    load ENTRYPOINT_PATH
    plugins = UI.menu('Plugins')
    submenus = plugins.submenus.select { |s| s.name == 'SU-AI-Plugin' }
    assert_equal 1, submenus.length, 'second load must not duplicate the submenu'
    assert_equal 1, submenus.first.items.length, 'second load must not duplicate the item'
    assert_equal 1, FakeUI.state.dialogs.length, 'second load must not create extra dialogs'

    # file_unloaded (simulating the Ruby Console reset) + reset
    # Loader sentinel. We KEEP the FakeUI state so the third load's
    # add_submenu call sees the existing 'SU-AI-Plugin' submenu.
    # If FakeMenu.add_submenu were a nonstandard create-or-return,
    # the third load would reuse the existing submenu and we'd see
    # ONE. With the honest FakeMenu (always creates a NEW submenu),
    # the third load adds a second submenu — proving production
    # idempotency relies on file_loaded? + sentinel, NOT on
    # FakeMenu.find_or_create.
    file_unloaded ENTRY_NAME
    SUAnalysis::Extension::Loader.instance_variable_set(:@registered, false)
    load ENTRYPOINT_PATH
    plugins = UI.menu('Plugins')
    submenus = plugins.submenus.select { |s| s.name == 'SU-AI-Plugin' }
    assert_equal 2, submenus.length,
                 'after file_unloaded + sentinel reset, entrypoint re-registers; ' \
                 "honest FakeMenu surfaces a 2nd submenu (got #{submenus.length})"
  ensure
    unstub_sketchup
  end
ensure
  FakeUI.uninstall!
  $__file_loaded_set.clear
end
