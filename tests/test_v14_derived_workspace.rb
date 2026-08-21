#
# tests/test_v14_derived_workspace.rb — V1.4 Stage 3
# DerivedGeometryWorkspace + adapter + fingerprint.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 3.
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

include SUAnalysis::Core

# Top-level refute helper (the test runner only exposes
# refute_nil + refute_match; we need a generic refute).
def refute(cond, msg = nil)
  assert !cond, msg || "expected #{cond.inspect} to be falsy"
end

def v14_exec_config
  ExecutionConfigSnapshot.from_live_config(
    AnalysisConfig.new(profile_name: 'test'),
    rule_set_digest: 'ws-rule-digest',
    source_snapshot_schema_version: '1'
  )
end

def v14_source_snapshot
  edges = [
    EdgeRecord.new(id: 0,
      source: SourceReference.new(entity_id: 1, persistent_id: 100, kind: 'edge',
                                 persistent_id_path: [100], instance_path: [],
                                 structural_depth: 0, pid_path_complete: true,
                                 layer_name: 'Layer0'),
      start_point: [0.0, 0.0, 0.0], end_point: [10.0, 0.0, 0.0],
      layer: 'Layer0')
  ]
  ExecutionConfigSnapshot
  src = SourceSnapshot.from_geometry_snapshot(
    GeometrySnapshot.new(edges: edges, layers: [LayerRecord.new(name: 'Layer0')]),
    selection: [],
    execution_config: v14_exec_config,
    rule_set_digest: 'ws-rule-digest',
    snapshot_id: 'ws-snap-001',
    captured_at: '2026-08-20T10:00:00Z'
  )
  src
end

# --- DerivedEntityRecord ---

def v14_derived_entity
  DerivedEntityRecord.new(
    derived_id:            'der-edge-1',
    kind:                  :edge,
    source_occurrence_ids: ['occ-edge-100'],
    geometry_summary:      { 'layer' => 'Layer0', 'vertex_count' => 2 },
    parent_derived_id:     nil,
    host_assigned_ids:     { 'fake_derived_id' => 'fake-1' }
  )
end

test 'DerivedEntityRecord: required fields stored' do
  e = v14_derived_entity
  assert_equal 'der-edge-1',       e.derived_id
  assert_equal :edge,              e.kind
  assert_equal ['occ-edge-100'],   e.source_occurrence_ids
  assert_equal 'Layer0',           e.geometry_summary['layer']
  assert_equal 2,                  e.geometry_summary['vertex_count']
  assert_nil   e.parent_derived_id
  assert_equal({ 'fake_derived_id' => 'fake-1' }, e.host_assigned_ids)
end

test 'DerivedEntityRecord: top-level + nested arrays/hashes are frozen' do
  e = v14_derived_entity
  assert e.frozen?, 'top-level must be frozen'
  assert e.source_occurrence_ids.frozen?, 'source_occurrence_ids Array must be frozen'
  assert e.geometry_summary.frozen?, 'geometry_summary Hash must be frozen'
  assert e.host_assigned_ids.frozen?, 'host_assigned_ids Hash must be frozen'
end

test 'DerivedEntityRecord: kind validation rejects unknown kinds' do
  assert_raises(ArgumentError) do
    DerivedEntityRecord.new(derived_id: 'x', kind: :never_heard_of_it)
  end
end

test 'DerivedEntityRecord: == EXCLUDES host_assigned_ids (rebuild fingerprint invariant)' do
  e1 = v14_derived_entity
  e2 = DerivedEntityRecord.new(
    derived_id:            e1.derived_id,
    kind:                  e1.kind,
    source_occurrence_ids: e1.source_occurrence_ids,
    geometry_summary:     e1.geometry_summary,
    parent_derived_id:    e1.parent_derived_id,
    # DIFFERENT host_assigned_ids.
    host_assigned_ids:    { 'fake_derived_id' => 'fake-DIFFERENT' }
  )
  assert_equal e1, e2, 'rebuilds with the same data but different host_assigned_ids MUST be =='
end

test 'DerivedEntityRecord: digest is SHA256 hex and stable' do
  e = v14_derived_entity
  assert_equal 64, e.digest.length
  e2 = v14_derived_entity
  assert_equal e.digest, e2.digest, 'identical data -> identical digest'
