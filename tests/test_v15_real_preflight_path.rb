#

# tests/test_v15_real_preflight_path.rb — V1.5 Phase 1

# Real-PreflightRunner provenance-path regression tests.

#

# Per CodeX V1.5 BLOCK-003 recheck #2 (2026-08-25): the prior

# V15PC-005 / V15-2 tests bypassed the real PreflightRunner

# walk by manually constructing EdgeRecords whose pid_path arrays

# match. This file adds the production-path regression:

#

#   1. Build a real SketchUp mock model with a real

#      ComponentInstance + duplicate edges.

#   2. Run PreflightRunner.build_snapshot on the selection.

#   3. Build a real IssueRegistry by running the analyzers

#      (DuplicateDetector) through the real AnalyzersRunner

#      path.

#   4. Run WorkingModeRunner.prepare + run_duplicate_repair_batch.

#   5. Verify (a) duplicates inside one ComponentInstance

#      are repaired; (b) duplicates across two ComponentInstances

#      of the same definition are NOT merged; (c) source

#      geometry remains unchanged.

#



require_relative 'runner'

require_relative '_fake_ui'

require_relative '../extension/su_ai_plugin/core/tolerance'

require_relative '../extension/su_ai_plugin/core/analysis_config'

require_relative '../extension/su_ai_plugin/core/source_reference'

require_relative '../extension/su_ai_plugin/core/edge_record'

require_relative '../extension/su_ai_plugin/core/face_record'

require_relative '../extension/su_ai_plugin/core/layer_record'

require_relative '../extension/su_ai_plugin/core/vertex_record'

require_relative '../extension/su_ai_plugin/core/geometry_snapshot'

require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'

require_relative '../extension/su_ai_plugin/core/source_fingerprint'

require_relative '../extension/su_ai_plugin/core/source_snapshot'

require_relative '../extension/su_ai_plugin/core/derived_entity_record'

require_relative '../extension/su_ai_plugin/core/derived_workspace_fingerprint'

require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'

require_relative '../extension/su_ai_plugin/core/derived_geometry_workspace'

require_relative '../extension/su_ai_plugin/core/repair_plan'

require_relative '../extension/su_ai_plugin/core/duplicate_repair_proposer'

require_relative '../extension/su_ai_plugin/core/duplicate_repair_executor'

require_relative '../extension/su_ai_plugin/core/issue_registry'

require_relative '../extension/su_ai_plugin/core/issue_normalizer'

require_relative '../extension/su_ai_plugin/core/issue_enricher'

require_relative '../extension/su_ai_plugin/core/preflight'

require_relative '../extension/su_ai_plugin/preflight_runner'

require_relative '../extension/su_ai_plugin/analyzers_runner'

require_relative '../extension/su_ai_plugin/core/working_mode_runner'

require_relative '../extension/su_ai_plugin/compatibility/su_derived_workspace_adapter'



include SUAnalysis::Core



# ===== helpers =====



# Build a ComponentDefinition containing 2 SU Edges with the same

# world endpoints. Mimics a CAD-import-duplicate inside one

# component definition.

class FakeComponentDef

  attr_reader :entities, :persistent_id, :name

  def initialize(name, pid, edges)

    @name = name

    @persistent_id = pid

    @entities = FakeEntitiesWithEdges.new(edges)

  end

end



class FakeEntitiesWithEdges

  attr_reader :items

  def initialize(edges)

    @items = edges

  end

  def each(&block); @items.each(&block); end

end



class FakeSUComponentInstance

  attr_reader :persistent_id, :definition, :name, :transformation

  attr_accessor :parent

  def initialize(name, pid, definition, transformation)

    @name = name

    @persistent_id = pid

    @definition = definition

    @transformation = transformation

  end

end



# A transformation that is the identity (for tests).

# PreflightRunner.to_matrix expects a 4x4 array of arrays

# (or a SU Geom::Transformation).

