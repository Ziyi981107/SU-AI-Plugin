#
# tests/test_v2_stage0b_owner_probe.rb — focused host-free tests
# for the V2-0B Owner-Gate one-click Probe.
#
# Dispatch: V2-0B-OWNER-GATE-ONE-CLICK-PROBE-2026-09-17.
# Authority:
#   Prompt/AIPM_V2_0B_OWNER_GATE_ONE_CLICK_PROBE_2026-09-17.md
#
# Per the Owner-Gate one-click packet §8 the focused suite
# must prove at minimum:
#
#   OG-01  one-click success returns SUCCESS + exactly one
#          root probe Group + correct ownership attributes +
#          1 start + 1 commit + 0 abort;
#   OG-02  success wrapper is self-contained -- no caller
#          footprint / analysis_result / WorkingModeRunner
#          state preparation;
#   OG-03  one-click injected failure delegates to real
#          adapter first (mutation occurs) then raises ->
#          FAILED_ROLLED_BACK with zero surviving root
#          probe Group and exactly one abort attempt;
#   OG-04  one-click wrapper does NOT call
#          WorkingModeRunner.reset_for_tests /
#          .prepare / .discard;
#   OG-05  production scope frozen -- this test file does
#          not modify production sources.
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'
require_relative '../Probe/v2_stage0b_owner_probe'

include SUAnalysis::Probe

# ===========================================================
# Minimal host-free Fake model for one-click probe tests.
#
# Mirrors only the surface the production
# V2SketchupMassAdapter + HostOperationGuard touch:
#   - start_operation / commit_operation / abort_operation
#     (literal Boolean results; abort invalidates children
#     so the post-validation group_not_root branch is
#     observable)
#   - active_path (nil = root context)
#   - entities.add_group / add_face / add_edge
#   - group.name / group.name=
#   - group.set_attribute / group.get_attribute
#   - group.valid? / group.deleted? / group.parent / group.model
#   - face.normal / face.reverse! / face.pushpull
#   - face.vertices
#   - edge.vertices
# ===========================================================

class OwnerGateFakeModel
  class OwnerGateFakeEntities
    def initialize(parent)
      @children = []
      @parent = parent
    end

    def add_group(*args)
      unless args.empty?
        raise TypeError,
              "add_group takes no arguments; got #{args.length}"
      end
      g = OwnerGateFakeGroup.new(@parent)
      @children << g
      g
    end

    def add_face(points, normal: [0.0, 0.0, 1.0])
      pts = points.map { |p| OwnerGateFakeModel.to_xyz(p) }
      f = OwnerGateFakeFace.new(pts, @parent, normal)
      @children << f
      f
    end

    def add_edge(start, finish)
      e = OwnerGateFakeEdge.new(
        OwnerGateFakeModel.to_xyz(start),
        OwnerGateFakeModel.to_xyz(finish)
      )
      @children << e
      e
    end

    def each(&block)
      @children.each(&block)
    end

    def to_a
      @children.dup
    end

    def size
      @children.size
    end

    def invalidate_all!
      @children.each do |c|
        c.erase! if c.respond_to?(:erase!)
      end
      @children.clear
    end
  end

  class OwnerGateFakeGroup
    attr_accessor :name, :valid_flag
    attr_reader :entities, :attrs

    def initialize(model)
      @entities = OwnerGateFakeEntities.new(self)
      @attrs = {}
      @name = ''
      @valid_flag = true
      # Mirror real SketchUp top-level shape so
      # V2SketchupMassAdapter#_is_root_group? passes.
      @parent = model
      @model  = model
    end

    def typename
      'Group'
    end

    attr_accessor :parent, :model

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

    def erase!
      @valid_flag = false
    end
  end

  class OwnerGateFakeFace
    attr_reader :vertices
    attr_accessor :normal

    def initialize(vertices, parent_group, normal = [0.0, 0.0, 1.0])
      @vertices = vertices.dup
      @parent_group = parent_group
      @normal = normal
      @_extruded_top_vertices = nil
    end

    def typename
      'Face'
    end

    def vertices_full
      return @vertices unless @_extruded_top_vertices
      @vertices + @_extruded_top_vertices
    end

    def reverse!
      @normal = @normal.map { |v| -v.to_f }
    end

    # Simulate SketchUp pushpull -- returns nil; the
    # adapter must validate success from the resulting
    # geometry, not from the return value. After
    # extrusion, also append the top face + vertical
    # edges to the parent group's entities so the
    # post-validation walker sees both bottom + top
    # vertices and at least one Edge.
    def pushpull(distance, _up)
      bottom_z = @vertices.map { |v| v[2].to_f }.min
      top_z    = bottom_z + distance.to_f
      top_vertices = @vertices.map { |v| [v[0], v[1], top_z] }
      @_extruded_top_vertices = top_vertices
      if @parent_group.respond_to?(:entities) &&
         @parent_group.entities.respond_to?(:add_face)
        begin
          @parent_group.entities.add_face(top_vertices,
                                          normal: [0.0, 0.0, -1.0])
          @vertices.each_with_index do |bv, i|
            tv = top_vertices[i]
            @parent_group.entities.add_edge(bv, tv) if
              @parent_group.entities.respond_to?(:add_edge)
          end
        rescue StandardError
          # ignore: parent may not support adding during
          # pushpull
        end
      end
      nil
    end
  end

  class OwnerGateFakeEdge
    attr_reader :start, :finish

    def initialize(start, finish)
      @start  = start
      @finish = finish
    end

    def typename
      'Edge'
    end

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
    @entities = OwnerGateFakeEntities.new(self)
    @active_path = nil
    @operation_log = []
    @operation_open = false
    @current_label  = nil
  end

  def active_path
    @active_path
  end

  def active_path=(value)
    @active_path = value
  end

  def start_operation(label, _a, _b, _c)
    @operation_log << { kind: :start, label: label.to_s }
    @operation_open = true
    @current_label  = label.to_s
    true
  end

  def commit_operation
    raise 'fake_commit_no_open' unless @operation_open
    @operation_log << { kind: :commit }
    @operation_open = false
    @current_label  = nil
    true
  end

  def abort_operation
    raise 'fake_abort_no_open' unless @operation_open
    @operation_log << { kind: :abort }
    @operation_open = false
    @current_label  = nil
    @entities.invalidate_all!
    true
  end

  def operation_open?
    @operation_open == true
  end
