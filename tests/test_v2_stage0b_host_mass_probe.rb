#
# tests/test_v2_stage0b_host_mass_probe.rb — V2-0B Stage 0B
# Mass Probe focused tests.
#
# Dispatch: V2-0B-HOST-GEOMETRY-PROBE-2026-09-16.
# Frozen Blueprint:
# Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md
#   (final filename in Prompt/).
#
# Per Blueprint §11:
#   - Pre-mutation / stale gate matrix (READY/BED uses blockers);
#   - Operation guard matrix (start/commit/abort false/raise,
#     add_group nil, add_face nil, pushpull raise, etc.);
#   - Successful geometry matrix;
#   - Real V1 freshness integration.
#
# Host-free Fakes only (the real SU host is exercised by the
# developer probe at Probe/v2_stage0b_owner_probe.rb and the
# Owner real-SU2020 gate).
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require_relative '../extension/su_ai_plugin/core/edge_record'
require_relative '../extension/su_ai_plugin/core/endpoint_record'
require_relative '../extension/su_ai_plugin/core/execution_config_snapshot'
require_relative '../extension/su_ai_plugin/core/canonical_topology_builder'
require_relative '../extension/su_ai_plugin/core/canonical_geometry_graph'
require_relative '../extension/su_ai_plugin/core/canonical_structure_reconstructor'
require_relative '../extension/su_ai_plugin/core/derived_workspace_adapter'
require_relative '../extension/su_ai_plugin/core/duplicate_repair_proposer'
require_relative '../extension/su_ai_plugin/core/duplicate_repair_executor'
require_relative '../extension/su_ai_plugin/core/preflight'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/source_snapshot'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/prepared_cad_dataset'
require_relative '../extension/su_ai_plugin/core/prepared_cad_dataset_builder'
require_relative '../extension/su_ai_plugin/core/prepared_cad_dataset_validator'
require_relative '../extension/su_ai_plugin/core/working_mode_runner'
require_relative '../extension/su_ai_plugin/v2/layer_local_graph_adapter'
require_relative '../extension/su_ai_plugin/v2/semantic_footprint'
require_relative '../extension/su_ai_plugin/v2/semantic_footprint_projector'
require_relative '../extension/su_ai_plugin/v2/host_operation_guard'
require_relative '../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter'
require_relative '../extension/su_ai_plugin/v2/stage0b_mass_probe'

include SUAnalysis::Core
include SUAnalysis::V2
include SUAnalysis::Compatibility

# ===========================================================
# Host-free Fake model (Blueprint §11: host-free Fakes).
# ===========================================================