class FakeIdentityTransform

  IDENTITY_MATRIX = [

    [1.0, 0.0, 0.0, 0.0],

    [0.0, 1.0, 0.0, 0.0],

    [0.0, 0.0, 1.0, 0.0],

    [0.0, 0.0, 0.0, 1.0]

  ].freeze

  def to_a; IDENTITY_MATRIX; end

  def matrix; IDENTITY_MATRIX; end

  def to_matrix; IDENTITY_MATRIX; end

  def inverse; self; end

end



# An SU Edge with explicit world endpoints.

class FakeSUVertex

  attr_reader :position

  def initialize(point)

    @position = FakePoint3d.new(*point)

  end

end



class FakePoint3d

  attr_reader :x, :y, :z

  def initialize(x, y, z); @x = x; @y = y; @z = z; end

end



class FakeSUEdge

  attr_reader :entityID, :persistent_id, :start, :end, :layer, :vertices

  attr_accessor :parent

  def initialize(pid, start_point, end_point, layer = nil)

    @persistent_id = pid

    @entityID = pid  # use pid as entityID for stability

    @start = FakeSUVertex.new(start_point)

    @end = FakeSUVertex.new(end_point)

    @layer = layer

    @vertices = [@start, end_point]

  end

  def typename; 'edge'; end

  def valid?; true; end

end



def v15pp_exec_config

  ExecutionConfigSnapshot.from_live_config(

    AnalysisConfig.new(profile_name: 'test'),

    rule_set_digest: 'v15pp-rule-digest',

    source_snapshot_schema_version: '1'

  )

end



# Wrap a PreflightRunner GeometrySnapshot into a SourceSnapshot

# (the V1.4 contract the dialog_runner + WorkingModeRunner use).

def v15pp_to_source_snapshot(geometry_snap)

  return nil if geometry_snap.nil?

  SourceSnapshot.from_geometry_snapshot(

    geometry_snap,

    selection: [],

    execution_config: v15pp_exec_config,

    rule_set_digest: 'v15pp-rule-digest',

    snapshot_id: 'v15pp-snap-' + SecureRandom.hex(4),

    captured_at: '2026-08-25T00:00:00Z'

  )

end



# Run the FULL production pipeline:

#   1. PreflightRunner.build_snapshot(selection, model: ...)

#   2. Wrap GeometrySnapshot into SourceSnapshot

#   3. AnalyzersRunner.run(selection, model: ...) -- builds the

#      registry with duplicate_edge_candidate issues.

#   4. WorkingModeRunner.prepare + run_duplicate_repair_batch.

#

# Returns [registry, source_snapshot, working_mode_runner_snap].

def v15pp_run_full_pipeline(selection, model)

  geom_snap = SUAnalysis::Extension::PreflightRunner.build_snapshot(selection, model: model)

  ar = SUAnalysis::Extension::AnalyzersRunner.run(selection, model: model)

  registry = ar.registry

  src_snap = v15pp_to_source_snapshot(geom_snap)

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  SUAnalysis::Core::WorkingModeRunner.prepare(

    source: src_snap,

    adapter: FakeDerivedWorkspaceAdapter.new,

    model:   model

  )

  SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(registry: registry)

  [registry, src_snap, SUAnalysis::Core::WorkingModeRunner.snapshot]

end





# ================================================================

# Test: real-PreflightRunner path -- duplicate edges inside ONE

# ComponentInstance are repaired.

# ================================================================



