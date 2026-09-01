#
# extension/dialog_runner.rb — HtmlDialog lifecycle.
#
# Per CodeX Round 018:
#   - set_file with absolute path (NOT set_html with embedded asset).
#   - add_action_callback with BLOCKS (NOT method(:name)).
#   - ready handshake: JS calls window.SUAIP.ready() after
#     DOMContentLoaded; Ruby then pushes data via execute_script.
#   - set_on_closed releases the controller (GC the dialog).
#   - show(result, model) propagates the model to the controller so
#     the Locate action can resolve against the real model.
#   - The dialog reference is held in Loader.@live_dialog so the
#     window is not GC'd; Loaderr.release_dialog! is called via
#     set_on_closed.
#

require 'json'
require 'time'
require_relative 'dialog_controller'
require_relative 'ui_bridge'
require_relative 'issue_locator'
require_relative 'core/working_mode_runner'
require_relative 'core/source_snapshot'
# V1.4 CodeX V14-RUNTIME-BLOCK-002 (2026-08-22, real-SU2020 Owner
# evidence): the dialog_runner references the production
# adapter + fake adapter directly in `_adapter_for`. In a real
# SU cold-start these constants MUST be loaded by the
# production load chain -- relying on a sibling test file to
# have pre-loaded them caused a NameError on the user's
# first Prepare click. Both files are now explicitly required
# so the load order is deterministic regardless of which
# test files ran previously.
require_relative 'core/derived_workspace_adapter'
require_relative 'compatibility/su_derived_workspace_adapter'

