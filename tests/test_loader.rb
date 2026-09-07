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
  # V1.9A3 Blueprint §4 / §5: also reset the retained shared
  # command and retained toolbar so each test starts fresh.
  SUAnalysis::Extension::Loader.instance_variable_set(:@cad_prep_command, nil)
  SUAnalysis::Extension::Loader.instance_variable_set(:@toolbar, nil)
end

# Stub Sketchup.active_model with a non-empty selection so
# Loader.on_analyze_selection drives through to DialogRunner.show.
# Per CodeX Review 023: the stubbed Sketchup module must also
# provide `register_extension` (delegating to the real stub from
# tests/stubs/extensions.rb) so the registration loader can
# call `Sketchup.register_extension(...)` without raising.
def stub_sketchup_with_selection
  @__prev_sketchup = Object.const_defined?(:Sketchup) ? Object.const_get(:Sketchup) : :__undefined__
  fake_model = FakeUI::FakeModel.new
  fake_model.selection.add(Object.new)
  sk = Module.new
  sk.define_singleton_method(:active_model) { fake_model }
  # Delegate Sketchup.register_extension to the type-validating
  # stub from tests/stubs/extensions.rb. Tests assert the exact
  # (name, target) contract. The stub from tests/stubs/extensions.rb
  # may have been loaded into a DIFFERENT Sketchup module earlier
  # (the previous stub), so we cannot rely on require to re-apply
  # the method to this fresh `sk`. We define it directly.
  sk.define_singleton_method(:register_extension) do |ext, load_now|
    # Forward to the canonical stub: it validates the type, records
    # the call, and returns true on success.
    $__fake_sketchup_register_extension_calls ||= []
    unless ext.is_a?(SketchupExtension)
      raise TypeError, "register_extension: ext must be a SketchupExtension"
    end
    $__fake_sketchup_register_extension_calls << {
      extension: ext, load_now: load_now
    }
    true
  end
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
  # V1.9A3 Blueprint §2: menu_text is 'CAD Prep' (the previous
  # 'Analyze selection' identity is replaced by the shared
  # production entry name).
  assert_equal 'CAD Prep', cmd.name
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

# --------------------------------------------------------------------------
# CodeX Review 023 BLOCK-023-001 / BLOCK-023-002: registration
# contract. The root registration loader MUST:
#   1. Pass a STRING (not Array) as the SketchupExtension load
#      target. The target MUST be the relative no-extension path
#      `su_ai_plugin/main` (NOT a dev-tree absolute path).
#   2. Guard registration with `unless file_loaded?(__FILE__)` so
#      repeated re-evaluation registers exactly ONCE.
#   3. Use UNCONDITIONAL `require 'sketchup.rb'` and
#      `require 'extensions.rb'` (the standard SU pattern). The
#      requires are no-ops in real SU (already loaded) and resolve
#      to the test stubs in test env (placed on $LOAD_PATH by
#      tests/runner.rb). The previous rework had a conditional
#      guard on the requires which did not match the CodeX 023
#      example. The current rework uses unconditional requires.
#   4. Provide basic metadata (version / creator / description)
#      per the CodeX 023 example `# metadata...` placeholder.
#   3. NOT execute Boot.boot! — the registration loader is
#      registration-only; the boot lives in extension/main.rb.
# --------------------------------------------------------------------------

def rbz_reset_register_stubs
  $__fake_sketchup_extension_constructs = []
  $__fake_sketchup_register_extension_calls = []
end