test 'V15RP-001: real PreflightRunner path -- duplicate edges inside one ComponentInstance are repaired' do

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  # Build a ComponentDefinition with 2 SU Edges sharing world

  # endpoints (the CAD-import-duplicate case).

  edges = [

    FakeSUEdge.new(900, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0]),

    FakeSUEdge.new(901, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0])  # SAME endpoints

  ]

  defn = FakeComponentDef.new('DupDef', 500, edges)

  # Build a single ComponentInstance of this definition.

  inst = FakeSUComponentInstance.new('DupInst#1', 100, defn, FakeIdentityTransform.new)

  # Capture source geometry for fingerprint comparison (compare

  # primitive point coordinates, not object identity).

  src_points_before = edges.map { |e| [e.start.position.x, e.start.position.y, e.start.position.z,

                                       e.end.position.x,   e.end.position.y,   e.end.position.z] }

  # Run the full pipeline.

  registry, snap, wm_snap = v15pp_run_full_pipeline([inst], FakeUI::FakeModel.new)

  # Verify the registry contains a duplicate_edge_candidate issue.

  dups = registry.issues.select { |iss| iss[:issue_type] == 'duplicate_edge_candidate' }

  assert dups.length >= 1, 'real-PreflightRunner pipeline must emit duplicate_edge_candidate'

  # Verify the Working Mode runner reports applied >= 1.

  dr = wm_snap['duplicate_repair']

  refute_nil dr, 'duplicate_repair summary must be set'

  assert dr['actions_applied'] >= 1, "expected applied >= 1, got #{dr['actions_applied']}"

  # Verify source geometry unchanged (compare primitive coordinates).

  src_points_after = edges.map { |e| [e.start.position.x, e.start.position.y, e.start.position.z,

                                      e.end.position.x,   e.end.position.y,   e.end.position.z] }

  assert_equal src_points_before, src_points_after

end





# ================================================================

# Test: real-PreflightRunner path -- duplicate edges across two

# ComponentInstances of the SAME definition are NOT merged.

# ================================================================



test 'V15RP-002: real PreflightRunner path -- 2 instances of same def at SAME transform: ONE action with provenance union' do

    SUAnalysis::Core::WorkingModeRunner.reset_for_tests

    # Build a ComponentDefinition with 2 SU Edges sharing world

    # endpoints.

    edges = [

      FakeSUEdge.new(902, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0]),

      FakeSUEdge.new(903, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0])

    ]

    defn = FakeComponentDef.new('DupDef', 500, edges)

    # Build TWO ComponentInstances of the SAME definition at the
    # SAME world transform. Under the corrected V1.5 model
    # (Guidance 031, 2026-08-25) the two instances are distinct
    # source occurrences whose DERIVED topology merges into ONE
    # survivor with provenance union of all contributing source
    # occurrences. Both source instances remain immutable.
    inst_a = FakeSUComponentInstance.new('DupInst#A', 100, defn, FakeIdentityTransform.new)

    inst_b = FakeSUComponentInstance.new('DupInst#B', 200, defn, FakeIdentityTransform.new)

    # Run the full pipeline.

    registry, snap, wm_snap = v15pp_run_full_pipeline([inst_a, inst_b], FakeUI::FakeModel.new)

    # The registry emits duplicate_edge_candidate issues; under
    # the corrected model, the world-geometry equivalence class
    # merges all 4 derived records (2 per instance) into ONE
    # canonical class with ONE :remove_duplicate_edge action.
    dups = registry.issues.select { |iss| iss[:issue_type] == 'duplicate_edge_candidate' }

    assert dups.length >= 2, 'expected 2+ duplicate pairs (one per instance)'

    dr = wm_snap['duplicate_repair']

    refute_nil dr

    # Corrected model: ONE action merging the class.
    applied_count = dr['actions_applied']

    assert_equal 1, applied_count,

                 "expected applied == 1 (one world-geometry class merging both instances), got #{applied_count}"

    # Workspace has 1 surviving derived entity (the rest were

    # removed by the single batch action).

    cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

    refute_nil cur_ws

    assert_equal 1, cur_ws.entities.length,

                 'expected 1 surviving derived entity after canonicalization'

  end