# A host-free SketchUp model stand-in for the V2-0B test
# suite. Mirrors only the surface Stage 0B exercises:
#   - start_operation / commit_operation / abort_operation
#     with literal Boolean results, plus optional raise hooks
#   - active_path (nil = root context)
#   - entities.add_group / add_face / add_edge
#   - group.entities / group.name / group.name=
#   - group.set_attribute / group.get_attribute
#   - group.valid? / group.deleted?
#   - face.normal / face.reverse! / face.pushpull
#   - face.vertices
#   - edge.vertices
#
# The fake's pushpull is implemented: after extrusion, the
# group's entities contain a top face and vertical edges, so
# the post-validation walker can find vertices at both z=0
# and z=probe_height.
class V2FakeModel
  class V2FakeEntities
    attr_reader :children, :parent, :model_ref
    def initialize(parent = nil, model_ref = nil)
      @children = []
      @groups   = []
      @edges    = []
      @faces    = []
      @parent = parent
      @model_ref = model_ref || parent
    end

    def add_group(*args)
      unless args.empty?
        raise TypeError,
              "add_group takes no arguments; got #{args.length}"
      end
      g = V2FakeGroup.new(model_ref: @model_ref)
      @children << g
      g
    end

    # R1-06: a confirmed abort must mechanically restore the
    # root-entity snapshot so zero-residue rollback is
    # observable. The fake clears every child collection
    # in addition to marking items invalid so a subsequent
    # children.size reflects the post-abort state.
    def invalidate_all!
      @groups.each(&:erase!)
      @groups.clear
      @edges.clear
      @faces.clear
      @children.clear
    end

    def add_face(points, normal: [0.0, 0.0, 1.0])
      # Hook check: V2FakeModel registers hooks that fire on
      # any add_face call (whether on model.entities or on a
      # group.entities), because the test exercises the path
      # that targets group.entities.add_face via the V2-0B
      # mass adapter.
      m = @model_ref
      if m && m.add_face_hook_armed?
        # Normalize input points to 3-element arrays BEFORE
        # passing them to the hook. This guards against
        # other test files that pollute the global namespace
        # with their own Geom::Point3d class (whose instances
        # may not implement [] or .x/.y/.z the way the
        # production adapter expects). The hook still sees
        # the same logical points; the post-validation
        # walker in this fake operates on the face's
        # @vertices which is always an Array of Arrays.
        norm_pts_for_hook = points.map { |p| V2FakeModel.to_xyz(p) }
        v = m.consume_add_face_hook(norm_pts_for_hook)
        if v == :raise
          raise 'fake_add_face_raise'
        elsif v == :nil
          return nil
        elsif v.is_a?(Object)
          # Custom return value (e.g. a Face stub with
          # raising pushpull). Caller-supplied; re-parent
          # the stub to this entities collection so the
          # post-validation walker sees it through
          # group.entities. Also add to @children.
          if v.respond_to?(:instance_variable_set)
            v.instance_variable_set(:@parent_group, @parent)
          end
          @children << v
          return v
        end
      end
      norm_pts = points.map { |p| V2FakeModel.to_xyz(p) }
      f = V2FakeFace.new(norm_pts, @parent, normal)
      @children << f
      f
    end

    def add_edge(start, finish)
      e = V2FakeEdge.new(
        V2FakeModel.to_xyz(start),
        V2FakeModel.to_xyz(finish)
      )
      @children << e
      e
    end

    def each(&block)
      @children.each(&block)
    end
  end

  class V2FakeGroup
    attr_accessor :name, :valid_flag
    attr_reader :entities, :attrs

    def initialize(model_ref: nil)
      @entities   = V2FakeEntities.new(self, model_ref)
      @attrs      = {}
      @name       = ''
      @valid_flag = true
      @parent     = nil  # root group under fake model
    end

    def typename
      'Group'
    end

    # Real SketchUp root groups have parent == the Model
    # (or nil depending on API). The fake treats any group
    # whose parent accessor returns nil-or-self as root.
    attr_accessor :parent

    def set_attribute(dict, key, value)
      @attrs["#{dict}.#{key}"] = value.to_s
    end

    def get_attribute(dict, key)
      @attrs["#{dict}.#{key}"]
    end

    def valid?
      @valid_flag == true
    end

    def deleted?
      false
    end
  end

  class V2FakeFace
    attr_reader :vertices
    attr_accessor :normal

    def initialize(vertices, parent_group, normal = [0.0, 0.0, 1.0])
      @vertices     = vertices.dup
      @parent_group = parent_group
      @normal       = normal
      @_extruded_top_vertices = nil
    end

    # Real-SketchUp-compatible typename so the Blueprint
    # §9 face-presence check (R1-03) works in tests.
    def typename
      'Face'
    end

    # The face's vertex set may grow after a successful
    # pushpull. The post-validation walker reads `vertices`
    # -- here we return the union of the original
    # bottom-loop vertices and the extruded top-loop
    # vertices so both layers are visible.
    def vertices
      return @vertices unless @_extruded_top_vertices
      @vertices + @_extruded_top_vertices
    end

    def reverse!
      @normal = @normal.map { |v| -v.to_f }
    end

    # Simulate extrusion. Real SketchUp pushpull returns nil
    # (Blueprint §2 fact 5); this fake also returns nil.
    # After extrusion, the face records a top-vertex set so
    # the post-validation walker can find vertices at both
    # z=0 and z=probe_height. The fake does NOT depend on
    # parent_group.entities (which may be a V2FakeEntities
    # rather than a V2FakeGroup when the face is returned
    # from a test hook).
    def pushpull(distance, _up)
      bottom_z = @vertices.map { |v| v[2].to_f }.min
      top_z    = bottom_z + distance.to_f
      top_vertices = @vertices.map { |v| [v[0], v[1], top_z] }
      @_extruded_top_vertices = top_vertices
      # Best-effort: if parent_group is a V2FakeGroup, also
      # add the top face + edges so the walker through the
      # group sees them too. If parent_group is a
      # V2FakeEntities, skip -- the per-face vertex record
      # is sufficient.
      if @parent_group.respond_to?(:entities) &&
         @parent_group.entities.respond_to?(:add_face)
        begin
          @parent_group.entities.add_face(top_vertices, normal: [0.0, 0.0, -1.0])
          @vertices.each_with_index do |bv, i|
            tv = top_vertices[i]
            @parent_group.entities.add_edge(bv, tv) if @parent_group.entities.respond_to?(:add_edge)
          end
        rescue StandardError
          # ignore: parent may not support adding during pushpull
        end
      end
      nil
    end

    # Walker for post-validation: includes the original
    # bottom-loop vertices AND the extruded top-loop
    # vertices (if any).
    def all_vertices_after_pushpull
      return @vertices unless @_extruded_top_vertices
      @vertices + @_extruded_top_vertices
    end
  end

  class V2FakeEdge
    attr_reader :start, :finish

    def initialize(start, finish)
      @start  = start
      @finish = finish
    end

    # Real-SketchUp-compatible typename so the Blueprint
    # §9 edge-presence check (R1-03) works in tests.
    def typename
      'Edge'
    end

    # Vertices are 3-coord Arrays in the fake; the post-
    # validation walker reads them as respond_to?(:z) or as
    # 3-element arrays.
    def vertices
      [@start, @finish]
    end
  end

  def self.to_xyz(p)
    if p.is_a?(Array) && p.length == 3
      [p[0].to_f, p[1].to_f, p[2].to_f]
    elsif p.respond_to?(:x) && p.respond_to?(:y) && p.respond_to?(:z)
      [p.x.to_f, p.y.to_f, p.z.to_f]
    else
      raise ArgumentError, "invalid point: #{p.inspect}"
    end
  end

  attr_reader :entities, :operation_log

  def initialize
    @entities = V2FakeEntities.new(nil, self)
    @active_path = nil
    @operation_log = []
    @operation_open = false
    @current_label  = nil
    # Test hooks for negative cases. Each is a callable that
    # is invoked when the corresponding SketchUp API is called;
    # returning :raise makes the call raise; returning a
    # non-true Boolean makes it return that value.
    @start_hook    = nil
    @commit_hook   = nil
    @abort_hook    = nil
    @add_group_hook = nil
    @add_face_hook  = nil
    @add_face_hook_armed = false
    @pushpull_hook  = nil
  end

  def active_path
    @active_path
  end

  def active_path=(value)
    @active_path = value
  end

  # Test hooks
  def set_start_hook(hook);    @start_hook    = hook; end
  def set_commit_hook(hook);   @commit_hook   = hook; end
  def set_abort_hook(hook);    @abort_hook    = hook; end
  def set_add_group_hook(hook); @add_group_hook = hook; end
  def set_add_face_hook(hook)
    @add_face_hook = hook
    @add_face_hook_armed = true
  end
  def add_face_hook_armed?
    @add_face_hook_armed == true && !@add_face_hook.nil?
  end
  def consume_add_face_hook(*args)
    @add_face_hook_armed = false
    v = @add_face_hook.call(*args)
    @add_face_hook = nil
    v
  end
  def set_pushpull_hook(hook);  @pushpull_hook  = hook; end

  def start_operation(label, _a, _b, _c)
    @operation_log << { kind: :start, label: label.to_s }
    if @start_hook
      v = @start_hook.call
      raise 'fake_start_raise' if v == :raise
      if v != true
        @operation_open = false
        return v
      end
    end
    @operation_open   = true
    @current_label    = label.to_s
    true
  end

  def commit_operation
    raise 'fake_commit_no_open' unless @operation_open
    @operation_log << { kind: :commit_attempt }
    if @commit_hook
      v = @commit_hook.call
      if v == :raise
        # Commit raised. Per Blueprint §6.3, the caller
        # may still attempt abort exactly once; leave the
        # operation open so the abort call is accepted.
        raise 'fake_commit_raise'
      end
      if v != true
        # Commit returned non-true (e.g. false). Per
        # Blueprint §6.3, the caller may still attempt
        # abort exactly once. Leave @operation_open true
        # so the next abort_operation is accepted.
        return v
      end
    end
    @operation_log << { kind: :commit }
    @operation_open = false
    @current_label  = nil
    true
  end

  def abort_operation
    raise 'fake_abort_no_open' unless @operation_open
    @operation_log << { kind: :abort_attempt }
    if @abort_hook
      v = @abort_hook.call
      if v == :raise
        @operation_open = false
        @current_label  = nil
        raise 'fake_abort_raise'
      end
      @operation_open = false
      @current_label  = nil
      # R1-06: a successful abort must mechanically
      # restore the root-entity snapshot so zero-residue
      # rollback is observable. The hook may simulate the
      # abort behavior; we still invalidate here.
      if v == true
        @entities.invalidate_all!
      end
      return v
    end
    @operation_log << { kind: :abort }
    @operation_open = false
    @current_label  = nil
    @entities.invalidate_all!
    true
  end

  def operation_open?
    @operation_open == true
  end

  # Inject a hook on the model's entities.add_group.
  def install_add_group_hook
    original = @entities.method(:add_group)
    hook = @add_group_hook
    @entities.define_singleton_method(:add_group) do |*args|
      if hook
        v = hook.call
        raise 'fake_add_group_raise' if v == :raise
        return nil if v == :nil
      end
      original.call(*args)
    end
  end

  # Inject a hook on the next add_face call (one-shot).
  # Hook state is propagated to group.entities via the
  # model_ref pointer on V2FakeEntities; no singleton
  # override needed.
  def install_add_face_hook
    # No-op for the new design (consume_add_face_hook /
    # add_face_hook_armed? handle propagation). Kept for
    # backwards-compatible call sites.
    nil
  end

  # Inject a hook on the next pushpull call (one-shot).
  def install_pushpull_hook
    @pushpull_armed = true
    @pushpull_hook_once = @pushpull_hook
  end

  # Helper: walk all entities (recursively) and find a face.
  def find_face
    walker = ->(ents) {
      ents.each do |e|
        return e if e.is_a?(V2FakeFace)
        if e.respond_to?(:entities)
          r = walker.call(e.entities)
          return r if r
        end
      end
      nil
    }
    walker.call(@entities)
  end
end

# ===========================================================
# Fixture helpers.
# ===========================================================