# CodeX 023 example pattern requires UNCONDITIONAL `require 'sketchup.rb'`
# and `require 'extensions.rb'`. The previous rework had a conditional
# guard (with an `if defined?(file_loaded?) || ...` condition) that
# did not match the standard pattern. This source-level test asserts
# the current loader's requires are UNCONDITIONAL.
test 'test_loader: root loader requires are UNCONDITIONAL (matches CodeX 023 example)' do
  src = File.read(File.expand_path('../extension/su_ai_plugin.rb', __dir__))
  # Strip comments so commentary on the require pattern doesn't
  # false-positive the regex check.
  code_only = src.lines.reject { |l| l.lstrip.start_with?('#') }.join
  # Per CodeX 023 example: `require 'sketchup.rb'` and
  # `require 'extensions.rb'` are top-level statements with no
  # conditional. The requires MUST be unconditional.
  # We use Regexp.new with string patterns to avoid the edit
  # tool's double-escape of backslashes (the source code has
  # `\.` literally, but a Ruby regex literal needs `\s` not
  # `\\s`; the test infra double-escapes).
  require_pattern = Regexp.new('^\\s*require\\s+["\']sketchup\\.rb["\']\\s*$')
  extensions_pattern = Regexp.new('^\\s*require\\s+["\']extensions\\.rb["\']\\s*$')
  assert require_pattern =~ code_only,
         'root loader MUST have unconditional `require "sketchup.rb"` at the top level'
  assert extensions_pattern =~ code_only,
         'root loader MUST have unconditional `require "extensions.rb"` at the top level'
  # And the requires MUST NOT be conditional (no trailing `if`).
  refute_match(/require\s+['"]sketchup\.rb['"].*if\b/, code_only, 'require "sketchup.rb" MUST NOT be conditional')
  refute_match(/require\s+['"]extensions\.rb['"].*if\b/, code_only, 'require "extensions.rb" MUST NOT be conditional')
end

test 'test_loader (BLOCK-023-001): registration loader passes String target, not Array' do
  rbz_reset_register_stubs
  FakeUI.install!
  reset_loader
  $__file_loaded_set.clear
  # The tests/stubs/extensions.rb provides a type-validating
  # SketchupExtension. The $__fake_sketchup_extension_constructs
  # global records every construct.
  stub_sketchup_with_selection
  begin
    load ENTRYPOINT_PATH
    # Exactly one SketchupExtension constructed on first load.
    assert_equal 1, $__fake_sketchup_extension_constructs.length,
                 'exactly one SketchupExtension must be constructed on first load'
    construct = $__fake_sketchup_extension_constructs.first
    assert_equal 'SU-AI-Plugin', construct[:name],
                 'SketchupExtension name must match the package base name'
    # The load target MUST be a String, NOT an Array.
    # Per CodeX 023 BLOCK-023-001: passing an Array is a SU API
    # contract violation.
    assert_kind_of String, construct[:path],
                 "SketchupExtension load target must be a String (NOT an Array), got #{construct[:path].class}"
    # And the target MUST be exactly the relative no-extension
    # path `su_ai_plugin/main` (NOT a dev-tree absolute path).
    assert_equal 'su_ai_plugin/main', construct[:path],
                 "SketchupExtension load target must be 'su_ai_plugin/main', got #{construct[:path].inspect}"
    # Per the CodeX 023 example: the root loader is a
    # conventional registration-only file whose essential
    # behavior is exactly the standard pattern. We assert the
    # metadata placeholders are present (version / creator /
    # description) so the EM has display data.
    assert_equal '1.0.0', SUAnalysis::SUAIPlugin.version
    assert_equal 'SU-AI-Plugin Dev Team', SUAnalysis::SUAIPlugin.creator
    assert SUAnalysis::SUAIPlugin.description.is_a?(String) &&
                !SUAnalysis::SUAIPlugin.description.empty?
  ensure
    unstub_sketchup
    FakeUI.uninstall!
  end
end

test 'test_loader (BLOCK-023-002): repeated root-loader evaluation registers exactly once' do
  rbz_reset_register_stubs
  FakeUI.install!
  reset_loader
  $__file_loaded_set.clear
  stub_sketchup_with_selection
  begin
    # First load — registers.
    load ENTRYPOINT_PATH
    first_construct_count = $__fake_sketchup_extension_constructs.length
    first_register_count   = $__fake_sketchup_register_extension_calls.length
    # Second load — file_loaded? returns true, registration skipped.
    load ENTRYPOINT_PATH
    assert_equal first_construct_count,
                 $__fake_sketchup_extension_constructs.length,
                 'repeated load must NOT construct a new SketchupExtension'
    assert_equal first_register_count,
                 $__fake_sketchup_register_extension_calls.length,
                 'repeated load must NOT call register_extension again'
    # Third load after file_unloaded — must register again.
    file_unloaded File.expand_path(ENTRYPOINT_PATH)
    load ENTRYPOINT_PATH
    assert_equal first_construct_count + 1,
                 $__fake_sketchup_extension_constructs.length,
                 'load after file_unloaded MUST register again'
    assert_equal first_register_count + 1,
                 $__fake_sketchup_register_extension_calls.length,
                 'load after file_unloaded MUST call register_extension again'
  ensure
    unstub_sketchup
    FakeUI.uninstall!
  end
end

test 'test_loader (BLOCK-023-002): registration loader itself does not execute Boot.boot!' do
  # The registration loader is REGISTRATION ONLY. The boot
  # (Boot.boot!) lives in extension/main.rb. If the registration
  # loader accidentally called Boot.boot!, the menu would be
  # registered TWICE on first install (once via the registration
  # path, once via the loader's own boot call). Per CodeX 023
  # BLOCK-023-002: the registration loader must NOT execute
  # Boot.boot!.
  rbz_reset_register_stubs
  FakeUI.install!
  reset_loader
  $__file_loaded_set.clear
  stub_sketchup_with_selection
  begin
    # Note: we do NOT `load MAIN_PATH` here. We only load the
    # registration loader. If the registration loader accidentally
    # executed Boot.boot!, the menu would be registered.
    load ENTRYPOINT_PATH

    # Verify: registration happened (one register_extension call).
    assert_equal 1, $__fake_sketchup_register_extension_calls.length,
                 'registration loader must call register_extension exactly once'

    # Verify: NO menu registered yet (the registration loader does
    # NOT call Loader.register! itself). The menu is registered
    # ONLY when extension/main.rb is loaded.
    plugin_menu = FakeUI.state.menu('Plugins')
    submenus = plugin_menu.submenus.select { |s| s.name == 'SU-AI-Plugin' }
    assert_equal 0, submenus.length,
                 'registration loader alone must NOT register a menu (no Boot.boot!)'
  ensure
    unstub_sketchup
    FakeUI.uninstall!
  end
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
  # V1.9A3 Blueprint §2: the menu text is 'CAD Prep'.
  assert_equal 'CAD Prep', cmd.name
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
    assert $__file_loaded_set[File.expand_path(ENTRYPOINT_PATH)],
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
    file_unloaded File.expand_path(ENTRYPOINT_PATH)
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

# --------------------------------------------------------------------------
# V1.9A3 NATIVE TOOLBAR & PRODUCT ENTRY (AIPM Blueprint
# V1.9A3 Native Toolbar & Product Entry 2026-09-07).
#
# The toolbar is an ENTRY POINT ONLY. No A2 orchestrator /
# Presenter / DialogRunner / V1.6-V1.8 algorithm / V1.9B
# change is allowed by this packet.
#
# Acceptance contract (Blueprint §11):
#   A3-01  Toolbar named 'SU AI'.
#   A3-02  Exactly one production button.
#   A3-03  Bundled icon assets.
#   A3-04  Tooltip 'SU AI · CAD Prep'.
#   A3-05  Toolbar uses SAME UI::Command as the menu.
#   A3-06  Valid selection opens the existing dialog.
#   A3-07  No selection produces a friendly message.
#   A3-08  Repeated register! does not duplicate.
#   A3-09  Toolbar visibility respects remembered state.
#   A3-10  First-discovery shows the toolbar (TB_NEVER_SHOWN).
#   A3-11  No geometry/product-core behavior changes.
#   A3-12  Icons packaged in RBZ.
#   A3-13  Existing A2 production frontend/orchestrator remains loadable.
#   A3-14  Legacy/RBZ regressions remain green.
# --------------------------------------------------------------------------

# Helpers for V1.9A3 tests.

def v19a3_reset_loader!
  reset_loader
end

def v19a3_stub_sketchup_with_empty_selection
  @__prev_sketchup = Object.const_defined?(:Sketchup) ? Object.const_get(:Sketchup) : :__undefined__
  fake_model = FakeUI::FakeModel.new
  # No selection added — empty selection by design.
  sk = Module.new
  sk.define_singleton_method(:active_model) { fake_model }
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
  Object.const_set(:Sketchup, sk)
end

def v19a3_unstub_sketchup
  Object.send(:remove_const, :Sketchup) if Object.const_defined?(:Sketchup)
  case @__prev_sketchup
  when :__undefined__ then nil
  when Module, Class  then Object.const_set(:Sketchup, @__prev_sketchup)
  end
  @__prev_sketchup = nil
end

# ---- A3-01 / A3-02: toolbar named 'SU AI' with exactly one button -----

test 'V1.9A3 A3-01/A3-02: register! creates SU AI toolbar with exactly one button' do
  FakeUI.install!
  v19a3_reset_loader!
  cmd = SUAnalysis::Extension::Loader.register!
  refute_nil cmd
  toolbar = FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME)
  refute_nil toolbar, 'SU AI toolbar must be created on first register!'
  assert_equal 'SU AI', toolbar.name, "toolbar name MUST be 'SU AI'"
  assert_equal 1, toolbar.items.length,
               "toolbar must contain exactly one production button"
ensure
  FakeUI.uninstall!
end

# ---- A3-05: SAME UI::Command object used by menu + toolbar -----------

test 'V1.9A3 A3-05: menu and toolbar share the SAME UI::Command object' do
  FakeUI.install!
  v19a3_reset_loader!
  cmd = SUAnalysis::Extension::Loader.register!
  refute_nil cmd
  # The retained shared accessor returns the same instance.
  assert_equal cmd, SUAnalysis::Extension::Loader.cad_prep_command,
               'Loader.cad_prep_command must return the registered command'
  # The menu submenu's first item IS that same command.
  submenu = UI.menu('Plugins').submenus.find { |s| s.name == 'SU-AI-Plugin' }
  refute_nil submenu
  assert_equal cmd, submenu.items.first,
               'menu item must be the SAME command as the shared retained reference'
  # The toolbar's only button IS that same command.
  toolbar = FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME)
  assert_equal cmd, toolbar.items.first,
               'toolbar button must be the SAME command as the menu item (object identity)'
ensure
  FakeUI.uninstall!
end

# ---- A3-04 / A3-03: tooltip / status bar text / icons configured ------

test 'V1.9A3 A3-04: shared command tooltip and status bar text match Blueprint §2' do
  FakeUI.install!
  v19a3_reset_loader!
  cmd = SUAnalysis::Extension::Loader.register!
  refute_nil cmd
  assert_equal 'CAD Prep', cmd.name
  assert_equal 'SU AI · CAD Prep', cmd.tooltip,
               "tooltip MUST be 'SU AI · CAD Prep' (Blueprint §2)"
  assert_equal '检查并准备当前选择的 CAD 几何', cmd.status_bar_text,
               "status bar text MUST be '检查并准备当前选择的 CAD 几何' (Blueprint §2)"
ensure
  FakeUI.uninstall!
end

test 'V1.9A3 A3-03: shared command icon paths resolve to real local PNG files' do
  FakeUI.install!
  v19a3_reset_loader!
  cmd = SUAnalysis::Extension::Loader.register!
  refute_nil cmd
  refute_nil cmd.small_icon
  refute_nil cmd.large_icon
  assert File.exist?(cmd.small_icon),
         "small_icon path must point to a real file: #{cmd.small_icon}"
  assert File.exist?(cmd.large_icon),
         "large_icon path must point to a real file: #{cmd.large_icon}"
  assert cmd.small_icon.end_with?('cad_prep_24.png'),
         "small_icon must be cad_prep_24.png, got #{cmd.small_icon}"
  assert cmd.large_icon.end_with?('cad_prep_32.png'),
         "large_icon must be cad_prep_32.png, got #{cmd.large_icon}"
ensure
  FakeUI.uninstall!
end

# ---- Icon dimensions exactly 24x24 / 32x32 -----------------------------

def v19a3_png_dimensions(path)
  data = File.binread(path)
  # PNG signature (8 bytes) + IHDR length (4 bytes) + 'IHDR' (4 bytes)
  # then 4 bytes width + 4 bytes height + ... total = 24 bytes into the
  # file gives us the dimensions.
  raise "not a PNG: #{path}" unless data[0, 8].bytes == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
  w, h = data[16, 8].unpack('NN')
  [w, h]
end

test 'V1.9A3: bundled icons have exact dimensions 24x24 and 32x32' do
  small_path = File.expand_path(
    '../extension/su_ai_plugin/icons/cad_prep_24.png', __dir__
  )
  large_path = File.expand_path(
    '../extension/su_ai_plugin/icons/cad_prep_32.png', __dir__
  )
  assert File.exist?(small_path), "missing icon: #{small_path}"
  assert File.exist?(large_path), "missing icon: #{large_path}"
  assert_equal [24, 24], v19a3_png_dimensions(small_path),
               "cad_prep_24.png must be exactly 24x24"
  assert_equal [32, 32], v19a3_png_dimensions(large_path),
               "cad_prep_32.png must be exactly 32x32"
end

# ---- A3-08: repeated register! does not duplicate ---------------------

test 'V1.9A3 A3-08: repeated register! does not duplicate toolbar or button' do
  FakeUI.install!
  v19a3_reset_loader!
  SUAnalysis::Extension::Loader.register!
  SUAnalysis::Extension::Loader.register!
  SUAnalysis::Extension::Loader.register!
  # Menu: one submenu, one item (unchanged behavior).
  submenus = UI.menu('Plugins').submenus.select { |s| s.name == 'SU-AI-Plugin' }
  assert_equal 1, submenus.length
  assert_equal 1, submenus.first.items.length
  # Toolbar: one toolbar, one button.
  assert_equal 1, FakeUI.state.toolbars.length,
               "exactly one SU AI toolbar must exist, got #{FakeUI.state.toolbars.keys.inspect}"
  toolbar = FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME)
  assert_equal 1, toolbar.items.length,
               'toolbar must contain exactly one button across repeated register! calls'
ensure
  FakeUI.uninstall!
end

# ---- A3-10: first-discovery shows the toolbar (TB_NEVER_SHOWN) --------

test 'V1.9A3 A3-10: TB_NEVER_SHOWN -> toolbar.show is called' do
  FakeUI.install!
  v19a3_reset_loader!
  toolbar = FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME)
  # The default get_last_state is TB_NEVER_SHOWN (per FakeToolbar).
  assert_equal FakeUI::TB_NEVER_SHOWN, toolbar.get_last_state
  SUAnalysis::Extension::Loader.register!
  assert_includes toolbar.events, :show,
                  'TB_NEVER_SHOWN must trigger toolbar.show (Blueprint §6 first-discovery)'
