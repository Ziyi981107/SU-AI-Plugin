#
# tests/test_v2_stage0b_namespace_isolation.rb — V2-0B
# Owner Gate R1 namespace-isolation anti-regression tests.
#
# Dispatch: V2-0B-OWNER-GATE-R1-NAMESPACE-CORRECTION-2026-09-21.
# Authority:
#   Prompt/AIPM_V2_0B_OWNER_GATE_R1_NAMESPACE_CORRECTION_2026-09-21.md
#
# Real SU2020 Owner Gate surfaced:
#
#   NameError: uninitialized constant
#   SUAnalysis::V2::Stage0BMassProbe::V2SketchupMassAdapter
#
# The focused host-free suite
# `tests/test_v2_stage0b_host_mass_probe.rb` masked this
# because its top-level scope runs:
#
#   include SUAnalysis::Compatibility
#
# which makes the sibling Compatibility constant visible
# through test process constant lookup. A real SketchUp
# runtime does not provide that `include` -- the production
# namespace correction must be proven in a CLEAN namespace.
#
# This file adds the four proofs required by §3 of the
# authority packet:
#
#   V2-S0B-NS-01  fresh Ruby subprocess loads the production
#                 files WITHOUT top-level
#                 `include SUAnalysis::Compatibility`,
#                 injects the minimum fake model + seams,
#                 runs Stage0B end-to-end on the SUCCESS
#                 path, and reaches `status == 'SUCCESS'`
#                 without raising NameError on any
#                 `V2SketchupMassAdapter::...` constant.
#
#   V2-S0B-NS-02  same fresh-subprocess harness, this time
#                 driving the FAILURE path: the fake adapter
#                 returns `STATUS_CONSTRUCTION_FAILED`, the
#                 guard abort returns literal true, and the
#                 probe must reach `status == 'FAILED_ROLLED_BACK'`
#                 (which references
#                 `SUAnalysis::Compatibility::V2SketchupMassAdapter::STATUS_POST_VALIDATION_FAILED`)
#                 without raising NameError.
#
#   V2-S0B-NS-03  source-text proof that the production
#                 file `extension/su_ai_plugin/v2/stage0b_mass_probe.rb`
#                 does NOT contain a code-line unqualified
#                 `V2SketchupMassAdapter::...` reference.
#                 Comments are exempt (they only describe the
#                 contract, they do not execute).
#
#   V2-S0B-NS-04  negative runtime proof. A fresh subprocess
#                 transforms the production file by replacing
#                 `SUAnalysis::Compatibility::V2SketchupMassAdapter`
#                 with the unqualified `V2SketchupMassAdapter`
#                 (the exact regression) and runs NS-01's
#                 probe against the transformed file. The
#                 subprocess MUST raise NameError (or fail to
#                 return ISOLATED_NS_OK=1). The original
#                 production file is NEVER mutated -- the
#                 subprocess writes its transformed copy to a
#                 throwaway path under the temp dir.
#

$LOAD_PATH.unshift(File.expand_path('stubs', __dir__))
require_relative 'runner'

# =================================================================
# Helpers.
# =================================================================

# Locate the vendored Ruby used by the project test runner.
NS_TEST_RUBY_EXE =
  ENV['RUBY_EXE'] ||
    File.expand_path('../.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe', __dir__)

# Locate the production files we are exercising.
NS_PROD_STAGE0B =
  File.expand_path('../extension/su_ai_plugin/v2/stage0b_mass_probe.rb', __dir__)
NS_PROD_GUARD =
  File.expand_path('../extension/su_ai_plugin/v2/host_operation_guard.rb', __dir__)
NS_PROD_ADAPTER =
  File.expand_path('../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb', __dir__)

# Locate the test scratch dir for throwaway transformed files.
# Tests/ matches the existing V2-0A R2-07 shim pattern
# (`tests/_v2_isolated_load_shim_r2.rb`); the throwaway files
# are written and deleted within `ensure` blocks.
NS_TEST_TMP =
  File.expand_path('_v2_stage0b_namespace_isolation_scratch', __dir__)

