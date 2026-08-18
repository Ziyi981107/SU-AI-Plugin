#
# extension/su_ai_plugin.rb — Real SketchUp boot entrypoint.
#
# Per CodeX Round 018 BLOCK-002:
#   - This is the file SketchUp loads when the .rbz is registered.
#   - Uses `file_loaded?` / `file_loaded` (the official SketchUp Ruby
#     API for guarding duplicate loads; submenus/items introspection
#     is not reliable on the real host).
#   - Requires all Gate B dependencies in safe order.
#   - Calls Loader.register! exactly once.
#   - Is idempotent across reloads / multiple file_loaded? calls.
#
# SketchUp registers this file in the .rbz manifest. The Owner
# loads the plugin via Extension Manager; this file is the entrypoint.
#

# Guard: file_loaded? is a SketchUp top-level API; if not available
# (test environment), no-op out cleanly.
if defined?(file_loaded?) && file_loaded?('SU-AI-Plugin/extension/su_ai_plugin')
  # Already loaded; do nothing.
elsif defined?(file_loaded?)
  # First real load. Mark first to break re-entry cycles, then
  # require dependencies in safe order, then call Loader.register!
  # EXACTLY once.
  file_loaded('SU-AI-Plugin/extension/su_ai_plugin')

  # Boot path: load Gate B core + extension pieces in dependency
  # order. Failures in any require are logged and skipped (loader
  # output is best-effort inside SketchUp).
  module SUAnalysis
    module Boot
      module_function

      def boot!
        require_relative '../compatibility/su_capability'
        require_relative '../core/tolerance'
        require_relative '../core/analysis_config'
        require_relative '../core/preflight'
        require_relative '../core/analyzers/duplicate_detector'
        require_relative '../core/analyzers/short_edge_detector'
        require_relative '../core/analyzers/open_endpoint_detector'
        require_relative '../core/analyzers/gap_candidate_detector'
        require_relative '../core/issue_registry'
        require_relative '../core/issue_id_assigner'
        require_relative '../core/issue_normalizer'
        require_relative '../core/issue_enricher'
        require_relative '../core/issue_grouper'
        require_relative '../core/issue_locator_policy'
        require_relative '../core/analysis_result'
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

  begin
    SUAnalysis::Boot.boot!
  rescue StandardError => e
    # Best-effort: do not raise; Loader output is informational.
    if defined?(STDERR)
      STDERR.puts("[SU-AI-Plugin] boot failed: #{e.class}: #{e.message}")
    end
  end
end