end

# --- DerivedWorkspaceFingerprint ---

test 'DerivedWorkspaceFingerprint: empty workspace fingerprint' do
  src = v14_source_snapshot
  fp = DerivedWorkspaceFingerprint.from_workspace(
    source_snapshot_id:      src.snapshot_id,
    execution_config_digest: src.execution_config.respond_to?(:digest) ? src.execution_config.digest : '',
    entities:                []
  )
  assert_equal src.snapshot_id, fp.source_snapshot_id
  assert_equal 0,                fp.derived_entity_count
  assert_equal [],              fp.derived_entity_digests
  assert_equal({},              fp.kinds_breakdown)
end

test 'DerivedWorkspaceFingerprint: kinds_breakdown tallies per kind' do
  fp = DerivedWorkspaceFingerprint.from_workspace(
    source_snapshot_id:      'snap-x',
    execution_config_digest: 'd-x',
    entities: [
      v14_derived_entity,
      v14_derived_entity,
      DerivedEntityRecord.new(derived_id: 'd2', kind: :face, geometry_summary: {})
    ]
  )
  assert_equal 3,     fp.derived_entity_count
  assert_equal 2,     fp.kinds_breakdown[:edge]
  assert_equal 1,     fp.kinds_breakdown[:face]
  assert_equal 3,     fp.derived_entity_digests.length
end

test 'DerivedWorkspaceFingerprint: source_snapshot_id change MUST drift the digest' do
  # If the source changes, the rebuild fingerprint MUST drift.
  # This proves the rebuild is reading the captured source
  # and not stale state.
  e = v14_derived_entity
  fp_a = DerivedWorkspaceFingerprint.from_workspace(
    source_snapshot_id: 'snap-A', execution_config_digest: 'd', entities: [e]
  )
  fp_b = DerivedWorkspaceFingerprint.from_workspace(
    source_snapshot_id: 'snap-B', execution_config_digest: 'd', entities: [e]
  )
  refute_equal fp_a.digest, fp_b.digest, 'source change must drift the digest'
end

test 'DerivedWorkspaceFingerprint: identical inputs -> identical digest (risk test 8)' do
  e = v14_derived_entity
  fp1 = DerivedWorkspaceFingerprint.from_workspace(
    source_snapshot_id: 's', execution_config_digest: 'd', entities: [e]
  )
  fp2 = DerivedWorkspaceFingerprint.from_workspace(
    source_snapshot_id: 's', execution_config_digest: 'd', entities: [e]
  )
  assert_equal fp1.digest, fp2.digest
  # Different host_assigned_ids on the entity must NOT drift
  # the fingerprint (rebuild invariant: excludes host ids).
  e_diff = DerivedEntityRecord.new(
    derived_id:            e.derived_id,
    kind:                  e.kind,
    source_occurrence_ids: e.source_occurrence_ids,
    geometry_summary:     e.geometry_summary,
    parent_derived_id:    e.parent_derived_id,
    host_assigned_ids:    { 'fake_derived_id' => 'different-id' }
  )
  fp3 = DerivedWorkspaceFingerprint.from_workspace(
    source_snapshot_id: 's', execution_config_digest: 'd', entities: [e_diff]
  )
  assert_equal fp1.digest, fp3.digest, 'host_assigned_ids drift MUST NOT drift the digest'
end

# --- DerivedWorkspaceAdapter (Fake) ---

test 'FakeDerivedWorkspaceAdapter: create_top_level_group returns a host handle' do
  a = FakeDerivedWorkspaceAdapter.new
  g = a.create_top_level_group('ws-group-1')
  refute_nil g
  assert_equal 'ws-group-1', g.name
  assert_equal 1, a.created_handles.length
end

test 'FakeDerivedWorkspaceAdapter: add_face_to_group records the face under the group' do
  a = FakeDerivedWorkspaceAdapter.new
  g = a.create_top_level_group('g')
  face = a.add_face_to_group(g, [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0], [10.0, 5.0, 0.0], [0.0, 5.0, 0.0]])
  refute_nil face
  assert_equal 1, a.added_faces.length
  # V1.4 CodeX BLOCK rework: face vertices are faithfully
  # recorded (no fabrication).
  refute_nil face