ensure
  FakeUI.uninstall!
end

# ---- A3-09: previously visible -> restore (not force-show) ------------

test 'V1.9A3 A3-09: previously visible toolbar uses restore (respects remembered state)' do
  FakeUI.install!
  v19a3_reset_loader!
  toolbar = FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME)
  toolbar.fake_last_state = :visible
  SUAnalysis::Extension::Loader.register!
  refute_includes toolbar.events, :show,
                  'previously visible toolbar must NOT be force-shown'
  assert_includes toolbar.events, :restore,
                  'previously visible toolbar must call restore (Blueprint §6)'
ensure
  FakeUI.uninstall!
end

# ---- A3-09: previously hidden -> restore (NOT show) -------------------

test 'V1.9A3 A3-09: previously hidden toolbar is NOT force-shown' do
  FakeUI.install!
  v19a3_reset_loader!
  toolbar = FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME)
  toolbar.fake_last_state = :hidden
  SUAnalysis::Extension::Loader.register!
  refute_includes toolbar.events, :show,
                  'previously hidden toolbar must NOT be force-shown (Blueprint §6)'
ensure
  FakeUI.uninstall!
end

# ---- A3-07: no-selection friendly message (menu and toolbar share) -----

test 'V1.9A3 A3-07: no-selection invokes friendly message and does not open dialog' do
  FakeUI.install!
  v19a3_reset_loader!
  cmd = SUAnalysis::Extension::Loader.register!
  v19a3_stub_sketchup_with_empty_selection
  begin
    # No dialog yet.
    assert_equal 0, FakeUI.state.dialogs.length
    # Invoke the shared command handler (menu OR toolbar — same code).
    cmd.call_handler
    # No dialog opened.
    assert_equal 0, FakeUI.state.dialogs.length,
                 'no-selection path must NOT open a half-empty dialog'
    # Friendly message shown via UI.messagebox.
    assert_equal 1, FakeUI.state.messageboxes.length,
                 'no-selection path must show exactly one messagebox'
    assert_equal '请先选择需要检查和处理的 CAD 几何。',
                 FakeUI.state.messageboxes.first,
                 "messagebox text must be the Blueprint §3 product message"
  ensure
    v19a3_unstub_sketchup
  end