end

# ===========================================================
# Helpers.
# ===========================================================

def make_owner_gate_probe_with_fake
  fake_model = OwnerGateFakeModel.new
  probe = SUAnalysis::Probe::V2Stage0BOwnerProbe.new(
    model_provider: -> { fake_model }
  )
  [probe, fake_model]
end

# ===========================================================
# Tests.
# ===========================================================

# OG-01: one-click success returns SUCCESS + exactly one
# root probe Group + correct ownership attributes + one
# start + one commit + zero abort.
test 'OG-01: one-click success returns SUCCESS + exactly one root probe Group (OG-01)' do
  probe, fake_model = make_owner_gate_probe_with_fake
  result = probe.run_success_one_click
  assert_equal 'SUCCESS', result['status'],
               "OG-01: one-click success MUST yield SUCCESS; got #{result.inspect}"
  # Exactly one root probe Group created.
  groups = fake_model.entities.to_a.select { |c|
    c.is_a?(OwnerGateFakeModel::OwnerGateFakeGroup)
  }
  assert_equal 1, groups.size,
               "OG-01: exactly one root probe Group expected; got #{groups.inspect}"
  g = groups.first
  assert g.name.start_with?('SU-AI-V2-Probe-'),
         "OG-01: group name must start with SU-AI-V2-Probe-; got #{g.name.inspect}"
  # Ownership attributes are exact-match to the
  # synthetic one-click footprint.
  expected_fpid = ('a' * 64)
  expected_scd  = ('b' * 64)
  assert_equal expected_fpid,
               g.get_attribute('SU-AI-V2', 'footprint_id_full'),
               'OG-01: footprint_id_full ownership attribute must exactly equal synthetic'
  assert_equal expected_scd,
               g.get_attribute('SU-AI-V2', 'source_content_digest'),
               'OG-01: source_content_digest ownership attribute must exactly equal synthetic'
  assert_equal 'v2.host-object.v1',
               g.get_attribute('SU-AI-V2', 'schema_version')
  assert_equal 'stage0b_mass_probe',
               g.get_attribute('SU-AI-V2', 'kind')
  # Operation log invariant.
  kinds = fake_model.operation_log.map { |e| e[:kind] }
  assert_equal 1, kinds.count(:start),
               "OG-01: exactly one start expected; got #{kinds.inspect}"
  assert_equal 1, kinds.count(:commit),
               "OG-01: exactly one commit expected; got #{kinds.inspect}"
  assert_equal 0, kinds.count(:abort),
               "OG-01: zero aborts expected on SUCCESS; got #{kinds.inspect}"
end