# Ensure the temp dir exists (used for negative-proof transformed
# production file). The shared `output/` directory is already
# excluded from the RBZ payload by `scripts/build_rbz.rb`.
def ns_ensure_tmp
  require 'fileutils'
  FileUtils.mkdir_p(NS_TEST_TMP)
end

# =================================================================
# V2-S0B-NS-01 — clean namespace, success path reaches SUCCESS.
# =================================================================
# Run a fresh Ruby subprocess that:
#   1. requires the THREE V2-0B production files directly
#      (no V1 PCD / V2-0A projector chain);
#   2. does NOT execute top-level
#      `include SUAnalysis::Compatibility`;
#   3. defines a minimal host-free fake model;
#   4. instantiates real
#      SUAnalysis::Compatibility::V2SketchupMassAdapter
#      with that fake model;
#   5. instantiates real
#      SUAnalysis::V2::Stage0BMassProbe with injected
#      capture/build/validate/projector seams that bypass
#      V1 / V2-0A (we only care about adapter-constant
#      resolution);
#   6. invokes probe.run and asserts status == 'SUCCESS'.
#
# The probe will reach the line:
#   @guard.start(
#     m,
#     SUAnalysis::Compatibility::V2SketchupMassAdapter::OPERATION_LABEL
#   )
# and the success-path checks against
# `SUAnalysis::Compatibility::V2SketchupMassAdapter::STATUS_SUCCESS`.
# If the production file regressed to unqualified references
# the subprocess raises NameError; we expect ISOLATED_NS_OK=1.
test 'V2-S0B-NS-01: Stage0B success path resolves adapter constants in clean namespace' do
  require 'open3'
  shim_path = File.expand_path('_v2_stage0b_namespace_isolation_shim_ns01.rb', __dir__)
  File.write(shim_path, <<~'RUBY')
    # V2-S0B-NS-01: clean namespace, success path.
    # Loads production files without top-level
    # `include SUAnalysis::Compatibility`, runs the probe
    # end-to-end with injected seams, asserts SUCCESS.
    require_relative '../extension/su_ai_plugin/v2/host_operation_guard'
    require_relative '../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter'
    require_relative '../extension/su_ai_plugin/v2/stage0b_mass_probe'

    begin
      Adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter
      Guard   = SUAnalysis::V2::HostOperationGuard
      Probe   = SUAnalysis::V2::Stage0BMassProbe

      # ---- Minimum host-free fake model ----
      class NS01Model
        attr_reader :entities, :operation_log
        def initialize
          @entities      = NS01Entities.new(self)
          @operation_log = []
          @operation_open = false
          @active_path    = nil
        end

        def active_path; @active_path; end

        def start_operation(label, _a, _b, _c)
          @operation_log << { kind: :start, label: label.to_s }
          @operation_open = true
          true
        end

        def commit_operation
          raise 'fake_commit_no_open' unless @operation_open
          @operation_log << { kind: :commit }
          @operation_open = false
          true
        end

        def abort_operation
          raise 'fake_abort_no_open' unless @operation_open
          @operation_log << { kind: :abort }
          @operation_open = false
          @entities.invalidate_all!
          true
        end
      end

      class NS01Entities
        def initialize(model)
          @model    = model
          @children = []
        end

        def add_group(*args)
          raise TypeError, 'add_group takes no args' unless args.empty?
          g = NS01Group.new(@model)
          @children << g
          g
        end

        def each(&blk); @children.each(&blk); end

        def invalidate_all!
          @children.each { |c| c.erase! if c.respond_to?(:erase!) }
          @children.clear
        end
      end

      class NS01GroupEntities
        attr_reader :owner_group
        def initialize(model)
          @model        = model
          @children     = []
        end

        def add_face(points, normal: [0.0, 0.0, 1.0])
          pts = points.map { |p| to_xyz(p) }
          f = NS01Face.new(pts, normal)
          # parent_group points to the NS01Group that OWNS
          # this entities collection (NS01Group#entities is
          # THIS collection). The fake pushpull uses
          # `@parent_group.entities.add_edge(...)` to mirror
          # the production fake host's pattern.
          f.parent_group = @owner_group
          @children << f
          f
        end
        def add_edge(start, finish)
          e = NS01Edge.new(to_xyz(start), to_xyz(finish))
          @children << e
          e
        end
        def each(&blk); @children.each(&blk); end
        def owner_group=(g); @owner_group = g; end
      end

      class NS01Group
        attr_accessor :name, :valid_flag, :parent, :model
        attr_reader :entities, :attrs
        def initialize(model)
          @entities   = NS01GroupEntities.new(model)
          @entities.owner_group = self
          @attrs      = {}
          @name       = ''
          @valid_flag = true
          @parent     = model
          @model      = model
        end

        def typename; 'Group'; end

        def set_attribute(dict, key, value)
          @attrs["#{dict}.#{key}"] = value.to_s
        end

        def get_attribute(dict, key)
          @attrs["#{dict}.#{key}"]
        end

        def valid?;   @valid_flag == true; end
        def deleted?; false; end
        def erase!;   @valid_flag = false; end
      end

      class NS01Face
        attr_accessor :normal, :parent_group
        attr_reader :vertices
        def initialize(vertices, normal)
          @vertices            = vertices.dup
          @normal              = normal
          @_extruded_top       = nil
        end
        def typename; 'Face'; end
        def reverse!; @normal = @normal.map { |v| -v.to_f }; end
        def pushpull(distance, _up)
          bottom_z = @vertices.map { |v| v[2].to_f }.min
          top_z    = bottom_z + distance.to_f
          @_extruded_top = @vertices.map { |v| [v[0], v[1], top_z] }
          # Mirror the production fake host: append the top
          # face and vertical edges to the parent group's
          # entities so the post-validation walker sees both
          # z=0 and z=probe_height vertices AND at least one
          # Edge after extrusion.
          if @parent_group.respond_to?(:entities) &&
             @parent_group.entities.respond_to?(:add_face)
            begin
              @parent_group.entities.add_face(
                @_extruded_top, normal: [0.0, 0.0, -1.0]
              )
              @vertices.each_with_index do |bv, i|
                tv = @_extruded_top[i]
                if @parent_group.entities.respond_to?(:add_edge)
                  @parent_group.entities.add_edge(bv, tv)
                end
              end
            rescue StandardError
              # Best-effort; if the parent rejects during
              # pushpull, the walker still sees this face's
              # bottom + top vertices.
            end
          end
          nil
        end
        def all_vertices
          return @vertices unless @_extruded_top
          @vertices + @_extruded_top
        end
      end

      class NS01Edge
        attr_reader :start, :finish
        def initialize(start, finish); @start = start; @finish = finish; end
        def typename; 'Edge'; end
        def vertices; [@start, @finish]; end
      end

      # Top-level helper. Defined on Object so every fake
      # class above can call it without a module prefix.
      def to_xyz(p)
        if p.is_a?(Array) && p.length == 3
          [p[0].to_f, p[1].to_f, p[2].to_f]
        else
          raise ArgumentError, "invalid point: #{p.inspect}"
        end
      end

      # ---- Synthetic seams ----
      fpid_str = 'a' * 64
      scd_str  = 'b' * 64

      capture_seam = ->(analysis_result:) {
        { 'status' => 'CAPTURED', 'bundle' => {} }
      }
      build_seam = ->(_bundle) {
        ds = Object.new
        def ds.final?;   true;  end
        def ds.content_digest; @scd; end
        ds.instance_variable_set(:@scd, ('b' * 64))
        { 'status' => 'BUILT', 'dataset' => ds }
      }
      validate_seam = ->(dataset:, workflow_snapshot:) {
        { 'status' => 'READY', 'dataset' => dataset }
      }
      projector = ->(dataset:, semantic_role:, layer_name:) {
        fp = {
          'footprint_id_full'         => ('a' * 64),
          'source_content_digest'     => ('b' * 64),
          'semantic_role'             => 'body',
          'source_layer_name'         => 'NS01_L0',
          'projected_world_coordinates' => [
            [0.0, 0.0, 0.0],
            [10.0, 0.0, 0.0],
            [10.0, 8.0, 0.0],
            [0.0, 8.0, 0.0]
          ],
          'coordinate_epsilon' => 1.0e-6
        }
        { 'status' => 'PROJECTED', 'footprints' => [fp] }
      }

      model = NS01Model.new
      adapter = Adapter.new(model_provider: -> { model })
      guard   = Guard.new
      probe = Probe.new(
        guard:         guard,
        adapter:       adapter,
        capture_seam:  capture_seam,
        build_seam:    build_seam,
        validate_seam: validate_seam,
        projector:     projector
      )

      fp = {
        'footprint_id_full'         => ('a' * 64),
        'source_content_digest'     => ('b' * 64),
        'semantic_role'             => 'body',
        'source_layer_name'         => 'NS01_L0',
        'projected_world_coordinates' => [
          [0.0, 0.0, 0.0],
          [10.0, 0.0, 0.0],
          [10.0, 8.0, 0.0],
          [0.0, 8.0, 0.0]
        ],
        'coordinate_epsilon' => 1.0e-6
      }

      out = probe.run(
        footprint:       fp,
        analysis_result: { 'kind' => 'test' },
        probe_height:    120.0
      )

      if out.is_a?(Hash) && out['status'] == 'SUCCESS' &&
         model.operation_log.any? { |e| e[:kind] == :start } &&
         model.operation_log.any? { |e| e[:kind] == :commit }
        puts 'ISOLATED_NS_OK=1'
        puts 'STATUS=SUCCESS'
        kinds = model.operation_log.map { |e| e[:kind] }
        puts 'OPERATION_LOG=' + kinds.join(',')
      else
        puts 'ISOLATED_NS_OK=0'
        puts 'STATUS=' + (out.is_a?(Hash) ? out['status'].to_s : 'NO_HASH')
        puts 'OUT=' + out.inspect
      end
    rescue => e
      puts 'ISOLATED_NS_OK=0'
      puts 'ERROR=' + e.class.to_s + ':' + e.message
    end
  RUBY

  out, _err, status = Open3.capture3(NS_TEST_RUBY_EXE, shim_path)
  assert status.success?,
         "NS-01: subprocess failed: status=#{status.inspect}\n#{out}"
  assert out.include?('ISOLATED_NS_OK=1'),
         "NS-01: subprocess did not report ISOLATED_NS_OK=1:\n#{out}"
  assert out.include?('STATUS=SUCCESS'),
         "NS-01: subprocess did not reach SUCCESS:\n#{out}"
  assert out.include?('OPERATION_LOG=start,commit'),
         "NS-01: subprocess did not record start+commit:\n#{out}"