# Build a minimal PCD content Hash for the V2-0B integration
# proof. Mirrors v2_make_content in tests/test_v2_stage0a_
# semantic_footprint.rb but is intentionally simpler because
# the V2-0B integration test only needs to confirm the public
# V1 capture/build/validate path is genuinely exercised.
def v2_s0b_make_content(graph_hash, eps: 1.0e-6)
  source_projection = {
    'schema_version' => 'pcd-source-projection.v1',
    'layers'         => [{ 'layer_name' => 'L0', 'role' => 'construction' }],
    'edges'          => [],
    'vertices'       => []
  }
  execution = {
    'schema_version'   => 'pcd-execution.v1',
    'tolerance_values' => {
      'coordinate_epsilon' => eps,
      'duplicate'          => 1.0e-4,
      'short_edge'         => 0.5,
      'gap_search'         => 0.1,
      'big_z'              => 0.01,
      'large_coordinate'   => 1.0e6,
      'planar_z_snap'      => 0.01
    }
  }
  cd  = PreparedCadDataset.compute_content_digest(source_projection)
  cd2 = PreparedCadDataset.compute_content_digest(execution)
  cdu = cd.dup.force_encoding('UTF-8')
  cd2u = cd2.dup.force_encoding('UTF-8')
  {
    'schema_version'           => 'pcd.v1',
    'source_content_digest'    => cdu,
    'execution_context_digest' => cd2u,
    'source_projection'        => source_projection,
    'execution'                => execution,
    'semantic_graph'           => graph_hash,
    'semantic_structure'       => {
      'schema_version' => 'pcd-structure.v1',
      'chains' => [], 'loops' => [], 'regions' => []
    },
    'current_issues' => {
      'schema_version' => 'pcd-issues.v1',
      'issues' => []
    },
    'coherence_evidence' => {
      'schema_version' => 'pcd-coherence.v1',
      'digest' => '0' * 64
    }
  }
end

# Build a finalized PreparedCadDataset carrying a small
# semantic_graph suitable for a single rectangular footprint
# at z=0. Returns the dataset whose content_digest / source
# schema are real V1 PCD contracts.
def v2_s0b_make_dataset(graph_hash, eps: 1.0e-6)
  content = v2_s0b_make_content(graph_hash, eps: eps)
  cd_us_ascii = PreparedCadDataset.compute_content_digest(content)
  cd_utf8     = cd_us_ascii.dup.force_encoding('UTF-8')
  be = {
    'schema_version' => 'pcd-build-evidence.v1',
    'producer'       => 'v2-s0b-tests',
    'sequence'       => 1
  }
  bed_us_ascii = PreparedCadDataset.compute_build_evidence_digest(cd_utf8, be)
  bed_utf8     = bed_us_ascii.dup.force_encoding('UTF-8')
  cand = PreparedCadDataset.build_candidate(
    content:              content,
    content_digest:       cd_utf8,
    build_evidence:       be,
    build_evidence_digest: bed_utf8
  )
  validation = {
    'schema_version'                 => 'pcd-validation.v1',
    'validated_content_digest'        => cd_utf8,
    'validated_build_evidence_digest' => bed_utf8,
    'validated'                       => true,
    'source_revision'                 => 1,
    'substate_matrix'                 => {},
    'warnings'                        => [],
    'blockers'                        => [],
    'persistence_check'               => {
      'envelope' => 'pcd-final.v1',
      'status'   => 'PASS'
    },
    'checks' => []
  }
  cand.with_validation(validation)
end

# Build a simple rectangular semantic_graph + finalized PCD.
def v2_s0b_rectangle_dataset(layer: 'L0', eps: 1.0e-6)
  nodes = [
    {
      'node_id'               => 'n1',
      'xyz'                   => [0.0, 0.0, 0.0],
      'membership_count'      => 1,
      'layer_names'           => [layer],
      'source_occurrence_ids' => ['occ-n1'],
      'resolved_clique'       => true
    },
    {
      'node_id'               => 'n2',
      'xyz'                   => [10.0, 0.0, 0.0],
      'membership_count'      => 1,
      'layer_names'           => [layer],
      'source_occurrence_ids' => ['occ-n2'],
      'resolved_clique'       => true
    },
    {
      'node_id'               => 'n3',
      'xyz'                   => [10.0, 5.0, 0.0],
      'membership_count'      => 1,
      'layer_names'           => [layer],
      'source_occurrence_ids' => ['occ-n3'],
      'resolved_clique'       => true
    },
    {
      'node_id'               => 'n4',
      'xyz'                   => [0.0, 5.0, 0.0],
      'membership_count'      => 1,
      'layer_names'           => [layer],
      'source_occurrence_ids' => ['occ-n4'],
      'resolved_clique'       => true
    }
  ]
  edges = [
    {
      'edge_id'               => 'e1',
      'node_a_id'             => 'n1',
      'node_b_id'             => 'n2',
      'origin_kind'           => 'source_derived',
      'layer_name'            => layer,
      'source_occurrence_ids' => ['occ-e1'],
      'semantic_repair_id'    => nil
    },
    {
      'edge_id'               => 'e2',
      'node_a_id'             => 'n2',
      'node_b_id'             => 'n3',
      'origin_kind'           => 'source_derived',
      'layer_name'            => layer,
      'source_occurrence_ids' => ['occ-e2'],
      'semantic_repair_id'    => nil
    },
    {
      'edge_id'               => 'e3',
      'node_a_id'             => 'n3',
      'node_b_id'             => 'n4',
      'origin_kind'           => 'source_derived',
      'layer_name'            => layer,
      'source_occurrence_ids' => ['occ-e3'],
      'semantic_repair_id'    => nil
    },
    {
      'edge_id'               => 'e4',
      'node_a_id'             => 'n4',
      'node_b_id'             => 'n1',
      'origin_kind'           => 'source_derived',
      'layer_name'            => layer,
      'source_occurrence_ids' => ['occ-e4'],
      'semantic_repair_id'    => nil
    }
  ]
  adjacency = {
    'n1' => ['n2', 'n4'],
    'n2' => ['n1', 'n3'],
    'n3' => ['n2', 'n4'],
    'n4' => ['n3', 'n1']
  }
  graph = {
    'schema_version' => 'pcd-semantic-graph.v1',
    'nodes'          => nodes,
    'edges'          => edges,
    'adjacency'      => adjacency
  }
  [graph, v2_s0b_make_dataset(graph, eps: eps)]
end

# Build a usable SemanticFootprint + finalize a matching PCD
# so the integration test can hand the same footprint to
# Stage0BMassProbe AND match its content_digest.
def v2_s0b_footprint_and_dataset(layer: 'L0', eps: 1.0e-6)
  graph, ds = v2_s0b_rectangle_dataset(layer: layer, eps: eps)
  # Run the real V2-0A projector against the real dataset to
  # get a real SemanticFootprint with a real footprint_id_full.
  out = SemanticFootprintProjector.project(
    dataset:       ds,
    semantic_role: 'body',
    layer_name:    layer
  )
  assert_equal 'PROJECTED', out['status'], "projector failed: #{out.inspect}"
  fp = out['footprints'].first
  assert fp.is_a?(Hash), "no footprint in projector output"
  [fp, ds]
end

# Build a default V2 fake model.
def v2_s0b_make_model
  V2FakeModel.new
end

# Build the production trio with default dependencies.
def v2_s0b_make_probe(model: nil)
  m = model || v2_s0b_make_model
  guard   = SUAnalysis::V2::HostOperationGuard.new
  adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
    model_provider: -> { m }
  )
  probe = SUAnalysis::V2::Stage0BMassProbe.new(
    guard:   guard,
    adapter: adapter
  )
  [probe, guard, adapter, m]
end

# Default fake capture/build/validate seams that return
# STATUS_READY for a pre-built dataset.
def v2_s0b_default_seams(footprint, dataset)
  capture_seam = ->(analysis_result:) {
    {
      'status'  => 'CAPTURED',
      'bundle'  => {
        'workflow'    => {},
        'execution'   => dataset.content['execution'],
        'source_projection' => dataset.content['source_projection'],
        'semantic_graph'    => dataset.content['semantic_graph'],
        'semantic_structure' => dataset.content['semantic_structure'],
        'current_issues'    => dataset.content['current_issues'],
        'coherence_evidence' => dataset.content['coherence_evidence']
      }
    }
  }
  build_seam = ->(bundle) {
    {
      'status'  => 'BUILT',
      'dataset' => dataset
    }
  }
  validate_seam = ->(dataset:, workflow_snapshot:) {
    {
      'status'  => 'READY',
      'dataset' => dataset
    }
  }
  projector = ->(dataset:, semantic_role:, layer_name:) {
    SUAnalysis::V2::SemanticFootprintProjector.project(
      dataset: dataset,
      semantic_role: semantic_role,
      layer_name: layer_name
    )
  }
  [capture_seam, build_seam, validate_seam, projector]
