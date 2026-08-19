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
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/loader'
require_relative '../extension/su_ai_plugin/dialog_runner'

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

test 'test_loader: root registration loader uses file_loaded? guard (no operational code)' do
  # Per CodeX Review 022 BLOCK-022-001: extension/su_ai_plugin.rb
  # is the root registration loader. Its ONLY job is to define a
  # SketchupExtension and register it. No operational plugin code
  # lives here. The boot (Boot.boot!) moved to extension/main.rb.
  entrypoint_path = File.expand_path('../extension/su_ai_plugin.rb', __dir__)
  assert File.exist?(entrypoint_path)
  # Strip comment lines so commentary on what the file does NOT
  # contain does not false-positive the regex check.
  code_only = File.readlines(entrypoint_path, encoding: 'utf-8')
    .reject { |l| l.lstrip.start_with?('#') }
    .join
  # Must use the documented file_loaded? / file_loaded guard to
  # prevent double-registration on REPL re-evaluation.
  assert code_only.include?('file_loaded?'),
         'registration loader must guard against double-load with file_loaded?'
  assert code_only.include?('file_loaded'),
         'registration loader must call file_loaded after successful registration'
  # Must NOT contain any operational plugin boot code.
  assert !code_only.include?('SUAnalysis::Boot.boot!'),
         'registration loader must NOT call Boot.boot! (boot lives in extension/main.rb)'
  assert !code_only.include?('Loader.register!'),
         'registration loader must NOT call Loader.register! (boot lives in extension/main.rb)'
  # Must reference the SketchupExtension contract.
  assert code_only.include?('SketchupExtension.new'),
         'registration loader must define a SketchupExtension object'
  assert code_only.include?('register_extension'),
         'registration loader must call Sketchup.register_extension'
end

test 'test_loader: boot main.rb uses file_loaded? guard + executes Boot.boot!' do
  # Per CodeX Review 022 BLOCK-022-001: the actual boot lives in
  # extension/su_ai_plugin/main.rb (the support-folder entry-point).
  # The boot still uses the file_loaded? guard pattern (defensive — the
  # Loader.@registered sentinel is the primary guard against
  # double-boot).
  main_path = File.expand_path('../extension/su_ai_plugin/main.rb', __dir__)
  assert File.exist?(main_path), "boot main.rb must exist at #{main_path}"
  src = File.read(main_path)
  assert src.include?('Boot.boot!'),
         'extension/main.rb must call SUAnalysis::Boot.boot!'
  assert src.include?('Loader.register!') || src.include?('SUAnalysis::Extension::Loader.register!'),
         'Boot.boot! must ultimately call Loader.register!'
  # The boot is wrapped in begin/rescue so a transient failure does
  # not leave the plugin half-loaded.
  assert src.include?('rescue StandardError'),
         'main.rb boot must wrap the boot in begin/rescue'
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
MAIN_PATH       = File.expand_path('../extension/su_ai_plugin/main.rb', __dir__).freeze
ENTRY_NAME      = 'SU-AI-Plugin/extension/su_ai_plugin'.freeze

test 'test_loader: faithful boot — load entrypoint twice, one menu item, handler reaches dialog' do
  FakeUI.install!
  reset_loader
  $__file_loaded_set.clear
  stub_sketchup_with_selection
  begin
    # First load — registration loader + boot.
    # Per CodeX Review 022: the registration loader (su_ai_plugin.rb)
    # does NOT load the boot file itself; in real SketchUp, the
    # registered SketchupExtension's load callback fires main.rb.
    # In the test env (FakeUI stubs Sketchup without the extension
    # load callback), we have to `load main.rb` explicitly to
    # exercise the same boot path.
    load ENTRYPOINT_PATH
    load MAIN_PATH
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
    load MAIN_PATH
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
    load MAIN_PATH
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
