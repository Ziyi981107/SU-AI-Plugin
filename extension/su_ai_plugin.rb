#
# extension/su_ai_plugin.rb — Root registration loader for the
# SU-AI-Plugin SketchUp extension.
#
# Per CodeX Review 022 (2026-08-19) BLOCK-022-001: the .rbz has
# exactly one root .rb (this file) and a same-named support folder
# `su_ai_plugin/`. This loader's ONLY job is to define a
# SketchupExtension and register it with `Sketchup.register_extension`.
# No operational plugin code lives here.
#
# The standard SketchUp extension contract requires:
#   - One root `.rb` loader (this file).
#   - One same-named support folder (`su_ai_plugin/`) containing
#     `main.rb` (the boot implementation).
#
# Layout inside the installed .rbz (after SketchUp extracts it):
#
#   <Plugins>/
#     su_ai_plugin.rb               # this file (registration only)
#     su_ai_plugin/                 # support folder (same base name)
#       main.rb                     # boot implementation
#       loader.rb
#       core/...
#       compatibility/...
#       html/...
#
# SketchUp loads this file at startup (when the .rbz is installed).
# After registration, SketchUp immediately loads `main.rb` via
# the registered load target.
#

# Per the SketchUp extension contract, this file is loaded by
# SketchUp's Extension Manager at startup. Inside real SketchUp,
# the Sketchup module + SketchupExtension class are already loaded
# into the Ruby process BEFORE the extension's root .rb runs.
# Therefore we do NOT need to `require 'sketchup.rb'` /
# `require 'extensions.rb'` — those requires are for standalone
# scripts that initialize the SU environment, NOT for extensions.
#
# We do still guard against the registration block: in real SU,
# `SketchupExtension` is defined (the class is loaded by SU startup).
# In the test environment (FakeUI), we may stub `Sketchup` without
# defining `SketchupExtension`; in that case the registration block
# is skipped (test environment exercises the BOOT path through
# extension/main.rb + Loader.register!, not the EM registration path).

# Compute the main.rb path. __dir__ is the directory containing
# THIS file (e.g. SketchUp/Plugins/ in production, or the build's
# staging area in dev). The support folder is a sibling named
# `su_ai_plugin/`. The main entry-point is `<__dir__>/su_ai_plugin/main.rb`.
main_path = File.join(__dir__, 'su_ai_plugin', 'main.rb')

# SketchUp APIs (SketchupExtension + register_extension) are ONLY
# available inside real SketchUp. In real SketchUp BOTH `Sketchup`
# and `SketchupExtension` are defined by SU startup. The test
# environment (FakeUI) stubs `Sketchup` but does NOT define
# `SketchupExtension`, so the registration block is skipped in
# tests. The test environment exercises the BOOT path
# (extension/main.rb + Loader.register!) via FakeUI; it does NOT
# exercise the Extension Manager registration path.
if defined?(SketchupExtension) && defined?(Sketchup)
  # Guard: define the SketchupExtension exactly once per process.
  # We do not want double-registration on REPL re-evaluation.
  unless defined?(SUAnalysis::SUAIPlugin::EXTENSION) &&
         SUAnalysis::SUAIPlugin::EXTENSION.is_a?(SketchupExtension)
    module SUAnalysis
      module SUAIPlugin
        # SketchupExtension object. The `name` is shown in the
        # Extension Manager (matches the .rb / folder base name).
        # The second arg is the path to the main boot file,
        # relative to the .rb loader's directory.
        EXTENSION = SketchupExtension.new(
          'SU-AI-Plugin',
          [main_path]
        )
      end
    end
  end

  # Register the extension. The second arg `true` means "load now":
  # SketchUp immediately loads the extension's files when registered.
  # (The load target is su_ai_plugin/main.rb which boots the plugin.)
  Sketchup.register_extension(SUAnalysis::SUAIPlugin::EXTENSION, true)
end

# Mark this file as loaded to prevent double-registration on REPL
# re-evaluation. file_loaded? / file_loaded is the documented
# SketchUp Ruby API for guarding duplicate loads (Round 018 BLOCK-002).
# We mark as loaded regardless of whether registration actually
# ran (test env vs real SU) so the guard works uniformly.
if defined?(file_loaded?)
  file_loaded('SU-AI-Plugin/extension/su_ai_plugin')
end