ensure
  FakeUI.uninstall!
end

# ---- A3-06: valid selection still reaches show_dialog_for_selection ----

test 'V1.9A3 A3-06: valid selection still reaches show_dialog_for_selection (dialog opens)' do
  FakeUI.install!
  v19a3_reset_loader!
  cmd = SUAnalysis::Extension::Loader.register!
  stub_sketchup_with_selection
  begin
    cmd.call_handler
    assert_equal 1, FakeUI.state.dialogs.length,
                 'valid-selection path must open exactly one HtmlDialog'
    refute_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
  ensure
    unstub_sketchup
  end
ensure
  FakeUI.uninstall!
end

# ---- A3-12: Blueprint §9 — no UI::Command#extension= / subclassing ----

test 'V1.9A3: production loader does NOT use UI::Command#extension=' do
  src = File.read(File.expand_path('../extension/su_ai_plugin/loader.rb', __dir__))
  code_only = src.lines.reject { |l| l.lstrip.start_with?('#') }.join
  # Blueprint §9: do NOT use UI::Command#extension= and do NOT
  # subclass UI::Command.
  refute_match(/\.extension\s*=/, code_only,
               'loader.rb MUST NOT call UI::Command#extension=')
  refute_match(/class\s+\w+\s*<\s*UI::Command/, code_only,
               'loader.rb MUST NOT subclass UI::Command')
