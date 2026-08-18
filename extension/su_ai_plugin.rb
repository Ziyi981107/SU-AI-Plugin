#
# extension/su_ai_plugin.rb — Real SketchUp boot entrypoint.
#
# Per CodeX Round 018 BLOCK-002 (rework per Round 019 BLOCK-002-R2):
#   - This is the file SketchUp loads when the .rbz is registered.
#   - Uses `file_loaded?` / `file_loaded` (the official SketchUp Ruby
#     API for guarding duplicate loads; submenus/items introspection
#     is not reliable on the real host).
#   - Requires all Gate B dependencies in safe order.
#   - Calls Loader.register! exactly once.
#   - Is idempotent across reloads / multiple file_loaded? calls.
#   - **file_loaded is marked ONLY after a successful boot.** A
#     transient failure (e.g. a single require error) leaves the
#     "loaded" state unset so the next load can retry. This is the
#     safe-retry contract per CodeX Round 019 BLOCK-002-R2.
#
# SketchUp registers this file in the .rbz manifest. The Owner
# loads the plugin via Extension Manager; this file is the entrypoint.
# In the dev tree the Owner loads the same file via
# `load 'D:/Projects/SU-AI-Plugin/extension/su_ai_plugin.rb'`.
#

# Guard: file_loaded? is a SketchUp top-level API; if not available
# (test environment), fall through to a no-op out path that still
# allows the boot to attempt.
$__su_ai_plugin_entry_name = 'SU-AI-Plugin/extension/su_ai_plugin' unless defined?($__su_ai_plugin_entry_name)

# Step 1: cheap no-op if SketchUp already marked this file as loaded.
# (This is the normal case: SU loads the file once at startup.)
if defined?(file_loaded?) && file_loaded?($__su_ai_plugin_entry_name)
  # Already loaded successfully on a previous run; do nothing.
  return if false  # unreachable; keeps the if branch explicit
end

# Step 2: define the boot path. Failures are isolated to the rescue
# below so a single bad require cannot leave the plugin half-loaded.
module SUAnalysis
  unless defined?(SUAnalysis::Boot)
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
end

# Step 3: attempt the boot. Only mark file_loaded on FULL success.
# On failure, the next load retries from scratch — file_loaded? will
# still return false because we did not call file_loaded.
if defined?(file_loaded?) && file_loaded?($__su_ai_plugin_entry_name)
  # defensive re-check after module definition (covers test
  # environments that re-define file_loaded? mid-flight).
elsif defined?(file_loaded?)
  begin
    SUAnalysis::Boot.boot!
    # Success: mark loaded. Subsequent loads of this file are a no-op.
    file_loaded($__su_ai_plugin_entry_name)
  rescue StandardError => e
    # Boot failed. Do NOT mark loaded; the next load retries.
    # Print to STDERR (visible in Ruby Console) and to $stdout
    # (visible in test output) so the failure is observable.
    msg = "[SU-AI-Plugin] boot failed: #{e.class}: #{e.message}"
    if defined?(STDERR)
      STDERR.puts(msg)
    elsif $stdout.respond_to?(:puts)
      $stdout.puts(msg)
    end
  end
else
  # No file_loaded? API (test env). Best-effort boot.
  begin
    SUAnalysis::Boot.boot!
  rescue StandardError => e
    if defined?(STDERR)
      STDERR.puts("[SU-AI-Plugin] boot failed: #{e.class}: #{e.message}")
    end
  end
end