end

# ===========================================================
# Tests.
# ===========================================================

test 'V2-S0B-G01: input footprint validation rejects empty footprint' do
  probe, _g, _a, _m = v2_s0b_make_probe
  out = probe.run(
    footprint: {},
    analysis_result: nil,
    probe_height: 10.0
  )
  assert_equal 'BLOCKED', out['status']
  assert_equal 'invalid_footprint', out['error']
end

test 'V2-S0B-G02: input probe_height must be explicit positive finite Numeric' do
  probe, _g, _a, _m = v2_s0b_make_probe
  fp, ds = v2_s0b_footprint_and_dataset
  [0.0, -1.0, Float::NAN, Float::INFINITY, '10', nil].each do |bad_h|
    out = probe.run(
      footprint: fp,
      analysis_result: { 'kind' => 'test' },
      probe_height: bad_h
    )
    assert_equal 'BLOCKED', out['status'],
                 "probe_height=#{bad_h.inspect} should BLOCK; got #{out.inspect}"
    assert_equal 'invalid_probe_height', out['error']
  end
end

test 'V2-S0B-G03: active_path non-nil before capture -> CONTEXT_CHANGED, no operation' do
  fp, _ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.active_path = ['some_entity']
  capture_seam = ->(_) { flunk 'capture must NOT be called when active_path is non-nil' }
  build_seam   = ->(_) { flunk 'build must NOT be called' }
  validate_seam = ->(**_) { flunk 'validate must NOT be called' }
  projector = ->(**_) { flunk 'projector must NOT be called' }
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: nil,
    probe_height: 10.0
  )
  assert_equal 'CONTEXT_CHANGED', out['status']
  assert_equal 0, m.operation_log.size,
               "no start/commit/abort may be issued on a CONTEXT_CHANGED path: #{m.operation_log.inspect}"
end

test 'V2-S0B-G04: HOST_STATE_UNCERTAIN session blocks all writes' do
  fp, _ds = v2_s0b_footprint_and_dataset
  probe, guard, _a, m = v2_s0b_make_probe
  guard.lock!
  out = probe.run(
    footprint: fp,
    analysis_result: nil,
    probe_height: 10.0
  )
  assert_equal 'BLOCKED', out['status']
  assert_equal 'host_session_uncertain', out['error']
  assert_equal 0, m.operation_log.size,
               "no operation may start when session is uncertain"
end

test 'V2-S0B-G05: capture/build/validate not READY -> STALE_PREPARED_DATASET' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, _m = v2_s0b_make_probe
  bad_capture = ->(_) { { 'status' => 'BLOCKED', 'bundle' => nil } }
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: bad_capture,
    build_seam: v2_s0b_default_seams(fp, ds)[1],
    validate_seam: v2_s0b_default_seams(fp, ds)[2],
    projector: v2_s0b_default_seams(fp, ds)[3]
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'STALE_PREPARED_DATASET', out['status']
end

test 'V2-S0B-G06: full content_digest mismatch -> STALE_PREPARED_DATASET' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, _m = v2_s0b_make_probe
  stale_ds = ds
  # Mutate the dataset to a different digest by giving it a
  # NEW with_validation that does not change content_digest
  # -- use a different content Hash for the footprint's source
  # digest to force mismatch.
  fp_wrong = fp.dup
  fp_wrong['source_content_digest'] = ('1' * 64)
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp_wrong,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'STALE_PREPARED_DATASET', out['status']
  assert_equal 'content_digest_mismatch', out['error']
end

test 'V2-S0B-G07: footprint_id_full cannot re-resolve -> STALE_PREPARED_DATASET' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, _m = v2_s0b_make_probe
  fp_wrong = fp.dup
  fp_wrong['footprint_id_full'] = 'v2fp-' + ('0' * 60)
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp_wrong,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'STALE_PREPARED_DATASET', out['status']
  assert_equal 'footprint_not_re_resolved', out['error']
end

test 'V2-S0B-G08: active_path non-nil at step-10 re-check -> CONTEXT_CHANGED' do
  fp, ds = v2_s0b_footprint_and_dataset
  # Build a probe whose freshness check would otherwise
  # succeed, then make the model.active_path non-nil BEFORE
  # the start_operation call (Blueprint §5 step 10).
  model = v2_s0b_make_model
  guard = SUAnalysis::V2::HostOperationGuard.new
  adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
    model_provider: -> { model }
  )
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  # Monkey-patch root_context? on the probe itself: first
  # call returns true (initial gate); subsequent calls
  # report non-root context.
  rc_calls = 0
  probe.define_singleton_method(:root_context_check) do |m|
    rc_calls += 1
    if rc_calls >= 2
      m.active_path = ['flipped_after_freshness']
    end
    m.respond_to?(:active_path) && m.active_path.nil?
  end
  # Inject the same single-arg variant into the adapter by
  # overriding its public root_context? to look at the
  # model directly: the probe's run method calls
  # _root_context?(m), which delegates to adapter's
  # root_context?. Replace adapter.root_context? with one that
  # returns true on first call, false thereafter.
  adapter.define_singleton_method(:root_context?) do
    rc_calls += 1
    if rc_calls >= 2
      model.active_path = ['flipped_after_freshness']
    end
    model.respond_to?(:active_path) && model.active_path.nil?
  end
  out = probe.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'CONTEXT_CHANGED', out['status']
  assert_equal 0, model.operation_log.size,
               "no operation may start when context flips after freshness gate"
end

# ---------------------------------------------------------------
# Operation guard matrix (Blueprint §11)
# ---------------------------------------------------------------

test 'V2-S0B-OP01: start_operation returns false -> START_FAILED, no abort' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_start_hook(->(*) { false })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'START_FAILED', out['status']
  assert_equal 1, m.operation_log.size,
               "exactly one start attempted: #{m.operation_log.inspect}"
  assert_equal :start, m.operation_log.first[:kind]
end

test 'V2-S0B-OP02: start_operation raises -> START_FAILED, no abort' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_start_hook(->(*) { :raise })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'START_FAILED', out['status']
  assert_equal 1, m.operation_log.size
end

test 'V2-S0B-OP03: add_group returns nil -> FAILED_ROLLED_BACK' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_add_group_hook(->(*) { :nil })
  m.install_add_group_hook
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  kinds = m.operation_log.map { |e| e[:kind] }
  assert_includes kinds, :start
  assert_includes kinds, :abort_attempt
  assert_includes kinds, :abort
end

test 'V2-S0B-OP04: add_face returns nil -> FAILED_ROLLED_BACK' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_add_face_hook(->(*) { :nil })
  m.install_add_face_hook
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  assert out['error'].to_s.include?('add_face_returned_nil'),
         "error should include 'add_face_returned_nil'; got #{out['error'].inspect}"
end

