#
# extension/main.rb — Boot implementation for the SU-AI-Plugin
# extension. This file is loaded by SketchUp after the registration
# loader `su_ai_plugin.rb` calls `Sketchup.register_extension`.
#
# Per CodeX Review 022 (2026-08-19) BLOCK-022-001: this file lives
# INSIDE the `su_ai_plugin/` support folder (sibling of the
# entry-point `su_ai_plugin.rb` at the package root). All
# require_relative paths are siblings (no `../` going outside the
# support folder). `core/` and `compatibility/` are siblings of
# THIS file inside the same support folder.
#
# Layout inside the installed .rbz:
#
#   <Plugins>/
#     su_ai_plugin.rb               # registration loader (NOT here)
#     su_ai_plugin/                 # support folder
#       main.rb                     # THIS file
#       loader.rb
#       core/...
#       compatibility/...
#       html/...
#
# SketchUp loads this file once after registration. The
# Loader.register! call has its own @registered sentinel, so
# re-loading is safe.
#

# Step 1: best-effort boot. All operational files are siblings
# of this file inside the `su_ai_plugin/` support folder.
module SUAnalysis
  unless defined?(SUAnalysis::Boot)
    module Boot
      module_function

      def boot!
        require_relative 'compatibility/su_capability'
        require_relative 'core/tolerance'
        require_relative 'core/analysis_config'
        require_relative 'core/preflight'
        require_relative 'core/analyzers/duplicate_detector'
        require_relative 'core/analyzers/short_edge_detector'
        require_relative 'core/analyzers/open_endpoint_detector'
        require_relative 'core/analyzers/gap_candidate_detector'
        require_relative 'core/issue_registry'
        require_relative 'core/issue_id_assigner'
        require_relative 'core/issue_normalizer'
        require_relative 'core/issue_enricher'
        require_relative 'core/issue_grouper'
        require_relative 'core/issue_locator_policy'
        require_relative 'core/analysis_result'
        require_relative 'analyzers_runner'
        require_relative 'issue_locator'
        require_relative 'display_unit_formatter'
        require_relative 'ui_bridge'
        require_relative 'dialog_controller'
        require_relative 'dialog_runner'
        require_relative 'loader'
        SUAnalysis::Extension::Loader.register!
      end
    end
  end
end

# Step 2: best-effort boot. Failures are isolated to the rescue
# below so a single bad require cannot leave the plugin half-loaded.
# The Loader.@registered sentinel prevents double-registration on
# re-evaluation.
begin
  SUAnalysis::Boot.boot!
rescue StandardError => e
  msg = "[SU-AI-Plugin] boot failed: #{e.class}: #{e.message}"
  if defined?(STDERR)
    STDERR.puts(msg)
  elsif $stdout.respond_to?(:puts)
    $stdout.puts(msg)
  end
end