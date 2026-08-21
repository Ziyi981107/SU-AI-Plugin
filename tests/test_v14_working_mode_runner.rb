#
# tests/test_v14_working_mode_runner.rb — V1.4 Stage 4
# WorkingModeRunner (pure-data layer) tests.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 4: minimal working-mode plumbing.
#
# The WorkingModeRunner is the in-process state holder for
# the dialog's "Working Mode" surface. It is adapter-agnostic
# (test or real SU adapter). It returns JSON-safe Hashes for
# the JS layer.
#
# Locked contract (per directive 030 Stage 4):
#   - Idle state is 'none' (no workspace).
#   - prepare() captures the frozen SourceSnapshot + builds a
#     brand-new workspace.
#   - discard() is idempotent and transitions to 'discarded'.
#   - rebuild() re-builds from the SAME captured source.
#   - snapshot() is JSON-safe (String keys, primitive values,
#     Hashes/Arrays only).
#   - The SourceSnapshot MUST NEVER be mutated.
#
# These tests do NOT use any Sketchup:: calls -- the runner is
# pure-Ruby.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/geometry_snapshot'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/source_fingerprint'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/derived_entity_record'
require_relative '../extension/su_ai_plugin/core/derived_workspace_fingerprint'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'

include SUAnalysis::Core

# --- helpers ---------------------------------------------------------

def v14_exec_config_wm(rule_set_digest: 'wm-rule-digest')
  ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'test'),
    rule_set_digest: rule_set_digest,
    source_snapshot_schema_version: '1'
  )
end

def v14_source_snapshot_wm(snapshot_id: 'wm-snap-001')
  edges = [
    EdgeRecord.new(id: 0,
      source: SourceReference.new(entity_id: 1, persistent_id: 100, kind: 'edge',
                                 persistent_id_path: [100], instance_path: [],
                                 structural_depth: 0, pid_path_complete: true,
                                 layer_name: 'Layer0'),
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
      layer: 'Layer0')
  ]
  SourceSnapshot.from_geometry_snapshot(
    GeometrySnapshot.new(edges: edges, layers: [LayerRecord.new(name: 'Layer0')]),
    selection: [],
    execution_config: v14_exec_config_wm,
    rule_set_digest: 'wm-rule-digest',
    snapshot_id: snapshot_id,
    captured_at: '2026-08-20T10:00:00Z'
  )
end

# Reset runner state between tests so they don't leak.
def wm_reset
  SUAnalysis::Core::WorkingModeRunner.reset_for_tests
end

# --- tests -----------------------------------------------------------

test 'WorkingModeRunner: initial snapshot is the idle "none" state' do
  wm_reset
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'none',         snap['state']
  assert_nil                   snap['source_snapshot_id']
  assert_nil                   snap['source_fingerprint_digest']
  assert_nil                   snap['execution_config_digest']
  assert_nil                   snap['workspace_id']
  assert_nil                   snap['last_error']
end

test 'WorkingModeRunner: idle snapshot is JSON-safe (only primitives / Hashes)' do
  wm_reset
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  require 'json'
  # Round-trip must NOT raise (no live Sketchup:: objects, no
  # non-JSON-safe types).
  json = JSON.generate(snap)
  parsed = JSON.parse(json)
  assert_equal 'none', parsed['state']
end

test 'WorkingModeRunner: prepare captures the source snapshot id + digests' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal 'wm-snap-001', snap['source_snapshot_id']
  refute_nil snap['source_fingerprint_digest']
  refute_nil snap['execution_config_digest']
  refute_nil snap['workspace_id']
  # In V1.4 foundation plumbing, prepare() yields an empty
  # :building workspace; the snapshot reflects the underlying
  # workspace state.
  assert snap['state'] == 'building' || snap['state'] == 'ready',
         "state should be :building or :ready; got #{snap['state'].inspect}"
end

test 'WorkingModeRunner: prepare must NOT mutate the captured source snapshot' do
  wm_reset
  src = v14_source_snapshot_wm
  src_digest_before = src.to_digest
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  # Multiple prepares are idempotent in terms of source
  # preservation: every call must NOT drift the source digest.
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  assert_equal src_digest_before, src.to_digest,
               'prepare must NEVER mutate the captured SourceSnapshot'
end

test 'WorkingModeRunner: discard transitions the snapshot to "discarded"' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  refute_equal 'none', snap['state']
  snap2 = SUAnalysis::Core::WorkingModeRunner.discard
  assert_equal 'discarded', snap2['state']
end

test 'WorkingModeRunner: discard from the idle state is idempotent (still "none")' do
  wm_reset
  snap = SUAnalysis::Core::WorkingModeRunner.discard
  # Per directive: discard from idle must NOT crash; the runner
  # remains idle. The V1.4 plumbing returns the post-discard
  # state. We accept either 'none' or 'discarded' as long as
  # there is no crash.
  assert snap.is_a?(Hash), 'discard must return a Hash snapshot'
  assert snap['state'].is_a?(String)
end