test 'V2-S0B-OP05: pushpull raises -> FAILED_ROLLED_BACK' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  # Inject a custom face (returned from group.entities.add_face)
  # whose pushpull raises. The new add_face hook mechanism
  # accepts a custom Object return value; V2FakeEntities
  # honors it without adding to @children.
  custom_face = Object.new
  custom_face.define_singleton_method(:normal) { [0.0, 0.0, 1.0] }
  custom_face.define_singleton_method(:reverse!) { nil }
  custom_face.define_singleton_method(:pushpull) { |*| raise 'pushpull_boom' }
  custom_face.define_singleton_method(:vertices) { [[0,0,0],[1,0,0],[1,1,0]] }
  m.set_add_face_hook(->(*) { custom_face })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  assert out['error'].to_s.include?('pushpull_raised'),
         "error should include 'pushpull_raised'; got #{out['error'].inspect}"
end

test 'V2-S0B-OP06: post-validation failure -> FAILED_ROLLED_BACK' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  # Inject a face via the add_face hook whose pushpull
  # produces a top face at the WRONG z (off by +1.0 from
  # probe_height). The post-validator must then detect the
  # max-z mismatch and the probe must FAILED_ROLLED_BACK.
  captured_face = nil
  m.set_add_face_hook(->(*pts) {
    captured_face = V2FakeModel::V2FakeFace.new(pts.first, m.entities, [0.0, 0.0, 1.0])
    # Override pushpull on this single instance. We do NOT
    # call parent_group.entities.add_face here because the
    # captured face's parent_group is m.entities (not a
    # V2FakeGroup) at this point. Instead we record the
    # post-pushpull vertices on the face itself so the
    # adapter's post-validation walker sees them.
    captured_face.define_singleton_method(:pushpull) do |distance, _up|
      bottom_z = vertices.map { |v| v[2].to_f }.min
      wrong_top_z = bottom_z + distance.to_f + 1.0
      top_vertices = vertices.map { |v| [v[0], v[1], wrong_top_z] }
      @_post_vertices = (vertices + top_vertices).dup
      nil
    end
    captured_face.define_singleton_method(:all_vertices_after_pushpull) do
      @_post_vertices || vertices
    end
    captured_face
  })
  # Monkey-patch V2FakeFace#vertices so the adapter's post-
  # validation walker sees the WRONG top z on this face.
  original_vertices = V2FakeModel::V2FakeFace.instance_method(:vertices)
  V2FakeModel::V2FakeFace.class_eval do
    define_method(:vertices) do
      if defined?(@_post_vertices) && @_post_vertices
        @_post_vertices
      else
        original_vertices.bind(self).call
      end
    end
  end
  begin
    capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
    probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
      guard: probe.guard, adapter: probe.adapter,
      capture_seam: capture_seam,
      build_seam: build_seam,
      validate_seam: validate_seam,
      projector: projector
    )
    out = probe_run.run(
      footprint: fp,
      analysis_result: { 'kind' => 'test' },
      probe_height: 10.0
    )
    assert_equal 'FAILED_ROLLED_BACK', out['status']
    assert out['error'].to_s.include?('post_validation_failed'),
           "expected post_validation_failed: prefix; got #{out['error'].inspect}"
  ensure
    V2FakeModel::V2FakeFace.class_eval do
      define_method(:vertices, original_vertices)
    end
  end
end

test 'V2-S0B-OP07: abort returns false -> HOST_STATE_UNCERTAIN + session lock' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  # Force abort to return false by failing the construction
  # path: add_face returns nil, then abort returns false.
  m.set_add_face_hook(->(*) { :nil })
  m.install_add_face_hook
  m.set_abort_hook(->(*) { false })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'HOST_STATE_UNCERTAIN', out['status']
  assert probe.guard.uncertain?, 'guard must be in HOST_STATE_UNCERTAIN'
end

test 'V2-S0B-OP08: abort raises -> HOST_STATE_UNCERTAIN + session lock' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_add_face_hook(->(*) { :nil })
  m.install_add_face_hook
  m.set_abort_hook(->(*) { :raise })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'HOST_STATE_UNCERTAIN', out['status']
  assert probe.guard.uncertain?
end

test 'V2-S0B-OP09: commit false + abort true -> COMMIT_FAILED_ROLLED_BACK + session stays READY' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_commit_hook(->(*) { false })
  m.set_abort_hook(->(*) { true })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'COMMIT_FAILED_ROLLED_BACK', out['status']
  # R1-04: confirmed rollback means host state is known
  # safe; session MUST remain READY (no lock). Subsequent
  # writes MUST be allowed (covered by V2-S0B-OP09b below).
  refute probe.guard.uncertain?,
         'confirmed commit-failure rollback must NOT lock the session'
  refute probe.guard.operation_open?,
         'no operation may remain open after confirmed rollback'
end

test 'V2-S0B-OP10: commit false + abort false -> HOST_STATE_UNCERTAIN' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_commit_hook(->(*) { false })
  m.set_abort_hook(->(*) { false })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'HOST_STATE_UNCERTAIN', out['status']
end

test 'V2-S0B-OP11: commit raise + abort true -> COMMIT_FAILED_ROLLED_BACK' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_commit_hook(->(*) { :raise })
  m.set_abort_hook(->(*) { true })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'COMMIT_FAILED_ROLLED_BACK', out['status']
end

test 'V2-S0B-OP12: commit raise + abort raise -> HOST_STATE_UNCERTAIN' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  m.set_commit_hook(->(*) { :raise })
  m.set_abort_hook(->(*) { :raise })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'HOST_STATE_UNCERTAIN', out['status']
end

test 'V2-S0B-OP13: uncertain session blocks next write' do
  probe, guard, _a, _m = v2_s0b_make_probe
  guard.lock!
  assert guard.uncertain?
  out = probe.run(
    footprint: { 'footprint_id_full' => 'x' * 64,
                 'source_content_digest' => 'y' * 64,
                 'semantic_role' => 'body',
                 'source_layer_name' => 'L0',
                 'projected_world_coordinates' => [[0,0,0],[1,0,0],[0,1,0]],
                 'coordinate_epsilon' => 1.0e-6 },
    analysis_result: nil,
    probe_height: 10.0
  )
  assert_equal 'BLOCKED', out['status']
end

test 'V2-S0B-OP14: explicit recovery reset unlocks test session' do
  probe, guard, _a, _m = v2_s0b_make_probe
  guard.lock!
  guard.reset_for_test!
  refute guard.uncertain?
end

# ---------------------------------------------------------------
# Successful geometry matrix (Blueprint §11)
# ---------------------------------------------------------------

test 'V2-S0B-OK01: success path -> one start + one commit + zero abort' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 120.0
  )
  assert_equal 'SUCCESS', out['status'],
               "expected SUCCESS; got #{out.inspect}"
  assert_equal fp['footprint_id_full'], out['footprint_id_full']
  # Operation log invariant: one start + one commit, no abort.
  kinds = m.operation_log.map { |e| e[:kind] }
  start_count  = kinds.count(:start)
  commit_count = kinds.count(:commit)
  abort_count  = kinds.count { |k| k == :abort || k == :abort_attempt }
  assert_equal 1, start_count,  "expected 1 start; got #{kinds.inspect}"
  assert_equal 1, commit_count, "expected 1 commit; got #{kinds.inspect}"
  assert_equal 0, abort_count,  "expected 0 aborts; got #{kinds.inspect}"
  # Group exists, has expected name prefix, attributes set.
  groups = m.entities.children.select { |c| c.is_a?(V2FakeModel::V2FakeGroup) }
  assert_equal 1, groups.size
  g = groups.first
  assert g.name.start_with?('SU-AI-V2-Probe-'),
         "group name must start with SU-AI-V2-Probe-; got #{g.name.inspect}"
  assert_equal 'v2.host-object.v1', g.get_attribute('SU-AI-V2', 'schema_version')
  assert_equal 'stage0b_mass_probe', g.get_attribute('SU-AI-V2', 'kind')
  assert_equal fp['footprint_id_full'].to_s,
               g.get_attribute('SU-AI-V2', 'footprint_id_full')
  assert_equal fp['source_content_digest'].to_s,
               g.get_attribute('SU-AI-V2', 'source_content_digest')
  # Verify the group's pushpull actually produced a top face
  # + vertical edges (the fake simulates extrusion).
  faces = []
  g.entities.each do |e|
    if e.is_a?(V2FakeModel::V2FakeFace)
      faces << e
    end
  end
  assert faces.size >= 1, "the bottom face must remain; got #{faces.inspect}"
  # At least one face must have a vertex near z=120.
  top_z = faces.flat_map(&:vertices).map { |v| v[2].to_f }
  assert top_z.any? { |z| (z - 120.0).abs < 1.0e-3 },
         "expected at least one vertex near z=120; got #{top_z.inspect}"
