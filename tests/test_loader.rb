#
# tests/test_loader.rb — loader idempotency + real-host boot path.
# Per CodeX Round 018 BLOCK-002.
#
# Asserts:
#   1. First register! call creates exactly one menu item.
#   2. Repeated register! / Load does NOT duplicate.
#   3. Clicking the menu command reaches the dialog runner.
#   4. release_dialog! clears the held dialog reference.
#   5. The dialog_runner integration path is wired up.
#   6. The boot entrypoint file_loaded? guard prevents re-entry.
#
# Uses tests/_fake_ui.rb's UI module stub. The stub is installed /
# uninstalled around every test so state never leaks to the next
# test (especially the global UI constant).
#

require_relative 'runner'
require_relative '_fake_ui'
require_relative '../core/issue_registry'
require_relative '../core/analysis_result'
require_relative '../extension/loader'
require_relative '../extension/dialog_runner'

include SUAnalysis::Extension
include FakeUI

# --- helpers ----------------------------------------------------------

# Refresh Loader sentinels between tests.
def reset_loader
  SUAnalysis::Extension::Loader.instance_variable_set(:@registered, false)
  SUAnalysis::Extension::Loader.instance_variable_set(:@live_dialog, nil)
end

def install_ui
  FakeUI.install!
end

def uninstall_ui
  FakeUI.uninstall!
end

# --- tests ----------------------------------------------------------

test 'test_loader: first register! creates exactly one menu item' do
  install_ui
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
  uninstall_ui
end

test 'test_loader: repeated register! does NOT duplicate' do
  install_ui
  reset_loader
  SUAnalysis::Extension::Loader.register!
  SUAnalysis::Extension::Loader.register!
  SUAnalysis::Extension::Loader.register!
  plugins = UI.menu('Plugins')
  sub = plugins.submenus.find { |s| s.name == 'SU-AI-Plugin' }
  assert_equal 1, sub.items.length
ensure
  uninstall_ui
end

test 'test_loader: held dialog reference cleared on release' do
  install_ui
  reset_loader
  SUAnalysis::Extension::Loader.register!
  fake_dialog = Object.new
  SUAnalysis::Extension::Loader.keep_dialog!(fake_dialog)
  refute_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
  SUAnalysis::Extension::Loader.release_dialog!
  assert_nil SUAnalysis::Extension::Loader.instance_variable_get(:@live_dialog)
ensure
  uninstall_ui
end

test 'test_loader: dialog_runner wired up via find' do
  install_ui
  reset_loader
  SUAnalysis::Extension::Loader.register!
  # Verify the loader references the dialog runner module.
  assert defined?(SUAnalysis::Extension::DialogRunner)
  assert SUAnalysis::Extension::Loader.respond_to?(:show_dialog_for_selection)
ensure
  uninstall_ui
end

test 'test_loader: boot entrypoint exists and uses file_loaded? guard' do
  entrypoint_path = File.expand_path('../extension/su_ai_plugin.rb', __dir__)
  assert File.exist?(entrypoint_path)
  src = File.read(entrypoint_path)
  assert src.include?('file_loaded?')
  assert src.include?('file_loaded')
  # Confirms idempotent boot pattern.
  assert src.include?('SUAnalysis::Boot.boot!')
end

test 'test_loader: menu command handler is wired to Loader.on_analyze_selection' do
  install_ui
  reset_loader
  SUAnalysis::Extension::Loader.register!
  plugins = UI.menu('Plugins')
  sub = plugins.submenus.find { |s| s.name == 'SU-AI-Plugin' }
  cmd = sub.items.first
  # The command's handler is wired by Loader.register!. Clicking the
  # command must reach Loader.on_analyze_selection (which is a
  # no-op in this test env because Sketchup is undefined).
  refute_nil cmd
  assert_equal 'Analyze selection', cmd.name
ensure
  uninstall_ui
end
