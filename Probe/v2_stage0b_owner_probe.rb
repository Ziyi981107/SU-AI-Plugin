#
# Probe/v2_stage0b_owner_probe.rb — V2-0B Owner / Developer
# Real-SketchUp Probe.
#
# Per frozen V2-0B Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md)
# §12 + §15:
#
#   Add developer-only callable commands that invoke the SAME
#   production Stage0B mass executor + SAME real SketchUp
#   compatibility adapter. The probe may build a small
#   synthetic FINAL PCD + matching SemanticFootprint for
#   host-only diagnostics, provided the automated suite
#   separately proves the real public V1 freshness path.
#
#   The probe provides two callable developer commands:
#
#     1. success probe
#        - create one simple rectangular V2 mass;
#        - print status + created group name;
#        - Owner presses native Undo once;
#        - expected: the complete V2 probe group
#          disappears in one Undo.
#
#     2. injected construction-failure probe
#        - use a Probe-only adapter subclass/decorator
#          that raises after mutation has begun (for
#          example at extrusion);
#        - production code itself must NOT gain a
#          `failure_stage` test switch;
#        - expected result is FAILED_ROLLED_BACK when
#          abort succeeds;
#        - expected visible residue = zero V2 probe
#          group.
#
#   Do NOT put Owner-probe test switches into production
#   modules.
#
#   This script is loaded only by the Owner / developer in
#   real SU2020. The automated suite (tests/test_v2_stage0b_
#   host_mass_probe.rb) does NOT depend on this script.
#

require_relative '../extension/su_ai_plugin/v2/host_operation_guard'
require_relative '../extension/su_ai_plugin/v2/stage0b_mass_probe'
require_relative '../extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter'

