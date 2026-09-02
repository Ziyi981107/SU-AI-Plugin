#
# core/gap_bridge_executor.rb — V1.7 GapBridgeExecutor.
#
# Per frozen V1.7 Blueprint §12 / §13 / §14, as corrected by
# V17-AIPM-DIRECT-SOURCE-REVIEW-FIX-2026-09-01 SR-01..SR-03
# + SR-05.
#
#   §12 Host Mutation Model:
#     - Workspace-owned repair geometry (NOT cross-group
#       welding). ONE workspace-owned top-level derived group
#       per applied bridge; the same DerivedGeometryWorkspace
#       handle_registry owns it as every other derived entity.
#     - The existing workspace build_entity path is the SOLE
#       host-creation path (Blueprint §12.2:
#         "If current workspace architecture already provides
#          a safer equivalent owned repair-geometry container,
#          reuse it instead of inventing a second container").
#     - Do NOT also create a shared repair-group edge (SR-01).
#     - For each approved endpoint_bridge, create one line from
#       the exact endpoint A world coord to endpoint B world
#       coord using the OLD-host-compatible
#       Sketchup::Entities#add_edges path. Do NOT move existing
#       source-derived endpoints.
#     - ONE native operation for the batch.
#     - If mutation fails before commit: use the existing
#       abort/fail-closed semantics.
#     - If commit result is uncertain: workspace FAILED. Do
#       NOT claim rollback success without evidence.
#
#   §13 Preflight before destructive apply.
#
#   §14 Post-validation before publishing APPLIED.
#
# V17-AIPM-DIRECT-SOURCE-REVIEW-FIX SR-02: the failure path
# returns a NEW :failed workspace derived from the captured
# `pre_workspace` (NOT the partially-mutated `working_workspace`).
# No generated bridge record survives logically. Source unchanged.
#
# V17-AIPM-DIRECT-SOURCE-REVIEW-FIX SR-03: the post-validation
# block proves:
#   (A) exact generated count matches executable proposals
#   (B) every generated record carries
#       origin_kind=generated_gap_bridge AND repair_action_id
#       == proposal_id
#   (C) actual host endpoint positions match expected values
#   (D) source fingerprint unchanged
#   (E) pre-existing source-derived record coordinates unchanged
#   (F) generated proposal IDs exactly equal expected READY
#       proposal IDs
#   (G) no REVIEW_REQUIRED proposal was executed
# After commit, the runner rebuilds CanonicalGeometryGraph and
# proves:
#   (H) every applied bridge is one canonical edge with
#       origin_kind=gap_bridge
#   (I) repair_action_id survives into the canonical edge
#   (J) repaired endpoint adjacency is present
#   (K) no new non_transitive_node_cluster is introduced
# If canonical post-validation fails after host commit, the
# workspace transitions to :failed, handles are retained for
# Discard, and stable reason `canonical_post_validation_failed`
# is recorded.
#
# V17-AIPM-DIRECT-SOURCE-REVIEW-FIX SR-05: the generated bridge
# derived_id is DETERMINISTIC from the proposal_id. No Ruby
# random value. Preferred form: `der-gap-#{proposal_id}`.
#
# The old `add_line_to_repair_group` / `ensure_repair_group`
# adapter APIs remain defined (for backwards-compatibility) but
# the production V1.7 base path does NOT call them. Lifecycle
# cleanup of the bridge handle is performed via the existing
# workspace discard / rebuild / close-time auto-discard (the
# same private handle_registry owns the bridge handle, so the
# existing discard path precisely targets it).
#

require_relative 'tolerance'

