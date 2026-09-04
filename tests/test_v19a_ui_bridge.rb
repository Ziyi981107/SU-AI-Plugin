#
# tests/test_v19a_ui_bridge.rb
#
# V1.9A-A1 — additive `cadPrepWorkflow` payload at the
# UIBridge boundary. Verifies:
#   - cadPrepWorkflow exists as a top-level key;
#   - JSON-safe (no Symbol / live SU objects);
#   - legacy keys (selectionType, summary, groups,
#     layerGroups, layerIssueGroups, faceInventoryGroups,
#     derivedWorkspace) remain available unchanged;
#   - the presenter does NOT silently swallow a bad
#     snapshot — it emits a STALE recovery payload instead.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/issue_normalizer'
require_relative '../extension/su_ai_plugin/core/issue_enricher'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/ui_bridge'

include SUAnalysis::Core
include SUAnalysis::Extension

# --- helpers --------------------------------------------------------

def v19a_b_make_issue(id, type: 'short_edge', severity: 'low')
  {
    issue_id:          id,
    issue_type:        type,
    severity:          severity,
    confidence:        'high',
    sources:           [],
    source_entity_ids: [],
    edge_ids:          [],
    location:          nil,
    message:           'm',
    metadata:          {},
    locatable:         false,
    display_length:    nil
  }
end

def v19a_b_make_result
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count, :face_count, :faces_with_holes_count).new(10, 12, 0, 0, 0, 0)
  reg = IssueRegistry.new([v19a_b_make_issue('short_edge|1|1')])
  AnalysisResult.new(preflight: pf, registry: reg,
                     selection_type: 'Group', selection_label: '别墅平面图')
end

# --- legacy keys preserved -----------------------------------------

test 'v19a_bridge: legacy top-level keys are unchanged (V1.0-V1.8 backward compat)' do
  result = v19a_b_make_result
  payload = UIBridge.as_html_data(result)
  expected_legacy = %w[selectionType selectionLabel summary displayData diagnostics
                       groups layerGroups layerIssueGroups faceInventoryGroups
                       derivedWorkspace]
  expected_legacy.each do |k|
    assert payload.key?(k), "legacy key #{k.inspect} MUST be present"
  end
end

# --- cadPrepWorkflow is added on top ------------------------------

test 'v19a_bridge: cadPrepWorkflow top-level key is present' do
  payload = UIBridge.as_html_data(v19a_b_make_result)
  assert payload.key?('cadPrepWorkflow'),
         "expected top-level 'cadPrepWorkflow' key, got #{payload.keys.inspect}"
end

test 'v19a_bridge: cadPrepWorkflow has the locked schema_version' do
  payload = UIBridge.as_html_data(v19a_b_make_result)
  assert_equal '1', payload['cadPrepWorkflow']['schema_version']
end

test 'v19a_bridge: cadPrepWorkflow carries selection / overall_state / cards / issue_summary / recovery' do
  payload = UIBridge.as_html_data(v19a_b_make_result)
  wf = payload['cadPrepWorkflow']
  %w[overall_state headline subheadline selection issue_summary cards recovery schema_version].each do |k|
    assert wf.key?(k), "cadPrepWorkflow missing #{k.inspect}"
  end
end

test 'v19a_bridge: cadPrepWorkflow.cards is exactly 5 in the locked order' do
  payload = UIBridge.as_html_data(v19a_b_make_result)
  cards = payload['cadPrepWorkflow']['cards']
  assert_equal 5, cards.length
  assert_equal %w[duplicate_cleanup planar_normalization gap_endpoint structure_region other],
               cards.map { |c| c['id'] }
end

# --- JSON-safety ---------------------------------------------------

test 'v19a_bridge: cadPrepWorkflow has no Symbol / live-object leakage' do
  payload = UIBridge.as_html_data(v19a_b_make_result)
  wf = payload['cadPrepWorkflow']
  walker = ->(obj, path) {
    case obj
    when Hash
      obj.each do |k, v|
        assert k.is_a?(String), "non-String key at #{path}.#{k.inspect}"
        walker.call(v, "#{path}.#{k}")
      end
    when Array
      obj.each_with_index { |v, i| walker.call(v, "#{path}[#{i}]") }
    when String, Numeric, TrueClass, FalseClass, NilClass
      # OK
    else
      raise "non-JSON-safe value at #{path}: #{obj.class}"
    end
  }
  walker.call(wf, '$')
end

test 'v19a_bridge: cadPrepWorkflow round-trips through JSON.generate + JSON.parse' do
  require 'json'
  result = v19a_b_make_result
  json = UIBridge.to_json(result)
  parsed = JSON.parse(json)
  assert_equal 5, parsed['cadPrepWorkflow']['cards'].length
  assert_equal '别墅平面图', parsed['cadPrepWorkflow']['selection']['label']
end

# --- presenter fault tolerance ------------------------------------

test 'v19a_bridge: presenter exception falls back to a STALE recovery payload (no crash)' do
  # Force the presenter to raise by stubbing its module method.
  mod = SUAnalysis::Extension::CadPrepWorkflowPresenter
  mod.singleton_class.send(:define_method, :present) do |_args|
    raise 'synthetic presenter failure'
  end
  begin
    payload = UIBridge.as_html_data(v19a_b_make_result)
    wf = payload['cadPrepWorkflow']
    refute_nil wf
    assert_equal 'STALE', wf['overall_state'],
                 'presenter fault MUST surface as STALE recovery state'
    refute_nil wf['recovery'], 'presenter fault MUST carry a recovery banner'
    assert_equal 'rebuild_workspace', wf['recovery']['primary_callback']
  ensure
    # Restore the original present method.
    load 'extension/su_ai_plugin/cad_prep_workflow_presenter.rb'
  end
end