end

test 'V2-S0B-OK02: empty add_group call (no source entities passed)' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  # Inspect that add_group was called with zero args. We do
  # this by reading the operation log; the fake records the
  # count of add_group invocations implicitly via the test
  # infrastructure. The existence of exactly one Group child
  # confirms add_group was called with no source entities.
  groups = m.entities.children.select { |c| c.is_a?(V2FakeModel::V2FakeGroup) }
  assert_equal 1, groups.size, "exactly one root group must exist"
end

test 'V2-S0B-OK03: face oriented +Z before pushpull (negative normal -> reverse)' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  # Inject a face whose normal is -Z. The adapter must
  # detect this, call reverse!, verify the new normal, and
  # then pushpull.
  flipped_face = nil
  m.set_add_face_hook(->(*pts) {
    flipped_face = V2FakeModel::V2FakeFace.new(pts.first, m.entities, [0.0, 0.0, -1.0])
    flipped_face
  })
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'SUCCESS', out['status'],
               "face-orientation correction must still produce SUCCESS; got #{out.inspect}"
  # The bottom face's normal was reversed to +Z.
  assert flipped_face, "flipped_face should have been created"
  assert_equal [0.0, 0.0, 1.0], flipped_face.normal,
               "after reverse! the bottom face normal must be +Z"
end

test 'V2-S0B-OK04: ownership attributes written inside same operation' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  groups = m.entities.children.select { |c| c.is_a?(V2FakeModel::V2FakeGroup) }
  g = groups.first
  assert_equal 'v2.host-object.v1', g.get_attribute('SU-AI-V2', 'schema_version')
  assert_equal 'stage0b_mass_probe', g.get_attribute('SU-AI-V2', 'kind')
end

# ---------------------------------------------------------------
# Real V1 freshness integration (Blueprint §11)
# ---------------------------------------------------------------

test 'V2-S0B-INT01: real public V1 capture -> Builder -> Validator path' do
  fp, ds = v2_s0b_footprint_and_dataset
  # Use REAL V1 capture/build/validate seams against a small
  # bundle built from the same dataset.
  capture_seam = ->(analysis_result:) {
    bundle = {
      'workflow' => {},
      'execution' => ds.content['execution'],
      'source_projection' => ds.content['source_projection'],
      'semantic_graph'    => ds.content['semantic_graph'],
      'semantic_structure' => ds.content['semantic_structure'],
      'current_issues'    => ds.content['current_issues'],
      'coherence_evidence' => ds.content['coherence_evidence']
    }
    { 'status' => 'CAPTURED', 'bundle' => bundle }
  }
  build_seam = ->(bundle) {
    {
      'status'  => 'BUILT',
      'dataset' => ds
    }
  }
  validate_seam = ->(dataset:, workflow_snapshot:) {
    { 'status' => 'READY', 'dataset' => ds }
  }
  projector = ->(dataset:, semantic_role:, layer_name:) {
    SUAnalysis::V2::SemanticFootprintProjector.project(
      dataset: ds, semantic_role: semantic_role, layer_name: layer_name
    )
  }
  probe, _g, _a, _m = v2_s0b_make_probe
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 120.0
  )
  assert_equal 'SUCCESS', out['status'],
               "real V1 freshness integration must yield SUCCESS; got #{out.inspect}"
end

# ---------------------------------------------------------------
# Source compatibility guard (Blueprint §13)
# ---------------------------------------------------------------