module SUAnalysis
  module Probe
    # V2Stage0BOwnerProbe wires the production Stage0B mass
    # executor to the real SketchUp adapter for live Owner
    # verification. The probe never modifies production
    # modules.
    class V2Stage0BOwnerProbe
      # Default probe height. The Owner may override via
      # ENV['V2_S0B_PROBE_HEIGHT'].
      DEFAULT_PROBE_HEIGHT = 120.0

      # Deterministic one-click synthetic data. These
      # values are intentionally fixed so the Owner gate
      # is reproducible across runs and across developers.
      ONE_CLICK_RECT_W         = 240.0
      ONE_CLICK_RECT_H         = 180.0
      ONE_CLICK_PROBE_HEIGHT   = 120.0
      ONE_CLICK_COORD_EPSILON  = 1.0e-6
      ONE_CLICK_FOOTPRINT_ID_FULL =
        ('a' * 64).freeze
      ONE_CLICK_SOURCE_CONTENT_DIGEST =
        ('b' * 64).freeze
      ONE_CLICK_DATASET_ID =
        'ds-v2-owner-probe-one-click'.freeze
      ONE_CLICK_LAYER_NAME =
        'V2_OWNER_PROBE'.freeze
      ONE_CLICK_SEMANTIC_ROLE =
        'body'.freeze

      attr_reader :guard, :adapter, :probe

      def initialize(model_provider: nil)
        @guard   = SUAnalysis::V2::HostOperationGuard.new
        @adapter = SUAnalysis::Compatibility::V2SketchupMassAdapter.new(
          model_provider: model_provider
        )
        @probe   = SUAnalysis::V2::Stage0BMassProbe.new(
          guard:   @guard,
          adapter: @adapter
        )
      end

      # ------------------------------------------------------------
      # Owner-facing class-level one-click entry points.
      #
      # The Owner loads this Probe file and calls these
      # two methods directly from the SU Ruby console.
      # No footprint / analysis_result / PCD / Runner /
      # Builder / Validator / Projector object construction
      # is required.
      #
      # Both methods are deliberately self-contained:
      # they DO NOT mutate, prepare, or reset the
      # Runner / CAD Prep session; they DO NOT touch
      # source CAD or V1 Derived Workspace; they use a
      # fixed Probe-only synthetic freshness package to
      # satisfy Stage0B's existing injected-seam
      # contract so that ONLY the real SketchUp host
      # mutation / native Undo / abort-rollback
      # behavior is exercised.
      #
      # Optional `model_provider:` is exposed ONLY for
      # host-free test injection; in real SU2020 the
      # adapter's normal `Sketchup.active_model` provider
      # is used.
      # ------------------------------------------------------------

      def self.run_success_one_click(model_provider: nil)
        new(model_provider: model_provider).run_success_one_click
      end

      def self.run_injected_failure_one_click(model_provider: nil)
        new(model_provider: model_provider).run_injected_failure_one_click
      end

      # ------------------------------------------------------------
      # Instance-level one-click probes.
      # ------------------------------------------------------------

      # One-click SUCCESS probe against the real SketchUp
      # host boundary. Returns the normal Stage0B result
      # Hash; prints an Owner-readable summary.
      def run_success_one_click
        seams   = _one_click_synthetic_seams
        footprint = _one_click_synthetic_footprint
        # Stage0BMassProbe takes the synthetic seams via
        # the constructor, NOT via run kwargs. We construct
        # a dedicated Stage0BMassProbe instance per
        # invocation so the seams cannot leak into
        # subsequent probe calls.
        probe = SUAnalysis::V2::Stage0BMassProbe.new(
          guard:        @guard,
          adapter:      @adapter,
          capture_seam: seams[:capture],
          build_seam:   seams[:build],
          validate_seam: seams[:validate],
          projector:    seams[:projector]
        )
        result = probe.run(
          footprint:        footprint,
          analysis_result:  nil,
          probe_height:     ONE_CLICK_PROBE_HEIGHT
        )
        _print_success_result(result)
        result
      end

      # One-click INJECTED-FAILURE probe against the real
      # SketchUp host boundary. Delegates to the real
      # adapter FIRST (so Group + Face + extrusion +
      # ownership attributes are actually created inside
      # the open operation), then raises a Probe-only
      # exception so Stage0B's exception boundary
      # performs exactly one abort attempt.
      #
      # The failure probe MUST NOT require Owner to press
      # Undo. Confirmed abort removes the V2 group with
      # zero visible residue.
      def run_injected_failure_one_click
        seams   = _one_click_synthetic_seams
        footprint = _one_click_synthetic_footprint
        decorator = PushpullRaisingAdapterDecorator.new(@adapter)
        probe = SUAnalysis::V2::Stage0BMassProbe.new(
          guard:        @guard,
          adapter:      decorator,
          capture_seam: seams[:capture],
          build_seam:   seams[:build],
          validate_seam: seams[:validate],
          projector:    seams[:projector]
        )
        result = probe.run(
          footprint:        footprint,
          analysis_result:  nil,
          probe_height:     ONE_CLICK_PROBE_HEIGHT
        )
        _print_injected_failure_result(result)
        result
      end

      # ------------------------------------------------------------
      # Probe-only synthetic freshness package.
      #
      # The truthful production-default V1 -> Builder ->
      # Validator -> Projector -> Stage0B integration is
      # already separately proven by V2-S0B-R2-INT04. The
      # purpose of this Owner gate is specifically to
      # isolate and verify real SketchUp host mutation /
      # native Undo / abort-rollback behavior, NOT to
      # retest the V1 pure-data chain.
      #
      # Therefore the one-click wrappers use a fixed
      # synthetic freshness package that satisfies
      # Stage0B's existing injected-seam contract without
      # disturbing the user CAD Prep session.
      # ------------------------------------------------------------

      private

      # Deterministic rectangular SemanticFootprint-shaped
      # Hash that satisfies the V2-0A SemanticFootprint
      # Blueprint §3.2 contract shape and Stage0B input
      # validation (Blueprint §4). The fingerprint values
      # are intentionally fixed.
      def _one_click_synthetic_footprint
        {
          'schema_version'      => 'v2.semantic-footprint.v1',
          'footprint_id'        => 'v2fp-' + ONE_CLICK_FOOTPRINT_ID_FULL[0, 20],
          'footprint_id_full'   => ONE_CLICK_FOOTPRINT_ID_FULL,
          'semantic_role'       => ONE_CLICK_SEMANTIC_ROLE,
          'source_layer_name'   => ONE_CLICK_LAYER_NAME,
          'source_dataset_id'   => ONE_CLICK_DATASET_ID,
          'source_content_digest' => ONE_CLICK_SOURCE_CONTENT_DIGEST,
          'coordinate_epsilon'  => ONE_CLICK_COORD_EPSILON,
          'source_node_ids'     => %w[n1 n2 n3 n4],
          'source_edge_ids'     => %w[e1 e2 e3 e4],
          'projected_world_coordinates' => [
            [0.0,                  0.0,                  0.0],
            [ONE_CLICK_RECT_W,     0.0,                  0.0],
            [ONE_CLICK_RECT_W,     ONE_CLICK_RECT_H,     0.0],
            [0.0,                  ONE_CLICK_RECT_H,     0.0]
          ],
          'area_xy'   => ONE_CLICK_RECT_W * ONE_CLICK_RECT_H,
          'perimeter' => 2.0 * (ONE_CLICK_RECT_W + ONE_CLICK_RECT_H)
        }
      end

      # Duck-typed final PreparedCadDataset stand-in.
      # Stage0B's freshness check uses two accessors:
      # - `dataset.respond_to?(:final?) && dataset.final?`
      # - `dataset.respond_to?(:content_digest) ? dataset.content_digest.to_s : ''`
      # We provide only those accessors plus a minimal
      # marker. This stand-in is constructed ONCE per
      # probe invocation (closure-shared across the four
      # seams so object identity is stable).
      def _one_click_synthetic_dataset
        digest = ONE_CLICK_SOURCE_CONTENT_DIGEST
        ds = Object.new
        ds.define_singleton_method(:final?) { true }
        ds.define_singleton_method(:content_digest) { digest }
        ds
      end

      # Returns a Hash of four Procs that satisfy
      # Stage0B's injected-seam contract. The four seams
      # are intentionally synthetic and self-contained;
      # they DO NOT touch source CAD or V1 Derived
      # Workspace.
      def _one_click_synthetic_seams
        dataset   = _one_click_synthetic_dataset
        footprint = _one_click_synthetic_footprint
        capture_seam = ->(analysis_result:) {
          {
            'status' => 'CAPTURED',
            'bundle' => {
              'source_snapshot'    => nil,
              'workflow_snapshot'  => {},
              'topology_snapshot'  => nil,
              'canonical_graph'    => nil,
              'structure_result'   => nil,
              'analysis_result'    => analysis_result
            }
          }
        }
        build_seam = ->(bundle) {
          { 'status' => 'BUILT', 'dataset' => dataset }
        }
        validate_seam = ->(dataset:, workflow_snapshot:) {
          { 'status' => 'READY', 'dataset' => dataset }
        }
        projector = ->(dataset:, semantic_role:, layer_name:) {
          {
            'status'    => 'PROJECTED',
            'footprints' => [footprint]
          }
        }
        {
          capture:  capture_seam,
          build:    build_seam,
          validate: validate_seam,
          projector: projector
        }
      end

      def _print_success_result(result)
        if result['status'] == SUAnalysis::V2::Stage0BMassProbe::STATUS_SUCCESS
          group = result['group']
          puts '[V2-0B Owner-Gate one-click SUCCESS]'
          puts "  status:    #{result['status']}"
          puts "  group:     #{group.respond_to?(:name) ? group.name : '<unknown>'}"
          puts "  fpid:      #{result['footprint_id_full']}"
          puts "  probe_height: #{ONE_CLICK_PROBE_HEIGHT}"
          puts '  Owner action required:'
          puts '    Press native SketchUp Undo ONCE.'
          puts '    Expected: the entire SU-AI-V2-Probe-* Group'
          puts '    disappears in a single Undo.'
        else
          puts '[V2-0B Owner-Gate one-click NON-SUCCESS]'
          result.each do |k, v|
            puts "  #{k}: #{v.inspect}"
          end
          puts '  Owner action required:'
          puts '    Inspect the failure status / error and'
          puts '    return the console output to AIPM.'
        end
      end

      def _print_injected_failure_result(result)
        puts '[V2-0B Owner-Gate one-click INJECTED FAILURE]'
        result.each do |k, v|
          puts "  #{k}: #{v.inspect}"
        end
        if result['status'] ==
           SUAnalysis::V2::Stage0BMassProbe::STATUS_FAILED_ROLLED_BACK
          puts '  Owner action required:'
          puts '    Confirm no SU-AI-V2-Probe-* Group remains'
          puts '    visible in the model. Expected: zero visible'
          puts '    V2 probe residue remains. Do NOT press Undo.'
        else
          puts '  Owner action required:'
          puts '    Inspect the failure status / error and'
          puts '    return the console output to AIPM.'
        end
      end

      # Success probe. Owner invokes this in real SU2020,
      # then presses native Undo once and confirms the
      # entire V2 probe group disappears.
      #
      # Required:
      #   footprint      : SemanticFootprint value record
      #   analysis_result: real AnalysisResult for the V1
      #                    public capture seam
      #   workflow_snapshot: optional explicit Hash for
      #                    Validator
      #
      # Optional:
      #   probe_height   : default DEFAULT_PROBE_HEIGHT
      def run_success_probe(footprint:, analysis_result:,
                             workflow_snapshot: nil,
                             probe_height: nil)
        h = probe_height ||
            (ENV['V2_S0B_PROBE_HEIGHT'] &&
             ENV['V2_S0B_PROBE_HEIGHT'].to_f) ||
            DEFAULT_PROBE_HEIGHT
        result = @probe.run(
          footprint:        footprint,
          analysis_result:  analysis_result,
          workflow_snapshot: workflow_snapshot,
          probe_height:     h
        )
        if result['status'] == SUAnalysis::V2::Stage0BMassProbe::STATUS_SUCCESS
          group = result['group']
          puts "[V2-0B probe SUCCESS]"
          puts "  status:    #{result['status']}"
          puts "  group:     #{group.respond_to?(:name) ? group.name : '<unknown>'}"
          puts "  fpid:      #{result['footprint_id_full']}"
          puts "  probe_height: #{h}"
          puts "  Owner: please press native Undo once and"
          puts "  confirm the V2 probe group disappears."
        else
          puts "[V2-0B probe NON-SUCCESS]"
          result.each do |k, v|
            puts "  #{k}: #{v.inspect}"
          end
        end
        result
      end

      # Injected construction-failure probe. Wraps the
      # production adapter in a decorator that raises at
      # pushpull time. The production adapter itself is
      # NOT modified.
      def run_injected_failure_probe(footprint:, analysis_result:,
                                     workflow_snapshot: nil,
                                     probe_height: nil)
        h = probe_height ||
            (ENV['V2_S0B_PROBE_HEIGHT'] &&
             ENV['V2_S0B_PROBE_HEIGHT'].to_f) ||
            DEFAULT_PROBE_HEIGHT
        decorator = PushpullRaisingAdapterDecorator.new(@adapter)
        probe = SUAnalysis::V2::Stage0BMassProbe.new(
          guard:   @guard,
          adapter: decorator
        )
        result = probe.run(
          footprint:        footprint,
          analysis_result:  analysis_result,
          workflow_snapshot: workflow_snapshot,
          probe_height:     h
        )
        puts "[V2-0B probe INJECTED FAILURE]"
        result.each do |k, v|
          puts "  #{k}: #{v.inspect}"
        end
        if result['status'] ==
           SUAnalysis::V2::Stage0BMassProbe::STATUS_FAILED_ROLLED_BACK
          puts "  Owner: confirm zero V2 probe group remains"
          puts "  visible in the model."
        end
        result
      end

      # Probe-only decorator: forward every method to the
      # real adapter EXCEPT build_mass, which delegates to
      # the real adapter FIRST (creating real V2 geometry
      # inside the open operation) and then raises a
      # Probe-only exception BEFORE Stage0B can commit.
      # The production exception boundary converts the
      # raise to exactly one abort attempt; confirmed
      # rollback removes the already-created V2 group
      # with zero visible residue.
      #
      # Production code does NOT gain a `failure_stage`
      # switch. This decorator is only used by
      # `run_injected_failure_probe` and never by the
      # production success path.
      class PushpullRaisingAdapterDecorator
        def initialize(real_adapter)
          @real = real_adapter
        end

        def respond_to_missing?(sym, include_private = false)
          @real.respond_to?(sym, include_private) || super
        end

        def method_missing(name, *args, **kw, &block)
          if name == :build_mass
            _delegate_then_raise(*args, **kw)
          else
            @real.send(name, *args, **kw, &block)
          end
        end

        private

        # Delegate to the real adapter FIRST so real V2
        # geometry (group + face + extruded volume +
        # ownership attributes) is created inside the
        # open operation. Then raise a Probe-only
        # exception so Stage0B's exception boundary
        # invokes exactly one abort attempt.
        #
        # The real adapter call returns its own Hash
        # result which we explicitly discard; the raise
        # escapes through Stage0B's rescue, becomes a
        # construction failure, and triggers one abort.
        # Confirmed rollback removes the V2 group with
        # zero visible residue.
        def _delegate_then_raise(footprint:, probe_height:)
          @real.build_mass(footprint: footprint,
                           probe_height: probe_height)
          # Defensive: if the real adapter somehow
          # succeeded without raising, the Stage0B flow
          # would commit. Force an explicit failure AFTER
          # real geometry exists so the test still
          # exercises the abort path.
          raise 'V2-0B probe injected post-construction failure'
        end
      end
    end
  end