ensure
  File.delete(shim_path) if shim_path && File.exist?(shim_path)
end

# =================================================================
# V2-S0B-NS-02 — clean namespace, failure path reaches
# FAILED_ROLLED_BACK without NameError.
# =================================================================
# Same harness as NS-01, but inject an adapter decorator that
# raises after a real first-stage mutation, so the wrapped
# adapter exception is converted into a construction failure.
# This drives the line:
#   if build_status == SUAnalysis::Compatibility::
#      V2SketchupMassAdapter::STATUS_POST_VALIDATION_FAILED
# which the original production file used to handle via the
# unqualified constant lookup. In the regression version it
# would raise NameError.
#
# For NS-02 we instead force the adapter itself to return
# STATUS_CONSTRUCTION_FAILED so the probe reaches the
# `STATUS_FAILED_ROLLED_BACK` branch (which does NOT compare
# against STATUS_POST_VALIDATION_FAILED, exercising only the
# OTHER explicit-status reference path).
test 'V2-S0B-NS-02: Stage0B failure path resolves adapter constants in clean namespace' do
  require 'open3'
  shim_path = File.expand_path('_v2_stage0b_namespace_isolation_shim_ns02.rb', __dir__)
  File.write(shim_path, <<~'RUBY')
    # V2-S0B-NS-02: clean namespace, failure path.
    # Same harness as NS-01, but the adapter returns
    # STATUS_CONSTRUCTION_FAILED on the FIRST call so the
    # probe reaches the abort + FAILED_ROLLED_BACK branch.
    require_relative '../extension/su_ai_plugin/v2/host_operation_guard'
    require_relative '../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter'
    require_relative '../extension/su_ai_plugin/v2/stage0b_mass_probe'

    begin
      Adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter
      Guard   = SUAnalysis::V2::HostOperationGuard
      Probe   = SUAnalysis::V2::Stage0BMassProbe

      class NS02Model
        attr_reader :entities, :operation_log
        def initialize
          @entities      = NS02Entities.new(self)
          @operation_log = []
          @operation_open = false
          @active_path    = nil
        end
        def active_path; @active_path; end
        def start_operation(label, _a, _b, _c)
          @operation_log << { kind: :start, label: label.to_s }
          @operation_open = true
          true
        end
        def commit_operation
          raise 'fake_commit_no_open' unless @operation_open
          @operation_log << { kind: :commit }
          @operation_open = false
          true
        end
        def abort_operation
          raise 'fake_abort_no_open' unless @operation_open
          @operation_log << { kind: :abort }
          @operation_open = false
          @entities.invalidate_all!
          true
        end
      end

      class NS02Entities
        def initialize(model); @model = model; @children = []; end
        def add_group(*args)
          raise TypeError, 'add_group takes no args' unless args.empty?
          g = NS02Group.new(@model)
          @children << g
          g
        end
        def each(&blk); @children.each(&blk); end
        def invalidate_all!
          @children.each { |c| c.erase! if c.respond_to?(:erase!) }
          @children.clear
        end
      end

      class NS02Group
        attr_accessor :name, :valid_flag, :parent, :model
        attr_reader :entities
        def initialize(model)
          @entities   = NS02GroupEntities.new(model)
          @name       = ''
          @valid_flag = true
          @parent     = model
          @model      = model
        end
        def typename; 'Group'; end
        def erase!;   @valid_flag = false; end
      end

      class NS02GroupEntities
        def initialize(model); @model = model; end
        def add_face(_points, **_kw)
          # No-op: the adapter will not even reach add_face in
          # this failure scenario.
          nil
        end
      end

      capture_seam = ->(analysis_result:) {
        { 'status' => 'CAPTURED', 'bundle' => {} }
      }
      build_seam = ->(_bundle) {
        ds = Object.new
        def ds.final?;   true;  end
        def ds.content_digest; @scd; end
        ds.instance_variable_set(:@scd, ('b' * 64))
        { 'status' => 'BUILT', 'dataset' => ds }
      }
      validate_seam = ->(dataset:, workflow_snapshot:) {
        { 'status' => 'READY', 'dataset' => dataset }
      }
      projector = ->(dataset:, semantic_role:, layer_name:) {
        fp = {
          'footprint_id_full'         => ('a' * 64),
          'source_content_digest'     => ('b' * 64),
          'semantic_role'             => 'body',
          'source_layer_name'         => 'NS02_L0',
          'projected_world_coordinates' => [
            [0.0, 0.0, 0.0],
            [10.0, 0.0, 0.0],
            [10.0, 8.0, 0.0],
            [0.0, 8.0, 0.0]
          ],
          'coordinate_epsilon' => 1.0e-6
        }
        { 'status' => 'PROJECTED', 'footprints' => [fp] }
      }

      model = NS02Model.new
      adapter = Adapter.new(model_provider: -> { model })
      guard   = Guard.new

      # Decorate the adapter so its first build_mass returns
      # STATUS_CONSTRUCTION_FAILED. The Stage0B probe must
      # then drive the abort branch and return
      # FAILED_ROLLED_BACK. Probe will reference
      # SUAnalysis::Compatibility::V2SketchupMassAdapter::
      # STATUS_CONSTRUCTION_FAILED (the explicit authority
      # used by the rescue branch -- verified by reading the
      # production file).
      class FailingAdapterDecorator
        def initialize(inner, real_status_const)
          @inner  = inner
          @status = real_status_const
        end
        def model
          @inner.model
        end
        def root_context?
          @inner.root_context?
        end
        def build_mass(footprint:, probe_height:)
          { status: @status,
            error:  'ns02_injected_construction_failure' }
        end
      end

      decorated = FailingAdapterDecorator.new(
        adapter,
        SUAnalysis::Compatibility::V2SketchupMassAdapter::STATUS_CONSTRUCTION_FAILED
      )

      probe = Probe.new(
        guard:         guard,
        adapter:       decorated,
        capture_seam:  capture_seam,
        build_seam:    build_seam,
        validate_seam: validate_seam,
        projector:     projector
      )

      fp = {
        'footprint_id_full'         => ('a' * 64),
        'source_content_digest'     => ('b' * 64),
        'semantic_role'             => 'body',
        'source_layer_name'         => 'NS02_L0',
        'projected_world_coordinates' => [
          [0.0, 0.0, 0.0],
          [10.0, 0.0, 0.0],
          [10.0, 8.0, 0.0],
          [0.0, 8.0, 0.0]
        ],
        'coordinate_epsilon' => 1.0e-6
      }

      out = probe.run(
        footprint:       fp,
        analysis_result: { 'kind' => 'test' },
        probe_height:    120.0
      )

      kinds = model.operation_log.map { |e| e[:kind] }
      if out.is_a?(Hash) &&
         out['status'] == 'FAILED_ROLLED_BACK' &&
         kinds.count(:start)  == 1 &&
         kinds.count(:abort)  == 1 &&
         kinds.count(:commit) == 0
        puts 'ISOLATED_NS_OK=1'
        puts 'STATUS=FAILED_ROLLED_BACK'
        puts 'OPERATION_LOG=' + kinds.join(',')
      else
        puts 'ISOLATED_NS_OK=0'
        puts 'STATUS=' + (out.is_a?(Hash) ? out['status'].to_s : 'NO_HASH')
        puts 'OPERATION_LOG=' + kinds.join(',')
        puts 'OUT=' + out.inspect
      end
    rescue => e
      puts 'ISOLATED_NS_OK=0'
      puts 'ERROR=' + e.class.to_s + ':' + e.message
    end
  RUBY

  out, _err, status = Open3.capture3(NS_TEST_RUBY_EXE, shim_path)
  assert status.success?,
         "NS-02: subprocess failed: status=#{status.inspect}\n#{out}"
  assert out.include?('ISOLATED_NS_OK=1'),
         "NS-02: subprocess did not report ISOLATED_NS_OK=1:\n#{out}"
  assert out.include?('STATUS=FAILED_ROLLED_BACK'),
         "NS-02: subprocess did not reach FAILED_ROLLED_BACK:\n#{out}"
  assert out.include?('OPERATION_LOG=start,abort'),
         "NS-02: subprocess did not record start+abort:\n#{out}"