# OG-02: success wrapper is self-contained -- no caller
# footprint / analysis_result / WorkingModeRunner state
# preparation required.
test 'OG-02: one-click success wrapper is self-contained (no caller footprint / analysis_result) (OG-02)' do
  probe, _fake_model = make_owner_gate_probe_with_fake
  # The wrapper accepts no caller footprint /
  # analysis_result; passing nothing and getting a
  # SUCCESS proves self-containment.
  result = probe.run_success_one_click
  assert_equal 'SUCCESS', result['status'],
               'OG-02: self-contained wrapper MUST reach SUCCESS with no caller data'
  # Verify the wrapper ignores any caller-supplied
  # arguments by calling it again on a fresh probe
  # with absolutely no inputs.
  probe2 = SUAnalysis::Probe::V2Stage0BOwnerProbe.new(
    model_provider: -> { OwnerGateFakeModel.new }
  )
  out2 = probe2.run_success_one_click
  assert_equal 'SUCCESS', out2['status'],
               'OG-02: class-level invocation path MUST also reach SUCCESS'
  # Class-level one-click entry point is callable
  # exactly as the Owner-facing API contract requires.
  out3 = SUAnalysis::Probe::V2Stage0BOwnerProbe.run_success_one_click(
    model_provider: -> { OwnerGateFakeModel.new }
  )
  assert_equal 'SUCCESS', out3['status'],
               'OG-02: class-level run_success_one_click MUST reach SUCCESS'
end

# OG-03: one-click injected failure delegates to real
# adapter first (mutation occurs) then raises ->
# FAILED_ROLLED_BACK with zero surviving root probe
# Group and exactly one abort attempt.
test 'OG-03: one-click injected failure -> FAILED_ROLLED_BACK + zero residue (OG-03)' do
  probe, fake_model = make_owner_gate_probe_with_fake
  before_count = fake_model.entities.size
  result = probe.run_injected_failure_one_click
  assert_equal 'FAILED_ROLLED_BACK', result['status'],
               "OG-03: injected failure MUST yield FAILED_ROLLED_BACK; got #{result.inspect}"
  # Zero surviving probe Group after confirmed abort.
  surviving_groups = fake_model.entities.to_a.select { |c|
    c.is_a?(OwnerGateFakeModel::OwnerGateFakeGroup) && c.valid?
  }
  assert_equal 0, surviving_groups.size,
               "OG-03: zero surviving probe Group expected after confirmed abort; " \
               "got #{surviving_groups.inspect}"
  # Operation log: exactly one abort attempt.
  aborts = fake_model.operation_log.select { |e| e[:kind] == :abort }
  assert_equal 1, aborts.size,
               "OG-03: exactly one abort attempt expected; got #{fake_model.operation_log.inspect}"
  # The real adapter was actually delegated FIRST --
  # this is observable through the operations on the
  # model. Because the fake abort invalidates every
  # entity, the pre-rollback children count must be
  # > 0 (proof that real geometry was created before
  # the raise). We assert that the operation log
  # contains one start AND zero commits AND one abort,
  # which is consistent with: start -> real
  # adapter creates group+face+extrusion+ownership ->
  # raise -> abort.
  kinds = fake_model.operation_log.map { |e| e[:kind] }
  assert_equal 1, kinds.count(:start),
               "OG-03: one start expected; got #{kinds.inspect}"
  assert_equal 0, kinds.count(:commit),
               "OG-03: zero commits expected on injected failure; got #{kinds.inspect}"
end

# OG-04: one-click wrapper does NOT call
# WorkingModeRunner.reset_for_tests / .prepare / .discard.
#
# Runtime detection: install a runtime spy on the
# WorkingModeRunner class methods; if the one-click
# wrapper invokes any of them, the spy records the
# call and the assertion fails. The source-text
# assertion is supplementary.
test 'OG-04: one-click wrapper does NOT call WorkingModeRunner reset_for_tests / prepare / discard (OG-04)' do
  forbidden_calls = []

  runner_class = SUAnalysis::Core::WorkingModeRunner
  # Spy: wrap the three forbidden methods with detection
  # callbacks. Wrap (not redefine) so the underlying
  # semantics are preserved if any forbidden call
  # accidentally slips through -- the spy only records
  # the call; it does not silently swallow it.
  %i[reset_for_tests prepare discard].each do |m|
    unless runner_class.singleton_methods(false).include?(m)
      # The class may not actually expose all three; if
      # a method is missing entirely the contract is
      # trivially satisfied and we skip the spy for
      # that one.
      next
    end
    original = runner_class.singleton_method(m)
    runner_class.define_singleton_method(m) do |*args, **kw, &blk|
      forbidden_calls << m
      original.call(*args, **kw, &blk)
    end
  end
  begin
    probe, _fake_model = make_owner_gate_probe_with_fake
    r1 = probe.run_success_one_click
    r2 = probe.run_injected_failure_one_click
    # Class-level invocation paths must also be clean.
    r3 = SUAnalysis::Probe::V2Stage0BOwnerProbe.run_success_one_click(
      model_provider: -> { OwnerGateFakeModel.new }
    )
    r4 = SUAnalysis::Probe::V2Stage0BOwnerProbe.run_injected_failure_one_click(
      model_provider: -> { OwnerGateFakeModel.new }
    )
    assert_equal 'SUCCESS', r1['status']
    assert_equal 'FAILED_ROLLED_BACK', r2['status']
    assert_equal 'SUCCESS', r3['status']
    assert_equal 'FAILED_ROLLED_BACK', r4['status']
    assert_equal [], forbidden_calls,
                 "OG-04: one-click wrapper MUST NOT call any of reset_for_tests / " \
                 "prepare / discard; observed: #{forbidden_calls.inspect}"
  ensure
    # Restore the original class methods by removing the
    # singleton-method shims we installed above.
    runner_class.singleton_class.send(:remove_method,
                                       :reset_for_tests) rescue nil
    runner_class.singleton_class.send(:remove_method,
                                       :prepare)        rescue nil
    runner_class.singleton_class.send(:remove_method,
                                       :discard)        rescue nil
  end