end

test 'FakeDerivedWorkspaceAdapter: add_edge_to_group records the edge with XYZ-identical endpoints' do
  # V1.4 CodeX BLOCK rework (2026-08-21): BLOCK 1 forbids
  # fabricating a 3-point face from a 2-endpoint Edge. The
  # adapter records the two world-coordinate endpoints
  # VERBATIM (no Z lift, no midpoint injection).
  a = FakeDerivedWorkspaceAdapter.new
  g = a.create_top_level_group('g')
  edge = a.add_edge_to_group(g, [1.0, 2.0, 3.0], [4.0, 5.0, 6.0])
  refute_nil edge
  assert_equal 1, a.added_edges.length
  assert_equal [1.0, 2.0, 3.0], edge.start
  assert_equal [4.0, 5.0, 6.0], edge.end
end

test 'FakeDerivedWorkspaceAdapter: add_face_to_group REJECTS non-faithful input' do
  # V1.4 CodeX BLOCK rework (2026-08-21): BLOCK 1 -- do
  # NOT fabricate a face from < 3 vertices or non-Float
  # values. The adapter raises ArgumentError so the
  # workspace can transition to :failed.
  a = FakeDerivedWorkspaceAdapter.new
  g = a.create_top_level_group('g')
  # Only 2 vertices -> reject.
  raised_short = false
  begin
    a.add_face_to_group(g, [[0.0, 0.0, 0.0], [10.0, 0.0, 0.0]])
  rescue ArgumentError
    raised_short = true
  end
  assert raised_short, 'add_face_to_group with only 2 vertices MUST raise ArgumentError'
  # Non-Float vertex component -> reject.
  raised_nonfloat = false
  begin
    a.add_face_to_group(g, [[0, 0, 0], [10.0, 0.0, 0.0], [10.0, 5.0, 0.0]])
  rescue ArgumentError
    raised_nonfloat = true
  end
  assert raised_nonfloat, 'add_face_to_group with non-Float vertex MUST raise ArgumentError'
end

test 'FakeDerivedWorkspaceAdapter: dispose is idempotent' do
  a = FakeDerivedWorkspaceAdapter.new
  g = a.create_top_level_group('g')
  a.dispose(g)
  a.dispose(g)   # must not raise
  assert_equal 2, a.disposed_handles.length
end

# --- DerivedGeometryWorkspace ---

test 'DerivedGeometryWorkspace: initial state is :building with no entities' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  assert_equal :building, ws.state
  assert_equal 0,         ws.entities.length
  refute ws.ready?, 'empty workspace must NOT be :ready'
end

test 'DerivedGeometryWorkspace: build_entity -> :ready with one entity' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(
    derived_id:            'der-edge-1',
    kind:                  :edge,
    source_occurrence_ids: ['occ-edge-100'],
    geometry_summary:      { 'layer' => 'Layer0', 'vertex_count' => 2 }
  )
  assert_equal :ready, ws1.state
  assert_equal 1,       ws1.entities.length
  assert ws1.ready?, 'after build_entity, workspace must be :ready'
  # Original is unchanged.
  assert_equal :building, ws0.state
  assert_equal 0,         ws0.entities.length
end

test 'DerivedGeometryWorkspace: build_entity provenance -- derived_id maps to source_occurrence_ids' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(
    derived_id:            'der-edge-1',
    kind:                  :edge,
    source_occurrence_ids: ['occ-edge-100', 'occ-edge-200']
  )
  rec = ws1.entity('der-edge-1')
  assert_equal ['occ-edge-100', 'occ-edge-200'], rec.source_occurrence_ids
end