module SUAnalysis
  module Extension
    module DialogRunner
      module_function

      # V1.5 Phase 1 production accessor (per CodeX V1.5 BLOCK-004
      # recheck #2): module-level handle to the currently-open
      # dialog's controller. The Owner uses this in Ruby Console
      # commands to access the AnalysisResult / registry for the
      # V15-4 mid-action-failure test (instead of relying on a
      # private global like `$su_ai_plugin_dialog_controller`).
      # Only ONE dialog is open at a time (per Loader.keep_dialog!).
      # The accessor is reset when the dialog closes.
      def current_controller
        @@current_controller
      end

      def set_current_controller(controller)
        @@current_controller = controller
      end

      def clear_current_controller
        @@current_controller = nil
      end

      # Show the HtmlDialog for one AnalysisResult.
      # Returns the dialog instance (or nil in tests).
      def show(result, model: nil)
        return nil unless result
        return nil unless defined?(UI::HtmlDialog)
        return nil unless UI::HtmlDialog.respond_to?(:new)
        controller = DialogController.new(result, model: model)
        dialog = UI::HtmlDialog.new(
          dialog_title:    'CAD 检查结果',
          preferences_key: 'SU-AI-Plugin.cad_analyzer.v1',
          width:           720,
          height:          600,
          left:            100,
          top:             100,
          resizable:       true
        )
        # Absolute path for relative CSS/JS resolution.
        index_path = File.expand_path('html/index.html', __dir__)
        dialog.set_file(index_path)
        # V1.5 Phase 1 (BLOCK-004 recheck #2): publish the controller
        # for Owner Ruby Console access. Cleared in on_close.
        set_current_controller(controller)
        # Callbacks as BLOCKS (real SketchUp API). Keep references
        # alive via closures over controller/dialog so callbacks fire
        # on the correct controller instance.
        dialog.add_action_callback('ready')   { |_ctx| push_data(dialog, controller) }
        dialog.add_action_callback('locate')  { |_ctx, issue_id| on_locate(dialog, controller, issue_id) }
        dialog.add_action_callback('close')   { |_ctx| on_close(dialog, controller) }
        # V1.4 (per directive 030, Stage 4): working-mode plumbing.
        # The Prepare / Discard / Rebuild actions operate ONLY on
        # the runner-owned workspace; the source is NEVER touched.
        # These callbacks re-push the payload so the UI updates
        # after each action.
        dialog.add_action_callback('prepare_workspace') do |_ctx|
          on_prepare_workspace(dialog, controller)
        end
        dialog.add_action_callback('discard_workspace') do |_ctx|
          on_discard_workspace(dialog, controller)
        end
        dialog.add_action_callback('rebuild_workspace') do |_ctx|
          on_rebuild_workspace(dialog, controller)
        end
        # V1.6 Planar Normalization / Z Policy: callbacks
        # for the "Planar normalization" row in Working Mode.
        # Two-step user flow:
        #   - compute_planar_normalization  -> preview
        #   - apply_planar_normalization    -> explicit apply
        # Each handler delegates to WorkingModeRunner and
        # re-pushes the payload so the UI updates after each
        # action. Source CAD is NEVER touched.
        dialog.add_action_callback('compute_planar_normalization') do |_ctx|
          on_compute_planar_normalization(dialog, controller)
        end
        dialog.add_action_callback('apply_planar_normalization') do |_ctx|
          on_apply_planar_normalization(dialog, controller)
        end
        # set_on_closed releases the Loader-side cache so the window
        # can be GC'd after the user closes it.
        dialog.set_on_closed do
          on_close(dialog, controller)
        end
        controller.bind(dialog, model)
        # Hold the live dialog reference for the dialog lifetime.
        # Per CodeX Round 018 BLOCK-006 + official SketchUp guidance.
        Loader.keep_dialog!(dialog)
        dialog.show
        dialog
      end

      # ---- internals ------------------------------------------------------

      # Push the serialized AnalysisResult to the JS layer.
      # Uses JSON.generate + execute_script with a wrapped, fixed
      # function name. Never interpolates user text into executable JS.
      def push_data(dialog, controller)
        payload = UIBridge.as_html_data(controller.result)
        json = JSON.generate(payload)
        dialog.execute_script("window.SUAIP.render(#{json})")
      end

      def on_locate(dialog, controller, issue_id)
        return unless issue_id.is_a?(String)
        result = controller.locate(issue_id)
        return unless result
        if result[:status] == :unresolved
          msg = JSON.generate("source no longer available for: #{issue_id}")
          dialog.execute_script("window.SUAIP.toast(#{msg})")
          # V1.4 V14-RUNTIME-BLOCK-004 (2026-08-24, real SU2020
          # narrow test): $stdout IS Sketchup::Console in SU2020
          # and #puts is private. Direct $stdout.puts(...) raises
          # NoMethodError. Use _safe_log (warn) which is
          # best-effort and never propagates.
          _safe_log("[SU-AI-Plugin] locate_issue: #{result[:diagnostics].last || 'unresolved'}")
        end
      end

      # V1.4 (per directive 030, Stage 4): handlers for the
      # dialog's Working Mode section. Each handler delegates
      # to WorkingModeRunner (pure-data layer in core/) and
      # re-pushes the payload so the UI updates.
      #
      # V1.4 CodeX V14-RUNTIME-BLOCK-002 (2026-08-22):
      # error visibility contract. When a handler raises any
      # StandardError, the error MUST be:
      #   - logged to $stderr with a BLOCK prefix;
      #   - surfaced to the UI as a toast (so the user is not
      #     left wondering why a button click did nothing);
      #   - NEVER swallowed silently (the previous code
      #     surfaced only the "no source snapshot" path,
      #     leaving ALL other failures invisible).
      def on_prepare_workspace(dialog, controller)
        _safe_invoke(dialog, controller, 'prepare_workspace') do
          src = _source_snapshot_for(controller)
          if src.nil?
            _toast(dialog,
                   'Working Mode: no source snapshot available for this dialog.')
            next
          end
          SUAnalysis::Core::WorkingModeRunner.prepare(
            source:  src,
            adapter: _adapter_for(_host_safety_check: true),
            model:   _resolve_model_for(controller)
          )
          # V1.5 Phase 1 production call chain (CodeX BLOCK-002,
          # 2026-08-25): after Prepare builds the workspace, run
          # the duplicate-repair batch against the IssueRegistry
          # carried by the controller's AnalysisResult. The
          # IssueRegistry already contains the existing
          # duplicate_edge_candidate evidence from the
          # DuplicateDetector (no new analyzer). The batch is
          # atomic -- mid-batch failure rolls back the whole
          # batch via the adapter's end_operation(commit: false).
          ar = controller.result if controller
          registry = (ar && ar.respond_to?(:registry)) ? ar.registry : nil
          if registry
            SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(
              registry: registry
            )
          end
        end
      end

      def on_discard_workspace(dialog, controller)
        _safe_invoke(dialog, controller, 'discard_workspace') do
          SUAnalysis::Core::WorkingModeRunner.discard
        end
      end

      def on_rebuild_workspace(dialog, controller)
        _safe_invoke(dialog, controller, 'rebuild_workspace') do
          src = _source_snapshot_for(controller)
          if src.nil?
            _toast(dialog,
                   'Working Mode: no source snapshot available for this dialog.')
            next
          end
          SUAnalysis::Core::WorkingModeRunner.rebuild
          # V1.5 Phase 1 production call chain (CodeX BLOCK-002):
          # Rebuild must RE-RUN the duplicate-repair batch with
          # the SAME captured IssueRegistry (deterministic
          # rebuild per master plan §19.1). The registry is
          # rebuilt from the same source, so the post-rebuild
          # post-state matches the prior post-repair state.
          ar = controller.result if controller
          registry = (ar && ar.respond_to?(:registry)) ? ar.registry : nil
          if registry
            SUAnalysis::Core::WorkingModeRunner.run_duplicate_repair_batch(
              registry: registry
            )
          end
        end
      end

      # V1.6 Planar Normalization / Z Policy: handler for
      # `compute_planar_normalization`. Computes (without
      # mutating) the deterministic safe-batch proposal on the
      # CURRENT workspace and re-pushes the payload so the UI
      # updates the "Planar normalization" row. Per Blueprint
      # §7 the state can be NO_CANDIDATE / READY_TO_NORMALIZE
      # / REVIEW_REQUIRED / APPLIED / FAILED. Source CAD is
      # NEVER touched.
      def on_compute_planar_normalization(dialog, controller)
        _safe_invoke(dialog, controller, 'compute_planar_normalization') do
          SUAnalysis::Core::WorkingModeRunner.compute_planar_normalization
        end
      end

      # V1.6 Planar Normalization / Z Policy: handler for
      # `apply_planar_normalization`. This is the SOLE
      # user-triggered action that mutates derived geometry.
      # Per Blueprint §1.4: "User performs one explicit batch
      # approval: Apply Safe Normalization." Source CAD is
      # NEVER touched; only derived vertices move; XY is
      # preserved; outliers remain unchanged; the existing
      # Discard / Rebuild / host Undo safety remains.
      def on_apply_planar_normalization(dialog, controller)
        _safe_invoke(dialog, controller, 'apply_planar_normalization') do
          SUAnalysis::Core::WorkingModeRunner.apply_planar_normalization
        end
      end

      # The SourceSnapshot is held by the controller's analysis
      # result via the snapshot bridge. For V1.4 plumbing, we
      # accept the controller's analysis_result's underlying
      # geometry_snapshot; the V1.4-stage 4 wiring uses the
      # workspace adapter path. The adapter is the production
      # adapter when Sketchup is available, a nil adapter that
      # the runner rejects (-> :failed) when not.
      #
      # V1.4 CodeX BLOCK fix (Stage 4): this method MUST build a
      # SourceSnapshot from the REAL GeometrySnapshot carried by
      # the AnalysisResult (not synthetic plumbing). The captured
      # source has:
      #   - the real Edges + Faces + Layers from the user's
      #     selection (built by PreflightRunner.build_snapshot);
      #   - per-record SourceReference persistent_id_path /
      #     instance_path / structural_depth / pid_path_complete
      #     (per directive gate A: identity quality preserved);
      #   - the real selection scope (one entry per real selected
      #     entity, with persistent_id_path + instance_path);
      #   - the real active-edit transform context (the active
      #     path's transform, not "identity");
      #   - the real unit + coordinate_origin policy (inches +
      #     raw).
      # If the AnalysisResult was built by a V1.0/V1.1/V1.2/V1.3
      # caller that did NOT populate geometry_snapshot /
      # selection_entities / active_edit_facts, we fall back to
      # the plumbing summary; this preserves backward compat
      # (existing V1.0/V1.3 tests still pass) while allowing the
      # V1.4 dialog_runner path to use REAL source geometry.
      def _source_snapshot_for(controller)
        ar = controller.result if controller
        return nil if ar.nil?
        # Prefer the V1.4 AnalysisResult real source geometry.
        geom = ar.respond_to?(:geometry_snapshot) ? ar.geometry_snapshot : nil
        if geom
          # V1.4 V14-STAGE-BLOCK-001 (2026-08-24, CodeX V1.4 Stage Review
          # recheck): pass the controller's model through to
          # _source_snapshot_from_real_geometry. The previous
          # code did NOT pass the model -- _host_for(ar) returned
          # nil, which left the production path unable to read
          # model.edit_transform and forced the factory to
          # write the identity marker.
          model = (controller.respond_to?(:model) ? controller.model : nil)
          return _source_snapshot_from_real_geometry(ar, geom, model: model)
        end
        # Fallback: plumbing-only SourceSnapshot (V1.0/V1.1/V1.2/
        # V1.3 AnalysisResult callers).
        _plumbing_source_snapshot(ar)
      end

      # V1.4 CodeX BLOCK fix (Stage 4): build a SourceSnapshot
      # from the REAL GeometrySnapshot carried by the
      # AnalysisResult.
      #
      # V1.4 V14-STAGE-BLOCK-001 (2026-08-24, CodeX V1.4 Stage Review
      # recheck): the controller's model is REQUIRED here. The
      # previous code passed nil for the model (via _host_for(ar)
      # which always returned nil), which made it impossible to
      # read the real edit_transform from the host. AnalyzersRunner
      # stores active_edit_facts under the production keys
      # ('transform', 'pid_path', 'pid_path_complete',
      # 'raw_with_nil'); the production 'transform' value is a
      # LIVE Sketchup::Geom::Transformation object. We must convert
      # that live object into a 16-float Array (pure data) and
      # keep the snapshot free of any live SketchUp objects.
      def _source_snapshot_from_real_geometry(ar, geom, model: nil)
        cfg = ar.respond_to?(:config) && ar.config ? ar.config : nil
        cfg = SUAnalysis::Core::AnalysisConfig.new if cfg.nil?
        # Build the SourceFingerprint from the real GeometrySnapshot
        # + selection_entities + the SU host (model) so the
        # fingerprint matches what V1.0..V1.3 saw in the dialog
        # summary.
        sel_entities = ar.respond_to?(:selection_entities) ? ar.selection_entities : []
        active_facts = ar.respond_to?(:active_edit_facts) ? ar.active_edit_facts : {}
        fingerprint = SUAnalysis::Core::SourceFingerprint.from_snapshot(
          geom,
          selection: sel_entities,
          host: model
        )
        # Build the ExecutionConfigSnapshot from the live config
        # + the analysis's rule-set digest (consistent with
        # V1.0..V1.3 wiring).
        rule_set_digest = (ar.respond_to?(:snapshot_lookup) && ar.snapshot_lookup && ar.snapshot_lookup[:rule_set_digest]) ||
                          'plumbing.rule-set'
        ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
          cfg,
          rule_set_digest: rule_set_digest,
          source_snapshot_schema_version: '1'
        )
        # Selection scope: one entry per real selected entity,
        # with persistent_id_path / instance_path (per directive
        # "selection-scope identity").
        sel_scope = _selection_scope_for(sel_entities, geom)
        # V1.4 V14-STAGE-BLOCK-001 (2026-08-24, CodeX V1.4 Stage Review
        # recheck): the REAL active-edit transform MUST flow through
        # to SourceSnapshot.transform_context. We extract the
        # 16-float transform from the host's edit_transform
        # (via .to_a) AND/OR from the AnalysisResult's
        # active_edit_facts Hash (production keys: 'transform',
        # 'pid_path', 'pid_path_complete', 'raw_with_nil'). The
        # 'transform' value is a LIVE Sketchup::Geom::Transformation
        # object -- we MUST convert it to pure data (16-float
        # Array). Pure data only -- NO live Sketchup objects in
        # the snapshot.
        transform_context = _resolve_transform_context(
          active_facts: active_facts,
          model:        model
        )
        # Use the canonical from_geometry_snapshot factory to
        # build a deeply-frozen, fingerprintable SourceSnapshot.
        SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
          geom,
          selection: sel_scope,
          host: model,
          execution_config: ec,
          rule_set_digest: rule_set_digest,
          snapshot_id: "v14-#{rand(2**32)}",
          captured_at: Time.now.utc.iso8601,
          transform_context: transform_context
        )
      end

      # V1.4 V14-STAGE-BLOCK-001 (2026-08-24, CodeX V1.4 Stage Review
      # recheck): resolve the REAL active-edit transform context
      # as pure data. Reads the AnalyzersRunner-style
      # active_edit_facts Hash (production keys: 'transform',
      # 'pid_path', 'pid_path_complete', 'raw_with_nil') AND/OR
      # the host model's edit_transform. The 'transform' value
      # in active_edit_facts is a LIVE Sketchup::Geom::Transformation
      # object -- we MUST convert it to pure data (16-float Array)
      # via .to_a. The result is a frozen Hash carrying:
      #   - active_edit_transform (Array of 16 finite Floats)
      #   - active_edit_inverse   (Array of 16 finite Floats, when present)
      #   - active_edit_path      (Array of Integer / nil slots)
      #   - pid_path_complete     (Boolean -- true iff no slot is nil)
      #   - raw_with_nil          (Array of Integer / nil slots -- the
      #                            full active_path with nil slots)
      #   - active_edit_seed      ('real' String when a real transform
      #                            is supplied; otherwise the identity
      #                            marker fallback)
      # When the host has no active edit AND no edit_transform
      # AND no AnalyzersRunner facts, returns nil (factory writes
      # the identity marker). NEVER includes a live SketchUp
      # object in the returned Hash.
      def _resolve_transform_context(active_facts:, model:)
        facts = active_facts.is_a?(Hash) ? active_facts : {}
        # Normalize the keys: AnalyzersRunner stores String keys
        # in the AnalysisResult; the dialog_runner's helper
        # functions may pass Symbol keys. Coerce everything to
        # String for the normalize pass.
        facts = facts.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
        # Build a candidate Hash from the production fields.
        ctx = {}
        # 'transform' may be a LIVE Sketchup::Geom::Transformation
        # (production) OR a 16-float Array (already-converted by
        # a host adapter in tests). Handle both shapes.
        #
        # We keep `t_raw` (the original value, possibly a live
        # Sketchup object) so we can call .inverse on it for
        # the inverse extraction. The 16-float array is
        # derived from `t_raw` via _coerce_to_16floats.
        t_raw = facts['transform']
        t_raw_model = nil
        if t_raw.nil?
          # No transform in facts -- try the model's edit_transform.
          # The model's edit_transform may be a live
          # Sketchup::Geom::Transformation (real SU) or a plain
          # Object with .to_a (test env). The fallback path
          # needs to preserve the original Object so we can
          # call .inverse on it for the inverse extraction.
          t_raw_model = model
          if model && model.respond_to?(:edit_transform)
            et = model.edit_transform
            t_raw = et if et
          end
        end
        if t_raw
          arr = _coerce_to_16floats(t_raw)
          if arr
            ctx['active_edit_transform'] = arr
          end
        end
        # 'transform.inverse' (production) or 'active_edit_inverse'
        # (already-converted) -- whichever is present.
        if t_raw && t_raw.respond_to?(:inverse) && t_raw.inverse.respond_to?(:to_a)
          inv = _coerce_to_16floats(t_raw.inverse.to_a)
          if inv
            ctx['active_edit_inverse'] = inv
          end
        end
        inv_direct = facts['active_edit_inverse']
        if inv_direct && !ctx.key?('active_edit_inverse')
          arr = _coerce_to_16floats(inv_direct)
          if arr
            ctx['active_edit_inverse'] = arr
          end
        end
        # 'pid_path' (production: Array of Integers) AND/OR
        # 'active_edit_path' (already-coerced).
        if facts['pid_path'].is_a?(Array)
          ctx['active_edit_path'] = facts['pid_path']
        elsif facts['active_edit_path'].is_a?(Array)
          ctx['active_edit_path'] = facts['active_edit_path']
        end
        # 'pid_path_complete' (production: Boolean) AND/OR
        # 'pid_path_complete' (already-coerced).
        if [true, false].include?(facts['pid_path_complete'])
          ctx['pid_path_complete'] = facts['pid_path_complete']
        end
        # 'raw_with_nil' (production: Array of Integer / nil slots).
        if facts['raw_with_nil'].is_a?(Array)
          ctx['raw_with_nil'] = facts['raw_with_nil']
        end
        # 'structural_depth' (production: Integer).
        if facts['structural_depth'].is_a?(Integer)
          ctx['structural_depth'] = facts['structural_depth']
        end
        # V1.4 V14-STAGE-BLOCK-001 NIT fix (2026-08-24, CodeX recheck
        # #2): when no transform is supplied (root layer, no
        # active edit) but other production facts are present
        # (pid_path / pid_path_complete / raw_with_nil /
        # structural_depth), the context MUST carry the
        # explicit 'identity' seed marker so downstream
        # rebuild / V1.5+ tools can distinguish "no active
        # edit" from "real active edit". When a real
        # transform IS supplied, the seed is 'real'.
        if ctx.key?('active_edit_transform') || ctx.key?('active_edit_inverse')
          ctx['active_edit_seed'] = 'real'
        elsif !ctx.key?('active_edit_seed')
          ctx['active_edit_seed'] = 'identity'
        end
        # When we have NO production facts AND no host
        # edit_transform, return nil (factory writes the
        # identity marker).
        return nil if ctx.empty?
        SUAnalysis::Core::SourceSnapshot.normalize_transform_context(ctx)
      end

      # Coerce a SketchUp Geom::Transformation#to_a result
      # (either a flat 16-float Array or a 4x4 nested Array)
      # to the canonical flat Array of 16 finite Floats.
      def _coerce_to_16floats(arr)
        return nil if arr.nil?
        # When arr is a live Sketchup::Geom::Transformation
        # (or any object that responds to .to_a returning one
        # of the canonical shapes), extract the 16-float Array
        # via .to_a FIRST, then validate the canonical shape.
        # This is the production path: AnalyzersRunner stores
        # the live transform under active_edit_facts['transform'];
        # the snapshot MUST contain pure data (NOT a live
        # Sketchup object).
        if arr.respond_to?(:to_a) && !arr.is_a?(Array)
          arr = arr.to_a
        end
        if arr.is_a?(Array) && arr.length == 16 &&
               arr.all? { |v| v.is_a?(Numeric) }
          return arr.map { |v| v.to_f }
        end
        if arr.is_a?(Array) && arr.length == 4 &&
               arr.all? { |r| r.is_a?(Array) && r.length == 4 && r.all? { |v| v.is_a?(Numeric) } }
          flat = []
          arr.each { |row| row.each { |v| flat << v.to_f } }
          return flat
        end
        nil
      end

      # Build a SourceSnapshot from the plumbing summary
      # (PreflightReport scalar facts). Used as the fallback
      # path for V1.0/V1.1/V1.2/V1.3 callers that did not
      # populate the V1.4 fields on AnalysisResult.
      def _plumbing_source_snapshot(ar)
        cfg = ar.respond_to?(:config) && ar.config ? ar.config : nil
        cfg = SUAnalysis::Core::AnalysisConfig.new if cfg.nil?
        ec = SUAnalysis::Core::ExecutionConfigSnapshot.from_live_config(
          cfg,
          rule_set_digest: 'plumbing.rule-set',
          source_snapshot_schema_version: '1'
        )
        pf = ar.respond_to?(:preflight) ? ar.preflight : nil
        fp = SUAnalysis::Core::SourceFingerprint.new(
          edge_count: pf && pf.respond_to?(:edge_count) ? pf.edge_count : 0,
          face_count: pf && pf.respond_to?(:face_count) ? pf.face_count : 0,
          layer_count: pf && pf.respond_to?(:layer_distribution) ? pf.layer_distribution.keys.length : 0
        )
        sel_scope = []
        if ar.respond_to?(:selection_type)
          sel_scope << { kind: ar.selection_type.to_s, persistent_id_path: [], instance_path: [], layer: nil }
        end
        SUAnalysis::Core::SourceSnapshot.new(
          snapshot_id:       "plumbing-snap-#{rand(2**32)}",
          selection_scope:   sel_scope,
          edges:             [],
          faces:             [],
          layers:            [],
          vertex_records:    [],
          unit:              'inches',
          coordinate_origin: 'raw',
          transform_context: { 'plumbing' => 'preflight-scalar-only' },
          execution_config:  ec,
          fingerprint:       fp
        )
      end

      # Build the selection_scope entries from the real
      # selection entities. Per directive: each entry has
      # {kind:, persistent_id_path:, instance_path:, layer:}
      # so the rebuild contract can preserve occurrence
      # identity. We read the SourceReference for each
      # selected entity (Edge / Face / Group / Component).
      def _selection_scope_for(sel_entities, geom)
        sel_scope = []
        Array(sel_entities).each do |ent|
          kind = _typename_of(ent)
          layer = nil
          pid_path = []
          ipath = []
          if ent.respond_to?(:persistent_id) && ent.persistent_id
            pid_path = [ent.persistent_id]
          end
          if ent.respond_to?(:layer) && ent.layer
            layer = (ent.layer.respond_to?(:name) ? ent.layer.name : ent.layer).to_s
          end
          # Some SketchUp entities expose a definition; capture
          # its persistent_id as the second hop if available.
          if ent.respond_to?(:definition) && ent.definition && ent.definition.respond_to?(:persistent_id) && ent.definition.persistent_id
            pid_path = pid_path + [ent.definition.persistent_id]
          end
          sel_scope << {
            kind:               kind,
            persistent_id_path: pid_path,
            instance_path:      ipath,
            layer:              layer
          }
        end
        sel_scope
      end

      def _typename_of(entity)
        return 'unknown' if entity.nil?
        if entity.respond_to?(:typename)
          entity.typename.to_s.downcase
        else
          entity.class.name.to_s.split('::').last.to_s.downcase
        end
      end

      # Build a Hash representation of the real active-edit
      # transform context. Per directive gate A: "world/local
      # conversion or unit handling is uncertain" -- the V1.4
      # plumbing path MUST record the active edit transform
      # the rebuild uses, NOT a synthetic 'identity'.
      def _transform_context_for(active_facts)
        ctx = {}
        if active_facts.is_a?(Hash) && !active_facts.empty?
          # String-keyed (UI bridge convention) or Symbol-keyed.
          active_facts.each do |k, v|
            ctx[k.to_s] = v
          end
        else
          ctx['active_edit_seed'] = 'identity'
        end
        ctx
      end

      # The SU host (model). For the V1.4 plumbing path we
      # pass the model the dialog was constructed with so
      # the production adapter can wrap operations.
      def _host_for(_ar)
        # The dialog_runner passes the controller's model
        # directly to _source_snapshot_for and prepare. The
        # AnalysisResult itself does not carry the model
        # (host is an external reference); callers should
        # use the controller's #model accessor instead.
        nil
      end

      # V1.4 CodeX V14-RUNTIME-BLOCK-002 (2026-08-22):
      # resolve the production / fake adapter.
      #
      # Contract:
      #   - When SU is available (sketchup_available? returns true),
      #     return the PRODUCTION adapter (SketchupDerivedWorkspaceAdapter)
      #     unconditionally. The real adapter MUST be the one
      #     used in a real SketchUp host.
      #   - When SU is NOT available (test env / no SU module),
      #     return the FakeAdapter (only allowed in test envs).
      #   - When SU is available but the production adapter is
      #     not usable for some reason, raise a typed error
      #     (NOT silently fall back to the FakeAdapter in a real
      #     host -- that path produced the V14-RUNTIME-BLOCK-002
      #     NameError and must NOT recur).
      class AdapterUnavailableError < StandardError; end

      def _adapter_for(_host_safety_check:)
        adapter_module = SUAnalysis::Compatibility
        production_klass = adapter_module::SketchupDerivedWorkspaceAdapter
        fake_klass       = SUAnalysis::Core::FakeDerivedWorkspaceAdapter

        # Test env detection: real SU is NOT available iff
        # the Sketchup module is undefined OR has no active_model.
        # This is the SAME check the production adapter uses
        # internally (`sketchup_available?`).
        real_su_present =
          defined?(Sketchup) &&
          Sketchup.respond_to?(:active_model) &&
          (Sketchup.active_model.respond_to?(:entities) rescue false)

        if real_su_present
          # Real SketchUp host: MUST use the production
          # adapter. Both constants are now explicitly required
          # at the top of this file, so they are guaranteed
          # loaded. If the production adapter is somehow not
          # usable (e.g. SU version too old), raise -- do NOT
          # silently fall back to the FakeAdapter (that path is
          # what triggered V14-RUNTIME-BLOCK-002).
          unless production_klass.sketchup_available?
            raise AdapterUnavailableError,
                  "V1.4 WorkingMode prepare blocked: production adapter is not available in a real SketchUp host (sketchup_available? = false). " \
                  "Owner must restart SU2020 + reinstall the rbz (see Review/OWNER_VERIFICATION_V1_4_DERIVED_WORKSPACE_2026-08-21.txt)."
          end
          production_klass.new
        else
          # Test / no-SU env: use the FakeAdapter. This path
          # is NEVER taken on a real SketchUp host.
          fake_klass.new
        end
      end

      def _toast(dialog, message)
        json = JSON.generate(message.to_s)
        dialog.execute_script("window.SUAIP.toast(#{json})")
      end

      # V1.4 V14-RUNTIME-BLOCK-004 (2026-08-24, real SU2020 narrow
      # test): in SketchUp 2020, $stderr IS Sketchup::Console and
      # $stdout IS Sketchup::Console -- both have #puts as a
      # PRIVATE method. Direct $stderr.puts(...) /
      # $stdout.puts(...) raises NoMethodError, which masked
      # the original Prepare exception in _safe_invoke's
      # rescue block. We use bare `warn(...)` (a Kernel method
      # that goes through the C-level error stream and does
      # not require an explicit `.puts` on the receiver) AND
      # wrap the call in a defensive rescue. The logging path
      # MUST NEVER propagate an exception to the caller -- the
      # original action exception is the source of truth.
      def _safe_log(msg)
        begin
          warn(msg)
        rescue StandardError
          # Last-resort: silent. Logging is best-effort.
          # The original exception in _safe_invoke / on_locate
          # / main.rb boot is the source of truth for the UI
          # toast + push_data path.
          nil
        end
      end

      # V1.4 CodeX BLOCK fix (Stage 4): resolve the SU model
      # to use for the workspace's operation wrapping. The
      # controller carries the model passed to DialogRunner.show;
      # in tests the controller's model is a FakeUI::FakeModel.
      # The model is passed to WorkingModeRunner.prepare so the
      # production adapter can wrap mutations in
      # model.start_operation / commit_operation / abort_operation.
      def _resolve_model_for(controller)
        if controller && controller.respond_to?(:model)
          controller.model
        else
          nil
        end
      end

      # V1.4 CodeX V14-RUNTIME-BLOCK-002: wrap a host-action
      # block so any StandardError is surfaced as a UI toast.
      # The UI payload is then re-pushed so the dialog never
      # gets stuck in an invisible intermediate state.
      #
      # V1.4 V14-RUNTIME-BLOCK-004 (2026-08-24, real SU2020 narrow
      # test): the previous implementation called
      # $stderr.puts(...) inside the rescue block. In
      # SketchUp 2020, $stderr IS Sketchup::Console whose
      # #puts is private; the call raised NoMethodError and
      # MASKED the original Prepare exception, skipping both
      # the toast and the push_data. The fix:
      #   1. Each side-effect (log, toast, push_data) is in
      #      its own defensive rescue so a failure in one
      #      path does not stop the others.
      #   2. Logging uses _safe_log (bare `warn(...)` wrapped
      #      in a defensive rescue) instead of $stderr.puts.
      #   3. The original exception `e` is the source of truth
      #      for the toast text; the exception type and message
      #      are preserved.
      #   4. push_data runs UNCONDITIONALLY (even when the
      #      action raised) so the UI is re-pushed and the
      #      Working Mode state is refreshed.
      def _safe_invoke(dialog, controller, action_name)
        action_exception = nil
        begin
          yield
        rescue StandardError => e
          # Capture -- do NOT raise. The toast / push_data
          # paths must run after this rescue.
          action_exception = e
        end

        if action_exception
          e = action_exception
          # 1. Log (defensive -- never propagates).
          _safe_log("[SU-AI-Plugin V14-RUNTIME-BLOCK-002] " \
                    "#{action_name} raised #{e.class}: #{e.message}")
          _safe_log("  backtrace: #{e.backtrace.first(5).join(' | ')}")
          # 2. Toast (defensive -- never propagates).
          begin
            _toast(dialog, "V1.4 #{action_name} failed: #{e.class}: #{e.message}")
          rescue StandardError => toast_err
            _safe_log("[SU-AI-Plugin] toast error in #{action_name}: " \
                      "#{toast_err.class}: #{toast_err.message}")
          end
        end

        # 3. push_data (MUST always run; the UI is re-pushed so
        # the dialog never gets stuck in a stale state).
        begin
          push_data(dialog, controller)
        rescue StandardError => push_err
          _safe_log("[SU-AI-Plugin] push_data error in #{action_name}: " \
                    "#{push_err.class}: #{push_err.message}")
        end
      end

      # Idempotent close handler. Releases the controller and the
      # Loader-side live-dialog cache.
      #
      # V16-CLOSE-AUTODISCARD (Owner UX fix, 2026-09-01):
      # before releasing the dialog we run the EXISTING
      # discard-workspace path if (and only if) a current
      # transient Derived Workspace exists. The discard
      # contract is reused verbatim (WorkingModeRunner.discard)
      # — no second cleanup implementation is introduced.
      # The behavior matrix on dialog close is:
      #   state == 'none'      -> no-op (no current workspace)
      #   state == 'discarded' -> no-op (already discarded)
      #   state == 'building'  -> discard (cleanup transient)
      #   state == 'ready'     -> discard (the primary case)
      #   state == 'failed'    -> discard (cleanup partial state)
      # This makes the next plugin-open session begin cleanly
      # with the normal primary action `准备处理` (per the
      # V16-UI-CN-SIMPLIFICATION-FIX action-state matrix).
      #
      # The discard is FAIL-SAFE:
      #   - the existing WorkingModeRunner.discard path already
      #     has a `_discard_if_present` rescue that preserves
      #     the prior handle_registry on exception;
      #   - we additionally wrap the call in begin/rescue
      #     StandardError so a truly unexpected exception from
      #     the close path can NEVER block SketchUp shutdown,
      #     model close, or the HtmlDialog close callback;
      #   - if there is no current workspace, the call is a
      #     no-op (the @current_workspace nil guard inside
      #     `_discard_if_present` returns immediately).
      # Source CAD is NEVER touched by this path; only the
      # derived workspace + the V1.5 duplicate_repair summary
      # + the V1.6 planar_normalization proposal/audit (all
      # carried by WorkingModeRunner) are cleared, which is
      # the existing discard contract.
      def on_close(_dialog, controller)
        begin
          # Snapshot the current state BEFORE we release the
          # controller. We only need the state name; the
          # runner remains the single source of truth.
          current_state = SUAnalysis::Core::WorkingModeRunner.snapshot['state']
          if %w[building ready failed].include?(current_state)
            # Reuse the EXISTING discard-workspace path verbatim.
            # This clears:
            #   - the current Derived Workspace (via
            #     _discard_if_present -> workspace.discard)
            #   - the V1.5 duplicate_repair summary
            #   - the V1.6 planar_normalization proposal + audit
            # Source CAD is untouched. _discard_if_present has
            # its own rescue that preserves the prior handle
            # registry on exception; we wrap here as a second
            # line of defense so a truly unexpected exception
            # can never bubble out of the close callback.
            SUAnalysis::Core::WorkingModeRunner.discard
          end
        rescue StandardError => close_err
          # Per dispatch §4: the close cleanup must be fail-safe.
          # We log via _safe_log and swallow the exception so
          # SketchUp shutdown / model close / HtmlDialog close
          # is NEVER blocked by a transient close-time error.
          _safe_log("[SU-AI-Plugin] close-time auto-discard error: " \
                    "#{close_err.class}: #{close_err.message}")
        end
        controller.release!
        Loader.release_dialog!
        # V1.5 Phase 1 (BLOCK-004 recheck #2): clear the
        # module-level controller handle when the dialog closes.
        clear_current_controller
      end
    end
  end
end