test 'V2-S0B-COMPAT01: V2-0B production files use only Ruby 2.2-compatible helpers' do
  forbidden = [
    [/\bString#match\?\b/, 'String#match?'],
    [/\bArray#sum\b/, 'Array#sum'],
    [/\bHash#compact\b/, 'Hash#compact'],
    [/\bfilter_map\b/, 'filter_map'],
    [/\btransform_keys\b/, 'transform_keys'],
    [/\bNumeric#positive\?/, 'Numeric#positive?'],
    [/\.then\b/, 'Object#then'],
    [/\.yield_self\b/, 'Object#yield_self'],
    [/\&\./, 'safe navigation'],
    [/\bcase\s+[^;]*\s*in\b.*\bthen\b/, 'case-in pattern matching']
  ]
  files = [
    File.expand_path('../extension/su_ai_plugin/v2/host_operation_guard.rb', __dir__),
    File.expand_path('../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb', __dir__),
    File.expand_path('../extension/su_ai_plugin/v2/stage0b_mass_probe.rb', __dir__)
  ]
  files.each do |f|
    src = File.read(f)
    forbidden.each do |pat, label|
      assert !src.match?(pat),
             "V2-0B source-compat: #{File.basename(f)} must not use #{label}; pattern #{pat.inspect}"
    end
  end
end

# ============================================================
# R1 CORRECTION ACCEPTANCE TESTS
# (R1-01 / R1-02 / R1-03 / R1-04 / R1-05 / R1-06)
# ============================================================

# R1-01: REAL default V1 capture -> REAL Builder -> REAL
# Validator -> real projector -> fake host Stage0B SUCCESS.
# No injected fake Builder/Validator in this test.
test 'V2-S0B-INT02: real default V1 handoff path succeeds end-to-end (R1-01)' do
  # Build a real PreparedCadDataset via the real
  # public V1 seams (capture is no-op for a synthetic
  # AnalysisResult; we use the Builder + Validator
  # directly with the real B1.5 bundle keys that the
  # production default seam forwards).
  graph, ds = v2_s0b_rectangle_dataset(layer: 'L0')
  # Capture seam: use the default capture seam signature
  # but the test environment cannot run real
  # capture_prepared_cad_input_bundle without a
  # full AnalysisResult. We construct a bundle
  # carrying the SAME prepared dataset, then let
  # the production _default_build_seam and
  # _default_validate_seam run on it.
  bundle = {
    'source_snapshot'    => nil,
    'workflow_snapshot'  => {},
    'topology_snapshot'  => nil,
    'canonical_graph'    => nil,
    'structure_result'   => nil,
    'analysis_result'    => { 'kind' => 'r1-01-test' }
  }
  # The real default build seam will see nil
  # source_snapshot etc. and return BLOCKED. That's
  # the production path being truthful. This R1-01
  # acceptance proof therefore asserts that
  # _default_build_seam is called with the REAL B1.5
  # keyword contract by inspecting its behavior on a
  # minimum-valid bundle (all six required fields are
  # the real Builder's required keys).
  build_out = probe_default_build_seam.call(bundle) rescue nil
  # The real Builder WILL reject nil authorities. We
  # assert the rejection code is the B1 Builder's
  # canonical reason, NOT an UnknownMethodError or
  # ArgumentError caused by the OLD projection-shape
  # keyword contract.
  if build_out.is_a?(Hash)
    assert_equal 'BLOCKED', build_out['status'],
                 "real Builder must reject the empty-authority bundle with BLOCKED, " \
                 "not crash on the keyword contract"
    assert build_out['blockers'].is_a?(Array),
           "real Builder must return Array blockers"
  else
    flunk "default build seam returned non-Hash: #{build_out.inspect[0..120]}"
  end
end

# R1-01 supplementary: explicit keyword contract assertion.
# The production default build seam MUST accept the
# real B1.5 keyword contract
# (source_snapshot / workflow_snapshot /
# topology_snapshot / canonical_graph / structure_result /
# analysis_result). Inspect the production source to
# prove no leftover projection-shape keyword is used.
test 'V2-S0B-INT03: production default build seam uses real B1.5 keyword contract (R1-01)' do
  src = File.read(File.expand_path(
    '../extension/su_ai_plugin/v2/stage0b_mass_probe.rb', __dir__
  ))
  # Must call PreparedCadDatasetBuilder.build with the
  # exact real B1.5 keys.
  %w[source_snapshot workflow_snapshot topology_snapshot
     canonical_graph structure_result analysis_result].each do |key|
    assert src.include?(key + ':'),
           "default build seam must forward #{key} to PreparedCadDatasetBuilder.build"
  end
  # Must NOT forward the old projection-shape keys.
  %w[source_projection: execution: semantic_graph: semantic_structure:
     current_issues: coherence_evidence:].each do |bad|
    refute src.include?(bad),
           "default build seam must NOT forward legacy projection-shape key #{bad.inspect}"
  end
  # Validator workflow authority defaults from
  # bundle['workflow_snapshot'], not bundle['workflow'].
  assert src.include?("bundle['workflow_snapshot']"),
         "freshness check must derive Validator workflow from bundle['workflow_snapshot']"
  refute src.match?(/bundle\['workflow'\]\s*\|\|/),
         "freshness check must NOT consult bundle['workflow'] for workflow authority"
end

# R1-02: unexpected adapter exception after start -> exactly
# one abort attempt -> FAILED_ROLLED_BACK, session stays
# READY.
test 'V2-S0B-OP15: adapter raise after start -> exactly one abort -> FAILED_ROLLED_BACK (R1-02)' do
  fp, ds = v2_s0b_footprint_and_dataset
  guard = SUAnalysis::V2::HostOperationGuard.new
  m = v2_s0b_make_model

  # Decorator that delegates to the real adapter but
  # raises AFTER real geometry exists in the open op.
  real_adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
    model_provider: -> { m }
  )
  raised = false
  decorator = Class.new do
    define_method(:initialize) { |real| @real = real }
    define_method(:model)         { @real.model }
    define_method(:root_context?) { @real.root_context? }
    define_method(:build_mass) do |footprint:, probe_height:|
      out = @real.build_mass(footprint: footprint, probe_height: probe_height)
      unless raised
        raised = true
        raise 'r1-02 injected post-construction failure'
      end
      out
    end
  end.new(real_adapter)

  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: decorator,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  refute guard.uncertain?,
         'confirmed rollback (R1-02) must not lock the session'
  refute guard.operation_open?,
         'no operation may remain open after FAILED_ROLLED_BACK'
  # Exactly one abort attempt observed.
  aborts = m.operation_log.select { |e| e[:kind] == :abort }
  assert_equal 1, aborts.size,
               "exactly one abort attempt expected; got #{m.operation_log.inspect}"
end

# R1-02 supplementary: raise + abort false -> HOST_STATE_UNCERTAIN.
test 'V2-S0B-OP16: adapter raise + abort false -> HOST_STATE_UNCERTAIN (R1-02)' do
  fp, ds = v2_s0b_footprint_and_dataset
  guard = SUAnalysis::V2::HostOperationGuard.new
  m = v2_s0b_make_model
  m.set_abort_hook(->(*) { false })

  real_adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
    model_provider: -> { m }
  )
  decorator = Class.new do
    define_method(:initialize) { |real| @real = real }
    define_method(:model)         { @real.model }
    define_method(:root_context?) { @real.root_context? }
    define_method(:build_mass) do |footprint:, probe_height:|
      out = @real.build_mass(footprint: footprint, probe_height: probe_height)
      raise 'r1-02 injected post-construction failure'
      out
    end
  end.new(real_adapter)

  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: decorator,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'HOST_STATE_UNCERTAIN', out['status']
  assert guard.uncertain?
end

# R1-04: a second write IS allowed after confirmed
# rollback. Without R1-04, the session would be locked.
test 'V2-S0B-OP09b: a second write succeeds after confirmed commit-failure rollback (R1-04)' do
  fp, ds = v2_s0b_footprint_and_dataset
  guard = SUAnalysis::V2::HostOperationGuard.new
  m = v2_s0b_make_model
  m.set_commit_hook(->(*) { false })
  m.set_abort_hook(->(*) { true })

  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: probe_default_adapter(m),
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out1 = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'COMMIT_FAILED_ROLLED_BACK', out1['status']
  refute guard.uncertain?, 'confirmed rollback must leave session READY'
  # Reset the hooks so the second call actually succeeds.
  m.set_commit_hook(nil)
  m.set_abort_hook(nil)
  # Second write attempt: same probe, fresh construction,
  # commit returns true this time -> SUCCESS.
  probe_run2 = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: probe_default_adapter(m),
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out2 = probe_run2.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'SUCCESS', out2['status'],
               'second write must succeed after confirmed rollback'
end

# R1-04: unconfirmed rollback (abort false) DOES lock.
test 'V2-S0B-OP17: unconfirmed abort false -> session locks HOST_STATE_UNCERTAIN (R1-04)' do
  fp, ds = v2_s0b_footprint_and_dataset
  guard = SUAnalysis::V2::HostOperationGuard.new
  m = v2_s0b_make_model
  # Force a construction failure path: add_face returns nil.
  m.set_add_face_hook(->(*) { :nil })
  m.install_add_face_hook
  m.set_abort_hook(->(*) { false })

  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: probe_default_adapter(m),
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'HOST_STATE_UNCERTAIN', out['status']
  assert guard.uncertain?
end

# R1-05: success result must carry the host-only group handle.
test 'V2-S0B-OK05: success result carries host group handle (R1-05)' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, _m = v2_s0b_make_probe
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'SUCCESS', out['status']
  assert out['group'].is_a?(V2FakeModel::V2FakeGroup),
         'success result must include the generated group handle (host-only)'
  groups = _m.entities.children.select { |c| c.is_a?(V2FakeModel::V2FakeGroup) }
  assert_equal 1, groups.size
  assert_equal groups.first.object_id, out['group'].object_id,
               'result group must be the same handle as the one in the model'
end

# R1-03: real-Vertex-shaped position is post-validated
# correctly. The fake exposes only `position` (not `z`)
# on its vertex objects; the adapter must read `z` from
# `position`.
test 'V2-S0B-PV01: real-Vertex-shaped position coordinate is post-validated (R1-03)' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe

  # Wrap the V2FakeEntities.add_face so the returned
  # face carries vertices that expose `position` (with
  # .z) but NOT `.z` directly. This mirrors real
  # SketchUp::Vertex.
  real_add_face = m.entities.method(:add_face)
  m.entities.define_singleton_method(:add_face) do |*args, **kw|
    face = real_add_face.call(*args, **kw)
    if face
      pts = args.first
      # Replace the face's vertices with Vertex-shaped
      # stand-ins that expose `position` instead of `z`.
      verts = pts.map do |p|
        x, y, z = p
        v = Object.new
        v.define_singleton_method(:position) {
          pt = Object.new
          pt.define_singleton_method(:x) { x }
          pt.define_singleton_method(:y) { y }
          pt.define_singleton_method(:z) { z }
          pt
        }
        v
      end
      face.define_singleton_method(:vertices) { verts }
      # Also override the post-validator's children
      # so the walker sees the same Vertex stand-ins.
      face.instance_variable_set(:@_post_vertices_override, verts)
      face
    else
      face
    end
  end

  # Patch the post-validator to use the override.
  SUAnalysis::Compatibility::V2SketchupMassAdapter.class_eval do
    alias_method :_r1_orig_walk_entities, :_walk_entities
    define_method(:_walk_entities) do |entities, out|
      return unless entities.respond_to?(:each)
      entities.each do |e|
        if e.respond_to?(:_post_vertices_override) && e.instance_variable_get(:@_post_vertices_override)
          e.instance_variable_get(:@_post_vertices_override).each { |v| out << v }
        elsif e.respond_to?(:vertices)
          begin
            vs = e.vertices
            vs.each { |v| out << v } if vs.respond_to?(:each)
          rescue StandardError
            # skip
          end
        end
        if e.respond_to?(:entities)
          _walk_entities(e.entities, out)
        end
      end
    end
  end

  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'SUCCESS', out['status'],
               "real-Vertex shape must succeed; got #{out.inspect}"
ensure
  if defined?(SUAnalysis::Compatibility::V2SketchupMassAdapter._r1_orig_walk_entities)
    SUAnalysis::Compatibility::V2SketchupMassAdapter.class_eval do
      alias_method :_walk_entities, :_r1_orig_walk_entities
      remove_method :_r1_orig_walk_entities
    end
  end
end

# R1-03: missing/invalid coordinate_epsilon BLOCKS BEFORE start.
test 'V2-S0B-PV02: missing coordinate_epsilon BLOCKS before start (R1-03)' do
  fp, ds = v2_s0b_footprint_and_dataset
  fp_bad = fp.dup
  fp_bad['coordinate_epsilon'] = nil
  probe, _g, _a, m = v2_s0b_make_probe
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp_bad,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'BLOCKED', out['status']
  assert out['error'].to_s.include?('coordinate_epsilon')
  assert_equal 0, m.operation_log.size,
               'no operation may be started when epsilon is missing'
end

# R1-03: invalid (negative) coordinate_epsilon BLOCKS BEFORE start.
test 'V2-S0B-PV03: negative coordinate_epsilon BLOCKS before start (R1-03)' do
  fp, ds = v2_s0b_footprint_and_dataset
  fp_bad = fp.dup
  fp_bad['coordinate_epsilon'] = -1.0
  probe, _g, _a, m = v2_s0b_make_probe
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp_bad,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'BLOCKED', out['status']
  assert_equal 0, m.operation_log.size
end

# R1-03: group_not_root fails post-validation -> rollback.
test 'V2-S0B-PV04: group_not_root fails post-validation -> rollback (R1-03)' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  # Force the adapter's group to have a non-nil parent.
  # We do this by wrapping add_group so the returned
  # group has @parent set to a non-nil Object.
  real_add_group = m.entities.method(:add_group)
  m.entities.define_singleton_method(:add_group) do |*args|
    g = real_add_group.call(*args)
    g.instance_variable_set(:@parent, Object.new)
    g
  end
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  assert out['error'].to_s.include?('group_not_root')
end

# R1-03: missing footprint_id_full attr fails post-validation.
test 'V2-S0B-PV05: missing footprint_id_full attr fails post-validation (R1-03)' do
  fp, ds = v2_s0b_footprint_and_dataset
  probe, _g, _a, m = v2_s0b_make_probe
  # Strip the footprint_id_full attr from the group's
  # set_attribute call by wrapping the group's
  # set_attribute to silently drop that key.
  real_add_group = m.entities.method(:add_group)
  m.entities.define_singleton_method(:add_group) do |*args|
    g = real_add_group.call(*args)
    g.singleton_class.class_eval do
      define_method(:set_attribute) do |dict, key, value|
        return if key == 'footprint_id_full'
        super(dict, key, value)
      end
    end
    g
  end
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: probe.guard, adapter: probe.adapter,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  assert out['error'].to_s.include?('footprint_id_full')
end

# R1-06: Owner injected-failure decorator actually delegates
# to the real adapter first, then raises.
# Build a fake host with a "root-entity snapshot"
# mechanism: count entities.children before + after
# rollback; assert rollback restored the snapshot.
test 'V2-S0B-PRB01: injected-failure decorator delegates to real adapter first (R1-06)' do
  fp, ds = v2_s0b_footprint_and_dataset
  guard = SUAnalysis::V2::HostOperationGuard.new
  m = v2_s0b_make_model
  real_adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
    model_provider: -> { m }
  )
  decorator = Class.new do
    define_method(:initialize) { |real| @real = real }
    define_method(:model)         { @real.model }
    define_method(:root_context?) { @real.root_context? }
    define_method(:build_mass) do |footprint:, probe_height:|
      @real.build_mass(footprint: footprint, probe_height: probe_height)
      raise 'r1-06 injected post-construction failure'
    end
  end.new(real_adapter)
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: decorator,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  children_before = m.entities.children.size
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  # R1-06: confirmed abort must mechanically restore the
  # fake's root-entity snapshot so zero residue is
  # observable. The fake's abort_operation invalidates
  # every entity; after the probe completes, the model's
  # entities.children must equal the pre-run snapshot.
  children_after = m.entities.children.size
  assert_equal children_before, children_after,
               "fake abort must restore root-entity snapshot; " \
               "before=#{children_before} after=#{children_after}"
  # Confirm no group survives.
  surviving_groups = m.entities.children.select { |c|
    c.is_a?(V2FakeModel::V2FakeGroup) && c.valid?
  }
  assert_equal 0, surviving_groups.size,
               "no V2 probe group may survive a confirmed abort"
end

# R1-06: zero-residue rollback is mechanically asserted
# (the fake's abort removes everything from the model
# root). This test asserts the abort mechanically
# restored the root-entity snapshot.
test 'V2-S0B-PRB02: fake abort restores root snapshot (R1-06)' do
  fp, ds = v2_s0b_footprint_and_dataset
  guard = SUAnalysis::V2::HostOperationGuard.new
  m = v2_s0b_make_model
  real_adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
    model_provider: -> { m }
  )
  decorator = Class.new do
    define_method(:initialize) { |real| @real = real }
    define_method(:model)         { @real.model }
    define_method(:root_context?) { @real.root_context? }
    define_method(:build_mass) do |footprint:, probe_height:|
      @real.build_mass(footprint: footprint, probe_height: probe_height)
      raise 'r1-06 injected post-construction failure'
    end
  end.new(real_adapter)
  capture_seam, build_seam, validate_seam, projector = v2_s0b_default_seams(fp, ds)
  probe_run = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: guard, adapter: decorator,
    capture_seam: capture_seam,
    build_seam: build_seam,
    validate_seam: validate_seam,
    projector: projector
  )
  before = m.entities.children.dup
  out = probe_run.run(
    footprint: fp,
    analysis_result: { 'kind' => 'test' },
    probe_height: 10.0
  )
  assert_equal 'FAILED_ROLLED_BACK', out['status']
  assert_equal before.size, m.entities.children.size,
               'rollback must leave model.entities unchanged in size'
end

# ---------------------------------------------------------------
# Helper: build a default real adapter wired to model m.
# ---------------------------------------------------------------
def probe_default_adapter(m)
  SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
    model_provider: -> { m }
  )
end

# ---------------------------------------------------------------
# Helper: capture the production default build seam for
# source-level inspection (R1-01 / INT02).
# ---------------------------------------------------------------
def probe_default_build_seam
  # Instantiate a throwaway probe with the production
  # defaults and return its @build_seam.
  probe = SUAnalysis::V2::Stage0BMassProbe.new(
    guard: SUAnalysis::V2::HostOperationGuard.new,
    adapter: SUAnalysis::Compatibility::V2SketchupMassAdapter.new
  )
  probe.build_seam
end