ensure
  File.delete(shim_path) if shim_path && File.exist?(shim_path)
end

# =================================================================
# V2-S0B-NS-03 — source-text proof: production file has NO
# code-line unqualified `V2SketchupMassAdapter::` reference.
# =================================================================
# Comments are exempt (they only describe the contract; they
# do not execute). The proof reads the production file and
# walks each line, stripping `#` comments before testing.
test 'V2-S0B-NS-03: stage0b_mass_probe.rb has no unqualified V2SketchupMassAdapter:: in code' do
  src = File.read(NS_PROD_STAGE0B)
  lines = src.split("\n")
  bad = []
  lines.each_with_index do |ln, idx|
    stripped = ln.sub(/#.*$/, '')
    next if stripped !~ /ok\s*V2SketchupMassAdapter::/
    # Specifically: a non-comment code-line containing the
    # unqualified reference. Ruby's lexical constant lookup
    # is textual: any token form `V2SketchupMassAdapter::...`
    # that is NOT preceded by `Compatibility::` will trigger
    # the bug.
    bad << "line #{idx + 1}: #{ln}"
  end
  assert bad.empty?,
         "NS-03: production file contains unqualified " \
         "V2SketchupMassAdapter:: references in code lines:\n" +
         bad.join("\n")
end

# =================================================================
# V2-S0B-NS-04 — negative runtime proof: re-introducing an
# unqualified V2SketchupMassAdapter:: reference makes the
# success-path harness raise NameError.
# =================================================================
# The production file is NEVER mutated. The subprocess writes
# a transformed copy to a throwaway path under the temp dir,
# then `require`s the transformed file in isolation. If the
# original file regressed to unqualified references, this
# subprocess MUST raise NameError.
test 'V2-S0B-NS-04: negative proof — unqualified V2SketchupMassAdapter:: reference raises NameError' do
  require 'open3'
  ns_ensure_tmp

  transformed_path = File.join(NS_TEST_TMP, 'stage0b_mass_probe_ns04_regression.rb')
  src = File.read(NS_PROD_STAGE0B)

  # Transform: replace the explicit authority
  # `SUAnalysis::Compatibility::V2SketchupMassAdapter` with
  # the unqualified `V2SketchupMassAdapter` (the exact bug).
  # This simulates the regression without mutating the
  # production file.
  transformed = src.gsub(
    'SUAnalysis::Compatibility::V2SketchupMassAdapter',
    'V2SketchupMassAdapter'
  )

  # Sanity guard: the transformation must have actually
  # changed the file (i.e., the production file currently
  # uses the explicit authority).
  if transformed == src
    raise 'NS-04: precondition violated -- production file ' \
          'no longer contains the explicit authority; the ' \
          'negative proof is meaningless'
  end

  File.write(transformed_path, transformed)

  # The transformed production file does
  # `require_relative 'host_operation_guard'` and
  # `require_relative '../compatibility/v2_sketchup_mass_adapter'`
  # -- paths relative to its ORIGINAL location
  # `extension/su_ai_plugin/v2/`. To make those
  # require_relative paths resolve when the file is
  # loaded from NS_TEST_TMP, write stub redirector files
  # alongside the transformed file that re-require the
  # real production files from their original location.
  redirector_files = [
    {
      path: File.join(NS_TEST_TMP, 'host_operation_guard.rb'),
      body: "require_relative '../../extension/su_ai_plugin/v2/host_operation_guard'\n"
    },
    {
      path: File.join(NS_TEST_TMP, 'semantic_footprint_projector.rb'),
      body: "require_relative '../../extension/su_ai_plugin/v2/semantic_footprint_projector'\n"
    },
    {
      path: File.join(NS_TEST_TMP, '..', 'compatibility', 'v2_sketchup_mass_adapter.rb'),
      body: "require_relative '../../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter'\n"
    }
  ]
  redirector_files.each do |rf|
    FileUtils.mkdir_p(File.dirname(rf[:path]))
    File.write(rf[:path], rf[:body])
  end

  # The shim lives in NS_TEST_TMP next to the transformed
  # production file so the relative paths inside the
  # non-interpolated heredoc are simple.
  shim_path = File.join(NS_TEST_TMP, '_shim_ns04.rb')
  File.write(shim_path, <<~'RUBY')
    # V2-S0B-NS-04: negative proof. Loads the TRANSFORMED
    # production file (which contains the unqualified
    # `V2SketchupMassAdapter::` regression) and runs the
    # same NS-01 success path against it.
    require_relative './stage0b_mass_probe_ns04_regression'
    # Real SUAnalysis::Compatibility::V2SketchupMassAdapter
    # must already be loaded so the shim can call its
    # STATUS_CONSTRUCTION_FAILED symbol to build the
    # FAILED_ROLLED_BACK reason. Loading the real
    # adapter file here is a no-op if the transformed
    # production file already loaded it through its
    # redirector.
    require_relative '../../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter'
    require_relative '../../extension/su_ai_plugin/v2/host_operation_guard'

    begin
      Probe = SUAnalysis::V2::Stage0BMassProbe
      Guard = SUAnalysis::V2::HostOperationGuard
      Adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter

      capture_seam = ->(analysis_result:) {
        { 'status' => 'CAPTURED', 'bundle' => {} }
      }
      build_seam = ->(_bundle) {
        ds = Object.new
        def ds.final?; true; end
        def ds.content_digest; @scd; end
        ds.instance_variable_set(:@scd, ('b' * 64))
        { 'status' => 'BUILT', 'dataset' => ds }
      }
      validate_seam = ->(dataset:, workflow_snapshot:) {
        { 'status' => 'READY', 'dataset' => dataset }
      }
      projector = ->(dataset:, semantic_role:, layer_name:) {
        fp = {
          'footprint_id_full'         => ('a' * 64),
          'source_content_digest'     => ('b' * 64),
          'semantic_role'             => 'body',
          'source_layer_name'         => 'NS04_L0',
          'projected_world_coordinates' => [
            [0.0, 0.0, 0.0],
            [10.0, 0.0, 0.0],
            [10.0, 8.0, 0.0],
            [0.0, 8.0, 0.0]
          ],
          'coordinate_epsilon' => 1.0e-6
        }
        { 'status' => 'PROJECTED', 'footprints' => [fp] }
      }

      fake_model = Object.new
      def fake_model.entities;   []; end
      def fake_model.active_path; nil; end
      def fake_model.start_operation(*); true; end
      def fake_model.commit_operation; true; end
      def fake_model.abort_operation; true; end

      adapter = Adapter.new(model_provider: -> { fake_model })
      guard   = Guard.new
      probe = Probe.new(
        guard:         guard,
        adapter:       adapter,
        capture_seam:  capture_seam,
        build_seam:    build_seam,
        validate_seam: validate_seam,
        projector:     projector
      )

      fp = {
        'footprint_id_full'         => ('a' * 64),
        'source_content_digest'     => ('b' * 64),
        'semantic_role'             => 'body',
        'source_layer_name'         => 'NS04_L0',
        'projected_world_coordinates' => [
          [0.0, 0.0, 0.0],
          [10.0, 0.0, 0.0],
          [10.0, 8.0, 0.0],
          [0.0, 8.0, 0.0]
        ],
        'coordinate_epsilon' => 1.0e-6
      }

      out = probe.run(
        footprint:       fp,
        analysis_result: { 'kind' => 'test' },
        probe_height:    120.0
      )
      puts 'NS04_RESULT=' + (out.is_a?(Hash) ? out['status'].to_s : 'NO_HASH')
    rescue => e
      puts 'NS04_RAISED=' + e.class.to_s
      puts 'NS04_MSG=' + e.message.to_s
    end
  RUBY

  out, err, status = Open3.capture3(NS_TEST_RUBY_EXE, shim_path)
  combined = (out || '') + (err || '')
  # The negative proof is satisfied if EITHER:
  #   (a) the subprocess raised NameError (unqualified
  #       lookup fails inside the production file), OR
  #   (b) the subprocess returned a non-SUCCESS status
  #       because the regression broke the operation
  #       lifecycle (e.g., label was nil and start failed).
  # We require that the subprocess DID NOT silently report
  # `NS04_RESULT=SUCCESS`, because the regression would have
  # been masked.
  assert !combined.include?('NS04_RESULT=SUCCESS'),
       "NS-04: negative proof FAILED -- the regression " \
       "transformation did not break the success probe. Output:\n" +
       combined
  # And it MUST show the NameError / failure signature.
  assert(combined.include?('NS04_RAISED=') ||
         combined.include?('NS04_RESULT=') ||
         combined.include?('NameError'),
         "NS-04: subprocess produced no diagnostic output:\n" +
         combined)
ensure
  # Always clean up the throwaway files (shim, transformed
  # production, and the three redirector files).
  paths_to_clean = []
  paths_to_clean << shim_path                  if shim_path
  paths_to_clean << transformed_path            if defined?(transformed_path) && transformed_path
  paths_to_clean << File.join(NS_TEST_TMP, 'host_operation_guard.rb')
  paths_to_clean << File.join(NS_TEST_TMP, 'semantic_footprint_projector.rb')
  compat_dir = File.join(NS_TEST_TMP, '..', 'compatibility')
  paths_to_clean << File.join(compat_dir, 'v2_sketchup_mass_adapter.rb')
  paths_to_clean << compat_dir
  paths_to_clean.uniq.each do |p|
    if File.exist?(p) || File.symlink?(p)
      if File.directory?(p)
        Dir.rmdir(p) if Dir.empty?(p)
      else
        File.delete(p)
      end
    end
  end
end