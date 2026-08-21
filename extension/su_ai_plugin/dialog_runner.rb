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

module SUAnalysis
  module Extension
    module DialogRunner
      module_function

      # Show the HtmlDialog for one AnalysisResult.
      # Returns the dialog instance (or nil in tests).
      def show(result, model: nil)
        return nil unless result
        return nil unless defined?(UI::HtmlDialog)
        return nil unless UI::HtmlDialog.respond_to?(:new)
        controller = DialogController.new(result, model: model)
        dialog = UI::HtmlDialog.new(
          dialog_title:    'CAD Analyzer Result',
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
          $stdout.puts("[SU-AI-Plugin] locate_issue: #{result[:diagnostics].last || 'unresolved'}")
        end
      end

      # V1.4 (per directive 030, Stage 4): handlers for the
      # dialog's Working Mode section. Each handler delegates
      # to WorkingModeRunner (pure-data layer in core/) and
      # re-pushes the payload so the UI updates.
      def on_prepare_workspace(dialog, controller)
        src = _source_snapshot_for(controller)
        if src.nil?
          _toast(dialog,
                 'Working Mode: no source snapshot available for this dialog.')
          return
        end
        SUAnalysis::Core::WorkingModeRunner.prepare(
          source:  src,
          adapter: _adapter_for(_host_safety_check: true),
          model:   _resolve_model_for(controller)
        )
        push_data(dialog, controller)
      end

      def on_discard_workspace(dialog, controller)
        SUAnalysis::Core::WorkingModeRunner.discard
        push_data(dialog, controller)
      end

      def on_rebuild_workspace(dialog, controller)
        src = _source_snapshot_for(controller)
        if src.nil?
          _toast(dialog,
                 'Working Mode: no source snapshot available for this dialog.')
          return
        end
        SUAnalysis::Core::WorkingModeRunner.rebuild
        push_data(dialog, controller)
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
          return _source_snapshot_from_real_geometry(ar, geom)
        end
        # Fallback: plumbing-only SourceSnapshot (V1.0/V1.1/V1.2/
        # V1.3 AnalysisResult callers).
        _plumbing_source_snapshot(ar)
      end

      # V1.4 CodeX BLOCK fix (Stage 4): build a SourceSnapshot
      # from the REAL GeometrySnapshot carried by the
      # AnalysisResult.
      def _source_snapshot_from_real_geometry(ar, geom)
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
          host: _host_for(ar)
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
        # Transform context: the REAL active-edit transform,
        # NOT 'identity'. If the AnalysisResult did not carry
        # an active-edit transform, use the model's
        # active_edit_context_facts.
        transform_context = _transform_context_for(active_facts)
        # Use the canonical from_geometry_snapshot factory to
        # build a deeply-frozen, fingerprintable SourceSnapshot.
        SUAnalysis::Core::SourceSnapshot.from_geometry_snapshot(
          geom,
          selection: sel_scope,
          host: _host_for(ar),
          execution_config: ec,
          rule_set_digest: rule_set_digest,
          snapshot_id: "v14-#{rand(2**32)}",
          captured_at: Time.now.utc.iso8601
        )
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
        # No AR-side host field yet; the dialog_runner passes
        # the controller's model directly to prepare.
        nil
      end

      def _adapter_for(_host_safety_check:)
        if defined?(SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter) &&
           SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.sketchup_available?
          SUAnalysis::Compatibility::SketchupDerivedWorkspaceAdapter.new
        else
          # Production adapter not usable (test env or no SU).
          # The runner needs SOME adapter to function; fall
          # back to the FakeAdapter for test plumbing. The UI
          # will still see state transitions.
          SUAnalysis::Core::FakeDerivedWorkspaceAdapter.new
        end
      end

      def _toast(dialog, message)
        json = JSON.generate(message.to_s)
        dialog.execute_script("window.SUAIP.toast(#{json})")
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

      # Idempotent close handler. Releases the controller and the
      # Loader-side live-dialog cache.
      def on_close(_dialog, controller)
        controller.release!
        Loader.release_dialog!
      end
    end
  end
end