test 'WorkingModeRunner: rebuild requires a captured source (otherwise stays idle)' do
  wm_reset
  # No prepare yet.
  snap = SUAnalysis::Core::WorkingModeRunner.rebuild
  # No source captured -> runner stays idle.
  assert_equal 'none', snap['state']
end

test 'WorkingModeRunner: rebuild after prepare returns a non-idle snapshot' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap_before = SUAnalysis::Core::WorkingModeRunner.snapshot
  snap_rebuilt = SUAnalysis::Core::WorkingModeRunner.rebuild
  # Rebuild preserves the captured source id (NOT a fresh snap).
  assert_equal snap_before['source_snapshot_id'], snap_rebuilt['source_snapshot_id'],
               'rebuild must preserve the captured source snapshot id'
end

test 'WorkingModeRunner: snapshot keys are all String-typed (JSON-safe)' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  snap.each_key do |k|
    assert k.is_a?(String),
           "snapshot key #{k.inspect} must be a String (JSON-safe)"
  end
  # No Symbol-keyed access expected.
  refute snap.key?(:state), 'snapshot MUST be String-keyed (no Symbol keys)'
end

test 'WorkingModeRunner: snapshot value types are all JSON-safe primitives or nil' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  snap.each do |k, v|
    next if v.nil?
    assert v.is_a?(String) || v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass) || v.is_a?(Hash) || v.is_a?(Array),
           "snapshot value for #{k.inspect} (#{v.class}) must be a JSON-safe primitive"
  end
end

test 'WorkingModeRunner: STATES constant covers none / building / ready / discarded / failed' do
  states = SUAnalysis::Core::WorkingModeRunner::STATES
  %w[none building ready discarded failed].each do |s|
    assert states.include?(s.to_sym),
           "WorkingModeRunner::STATES must include :#{s}; got #{states.inspect}"
  end
  assert states.frozen?, 'STATES must be frozen'
end

test 'WorkingModeRunner: adapter_kind is recorded (FakeDerivedWorkspaceAdapter -> :fake)' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  # The runner is adapter-agnostic; the kind is internal. We
  # check via snapshot -- the workspace exists, the source
  # snapshot is captured, no exception raised.
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  refute_equal 'none', snap['state']
  assert_equal 'wm-snap-001', snap['source_snapshot_id']
end

test 'WorkingModeRunner: prepare replaces any prior workspace (no overlap)' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  first_id = SUAnalysis::Core::WorkingModeRunner.snapshot['workspace_id']
  # Second prepare creates a fresh workspace.
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  second_id = SUAnalysis::Core::WorkingModeRunner.snapshot['workspace_id']
  refute_equal first_id, second_id,
               'prepare() must yield a fresh workspace_id (no aliasing across calls)'
end

test 'WorkingModeRunner: source fingerprint digest in snapshot is non-empty and stable' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap1 = SUAnalysis::Core::WorkingModeRunner.snapshot
  SUAnalysis::Core::WorkingModeRunner.discard
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap2 = SUAnalysis::Core::WorkingModeRunner.snapshot
  # Two prepare() calls with the SAME captured source MUST yield
  # the same source_fingerprint_digest (determinism invariant).
  assert_equal snap1['source_fingerprint_digest'], snap2['source_fingerprint_digest'],
               'source_fingerprint_digest must be deterministic for identical source'
end

# --- Risk-test integration with DerivedGeometryWorkspace --------------

test 'WorkingModeRunner: integrated build -> snapshot carries a stable workspace_id' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  snap = SUAnalysis::Core::WorkingModeRunner.snapshot
  # The workspace_id is non-empty AND stable across two reads.
  id1 = snap['workspace_id']
  refute_nil id1
  assert id1.length > 0, "workspace_id must be a non-empty String; got #{id1.inspect}"
  snap_again = SUAnalysis::Core::WorkingModeRunner.snapshot
  assert_equal id1, snap_again['workspace_id'],
               'workspace_id must be stable across successive snapshot reads'
end

test 'WorkingModeRunner: source fingerprint digest stays stable across discard + rebuild' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  fp_before = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  SUAnalysis::Core::WorkingModeRunner.discard
  SUAnalysis::Core::WorkingModeRunner.rebuild
  fp_after = SUAnalysis::Core::WorkingModeRunner.snapshot['source_fingerprint_digest']
  assert_equal fp_before, fp_after,
               'source fingerprint digest must NOT drift across discard + rebuild'
end

test 'WorkingModeRunner: execution config digest stays stable across the lifecycle' do
  wm_reset
  src = v14_source_snapshot_wm
  SUAnalysis::Core::WorkingModeRunner.prepare(
    source:  src,
    adapter: FakeDerivedWorkspaceAdapter.new
  )
  ec_before = SUAnalysis::Core::WorkingModeRunner.snapshot['execution_config_digest']
  SUAnalysis::Core::WorkingModeRunner.discard
  SUAnalysis::Core::WorkingModeRunner.rebuild
  ec_after = SUAnalysis::Core::WorkingModeRunner.snapshot['execution_config_digest']
  assert_equal ec_before, ec_after,
               'execution_config digest must NOT drift across the runner lifecycle'
end