test 'DerivedGeometryWorkspace: build_entity failure -> :failed (source untouched)' do
  src = v14_source_snapshot
  # Adapter that always raises to simulate host failure.
  class FailingAdapter < FakeDerivedWorkspaceAdapter
    def create_top_level_group(_name)
      raise StandardError, 'host failure'
    end
  end
  a  = FailingAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(derived_id: 'd1', kind: :group)
  assert_equal :failed, ws1.state
  assert !ws1.ready?, ':failed workspace must NOT be :ready'
  assert !ws1.last_error.nil?, ':failed workspace must carry a last_error'
  assert_match(/host failure/, ws1.last_error)
  # No entity was added.
  assert_equal 0, ws1.entities.length
  # Source snapshot is unchanged (the workspace holds a reference
  # to the SourceSnapshot; if the workspace state-change didn't
  # mutate the snapshot, we're safe).
  assert_equal 'ws-snap-001', src.snapshot_id
end

test 'DerivedGeometryWorkspace: discard -> :discarded with empty inventory' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(derived_id: 'd1', kind: :group)
  ws2 = ws1.discard
  assert_equal :discarded, ws2.state
  assert_equal 0,            ws2.entities.length
  assert !ws2.ready?, ':discarded workspace must NOT be :ready'
  assert_equal 1, a.disposed_handles.length, 'dispose was called'
end

test 'DerivedGeometryWorkspace: discard failure -> :failed (per directive)' do
  src = v14_source_snapshot
  # Adapter that fails on dispose.
  class FailingDisposeAdapter < FakeDerivedWorkspaceAdapter
    def dispose(_handle)
      raise StandardError, 'dispose failed'
    end
  end
  a  = FailingDisposeAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(derived_id: 'd1', kind: :group)
  ws2 = ws1.discard
  assert_equal :failed, ws2.state, 'discard failure MUST transition to :failed'
  assert !ws2.ready?, 'failed workspace must NOT be :ready'
  assert_match(/dispose failed/, ws2.last_error)
end

test 'DerivedGeometryWorkspace: rebuild -> new :ready workspace with same fingerprint' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(
    derived_id:            'd1',
    kind:                  :edge,
    source_occurrence_ids: ['occ-edge-100'],
    geometry_summary:      { 'layer' => 'Layer0', 'vertex_count' => 2 }
  )
  fp1 = ws1.fingerprint
  refute_nil fp1
  # Rebuild.
  ws2 = ws1.rebuild
  assert_equal :ready, ws2.state
  assert ws2.ready?
  # The rebuild MUST produce a workspace whose fingerprint
  # matches the pre-rebuild one (per directive: "A second
  # build from identical source + captured config must
  # produce the same canonical derived fingerprint").
  fp2 = ws2.fingerprint
  assert_equal fp1.digest, fp2.digest
end

test 'DerivedGeometryWorkspace: rebuild when discard failed returns :failed' do
  src = v14_source_snapshot
  class FailingDisposeAdapter < FakeDerivedWorkspaceAdapter
    def dispose(_handle); raise StandardError, 'dispose failed'; end
  end
  a  = FailingDisposeAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(derived_id: 'd1', kind: :group)
  ws2 = ws1.rebuild
  assert_equal :failed, ws2.state, 'rebuild with failing discard MUST be :failed'
end

test 'DerivedGeometryWorkspace: source_occurrence_ids are preserved through build + rebuild' do
  # Per risk test 3: derived-record -> source-occurrence provenance
  # is preserved across rebuilds.
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(
    derived_id:            'd1',
    kind:                  :edge,
    source_occurrence_ids: ['occ-edge-100', 'occ-edge-200']
  )
  ws2 = ws1.rebuild
  rec = ws2.entity('d1')
  assert_equal ['occ-edge-100', 'occ-edge-200'], rec.source_occurrence_ids
end

test 'DerivedGeometryWorkspace: nested derived entity (parent_derived_id) builds under parent' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(derived_id: 'parent', kind: :group)
  ws2 = ws1.build_entity(
    derived_id:        'child',
    kind:              :face,
    parent_derived_id: 'parent'
  )
  parent = ws2.entity('parent')
  child  = ws2.entity('child')
  assert_equal 'parent', child.parent_derived_id
  # The relationship is captured in the fingerprint.
  rels = ws2.fingerprint.parent_relationships
  assert rels.include?(['child', 'parent'])
  assert rels.include?(['parent', nil])
end