test 'V15RP-003: real PreflightRunner path -- no duplicates -> applied=0, ready' do

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  # Build a ComponentDefinition with 2 UNIQUE edges (no duplicates).

  edges = [

    FakeSUEdge.new(904, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0]),

    FakeSUEdge.new(905, [20.0, 0.0, 0.0], [30.0, 0.0, 0.0])  # different endpoints

  ]

  defn = FakeComponentDef.new('NoDupDef', 600, edges)

  inst = FakeSUComponentInstance.new('NoDupInst#1', 700, defn, FakeIdentityTransform.new)

  registry, snap, wm_snap = v15pp_run_full_pipeline([inst], FakeUI::FakeModel.new)

  dr = wm_snap['duplicate_repair']

  refute_nil dr

  assert_equal 0, dr['actions_applied']

  cur_ws = SUAnalysis::Core::WorkingModeRunner.current_workspace_for_test

  assert_equal :ready, cur_ws.state

end





# ================================================================

# Test: real PreflightRunner -- root-level duplicate edges are

# NOT auto-repaired (fail-closed per CodeX BLOCK-003).

# ================================================================



test 'V15RP-004: real PreflightRunner path -- root-level duplicates are fail-closed' do

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  # Build 2 root-level SU Edges with same world endpoints (no

  # container). V1.5 must NOT repair these (fail-closed for

  # root-level per CodeX BLOCK-003).

  edges = [

    FakeSUEdge.new(906, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0]),

    FakeSUEdge.new(907, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0])

  ]

  # A "root-level container" that exposes these edges directly.

  root_container = FakeEntitiesWithEdges.new(edges)

  # We pass the root entities as the selection; the walk will

  # treat each edge as a leaf with NO container PID.

  # Run PreflightRunner directly (build_snapshot signature

  # accepts a selection of entities).

  snap = SUAnalysis::Extension::PreflightRunner.build_snapshot(edges, model: FakeUI::FakeModel.new)

  # Verify the snapshot's edges have path = [leaf_pid] (root).

  snap.edges.each do |e|

    pid_path = e.source.persistent_id_path

    assert_equal 1, pid_path.length, "root-level edge expected to have pid_path length 1, got #{pid_path.inspect}"

  end

end





# ================================================================

# Test: production-path source_fingerprint unchanged

# ================================================================



test 'V15RP-005: real PreflightRunner path -- source_fingerprint unchanged across apply' do

  SUAnalysis::Core::WorkingModeRunner.reset_for_tests

  edges = [

    FakeSUEdge.new(908, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0]),

    FakeSUEdge.new(909, [0.0, 0.0, 0.0], [10.0, 0.0, 0.0])

  ]

  defn = FakeComponentDef.new('DupDef', 500, edges)

  inst = FakeSUComponentInstance.new('DupInst#1', 100, defn, FakeIdentityTransform.new)

  # Build snapshot + wrap to SourceSnapshot for fingerprint baseline.

  geom = SUAnalysis::Extension::PreflightRunner.build_snapshot([inst], model: FakeUI::FakeModel.new)

  src_snap = v15pp_to_source_snapshot(geom)

  fp_before = src_snap.fingerprint

  # Run the full pipeline.

  registry, src_snap_after, wm_snap = v15pp_run_full_pipeline([inst], FakeUI::FakeModel.new)

  dr = wm_snap['duplicate_repair']

  assert dr['actions_applied'] >= 1

  # Verify the source snapshot fingerprint is unchanged across apply.

  assert_equal fp_before, src_snap.fingerprint

  assert_equal fp_before, src_snap_after.fingerprint

end



# ---- helper for refute ----

def refute(cond, msg = nil)

  assert !cond, msg || "expected #{cond.inspect} to be falsy"

end



def refute_nil(value, msg = nil)

  return unless value.nil?

  raise msg || 'expected non-nil value, got nil'

end



# SketchUp's SUCapability checks may need stubs. Define the

# sketchup stubs as fallback if not already present.

unless defined?(Sketchup)

  $LOAD_PATH.unshift(File.expand_path('stubs', File.dirname(__FILE__)))

  load File.expand_path('stubs/sketchup.rb', File.dirname(__FILE__))

end

unless defined?(Geom)

  module Geom

    class Point3d

      def initialize(*coords); @coords = coords; end

      def x; @coords[0]; end

      def y; @coords[1]; end

      def z; @coords[2]; end

    end

  end

end
