#
# extension/su_ai_plugin.rb — Root registration loader for the
# SU-AI-Plugin SketchUp extension.
#
# Per CodeX Review 022 (2026-08-19) BLOCK-022-001 + CodeX Review
# 023 (2026-08-19) BLOCK-023-001 / BLOCK-023-002: the .rbz has
# exactly one root .rb (this file) and a same-named support folder
# `su_ai_plugin/`. This loader's ONLY job is to define a
# SketchupExtension and register it. No operational plugin code
# lives here.
#
# The standard SketchUp extension contract requires:
#   - One root `.rb` loader (this file).
#   - One same-named support folder (`su_ai_plugin/`) containing
#     `main.rb` (the boot implementation).
#   - The SketchupExtension load target is a String (NOT an Array)
#     pointing to the support folder's main file (relative path,
#     without `.rb` extension, so SketchUp can resolve either
#     `.rb` or encrypted formats).
#   - The registration is GUARDED by `unless file_loaded?(__FILE__)`
#     to prevent duplicate registration on REPL re-evaluation.
#
# Layout inside the installed .rbz (after SketchUp extracts it):
#
#   <Plugins>/
#     su_ai_plugin.rb               # THIS file (registration only)
#     su_ai_plugin/                 # support folder (same base name)
#       main.rb                     # boot implementation
#       loader.rb
#       core/...
#       compatibility/...
#       html/...
#
# SketchUp loads this file at startup (when the .rbz is installed).
# After registration, SketchUp immediately loads `su_ai_plugin/main`
# (which is `<__dir__>/su_ai_plugin/main.rb` after SketchUp resolves
# the relative path) and that boots the plugin.
#

# Per the SketchUp extension contract, the SU Ruby API is already
# loaded into the process before the extension's root .rb runs.
# Therefore `require 'sketchup.rb'` and `require 'extensions.rb'`
# are no-ops in real SU (the files are already loaded). We keep
# them for clarity (and so that, in a script-mode SU startup, the
# constants are defined). The requires are NOT no-op'd for any
# runtime reason; they are part of the standard extension pattern.
#
# In the test environment, FakeUI does NOT define sketchup.rb /
# extensions.rb; the loader's behavior in test env is exercised
# through tests/test_loader.rb which stubs a fake Sketchup module
# (including a fake SketchupExtension class) and file_loaded? /
# file_loaded helpers.
require 'sketchup.rb' if defined?(file_loaded?) || (defined?(Sketchup) && !defined?($__su_ai_plugin_skip_sketchup_require))
require 'extensions.rb' if defined?(file_loaded?) || (defined?(Sketchup) && !defined?($__su_ai_plugin_skip_sketchup_require))

# Guard: register exactly once per process. On REPL re-evaluation
# (e.g. the Owner reloads the file from Ruby Console), file_loaded?
# returns true and we skip the registration. This is the documented
# SketchUp Ruby API for guarding duplicate loads (Round 018
# BLOCK-002). Note: we use `__FILE__` (the absolute path of this
# .rb file) so the guard is keyed to the file's own identity,
# not a hand-written constant.
unless file_loaded?(__FILE__)
  # Define the SketchupExtension object. Per CodeX 023
  # BLOCK-023-001: the second argument MUST be a String (the
  # relative path to the support folder's main file, WITHOUT the
  # `.rb` extension), NOT an Array. SketchUp resolves the relative
  # path against the .rb loader's directory (`__dir__`), so
  # `su_ai_plugin/main` resolves to `<__dir__>/su_ai_plugin/main.rb`
  # at install time.
  module SUAnalysis
    module SUAIPlugin
      EXTENSION = SketchupExtension.new(
        'SU-AI-Plugin',
        'su_ai_plugin/main'
      )
    end
  end

  # Register the extension. The second arg `true` means "load now":
  # SketchUp immediately loads the extension's files when registered.
  # (The load target is su_ai_plugin/main which resolves to
  # su_ai_plugin/main.rb at install time.)
  Sketchup.register_extension(SUAnalysis::SUAIPlugin::EXTENSION, true)

  # Mark this file as loaded to prevent double-registration on
  # REPL re-evaluation. The `file_loaded(__FILE__)` call uses
  # the absolute path of this file, matching the `file_loaded?`
  # check above.
  file_loaded(__FILE__)
end