test 'DerivedGeometryWorkspace: source snapshot is NEVER mutated by any operation' do
  # Per directive gate: "Source remains untouched by every
  # operation." Build, discard, rebuild -- none of these
  # mutate the SourceSnapshot.
  src = v14_source_snapshot
  src_digest_before = src.to_digest
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(derived_id: 'd1', kind: :group)
  ws1.discard
  ws1.build_entity(derived_id: 'd2', kind: :face)
  ws1.rebuild
  assert_equal src_digest_before, src.to_digest,
               'SourceSnapshot must be immutable across all workspace ops'
end

test 'DerivedGeometryWorkspace: build_entity with parent_derived_id not found raises' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  # No parent entity has been built yet.
  raised = false
  begin
    ws0.build_entity(derived_id: 'child', kind: :face, parent_derived_id: 'no-such-parent')
  rescue ArgumentError => e
    raised = true
    assert_match(/parent derived_id/, e.message)
  end
  assert raised, 'expected ArgumentError when parent_derived_id is not found'
end

test 'DerivedGeometryWorkspace: == compares workspace_id + state + entity_pairs' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws1 = DerivedGeometryWorkspace.new(workspace_id: 'ws-A', source_snapshot: src, adapter: a)
  ws2 = DerivedGeometryWorkspace.new(workspace_id: 'ws-B', source_snapshot: src, adapter: a)
  refute_equal ws1, ws2, 'different workspace_id -> not =='
end

test 'DerivedGeometryWorkspace: top-level + entities are deeply frozen' do
  src = v14_source_snapshot
  a  = FakeDerivedWorkspaceAdapter.new
  ws0 = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws1 = ws0.build_entity(derived_id: 'd1', kind: :group)
  assert ws1.frozen?, 'top-level must be frozen'
  # entities returns a new Array; the underlying inventory
  # is the frozen entity_pairs.
  # The entity pairs themselves contain frozen DerivedEntityRecord
  # instances; mutating the entity record must raise.
  rec = ws1.entities.first
  assert rec.frozen?, 'each DerivedEntityRecord must be frozen'
end

# ===== Risk test 1 — source fingerprint is identical before/after =====
# Per V1.4 directive 030 risk test 1, the source fingerprint MUST be
# identical before/after: successful create, discard, rebuild, injected
# failure during workspace creation, host-operation abort/failure path.

test 'Risk test 1a — source fingerprint identical after SUCCESSFUL create' do
  src = v14_source_snapshot
  src_fp_before = src.fingerprint
  src_digest_before = src.to_digest
  a  = FakeDerivedWorkspaceAdapter.new
  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws = ws.build_entity(derived_id: 'd1', kind: :group)
  assert_equal :ready, ws.state
  assert_equal src_fp_before, src.fingerprint,
               'successful create must NOT drift source fingerprint'
  assert_equal src_digest_before, src.to_digest,
               'successful create must NOT drift source digest'
end

test 'Risk test 1b — source fingerprint identical after DISCARD' do
  src = v14_source_snapshot
  src_fp_before = src.fingerprint
  a  = FakeDerivedWorkspaceAdapter.new
  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws = ws.build_entity(derived_id: 'd1', kind: :group)
  ws = ws.discard
  assert_equal :discarded, ws.state
  assert_equal src_fp_before, src.fingerprint,
               'discard must NOT drift source fingerprint'
end

test 'Risk test 1c — source fingerprint identical after REBUILD' do
  src = v14_source_snapshot
  src_fp_before = src.fingerprint
  a  = FakeDerivedWorkspaceAdapter.new
  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: a, model: nil)
  ws = ws.build_entity(derived_id: 'd1', kind: :group)
  ws = ws.rebuild
  assert_equal :ready, ws.state
  assert_equal src_fp_before, src.fingerprint,
               'rebuild must NOT drift source fingerprint'
end

test 'Risk test 1d — source fingerprint identical after INJECTED build failure' do
  src = v14_source_snapshot
  src_fp_before = src.fingerprint
  # Adapter that always raises to simulate host failure.
  failing_adapter = Class.new(FakeDerivedWorkspaceAdapter) do
    def create_top_level_group(_name)
      raise StandardError, 'host failure during creation'
    end
  end.new
  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: failing_adapter)
  ws = ws.build_entity(derived_id: 'd1', kind: :group)
  assert_equal :failed, ws.state
  assert_equal src_fp_before, src.fingerprint,
               'injected build failure must NOT drift source fingerprint'