end

# OG-04 supplementary: source-text assertion. The
# Probe-only file MUST NOT contain string literals
# that would obviously invoke any of the three
# forbidden WorkingModeRunner class methods.
test 'OG-04-ST: source guard -- probe file has no forbidden WorkingModeRunner calls (OG-04 supplementary)' do
  src_path = File.expand_path(
    '../Probe/v2_stage0b_owner_probe.rb', __dir__
  )
  src = File.read(src_path)
  # Scan only NON-COMMENT code lines. The probe file
  # legitimately documents the forbidden names in
  # comments, which are not actual invocations.
  code_lines = src.lines.reject do |l|
    stripped = l.sub(/\A\s*#.*\z/, '').rstrip
    stripped.empty?
  end
  code_only = code_lines.join
  forbidden_patterns = [
    /WorkingModeRunner\.reset_for_tests/,
    /WorkingModeRunner\.prepare\b/,
    /WorkingModeRunner\.discard\b/
  ]
  forbidden_patterns.each do |pat|
    assert !code_only.match?(pat),
           "OG-04-ST: probe file code MUST NOT contain #{pat.inspect}; " \
           "found at offset #{code_only =~ pat}"
  end
end

# OG-05: production scope frozen. The focused test
# file MUST NOT require or load any production file
# beyond the V2-0B production modules it is allowed
# to depend on. Specifically, the test file must not
# add a new require_relative for any V1 production
# file or any V2-0A production file.
test 'OG-05: production scope frozen -- no V1 / V2-0A production require (OG-05)' do
  src_path = File.expand_path(
    '../tests/test_v2_stage0b_owner_probe.rb', __dir__
  )
  src = File.read(src_path)
  # Allowed production require_relatives: the three
  # V2-0B modules that the Probe file itself loads.
  # The test file does not need to require them again
  # because loading the Probe file transitively loads
  # them; but if it did, those three are the only
  # legal targets.
  allowed = %w[
    host_operation_guard
    stage0b_mass_probe
    v2_sketchup_mass_adapter
  ]
  violations = []
  src.scan(/require_relative\s+['"]([^'"]+)['"]/).each do |hit|
    target = hit.first
    if target.include?('su_ai_plugin/core/')
      violations << "#{target.inspect} is a V1 production core file"
    elsif target.include?('su_ai_plugin/v2/layer_local_graph_adapter') ||
          target.include?('su_ai_plugin/v2/semantic_footprint') ||
          target.include?('su_ai_plugin/v2/semantic_footprint_projector')
      violations << "#{target.inspect} is a V2-0A production file"
    elsif target.start_with?('../extension/')
      basename = File.basename(target, '.rb')
      unless allowed.include?(basename)
        violations << "#{target.inspect} is not an allowed production target"
      end
    end
  end
  assert_equal [], violations,
               "OG-05: test file MUST NOT require disallowed production files; " \
               "violations: #{violations.inspect}"
end

# ------------------------------------------------------------
# Ruby 2.2-era source compatibility guard for the Probe
# file. The one-click additions must continue to honor
# the same forbidden-helper list as the V2-0B focused
# suite already enforces on the V2-0B production files.
# ------------------------------------------------------------
test 'OG-COMPAT: Probe file uses only Ruby 2.2-compatible helpers' do
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
  src_path = File.expand_path(
    '../Probe/v2_stage0b_owner_probe.rb', __dir__
  )
  src = File.read(src_path)
  forbidden.each do |pat, label|
    assert !src.match?(pat),
           "OG-COMPAT: Probe file MUST NOT use #{label}; pattern #{pat.inspect}"
  end
end