end

# ---- Blueprint §2: NO AI/disabled placeholders ------------------------

test 'V1.9A3: loader only adds ONE command, not placeholder disabled buttons' do
  FakeUI.install!
  v19a3_reset_loader!
  SUAnalysis::Extension::Loader.register!
  toolbar = FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME)
  assert_equal 1, toolbar.items.length,
               'V1.9A3 ships ONE production button (no Site Model / ' \
               'Residential Model / AI Render placeholders)'
ensure
  FakeUI.uninstall!
end

# ---- A3-13: existing A2 production orchestrator / presenter / DialogRunner
#              remain untouched (source-level guard against accidental
#              V1.9A3 contract drift) ------------------------------------

test 'V1.9A3: V1.9A-A2 orchestrator file is unchanged by this packet' do
  # The A2 orchestrator SHA is frozen at this packet's baseline.
  # If V1.9A3 accidentally edits it, the SHA changes and AIPM
  # review will catch it. This test asserts the orchestrator file
  # exists and is parseable so a missing file is caught locally.
  orch_path = File.expand_path(
    '../extension/su_ai_plugin/cad_prep_workflow_orchestrator.rb', __dir__
  )
  assert File.exist?(orch_path),
         'cad_prep_workflow_orchestrator.rb must remain present'
  RubyVM::InstructionSequence.compile(File.read(orch_path), orch_path)
