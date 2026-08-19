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
# Per CodeX 023 (2026-08-19) MINIMUM ACCEPTABLE FIX #2, the root
# loader MUST be a conventional registration-only file whose
# essential behavior is exactly:
#
#   require 'sketchup.rb'
#   require 'extensions.rb'
#   unless file_loaded?(__FILE__)
#     extension = SketchupExtension.new('SU-AI-Plugin', 'su_ai_plugin/main')
#     # metadata...
#     Sketchup.register_extension(extension, true)
#     file_loaded(__FILE__)
#   end
#
# - SketchupExtension.new's load target is a String
#   (NOT an Array); the relative no-extension path
#   'su_ai_plugin/main' (resolved against __dir__).
# - The registration is GUARDED by `unless file_loaded?(__FILE__)`
#   to prevent duplicate registration on REPL re-evaluation.
# - No operational boot code lives here (extension/su_ai_plugin/
#   main.rb is the boot target).
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
# SketchUp loads this file at startup. The `register_extension`
# call immediately tells SU to load 'su_ai_plugin/main' (which
# resolves to `<__dir__>/su_ai_plugin/main.rb` at install time)
# — the boot target.
#

# Per the standard SketchUp extension pattern, unconditionally
# require the SU Ruby API files. In real SU these files are
# already loaded by SU startup (the requires are no-ops). In
# the test env they resolve to the type-validating stubs in
# tests/stubs/ (placed on $LOAD_PATH by tests/runner.rb). The
# requires are NOT conditional — matching the exact CodeX 023
# pattern.
require 'sketchup.rb'
require 'extensions.rb'

# Guard: register exactly once per process. On REPL re-evaluation
# (e.g. the Owner reloads the file from Ruby Console after a
# `file_unloaded`), file_loaded? returns true and we skip the
# registration. This is the documented SketchUp Ruby API for
# guarding duplicate loads. We use `__FILE__` (the absolute
# path of this .rb file) as the key, NOT a hand-written
# constant, so the guard is keyed to the file's own identity.
unless file_loaded?(__FILE__)
  # Define the SketchupExtension object. Per CodeX 023
  # BLOCK-023-001: the second argument MUST be a String (the
  # relative path to the support folder's main file, WITHOUT
  # the `.rb` extension), NOT an Array. SketchUp resolves the
  # relative path against the .rb loader's directory
  # (`__dir__`), so 'su_ai_plugin/main' resolves to
  # `<__dir__>/su_ai_plugin/main.rb` at install time.
  module SUAnalysis
    module SUAIPlugin
      # The SketchupExtension object. The `name` is shown in
      # the Extension Manager (matches the .rb / folder base
      # name per the standard contract).
      EXTENSION = SketchupExtension.new(
        'SU-AI-Plugin',
        'su_ai_plugin/main'
      )

      # Metadata (per the CodeX 023 example `# metadata...`
      # placeholder). The Extension Manager displays these.
      # In real SU the user can edit these via the EM UI; they
      # are advisory metadata, not load-time requirements. The
      # type-validating test stub (tests/stubs/extensions.rb)
      # ignores them; the loader does not depend on them.
      def self.version
        '1.0.0'
      end

      def self.creator
        'SU-AI-Plugin Dev Team'
      end

      def self.description
        'Read-only CAD analyzer: geometry issues + locate.'
      end
    end
  end

  # Register the extension. The second arg `true` means "load
  # now": SketchUp immediately loads the extension's files when
  # registered. (The load target is 'su_ai_plugin/main' which
  # resolves to su_ai_plugin/main.rb at install time.)
  Sketchup.register_extension(SUAnalysis::SUAIPlugin::EXTENSION, true)

  # Mark this file as loaded to prevent double-registration on
  # REPL re-evaluation. The `file_loaded(__FILE__)` call uses
  # the absolute path of this file, matching the `file_loaded?`
  # check above. This is the standard SketchUp Ruby API for
  # guarding duplicate loads.
  file_loaded(__FILE__)
end