end

# Owner-friendly entry points. The developer pastes these
# commands into the SU Ruby console after loading this file
# via:
#   load 'D:/Projects/SU-AI-Plugin/Probe/v2_stage0b_owner_probe.rb'
#
# Then build a footprint via the V2-0A projector (real
# PCD -> SemanticFootprint) and invoke:
#
#   probe = SUAnalysis::Probe::V2Stage0BOwnerProbe.new
#   footprint = <SemanticFootprint from projector>
#   analysis_result = <current AnalysisResult>
#   probe.run_success_probe(
#     footprint: footprint,
#     analysis_result: analysis_result
#   )
#
# After pressing native Undo once, the V2 probe group
# should be gone.
#
#   probe.run_injected_failure_probe(
#     footprint: footprint,
#     analysis_result: analysis_result
#   )
#
# After completion, the model should contain no visible
# V2 probe residue.
#
# ----------------------------------------------------------------
# V2-0B Owner Gate ONE-CLICK entry points (added 2026-09-17
# per Prompt/AIPM_V2_0B_OWNER_GATE_ONE_CLICK_PROBE_2026-09-17.md).
#
# After loading this Probe file, the Owner runs ONLY:
#
#   SUAnalysis::Probe::V2Stage0BOwnerProbe.run_success_one_click
#
# then presses native SketchUp Undo ONCE and confirms the
# SU-AI-V2-Probe-* Group disappears. Next:
#
#   SUAnalysis::Probe::V2Stage0BOwnerProbe.run_injected_failure_one_click
#
# then confirms zero visible V2 residue remains. Do NOT
# press Undo for the injected-failure probe.
#
# The one-click wrappers do NOT touch source CAD or V1
# Derived Workspace; they do NOT require the Owner to
# construct any footprint / analysis_result / PCD / Runner
# / Builder / Validator / Projector object.
# ----------------------------------------------------------------