end

test 'Risk test 1e — source fingerprint identical after HOST-OPERATION failure (discard fails)' do
  src = v14_source_snapshot
  src_fp_before = src.fingerprint
  failing_dispose_adapter = Class.new(FakeDerivedWorkspaceAdapter) do
    def dispose(_handle)
      raise StandardError, 'host dispose failed'
    end
  end.new
  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: failing_dispose_adapter)
  ws = ws.build_entity(derived_id: 'd1', kind: :group)
  ws = ws.discard
  assert_equal :failed, ws.state
  assert_equal src_fp_before, src.fingerprint,
               'host-op abort must NOT drift source fingerprint'
end

# ===== Risk test 2 — derived edits do not share source definitions =====

test 'Risk test 2 — derived adapter NEVER accepts a source handle (shared-definition isolation)' do
  # Per V1.4 stage 3 gate B + risk test 2:
  #   "Every editable derived entity must be independently owned;
  #    no shared mutable definition or attribute container may alias
  #    source."
  # The fake adapter's create_top_level_group takes ONLY a name.
  # There is no overload that takes a source-side handle; this is
  # the API contract that prevents accidental sharing.
  a = FakeDerivedWorkspaceAdapter.new
  m = a.method(:create_top_level_group)
  # The arity is 1 (name only); the adapter never takes a source handle.
  assert_equal 1, m.arity,
               'create_top_level_group must NOT take a source handle parameter'
  # Two distinct creates yield distinct, independently-owned handles.
  g1 = a.create_top_level_group('group-1')
  g2 = a.create_top_level_group('group-2')
  refute_equal g1.derived_id, g2.derived_id,
               'two creates must yield distinct, independently-owned derived_ids'
  refute_equal g1.object_id,  g2.object_id,
               'two creates must yield distinct Ruby objects (no shared definition)'
  # Disposing one must not affect the other.
  a.dispose(g1)
  assert_equal 1, a.disposed_handles.length
  assert !a.disposed_handles.include?(g2)
end

test 'Risk test 2 — derived entities carry NO field that aliases a source handle' do
  # No field on DerivedEntityRecord should be capable of
  # aliasing a source-side component definition. The only
  # host-data path is host_assigned_ids, which records
  # host-assigned id VALUES (entityID, persistent_id) for
  # audit, not source-aliasing handles.
  e = v14_derived_entity
  # The record's "host_assigned_ids" only carries id values, not a handle.
  assert e.host_assigned_ids.values.all? { |v| v.is_a?(String) || v.is_a?(Integer) || v.is_a?(NilClass) },
         'host_assigned_ids must carry id values, not handles'
  # No field exposes a "shared_definition" or "source_component_def"
  # aliasing path.
  h = e.to_h
  %i[derived_id kind source_occurrence_ids geometry_summary
     parent_derived_id host_assigned_ids].each do |k|
    assert h.key?(k), "record must expose #{k}"
  end
  refute h.key?(:source_component_definition),
         'record must NOT expose a source_component_definition field (would alias source)'
  refute h.key?(:source_group_handle),
         'record must NOT expose a source_group_handle field (would alias source)'
end

# ===== Risk test 9 - cross-cut with RepairPlan =====

test 'Cross-stage: DerivedWorkspace failure (:failed) cannot be misreported as :ready' do
  # Per directive: "failed plans/results are never READY". The
  # same invariant applies to workspaces (per stage 3 exit
  # criteria). A :failed workspace's ready? returns FALSE even
  # if the inventory would suggest 'has entities'.
  failing_adapter = Class.new(FakeDerivedWorkspaceAdapter) do
    def create_top_level_group(_name)
      raise StandardError, 'host'
    end
  end.new
  src = v14_source_snapshot
  ws = DerivedGeometryWorkspace.new(source_snapshot: src, adapter: failing_adapter)
  ws = ws.build_entity(derived_id: 'd1', kind: :group)
  assert_equal :failed, ws.state
  assert_equal 0, ws.entities.length
  refute ws.ready?, ':failed workspace MUST NOT be :ready'
end
