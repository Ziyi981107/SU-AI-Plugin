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