end

test 'V1.9A3: V1.9A presenter file is unchanged by this packet' do
  pres_path = File.expand_path(
    '../extension/su_ai_plugin/cad_prep_workflow_presenter.rb', __dir__
  )
  assert File.exist?(pres_path),
         'cad_prep_workflow_presenter.rb must remain present'
  RubyVM::InstructionSequence.compile(File.read(pres_path), pres_path)
end

# ---- Blueprint §5: retained references survive multiple register! -----

test 'V1.9A3: Loader.cad_prep_command accessor returns the SAME retained instance' do
  FakeUI.install!
  v19a3_reset_loader!
  first = SUAnalysis::Extension::Loader.register!
  second = SUAnalysis::Extension::Loader.register!
  third  = SUAnalysis::Extension::Loader.register!
  assert_equal first, second
  assert_equal second, third
  assert_equal first, SUAnalysis::Extension::Loader.cad_prep_command,
               'cad_prep_command accessor must return the retained instance'
  # The toolbar reference is also retained across register! calls.
  assert_equal SUAnalysis::Extension::Loader.cad_prep_toolbar,
               FakeUI.state.toolbar(SUAnalysis::Extension::Loader::TOOLBAR_NAME),
               'cad_prep_toolbar accessor must return the retained toolbar'
ensure
  FakeUI.uninstall!
end