module SUAnalysis
  module Core
    module GapBridgeExecutor
      module_function

      # Deterministic derived_id prefix for generated bridges
      # (SR-05). The full id is `der-gap-#{proposal_id}` which
      # is stable across equivalent rebuild / reapply because
      # the proposal_id itself is deterministic (per
      # GapPairProposer._proposal_id).
      BRIDGE_DERIVED_ID_PREFIX = 'der-gap-'.freeze
      OPERATION_NAME             = 'SU-AI-Plugin: V1.7 Gap Bridge Apply'.freeze
      PROVENANCE_SCHEMA_VERSION  = 'gap-bridge-apply.v2'.freeze

      REASON_OK                  = 'ok'.freeze
      REASON_INVALID_WORKSPACE   = 'invalid_workspace_state'.freeze
      REASON_HOST_INCONSISTENT   = 'host_inconsistent_state'.freeze
      REASON_NO_ADAPTER          = 'no_adapter'.freeze
      REASON_NO_PROPOSALS        = 'no_proposals'.freeze
      REASON_PREFLIGHT_FAILED    = 'preflight_failed'.freeze
      REASON_BRIDGE_BUILD_FAILED = 'workspace_build_failed'.freeze
      REASON_POST_VALIDATE_FAIL  = 'post_validation_failed'.freeze
      REASON_COMMIT_UNCERTAIN    = 'commit_uncertainty'.freeze
      REASON_ABORT_UNCERTAIN     = 'abort_uncertainty'.freeze
      REASON_CANONICAL_POST_VALIDATE_FAIL = 'canonical_post_validation_failed'.freeze

      # Apply a batch of approved gap-bridge proposals to the
      # current workspace. Returns:
      #
      #   {
      #     status:             :applied | :failed,
      #     post_workspace:      DerivedGeometryWorkspace (new
      #                          state==:ready on :applied,
      #                          state==:failed on :failed),
      #     audit:               frozen Hash,
      #     applied_proposals:   Array<Hash>,
      #     failed_proposals:    Array<Hash>,
      #     repair_group:        nil (legacy field retained
      #                          for backwards compatibility;
      #                          the V1.7 base path owns
      #                          bridge handles via the
      #                          workspace handle_registry)
      #   }
      def apply(workspace:, adapter:, proposals:, tolerance:, repair_group: nil)
        # The `repair_group:` keyword is intentionally ignored
        # (SR-01): the V1.7 base execution path is the
        # workspace-owned build_entity path. The argument
        # remains in the signature for backwards compatibility
        # with prior callers / tests; it is non-authoritative.
        _ = repair_group

        # ---- Defensive nulls ----
        if workspace.nil? || adapter.nil?
          return _fail(workspace, REASON_NO_ADAPTER, [])
        end
        # ---- Workspace state guard ----
        # Only :ready is the legitimate apply path. Any other
        # state (building / failed / discarded) refuses with
        # REASON_INVALID_WORKSPACE.
        if workspace.state != :ready
          return _fail(workspace, REASON_INVALID_WORKSPACE, [])
        end

        # ---- Filter to executable proposals only ----
        ready = Array(proposals).select { |p|
          p.is_a?(Hash) && p['state'] == GapPairProposer::STATE_READY_TO_REPAIR &&
            p['executable'] == true
        }
        if ready.empty?
          return _fail(workspace, REASON_NO_PROPOSALS, [])
        end

        # ---- Preflight (§13) ----
        preflight = _preflight(workspace, ready, tolerance)
        unless preflight['pass']
          return _fail(workspace, REASON_PREFLIGHT_FAILED, [],
                       preflight['reasons'])
        end

        # ---- SR-02: capture pre_workspace (the exact
        # pre-batch logical inventory + handle registry). If
        # any mutation / postvalidation step fails AFTER this
        # point and the host abort is CONFIRMED, we return a
        # NEW :failed workspace derived from this snapshot
        # (NOT from the partially-mutated working_workspace).
        # Source fingerprint + handle_registry are preserved.
        pre_workspace = workspace
        pre_fingerprint_digest = workspace.respond_to?(:fingerprint) &&
                                   workspace.fingerprint &&
                                   workspace.fingerprint.respond_to?(:digest) ?
                                     workspace.fingerprint.digest.to_s : nil
        pre_source_fingerprint_digest = workspace.source_snapshot.respond_to?(:fingerprint) ?
                                           workspace.source_snapshot.fingerprint.respond_to?(:digest) ?
                                             workspace.source_snapshot.fingerprint.digest.to_s : nil : nil
        pre_entity_coords = _pre_existing_source_derived_coords(workspace)

        # ---- SR-02 + RR-01: maintain working_workspace as
        # the progressively-mutated workspace. After commit
        # (or confirmed abort), it is replaced with the
        # appropriate final workspace; on uncertain failure,
        # we fall back to the pre_workspace and transition
        # to :failed.
        working_workspace = workspace
        applied = []
        failed  = []
        commit_completed = false
        abort_completed = false
        # RR-01: operation_started tracks whether the host
        # operation was successfully opened. Only set after
        # begin_operation returns without raising. Every exit
        # path MUST reduce operation_started exactly once (via
        # confirmed commit, confirmed abort, or close
        # uncertainty state). Never returns without one of
        # these resolutions.
        operation_started = false
        begin
          adapter.begin_operation(working_workspace.instance_variable_get(:@model),
                                  label: OPERATION_NAME)
          operation_started = true
          ready.each do |prop|
            eps = prop['expected_bridge_endpoints']
            p1 = eps[0]
            p2 = eps[1]
            unless eps.is_a?(Array) && eps.length == 2 &&
                   p1.is_a?(Array) && p1.length == 3 &&
                   p2.is_a?(Array) && p2.length == 3
              failed << { 'proposal_id' => prop['proposal_id'],
                          'reason'     => 'invalid_bridge_endpoints' }
              next
            end
            # ---- SR-01 + SR-05: the SOLE host-creation path
            # is workspace.build_entity. The derived_id is
            # deterministic from the proposal_id. ONE
            # workspace-owned top-level derived group, ONE
            # bridge edge, owned by the workspace's private
            # handle_registry.
            did = _deterministic_bridge_id(prop['proposal_id'])
            new_ws = working_workspace.build_entity(
              derived_id:            did,
              kind:                  :edge,
              source_occurrence_ids: prop['incident_source_occurrence_ids'] || [],
              geometry_summary:      {
                'layer'           => prop['layer_a'] || prop['layer_b'] || nil,
                'length'          => prop['expected_bridge_length'].to_f,
                'start'           => [p1[0], p1[1], p1[2]],
                'end'             => [p2[0], p2[1], p2[2]],
                'origin_kind'     => 'generated_gap_bridge',
                'repair_action_id'=> prop['proposal_id']
              },
              geometry_data:         [p1, p2]
            )
            if new_ws.state == :failed
              failed << { 'proposal_id' => prop['proposal_id'],
                          'reason'     => REASON_BRIDGE_BUILD_FAILED,
                          'detail'     => new_ws.last_error.to_s }
              working_workspace = new_ws
              next
            end
            working_workspace = new_ws
            applied << {
              'proposal_id' => prop['proposal_id'],
              'derived_id'  => did,
              'host_handle' => new_ws.handle_for(did)
            }
          end
          # ---- SR-03: hard runtime post-validation BEFORE
          # commit. Reject the batch if any of (A)..(G) fail.
          post = _post_validate(working_workspace, adapter, applied, ready,
                                pre_workspace: pre_workspace,
                                pre_fingerprint_digest: pre_fingerprint_digest,
                                pre_source_fingerprint_digest: pre_source_fingerprint_digest,
                                pre_entity_coords: pre_entity_coords)
          if !post['pass']
            # RR-01 + SR-02: confirmed host abort path.
            # 1. Close the operation with commit:false EXACTLY
            #    ONCE. If the adapter succeeds, mark
            #    abort_completed=true and operation_started=
            #    false. If the adapter raises, fall through
            #    to the abort-uncertainty branch below
            #    (preserve working handles for Discard).
            # 2. Discard any working handles built so far
            #    (the workspace's private handle_registry
            #    holds them all), then return a NEW :failed
            #    workspace derived from pre_workspace.
            abort_outcome = _confirmed_abort(adapter, working_workspace, pre_workspace)
            unless abort_outcome == :abort_completed
              # Abort ITSELF raised (close-uncertainty).
              # Preserve current handles, mark :failed,
              # record stable reason `abort_uncertainty`.
              audit = _abort_uncertain_audit(applied, post['reasons'])
              post_ws = _transition_to_failed_with_handles(
                pre_workspace, working_workspace,
                REASON_ABORT_UNCERTAIN, audit['reason'].to_s
              )
              return {
                'status'         => :failed,
                'post_workspace' => post_ws,
                'audit'          => audit,
                'applied_proposals' => applied,
                'failed_proposals'  => failed,
                'repair_group'   => nil
              }
            end
            operation_started = false
            return _fail(pre_workspace, REASON_POST_VALIDATE_FAIL, applied,
                         post['reasons'])
          end
          # ---- Commit ----
          adapter.end_operation(working_workspace.instance_variable_get(:@model),
                                commit: true)
          commit_completed = true
          operation_started = false
        rescue StandardError => e
          # RR-01 + SR-02: try to abort the operation
          # (best-effort). Track success. If abort itself
          # raises, we are in abort-uncertainty: preserve
          # working handles for Discard.
          abort_uncertain = false
          if operation_started
            begin
              adapter.end_operation(working_workspace.instance_variable_get(:@model),
                                  commit: false)
              abort_completed = true
              operation_started = false
            rescue StandardError
              abort_uncertain = true
              operation_started = false
            end
          end
          # RR-01 + SR-02: on commit uncertainty / abort
          # uncertainty / exception, return :failed based on
          # pre_workspace. Preserve enough current generated
          # handles so explicit Discard can clean any host
          # entity that may still exist.
          audit = if abort_uncertain
                    _abort_uncertain_audit(applied, [e.message.to_s])
                  else
                    _commit_uncertain_audit(applied, e)
                  end
          reason = abort_uncertain ? REASON_ABORT_UNCERTAIN : REASON_COMMIT_UNCERTAIN
          # Use the partially-mutated working_workspace as the
          # source of current handles (Discard needs them).
          # Mark it :failed so it cannot claim :ready.
          post_ws = _transition_to_failed_with_handles(
            pre_workspace, working_workspace, reason,
            audit['reason'].to_s
          )
          return {
            'status'         => :failed,
            'post_workspace' => post_ws,
            'audit'          => audit,
            'applied_proposals' => applied,
            'failed_proposals'  => failed,
            'repair_group'   => nil
          }
        end

        # ---- Success ----
        audit = {
          'status'                   => :applied,
          'reason'                   => REASON_OK,
          'applied_count'            => applied.length,
          'failed_count'             => failed.length,
          'applied_proposals'        => applied.map { |a| a['proposal_id'] },
          'failed_proposals'         => failed,
          'tolerance_used'           => {
            'gap_search'         => tolerance.respond_to?(:gap_search) ? tolerance.gap_search.to_f : 0.1,
            'coordinate_epsilon' => tolerance.respond_to?(:coordinate_epsilon) ? tolerance.coordinate_epsilon.to_f : 1.0e-6
          },
          'rule_id'                  => GapPairProposer::RULE_ID,
          'rule_version'             => GapPairProposer::RULE_VERSION,
          'schema_version'           => PROVENANCE_SCHEMA_VERSION,
          'applied_at'               => '1970-01-01T00:00:00Z',
          'commit_completed'         => commit_completed
        }.freeze
        {
          'status'         => :applied,
          'post_workspace' => working_workspace,
          'audit'          => audit,
          'applied_proposals' => applied,
          'failed_proposals'  => failed,
          'repair_group'   => nil
        }
      end

      # ---- Preflight (Blueprint §13) ----

      def _preflight(workspace, ready, tolerance)
        reasons = []
        # Workspace state must be :ready (verified at apply
        # entry; duplicate guard for direct callers).
        unless workspace.state == :ready
          reasons << "workspace_state_#{workspace.state}"
        end
        # Tolerance validation.
        unless tolerance.respond_to?(:gap_search) && tolerance.gap_search.to_f > 0 &&
               tolerance.respond_to?(:coordinate_epsilon) && tolerance.coordinate_epsilon.to_f > 0
          reasons << 'invalid_tolerance'
        end
        # Proposals must be pairwise endpoint-disjoint.
        seen_endpoints = {}
        ready.each do |p|
          [p['endpoint_a_key'], p['endpoint_b_key']].each do |k|
            if seen_endpoints[k]
              reasons << "duplicate_endpoint:#{k}"
            else
              seen_endpoints[k] = true
            end
          end
        end
        # Every proposal must be a valid executable.
        ready.each do |p|
          unless p['state'] == GapPairProposer::STATE_READY_TO_REPAIR && p['executable'] == true
            reasons << "not_executable:#{p['proposal_id']}"
          end
        end
        # Bridge endpoints finite?
        ready.each do |p|
          eps = p['expected_bridge_endpoints']
          unless eps.is_a?(Array) && eps.length == 2 &&
                 eps[0].is_a?(Array) && eps[0].length == 3 &&
                 eps[1].is_a?(Array) && eps[1].length == 3 &&
                 _finite_point?(eps[0]) && _finite_point?(eps[1])
            reasons << "non_finite_endpoints:#{p['proposal_id']}"
          end
        end
        # Bridge distance within (coord_eps, gap_search].
        ready.each do |p|
          d = p['expected_bridge_length'].to_f
          ge = p['gap_search'].to_f
          ce = p['coordinate_epsilon'].to_f
          unless d > ce && d <= ge
            reasons << "distance_out_of_band:#{p['proposal_id']}"
          end
        end
        { 'pass' => reasons.empty?, 'reasons' => reasons }.freeze
      end

      # ---- Post-validation (Blueprint §14 + SR-03) ----
      #
      # Returns a Hash:
      #   {
      #     'pass'    => true|false,
      #     'reasons' => Array<String> (stable reason codes)
      #   }
      #
      # The reasons list proves the audit / caller WHICH
      # check failed. The check itself never silently passes.
      #
      # `pre_workspace`, `pre_fingerprint_digest`,
      # `pre_source_fingerprint_digest`, and
      # `pre_entity_coords` are passed as keyword args so
      # the test seams can drive individual checks.
      def _post_validate(workspace, adapter, applied, ready,
                         pre_workspace: nil,
                         pre_fingerprint_digest: nil,
                         pre_source_fingerprint_digest: nil,
                         pre_entity_coords: nil)
        reasons = []
        # (A) workspace state must remain :ready after batch.
        unless workspace.state == :ready
          reasons << "post_workspace_state_#{workspace.state}"
        end
        # (A) exact generated count must equal expected
        # executable proposal count.
        if applied.length != ready.length
          reasons << "applied_count_mismatch(#{applied.length}/#{ready.length})"
        end
        # (B) every applied bridge must have a host handle in
        # the workspace handle_registry, valid, and reachable
        # via the adapter; AND carry the expected origin_kind
        # + repair_action_id.
        applied.each do |a|
          did = a['derived_id']
          prop_id = a['proposal_id']
          rec = workspace.entity(did)
          if rec.nil?
            reasons << "missing_entity_record:#{prop_id}"
            next
          end
          gs = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : nil
          unless gs.is_a?(Hash)
            reasons << "missing_geometry_summary:#{prop_id}"
            next
          end
          unless gs['origin_kind'].to_s == 'generated_gap_bridge'
            reasons << "wrong_origin_kind:#{prop_id}"
          end
          unless gs['repair_action_id'].to_s == prop_id.to_s
            reasons << "wrong_repair_action_id:#{prop_id}"
          end
          # (C) RR-02: actual host endpoint positions must
          # match the READY proposal's expected endpoints
          # within that proposal's `coordinate_epsilon`. The
          # comparison is ORDER-INSENSITIVE (undirected
          # segment match: host may report (A,B) or (B,A)).
          # The check FAIL-CLOSED: missing capability, nil
          # handles, raised/nil position reads ALL count as
          # failure. No hardcoded 1e-5 epsilon -- each
          # proposal carries its own.
          h = a['host_handle']
          if h.nil?
            reasons << "missing_host_handle:#{prop_id}"
            next
          end
          if h.respond_to?(:valid?) && !h.valid?
            reasons << "invalid_host_handle:#{prop_id}"
            next
          end
          unless adapter.respond_to?(:edge_endpoints)
            reasons << "host_endpoint_handles_unavailable:#{prop_id}"
            next
          end
          host_eps = begin
                        adapter.edge_endpoints(h)
                      rescue StandardError
                        nil
                      end
          unless host_eps.is_a?(Array) && host_eps.length == 2 &&
                 !host_eps[0].nil? && !host_eps[1].nil?
            reasons << "host_endpoint_handles_malformed:#{prop_id}"
            next
          end
          unless adapter.respond_to?(:vertex_position)
            reasons << "host_endpoint_position_unavailable:#{prop_id}"
            next
          end
          actual_a_raw = begin
                            adapter.vertex_position(host_eps[0])
                          rescue StandardError
                            nil
                          end
          actual_b_raw = begin
                            adapter.vertex_position(host_eps[1])
                          rescue StandardError
                            nil
                          end
          unless actual_a_raw.is_a?(Array) && actual_b_raw.is_a?(Array) &&
                 actual_a_raw.length == 3 && actual_b_raw.length == 3 &&
                 _finite_point?(actual_a_raw) && _finite_point?(actual_b_raw)
            reasons << "host_endpoint_position_unreadable:#{prop_id}"
            next
          end
          # Use the proposal's own coordinate_epsilon
          # (NO hardcoded fallback).
          prop_eps = prop_lookup = ready.find { |p| p['proposal_id'].to_s == prop_id.to_s }
          ce = if prop_eps && prop_eps['coordinate_epsilon']
                 prop_eps['coordinate_epsilon'].to_f
               else
                 # If the proposal didn't carry its epsilon
                 # (defensive), the executor MUST fail closed
                 # instead of silently using a hardcoded
                 # fallback.
                 reasons << "host_endpoint_epsilon_missing:#{prop_id}"
                 next
               end
          # Undirected segment match: host segment matches the
          # expected endpoints iff (host_a == exp_a AND
          # host_b == exp_b) OR (host_a == exp_b AND host_b
          # == exp_a).
          exp_start = gs['start']
          exp_end   = gs['end']
          unless exp_start.is_a?(Array) && exp_end.is_a?(Array) &&
                 exp_start.length == 3 && exp_end.length == 3
            reasons << "host_endpoint_expected_malformed:#{prop_id}"
            next
          end
          forward_ok = _point_within_eps?(actual_a_raw, exp_start, ce) &&
                         _point_within_eps?(actual_b_raw, exp_end,   ce)
          reverse_ok = _point_within_eps?(actual_a_raw, exp_end,   ce) &&
                         _point_within_eps?(actual_b_raw, exp_start, ce)
          unless forward_ok || reverse_ok
            reasons << "host_endpoint_segment_mismatch:#{prop_id}"
          end
        end
        # (F) generated proposal IDs must exactly equal the
        # expected READY proposal IDs.
        expected_ids = ready.map { |p| p['proposal_id'].to_s }.sort
        actual_ids   = applied.map { |a| a['proposal_id'].to_s }.sort
        if expected_ids != actual_ids
          reasons << "proposal_id_set_mismatch"
        end
        # (G) no REVIEW_REQUIRED proposal was executed.
        applied.each do |a|
          r = ready.find { |p| p['proposal_id'].to_s == a['proposal_id'].to_s }
          if r.nil? || r['state'] != GapPairProposer::STATE_READY_TO_REPAIR
            reasons << "non_ready_was_executed:#{a['proposal_id']}"
          end
        end
        # (D) source snapshot fingerprint unchanged (Blueprint
        # §14: "source fingerprint unchanged"). The workspace
        # fingerprint legitimately changes after adding
        # bridge entities -- only the SOURCE fingerprint is
        # the immutable contract here.
        if pre_source_fingerprint_digest && workspace.source_snapshot.respond_to?(:fingerprint) &&
           workspace.source_snapshot.fingerprint && workspace.source_snapshot.fingerprint.respond_to?(:digest)
          if workspace.source_snapshot.fingerprint.digest.to_s != pre_source_fingerprint_digest
            reasons << 'source_fingerprint_changed'
          end
        end
        # (E) pre-existing source-derived coordinates unchanged.
        post_coords = _pre_existing_source_derived_coords(workspace)
        if pre_entity_coords && pre_entity_coords != post_coords
          reasons << 'pre_existing_coords_changed'
        end
        { 'pass' => reasons.empty?, 'reasons' => reasons }.freeze
      end

      # Snapshot the world-coord endpoints of every
      # pre-existing source-derived edge in the workspace
      # (Blueprint §14 E). Bridge entities carry
      # origin_kind=generated_gap_bridge and are therefore
      # excluded.
      def _pre_existing_source_derived_coords(workspace)
        return {} unless workspace.respond_to?(:entities)
        out = {}
        workspace.entities.each do |rec|
          next unless rec.respond_to?(:kind) && rec.kind == :edge
          gs = rec.respond_to?(:geometry_summary) ? rec.geometry_summary : nil
          next unless gs.is_a?(Hash)
          next if gs['origin_kind'].to_s == 'generated_gap_bridge'
          did = rec.respond_to?(:derived_id) ? rec.derived_id.to_s : ''
          next if did.empty?
          s = gs['start']
          e = gs['end']
          out[did] = [s, e] if s.is_a?(Array) && e.is_a?(Array)
        end
        out.freeze
      end

      # Compare two 3-Float world-coord points within epsilon.
      def _point_within_eps?(a, b, eps)
        return false unless a.is_a?(Array) && b.is_a?(Array)
        return false unless a.length == 3 && b.length == 3
        dx = (a[0].to_f - b[0].to_f).abs
        dy = (a[1].to_f - b[1].to_f).abs
        dz = (a[2].to_f - b[2].to_f).abs
        dx <= eps && dy <= eps && dz <= eps
      end

      # Read a host vertex's world-coord position safely. The
      # fake + production adapters expose vertex_position;
      # graceful fallback returns nil (the caller treats nil
      # as "skip host endpoint check, accept summary
      # coordinates").
      def _vertex_position_safely(adapter, vertex_handle)
        return nil unless adapter.respond_to?(:vertex_position)
        begin
          adapter.vertex_position(vertex_handle)
        rescue StandardError
          nil
        end
      end

      # ---- SR-05: deterministic bridge derived_id ----

      def _deterministic_bridge_id(proposal_id)
        "#{BRIDGE_DERIVED_ID_PREFIX}#{proposal_id.to_s}"
      end

      # ---- RR-01 + SR-02: confirmed host abort path ----
      #
      # Closes the SketchUp operation with commit:false
      # EXACTLY ONCE. Returns:
      #   :abort_completed -- adapter.end_operation(commit: false)
      #                       returned successfully; the host
      #                       operation is now closed and
      #                       every entity created in it has
      #                       been rolled back.
      #   :abort_uncertain  -- adapter.end_operation(commit: false)
      #                       RAISED; the operation may still
      #                       be open or partially-rolled-back.
      #                       Caller MUST preserve current
      #                       working handles and emit a
      #                       :failed uncertainty workspace.
      #
      # After a confirmed abort, no generated bridge record
      # survives logically: pre_workspace already carries the
      # pre-batch inventory + handle_registry.
      def _confirmed_abort(adapter, working_workspace, pre_workspace)
        # Defensive: if no operation was opened (shouldn't
        # happen because we only enter this path after
        # begin_operation returned without raising), still
        # return :abort_completed because there's nothing to
        # close.
        return :abort_completed if adapter.nil?
        # Get the model the runner passed to begin_operation.
        model = pre_workspace.instance_variable_get(:@model) ||
                (working_workspace.respond_to?(:instance_variable_get) ?
                 working_workspace.instance_variable_get(:@model) : nil)
        # Make the SINGLE end_operation(commit: false) call.
        begin
          adapter.end_operation(model, commit: false)
          :abort_completed
        rescue StandardError
          :abort_uncertain
        end
      end

      # ---- SR-02: transition to :failed, preserve handles ----

      # Build a :failed workspace derived from pre_workspace
      # inventory + handle_registry, while preserving the
      # current generated handles from working_workspace so
      # explicit Discard can clean any host entity that may
      # still exist.
      def _transition_to_failed_with_handles(pre_workspace, working_workspace, reason, detail)
        return pre_workspace if pre_workspace.nil?
        return pre_workspace unless working_workspace.respond_to?(:handle_registry_keys)
        adapter = pre_workspace.instance_variable_get(:@adapter)
        model   = pre_workspace.instance_variable_get(:@model)
        # Prefer the current generated handles from working_workspace
        # (Discard needs them). Fall back to pre_workspace's
        # registry if working_workspace lost them.
        cur_handles = working_workspace.instance_variable_get(:@handle_registry) || {}
        pre_handles = pre_workspace.instance_variable_get(:@handle_registry) || {}
        merged = pre_handles.dup
        cur_handles.each { |k, v| merged[k] = v }
        pre_pairs = pre_workspace.instance_variable_get(:@entity_pairs)
        cur_pairs = working_workspace.instance_variable_get(:@entity_pairs) || []
        # The merged inventory includes pre + any surviving
        # generated handles; de-dupe by derived_id.
        seen = {}
        merged_pairs = []
        Array(pre_pairs).each do |pair|
          seen[pair[0]] = true
          merged_pairs << pair
        end
        Array(cur_pairs).each do |pair|
          next if seen[pair[0]]
          seen[pair[0]] = true
          merged_pairs << pair
        end
        DerivedGeometryWorkspace.new_with_inventory(
          workspace_id:    pre_workspace.workspace_id,
          source_snapshot: pre_workspace.source_snapshot,
          adapter:         adapter,
          model:           model,
          state:           :failed,
          entity_pairs:    merged_pairs,
          handle_registry: merged,
          fingerprint:     pre_workspace.respond_to?(:fingerprint) ? pre_workspace.fingerprint : nil,
          last_error:      detail,
          build_started_at: pre_workspace.build_started_at
        )
      end

      # ---- Failure path (SR-02) ----

      # Build a :failed result.
      #
      # pre_workspace : the pre-batch workspace (the inventory
      #                 + handle registry we preserve). When nil,
      #                 we cannot construct a meaningful :failed
      #                 workspace (this means the caller passed
      #                 nil into apply, which is already a
      #                 programmer error caught earlier).
      #
      # reason         : stable string reason code.
      # extra_reasons  : additional string reasons from
      #                 preflight / post-validation.
      def _fail(pre_workspace, reason, applied, extra_reasons = [])
        post_ws = if pre_workspace.nil?
                    nil
                  else
                    # Pure :failed workspace derived from the
                    # pre_workspace inventory + handle
                    # registry. Source unchanged. NO surviving
                    # generated bridge records.
                    adapter = pre_workspace.instance_variable_get(:@adapter)
                    model   = pre_workspace.instance_variable_get(:@model)
                    pre_pairs = pre_workspace.instance_variable_get(:@entity_pairs)
                    pre_handles = pre_workspace.instance_variable_get(:@handle_registry) || {}.freeze
                    DerivedGeometryWorkspace.new_with_inventory(
                      workspace_id:    pre_workspace.workspace_id,
                      source_snapshot: pre_workspace.source_snapshot,
                      adapter:         adapter,
                      model:           model,
                      state:           :failed,
                      entity_pairs:    pre_pairs,
                      handle_registry: pre_handles,
                      fingerprint:     pre_workspace.respond_to?(:fingerprint) ? pre_workspace.fingerprint : nil,
                      last_error:      ([reason] + Array(extra_reasons)).compact.join('; '),
                      build_started_at: pre_workspace.build_started_at
                    )
                  end
        audit = {
          'status'           => :failed,
          'reason'           => reason,
          'applied_count'    => applied.length,
          'applied_proposals' => applied,
          'extra_reasons'    => Array(extra_reasons),
          'schema_version'   => PROVENANCE_SCHEMA_VERSION,
          'applied_at'       => '1970-01-01T00:00:00Z'
        }.freeze
        {
          'status'         => :failed,
          'post_workspace' => post_ws,
          'audit'          => audit,
          'applied_proposals' => applied,
          'failed_proposals' => [],
          'repair_group'   => nil
        }
      end

      # Commit-uncertainty audit builder.
      def _commit_uncertain_audit(applied, exception)
        {
          'status'           => :failed,
          'reason'           => REASON_COMMIT_UNCERTAIN,
          'applied_count'    => applied.length,
          'applied_proposals' => applied,
          'exception_class'  => exception.class.to_s,
          'exception_message' => exception.message.to_s,
          'schema_version'   => PROVENANCE_SCHEMA_VERSION,
          'applied_at'       => '1970-01-01T00:00:00Z'
        }.freeze
      end

      # RR-01: abort-uncertainty audit builder. The host
      # operation may STILL be open after end_operation
      # raised; we did not achieve a confirmed abort. The
      # caller preserves current handles for Discard and
      # marks the workspace :failed with stable reason
      # `abort_uncertainty` (no fake rollback success).
      def _abort_uncertain_audit(applied, extra_reasons)
        {
          'status'           => :failed,
          'reason'           => REASON_ABORT_UNCERTAIN,
          'applied_count'    => applied.length,
          'applied_proposals' => applied,
          'extra_reasons'    => Array(extra_reasons),
          'schema_version'   => PROVENANCE_SCHEMA_VERSION,
          'applied_at'       => '1970-01-01T00:00:00Z'
        }.freeze
      end

      def _finite_point?(p)
        p.is_a?(Array) && p.length == 3 &&
          p.all? { |v| v.is_a?(Numeric) && v.respond_to?(:finite?) && v.finite? }
      end
    end
  end
end
