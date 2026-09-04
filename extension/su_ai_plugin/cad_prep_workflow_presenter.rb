#
# extension/su_ai_plugin/cad_prep_workflow_presenter.rb — V1.9A-A1.
#
# Pure / testable presentation model for the new A1 product
# UX. This is the ONLY module in V1.9A-A1 that translates
# raw deterministic V1.4–V1.8 backend state into the
# product-facing `cadPrepWorkflow` payload consumed by the
# HtmlDialog frontend (app.js).
#
# Per dispatch §5 (V1.9A-A1):
#
#   AnalysisResult + WorkingModeRunner.snapshot
#   → CadPrepWorkflowPresenter
#   → cadPrepWorkflow
#   → UIBridge
#   → app.js
#
# The presenter is:
#   - PURE / deterministic — given the same input Hashes,
#     returns the same payload (no live SketchUp objects,
#     no Time.now, no Random, no ENV);
#   - IDEMPOTENT — repeated calls on the same inputs return
#     identical cadPrepWorkflow (deep ==);
#   - JSON-SAFE — only String / Numeric / Boolean / Array /
#     Hash with String keys cross the boundary;
#   - ADDITIVE — UIBridge still publishes the full legacy
#     raw payload (summary / groups / diagnostics /
#     layerGroups / layerIssueGroups / faceInventoryGroups /
#     derivedWorkspace) for backward compatibility. The
#     presentation model lives under the new top-level key
#     `cadPrepWorkflow`; legacy readers are unaffected.
#
# This presenter implements ONLY V1.9A-A1 scope:
#
#   A1 MAY:    port approved HTML/CSS/JS design; add pure
#              product-facing presenter; add additive
#              cadPrepWorkflow payload; keep existing raw
#              V1.0–V1.8 payload for details/backward
#              compatibility; map current existing backend
#              state into new cards; preserve existing
#              callbacks.
#
#   A1 MUST NOT: implement CadPrepWorkflowOrchestrator
#                (A2); add automatic full diagnostics after
#                Prepare (A2); add start_cad_prep
#                orchestration (A2); add automatic
#                downstream recompute after Z repair (A2);
#                add automatic structure recompute after
#                gap repair (A2); change V1.6/V1.7/V1.8
#                algorithms; change tolerance/source
#                ownership; add Face or Observer
#                architecture; add PreparedCadDataset /
#                persistence (V1.9B); begin V1.9B; add
#                MCP / LLM / Agent.
#
# The presenter therefore maps the CURRENT stepwise V1.4–
# V1.8 backend state (no orchestrator) into a coherent
# product-facing presentation, and tells the truth about
# what is NOT_COMPUTED vs what is genuinely clean.

module SUAnalysis
  module Extension
    module CadPrepWorkflowPresenter
      module_function

      # The schema version of the cadPrepWorkflow payload.
      # Bumped on additive / breaking shape changes. The
      # frontend reads this defensively.
      SCHEMA_VERSION = '1'.freeze

      # Overall presentation states (per Blueprint §4.4).
      # These are NOT exposed to the user verbatim — see
      # OVERALL_STATE_LABELS_CN below.
      OVERALL_STATES = [
        'IDLE',                     # not yet prepared (no workspace)
        'SCANNING',                 # workspace is building
        'NEEDS_ATTENTION',          # ready workspace has actionable / review items
        'READY_FOR_VALIDATION',     # ready workspace has no actionable / review items
        'STALE',                    # host-state invalidation (Undo / host change)
        'FAILED'                    # generic prepare / compute failure
      ].freeze

      # Frozen user-facing Simplified Chinese labels for each
      # overall presentation state. The frontend uses these
      # verbatim. Per Blueprint §4.4 the raw enum strings
      # must NEVER be exposed to the user.
      OVERALL_STATE_LABELS_CN = {
        'IDLE'                 => '尚未处理',
        'SCANNING'             => '正在检查',
        'NEEDS_ATTENTION'      => '发现需要处理的问题',
        'READY_FOR_VALIDATION' => '已完成检查',
        'STALE'                => '工作副本已失效',
        'FAILED'               => '处理失败'
      }.freeze

      # Frozen card states (per Blueprint §4.3). The frontend
      # map translates to icon / pill color.
      CARD_STATES = %w[
        UNCOMPUTED
        CHECKING
        CLEAN
        ACTIONABLE
        REVIEW_REQUIRED
        APPLIED
        BLOCKED
        STALE
        FAILED
      ].freeze

      # Frozen user-facing Simplified Chinese labels for each
      # card presentation state.
      CARD_STATE_LABELS_CN = {
        'UNCOMPUTED'      => '未检查',
        'CHECKING'        => '正在检查',
        'CLEAN'           => '已处理',
        'ACTIONABLE'      => '可安全校正',
        'REVIEW_REQUIRED' => '需要人工确认',
        'APPLIED'         => '已校正',
        'BLOCKED'         => '已阻塞',
        'STALE'           => '已过期',
        'FAILED'          => '失败'
      }.freeze

      # Frozen card titles (per Blueprint §4.3 fixed order).
      CARD_TITLES_CN = {
        'duplicate_cleanup'    => '重复线清理',
        'planar_normalization' => 'Z 轴 / 平面校正',
        'gap_endpoint'         => '间隙与断点',
        'structure_region'     => '轮廓与区域',
        'other'                => '其他需检查项'
      }.freeze

      # Frozen card ids in the locked order. The presenter
      # always emits exactly these five cards, in this
      # order, even when the underlying data is empty.
      CARD_IDS = [
        'duplicate_cleanup',
        'planar_normalization',
        'gap_endpoint',
        'structure_region',
        'other'
      ].freeze

      # Build the full cadPrepWorkflow payload.
      #
      # Inputs:
      #   analysis_result : AnalysisResult or nil.
      #     When nil (e.g. before the user opens the dialog),
      #     the presenter returns the IDLE shape with the
      #     summary block empty.
      #   workspace_snapshot : Hash (String-keyed). The
      #     WorkingModeRunner.snapshot result. Must be
      #     JSON-safe (already produced by the runner).
      #
      # Returns:
      #   Hash with String keys, deeply JSON-safe. Contains:
      #     - schema_version
      #     - overall_state
      #     - headline
      #     - subheadline
      #     - issue_summary
      #     - cards (Array of 5, frozen order)
      #     - recovery (Hash or nil)
      #     - selection (Hash describing the user's selection;
      #                  carries the same selection_type /
      #                  selection_label as the legacy payload)
      def present(analysis_result:, workspace_snapshot:)
        snap = _coerce_snapshot(workspace_snapshot)
        analysis_summary = _safe_summary(analysis_result)

        overall = _compute_overall_state(snap, analysis_summary)
        cards   = _build_cards(snap, analysis_summary)
        issue  = _build_issue_summary(overall, cards, snap, analysis_summary)
        headline, subheadline = _build_headlines(overall, cards, snap, analysis_summary)
        recovery = _build_recovery(overall, snap)

        {
          'schema_version' => SCHEMA_VERSION,
          'overall_state'  => overall,
          'headline'       => headline,
          'subheadline'    => subheadline,
          'selection'      => _build_selection(analysis_result),
          'issue_summary'  => issue,
          'cards'          => cards,
          'recovery'       => recovery
        }.freeze
      end

      # ---- internals ------------------------------------------------

      # Defensive coercion: WorkingModeRunner.snapshot is
      # already JSON-safe; we just normalize its shape so
      # the presenter never crashes on missing keys.
      def _coerce_snapshot(snap)
        return {} if snap.nil? || !snap.is_a?(Hash)
        # String-keyed defensive re-coercion.
        out = {}
        snap.each { |k, v| out[k.to_s] = v }
        out
      end

      def _safe_summary(ar)
        return {} if ar.nil? || !ar.respond_to?(:summary)
        s = ar.summary
        return {} unless s.is_a?(Hash)
        out = {}
        s.each { |k, v| out[k.to_s] = v }
        out
      end

      # Determine the overall presentation state from the
      # workspace snapshot + the analysis summary. The
      # workspace state is authoritative for "is there a
      # running workspace"; the per-stage planar / topology
      # / structure sub-snapshots drive NEEDS_ATTENTION vs
      # READY_FOR_VALIDATION.
      def _compute_overall_state(snap, analysis_summary)
        ws = (snap['state'] || 'none').to_s
        if ws == 'building'
          return 'SCANNING'
        end
        if ws == 'failed'
          # Distinguish STALE (host_state_changed) from generic
          # FAILED. The runner's last_error for STALE includes
          # the stable `host_state_changed` reason.
          last = snap['last_error'].to_s
          if last.include?('host_state_changed')
            return 'STALE'
          end
          return 'FAILED'
        end
        if ws == 'none' || ws == 'discarded'
          return 'IDLE'
        end
        # ws == 'ready' (the only remaining terminal
        # workspace state). Determine whether the user has
        # something actionable / reviewable.
        if _has_actionable_or_review?(snap)
          return 'NEEDS_ATTENTION'
        end
        'READY_FOR_VALIDATION'
      end

      # Returns true if any of (planar_normalization,
      # topology_repair, structure_reconstruction) is
      # ACTIONABLE or REVIEW_REQUIRED.
      def _has_actionable_or_review?(snap)
        pn = snap['planar_normalization']
        if pn.is_a?(Hash)
          ps = pn['state'].to_s
          return true if ps == 'READY_TO_NORMALIZE' || ps == 'REVIEW_REQUIRED'
        end
        tr = snap['topology_repair']
        if tr.is_a?(Hash)
          ts = tr['state'].to_s
          return true if ts == 'READY_TO_REPAIR' || ts == 'REVIEW_REQUIRED'
        end
        sr = snap['structure_reconstruction']
        if sr.is_a?(Hash)
          ss = sr['state'].to_s
          return true if ss.start_with?('REVIEW_REQUIRED') ||
                         ss == 'READY_WITH_WARNINGS'
        end
        false
      end

      # ---- selection ----------------------------------------------

      def _build_selection(analysis_result)
        if analysis_result.nil?
          return { 'type' => '', 'label' => '尚未选择' }.freeze
        end
        {
          'type'  => analysis_result.respond_to?(:selection_type) ? analysis_result.selection_type.to_s : '',
          'label' => analysis_result.respond_to?(:selection_label) ? analysis_result.selection_label.to_s : ''
        }.freeze
      end

      # ---- issue summary (error-only per dispatch §8) -----------

      def _build_issue_summary(overall, cards, snap, analysis_summary)
        case overall
        when 'IDLE'
          return {
            'kind'        => 'empty-idle',
            'headline'    => 'CAD 尚未处理',
            'subtitle'    => '点击"开始处理"以创建安全工作副本并完成全部检查',
            'chips'       => [],
            'cta'         => nil
          }.freeze
        when 'READY_FOR_VALIDATION'
          # No actionable item AND not STALE / FAILED. Render
          # the "clean" empty state OR the "all applied"
          # state. We prefer "clean" when nothing is in
          # :applied state; otherwise "all applied" so the
          # user sees the result of their work.
          if cards.any? { |c| c['state'] == 'APPLIED' }
            return {
              'kind'        => 'issues',
              'headline'    => '已完成 · 已应用所有安全修复',
              'subtitle'    => '可继续验证或查看当前已保留的问题',
              'chips'       => _collect_chips(cards, include_zero: false),
              'cta'         => '重新检测'
            }.freeze
          end
          return {
            'kind'        => 'clean',
            'headline'    => 'CAD 状态良好',
            'subtitle'    => '未发现需要处理的问题',
            'chips'       => [],
            'cta'         => nil
          }.freeze
        when 'STALE'
          return {
            'kind'        => 'issues',
            'headline'    => '工作副本已失效',
            'subtitle'    => '源对象已被修改或 SketchUp 撤销了一次操作',
            'chips'       => [{ 'value' => 1, 'label' => '需重新生成' }],
            'cta'         => nil
          }.freeze
        when 'FAILED'
          return {
            'kind'        => 'issues',
            'headline'    => '处理失败',
            'subtitle'    => _failure_subtitle(snap),
            'chips'       => [{ 'value' => 1, 'label' => '失败' }],
            'cta'         => '重新检测'
          }.freeze
        when 'SCANNING'
          return {
            'kind'        => 'empty-idle',
            'headline'    => '正在准备...',
            'subtitle'    => '正在创建安全工作副本',
            'chips'       => [],
            'cta'         => nil
          }.freeze
        end
        # NEEDS_ATTENTION — collect chips from cards.
        chips = _collect_chips(cards, include_zero: false)
        headline = if chips.length.zero?
                     '发现需要处理的问题'
                   else
                     "发现 #{chips.length} 类 · #{chips.map { |c| c['value'].to_i }.sum} 项问题"
                   end
        {
          'kind'        => 'issues',
          'headline'    => headline,
          'subtitle'    => nil,
          'chips'       => chips,
          'cta'         => '重新检测'
        }.freeze
      end

      def _failure_subtitle(snap)
        last = snap['last_error'].to_s
        return '请重试或放弃当前工作副本' if last.empty?
        # Surface a CONCISE summary of the last_error to the
        # user; full text remains in 详情.
        last[0, 80]
      end

      # Collect error-only chips from the per-card metrics.
      # Per dispatch §8, zero-value categories are hidden.
      def _collect_chips(cards, include_zero:)
        chips = []
        cards.each do |c|
          next unless c['metrics'].is_a?(Array)
          c['metrics'].each do |mm|
            v = mm['value']
            next if v.nil?
            v_int = v.to_i
            next if v_int <= 0 && !include_zero
            # De-duplicate: e.g. "12 Z 轴偏差" appears on
            # both the card and the chip list.
            chips << { 'value' => v_int, 'label' => mm['label'].to_s }
          end
        end
        chips
      end

      # ---- headlines ----------------------------------------------

      def _build_headlines(overall, cards, snap, analysis_summary)
        case overall
        when 'IDLE'
          return ['CAD 尚未处理', '开始后将创建安全工作副本并完成全部检查']
        when 'SCANNING'
          return ['正在准备...', '正在创建安全工作副本']
        when 'READY_FOR_VALIDATION'
          if cards.any? { |c| c['state'] == 'APPLIED' }
            return ['已完成 · 已应用安全修复', '可继续验证或查看当前已保留的问题']
          end
          return ['CAD 状态良好', '未发现需要处理的问题']
        when 'STALE'
          return ['工作副本已失效', '请重新生成或放弃工作副本以保持源 CAD 完整']
        when 'FAILED'
          return ['处理失败', _failure_subtitle(snap)]
        end
        # NEEDS_ATTENTION: count actionable categories from
        # the cards' primary actions.
        actionable_count = cards.count { |c| !c['primary_action'].nil? && c['primary_action']['enabled'] }
        if actionable_count.zero?
          return ['存在需人工查看的问题', '当前未自动修复']
        end
        ['发现需要处理的问题', nil]
      end

      # ---- recovery ----------------------------------------------

      def _build_recovery(overall, snap)
        if overall == 'STALE'
          return {
            'title'          => '工作副本已失效',
            'desc'           => '源对象已被修改或 SketchUp 撤销了一次操作。请重新生成工作副本，或放弃当前副本以保持源 CAD 完整。',
            'primary_label'  => '重新生成工作副本',
            'primary_callback' => 'rebuild_workspace',
            'secondary_label'  => '放弃工作副本',
            'secondary_callback' => 'discard_workspace'
          }.freeze
        end
        if overall == 'FAILED'
          return {
            'title'          => '处理失败',
            'desc'           => 'V1.4 工作副本或后续检查在准备过程中遇到错误。请重试，或放弃当前工作副本以保持源 CAD 完整。',
            'primary_label'  => '重新生成工作副本',
            'primary_callback' => 'rebuild_workspace',
            'secondary_label'  => '放弃工作副本',
            'secondary_callback' => 'discard_workspace'
          }.freeze
        end
        nil
      end

      # ---- cards (frozen 5 in fixed order) ----------------------

      def _build_cards(snap, analysis_summary)
        [
          _build_duplicate_cleanup_card(snap, analysis_summary),
          _build_planar_normalization_card(snap, analysis_summary),
          _build_gap_endpoint_card(snap, analysis_summary),
          _build_structure_region_card(snap, analysis_summary),
          _build_other_card(snap, analysis_summary)
        ]
      end

      # ---- card 1: duplicate_cleanup -----------------------------

      # Duplicate cleanup is high-confidence auto-apply per
      # V1.5; no manual repair button. The card surfaces the
      # actual post-batch audit (when one exists) and stays
      # UNCOMPUTED otherwise. Per Blueprint §4.3 the user
      # never sees a "repair duplicates" button.
      def _build_duplicate_cleanup_card(snap, analysis_summary)
        ws = (snap['state'] || 'none').to_s
        if ws == 'none' || ws == 'discarded'
          return _card_skeleton('duplicate_cleanup', 'UNCOMPUTED',
                                '将在开始处理后自动检查', [])
        end
        if ws == 'building'
          return _card_skeleton('duplicate_cleanup', 'CHECKING',
                                '正在自动清理高置信度重复线', [])
        end
        if ws == 'failed' || ws == 'stale'
          return _card_skeleton('duplicate_cleanup', 'STALE',
                                '等待重检', [])
        end
        # ws == 'ready'. Surface the duplicate_repair audit.
        summary = snap['duplicate_repair']
        if summary.is_a?(Hash)
          applied = summary['actions_applied'].to_i
          skipped = summary['actions_skipped'].to_i
          before  = summary['duplicate_pairs_before']
          after   = summary['duplicate_pairs_after']
          metrics = []
          if applied.positive?
            metrics << { 'value' => applied, 'label' => '已处理' }
          end
          if skipped.positive?
            metrics << { 'value' => skipped, 'label' => '跳过' }
          end
          # Surface the pre / post pair counts only when they
          # are truthful integers (tolerance was captured).
          if before.is_a?(Integer) && after.is_a?(Integer)
            metrics << { 'value' => [before - after, 0].max, 'label' => '已合并重复对' }
          end
          state_label = if applied.positive?
                          "已自动处理 #{applied} 条"
                        else
                          '无重复线'
                        end
          return {
            'id'               => 'duplicate_cleanup',
            'state'            => applied.positive? ? 'APPLIED' : 'CLEAN',
            'state_label'      => state_label,
            'title'            => CARD_TITLES_CN['duplicate_cleanup'],
            'summary'          => applied.positive? ? '高置信度自动修复已应用于工作副本' : '未检测到需要清理的重复线',
            'metrics'          => metrics,
            'primary_action'   => nil,
            'secondary_action' => nil,
            'detail_filter'    => 'duplicate'
          }.freeze
        end
        # Ready but no duplicate repair has run (unusual —
        # e.g. if Prepare was followed by an immediate
        # compute_gap_repair without the auto-batch). Surface
        # as UNCOMPUTED rather than CLEAN: truth rule from
        # dispatch §6.
        _card_skeleton('duplicate_cleanup', 'UNCOMPUTED',
                      '尚未执行', [])
      end

      # ---- card 2: planar_normalization -------------------------

      def _build_planar_normalization_card(snap, analysis_summary)
        ws = (snap['state'] || 'none').to_s
        if ws == 'none' || ws == 'discarded'
          return _card_skeleton('planar_normalization', 'UNCOMPUTED',
                                '将在开始处理后自动检查', [])
        end
        if ws == 'building'
          return _card_skeleton('planar_normalization', 'CHECKING',
                                '正在准备', [])
        end
        if ws == 'failed' || ws == 'stale'
          return _card_skeleton('planar_normalization', 'STALE',
                                '等待重检', [])
        end
        # ws == 'ready'.
        pn = snap['planar_normalization']
        if !pn.is_a?(Hash)
          # Truthful UNCOMPUTED — the user has not yet
          # clicked 检查平面偏差. NOT to be rendered as CLEAN.
          # A1 exposes the existing compute_* action so the
          # user can drive the diagnostic manually; A2 will
          # own one-click orchestration.
          return _card_with_primary_action(
            'planar_normalization', 'UNCOMPUTED',
            '点击右侧按钮检查当前几何的 Z 偏差', [],
            primary_label: '检查平面偏差',
            primary_callback: 'compute_planar_normalization'
          )
        end
        ps = pn['state'].to_s
        case ps
        when 'NOT_COMPUTED'
          _card_with_primary_action(
            'planar_normalization', 'UNCOMPUTED',
            '点击右侧按钮检查当前几何的 Z 偏差', [],
            primary_label: '检查平面偏差',
            primary_callback: 'compute_planar_normalization'
          )
        when 'READY_TO_NORMALIZE'
          # Surface the actual proposal metrics (Blueprint
          # §4.3). Per dispatch §7, only safe proposals
          # carry the 修复 Z 轴 action.
          proposal = pn['proposal'].is_a?(Hash) ? pn['proposal'] : {}
          movable  = (proposal['movable'].is_a?(Integer) ? proposal['movable'] : nil) ||
                     (proposal['proposed_movable'].is_a?(Integer) ? proposal['proposed_movable'] : nil)
          outliers = proposal['outlier_count'].is_a?(Integer) ? proposal['outlier_count'] : nil
          metrics  = []
          metrics << { 'value' => movable,  'label' => '可校正' } if movable.is_a?(Integer)
          metrics << { 'value' => outliers, 'label' => '异常点'  } if outliers.is_a?(Integer)
          {
            'id'               => 'planar_normalization',
            'state'            => 'ACTIONABLE',
            'state_label'      => '可安全校正',
            'title'            => CARD_TITLES_CN['planar_normalization'],
            'summary'          => _planar_safe_summary(movable, outliers),
            'metrics'          => metrics,
            'primary_action'   => {
              'label'    => '修复 Z 轴',
              'callback' => 'apply_planar_normalization',
              'enabled'  => true
            },
            'secondary_action' => nil,
            'detail_filter'    => 'planar'
          }.freeze
        when 'REVIEW_REQUIRED'
          proposal = pn['proposal'].is_a?(Hash) ? pn['proposal'] : {}
          outliers = proposal['outlier_count'].is_a?(Integer) ? proposal['outlier_count'] : nil
          metrics  = []
          metrics << { 'value' => outliers, 'label' => '需人工确认' } if outliers.is_a?(Integer)
          {
            'id'               => 'planar_normalization',
            'state'            => 'REVIEW_REQUIRED',
            'state_label'      => '需要人工确认',
            'title'            => CARD_TITLES_CN['planar_normalization'],
            'summary'          => '存在 Z 偏差属于不确定分类，不会被自动校正',
            'metrics'          => metrics,
            'primary_action'   => nil,
            'secondary_action' => {
              'label'    => '查看问题',
              'callback' => 'view_issues',
              'enabled'  => true
            },
            'detail_filter'    => 'planar'
          }.freeze
        when 'APPLIED'
          audit = pn['audit'].is_a?(Hash) ? pn['audit'] : {}
          moved = audit['moved'].is_a?(Integer) ? audit['moved'] :
                  audit['moved_applied'].is_a?(Integer) ? audit['moved_applied'] : nil
          metrics = []
          metrics << { 'value' => moved, 'label' => '已移动' } if moved.is_a?(Integer)
          {
            'id'               => 'planar_normalization',
            'state'            => 'APPLIED',
            'state_label'      => '已校正',
            'title'            => CARD_TITLES_CN['planar_normalization'],
            'summary'          => moved.is_a?(Integer) ? "已对 #{moved} 个顶点完成 Z 校正" : '已完成 Z 校正',
            'metrics'          => metrics,
            'primary_action'   => nil,
            'secondary_action' => nil,
            'detail_filter'    => 'planar'
          }.freeze
        when 'NO_CANDIDATE'
          _card_skeleton('planar_normalization', 'CLEAN',
                        '当前几何不存在需要 Z 校正的偏差', [])
        when 'FAILED'
          _card_skeleton('planar_normalization', 'FAILED',
                        _failure_summary_text(pn, 'Z 校正失败'), [])
        else
          # INVALID_TOLERANCE / INVALID_INPUT / unknown.
          _card_skeleton('planar_normalization', 'BLOCKED',
                        _planar_blocked_summary(ps), [])
        end
      end

      def _planar_safe_summary(movable, outliers)
        parts = []
        parts << "发现 #{movable} 个可安全校正点" if movable.is_a?(Integer) && movable.positive?
        parts << "另有 #{outliers} 个异常点不会自动校正" if outliers.is_a?(Integer) && outliers.positive?
        return '未发现需要 Z 校正的点' if parts.empty?
        parts.join('，')
      end

      def _planar_blocked_summary(ps)
        case ps
        when 'INVALID_TOLERANCE' then '容差配置无效'
        when 'INVALID_INPUT'     then '输入数据无效'
        else '当前阶段无法继续'
        end
      end

      # ---- card 3: gap_endpoint ----------------------------------

      def _build_gap_endpoint_card(snap, analysis_summary)
        ws = (snap['state'] || 'none').to_s
        if ws == 'none' || ws == 'discarded'
          return _card_skeleton('gap_endpoint', 'UNCOMPUTED',
                                '将在开始处理后自动检查', [])
        end
        if ws == 'building'
          return _card_skeleton('gap_endpoint', 'CHECKING',
                                '正在准备', [])
        end
        if ws == 'failed' || ws == 'stale'
          return _card_skeleton('gap_endpoint', 'STALE',
                                '等待重检', [])
        end
        tr = snap['topology_repair']
        if !tr.is_a?(Hash)
          return _card_with_primary_action(
            'gap_endpoint', 'UNCOMPUTED',
            '点击右侧按钮检查当前间隙', [],
            primary_label: '检查间隙',
            primary_callback: 'compute_gap_repair'
          )
        end
        ts = tr['state'].to_s
        case ts
        when 'NOT_COMPUTED'
          _card_with_primary_action(
            'gap_endpoint', 'UNCOMPUTED',
            '点击右侧按钮检查当前间隙', [],
            primary_label: '检查间隙',
            primary_callback: 'compute_gap_repair'
          )
        when 'READY_TO_REPAIR'
          proposal = tr['proposal'].is_a?(Hash) ? tr['proposal'] : {}
          ready    = _extract_topology_count(proposal, 'ready_proposals', 'ready_count')
          metrics  = []
          metrics << { 'value' => ready, 'label' => '可安全修复' } if ready.is_a?(Integer)
          {
            'id'               => 'gap_endpoint',
            'state'            => 'ACTIONABLE',
            'state_label'      => '发现安全修复项',
            'title'            => CARD_TITLES_CN['gap_endpoint'],
            'summary'          => ready.is_a?(Integer) ? "#{ready} 处间隙两端均在端点容差内" : '当前存在可安全修复的间隙',
            'metrics'          => metrics,
            'primary_action'   => {
              'label'    => '修复间隙',
              'callback' => 'apply_gap_repair',
              'enabled'  => true
            },
            'secondary_action' => nil,
            'detail_filter'    => 'gap'
          }.freeze
        when 'REVIEW_REQUIRED'
          proposal = tr['proposal'].is_a?(Hash) ? tr['proposal'] : {}
          review   = _extract_topology_count(proposal, 'review_proposals', 'review_count')
          metrics  = []
          metrics << { 'value' => review, 'label' => '需人工确认' } if review.is_a?(Integer)
          {
            'id'               => 'gap_endpoint',
            'state'            => 'REVIEW_REQUIRED',
            'state_label'      => '需要人工确认',
            'title'            => CARD_TITLES_CN['gap_endpoint'],
            'summary'          => '存在多种修复可能，V1 不会自动猜测',
            'metrics'          => metrics,
            'primary_action'   => nil,
            'secondary_action' => {
              'label'    => '查看问题',
              'callback' => 'view_issues',
              'enabled'  => true
            },
            'detail_filter'    => 'gap'
          }.freeze
        when 'NO_CANDIDATE'
          _card_skeleton('gap_endpoint', 'CLEAN',
                        '当前不存在需要修复的开放端点', [])
        when 'APPLIED'
          audit = tr['audit'].is_a?(Hash) ? tr['audit'] : {}
          applied = audit['applied'].is_a?(Integer) ? audit['applied'] : nil
          metrics = []
          metrics << { 'value' => applied, 'label' => '已修复' } if applied.is_a?(Integer)
          {
            'id'               => 'gap_endpoint',
            'state'            => 'APPLIED',
            'state_label'      => '已修复',
            'title'            => CARD_TITLES_CN['gap_endpoint'],
            'summary'          => applied.is_a?(Integer) ? "已对 #{applied} 处间隙完成修复" : '已完成间隙修复',
            'metrics'          => metrics,
            'primary_action'   => nil,
            'secondary_action' => nil,
            'detail_filter'    => 'gap'
          }.freeze
        when 'FAILED'
          _card_skeleton('gap_endpoint', 'FAILED',
                        _failure_summary_text(tr, '间隙修复失败'), [])
        else
          _card_skeleton('gap_endpoint', 'BLOCKED',
                        '当前阶段无法继续', [])
        end
      end

      def _extract_topology_count(proposal, *keys)
        keys.each do |k|
          v = proposal[k.to_s]
          v = proposal[k] if v.nil?
          if v.is_a?(Integer)
            return v
          end
          if v.is_a?(Array)
            return v.length
          end
        end
        nil
      end

      # ---- card 4: structure_region ------------------------------

      def _build_structure_region_card(snap, analysis_summary)
        ws = (snap['state'] || 'none').to_s
        if ws == 'none' || ws == 'discarded'
          return _card_skeleton('structure_region', 'UNCOMPUTED',
                                '将在开始处理后自动检查', [])
        end
        if ws == 'building'
          return _card_skeleton('structure_region', 'CHECKING',
                                '正在准备', [])
        end
        if ws == 'failed' || ws == 'stale'
          return _card_skeleton('structure_region', 'STALE',
                                '等待重检', [])
        end
        sr = snap['structure_reconstruction']
        if !sr.is_a?(Hash) || sr['computed'] != true
          return _card_with_primary_action(
            'structure_region', 'UNCOMPUTED',
            '点击右侧按钮检查当前结构', [],
            primary_label: '检查结构',
            primary_callback: 'compute_structure_reconstruction'
          )
        end
        ss = sr['state'].to_s
        metrics = sr['metrics'].is_a?(Hash) ? sr['metrics'] : {}
        case ss
        when 'READY'
          {
            'id'               => 'structure_region',
            'state'            => 'CLEAN',
            'state_label'      => '结构可用',
            'title'            => CARD_TITLES_CN['structure_region'],
            'summary'          => '闭合轮廓与区域均已稳定',
            'metrics'          => _structure_metrics(metrics, %w[closed_loops regions]),
            'primary_action'   => nil,
            'secondary_action' => nil,
            'detail_filter'    => 'structure'
          }.freeze
        when 'READY_WITH_WARNINGS'
          {
            'id'               => 'structure_region',
            'state'            => 'REVIEW_REQUIRED',
            'state_label'      => '存在需检查项',
            'title'            => CARD_TITLES_CN['structure_region'],
            'summary'          => '结构已重建，但存在需要人工查看的项',
            'metrics'          => _structure_metrics(metrics, %w[open_chains closed_loops regions holes]),
            'primary_action'   => nil,
            'secondary_action' => {
              'label'    => '查看问题',
              'callback' => 'view_issues',
              'enabled'  => true
            },
            'detail_filter'    => 'structure'
          }.freeze
        when 'FAILED'
          _card_skeleton('structure_region', 'FAILED',
                        _failure_summary_text(sr, '结构重建失败'),
                        _structure_metrics(metrics, %w[open_chains]))
        when 'NOT_COMPUTED'
          _card_with_primary_action(
            'structure_region', 'UNCOMPUTED',
            '点击右侧按钮检查当前结构', [],
            primary_label: '检查结构',
            primary_callback: 'compute_structure_reconstruction'
          )
        else
          # Review-only / partial states are surfaced as
          # REVIEW_REQUIRED so the user sees "需要人工查看".
          {
            'id'               => 'structure_region',
            'state'            => 'REVIEW_REQUIRED',
            'state_label'      => '存在需检查项',
            'title'            => CARD_TITLES_CN['structure_region'],
            'summary'          => '当前结构存在需要人工查看的项',
            'metrics'          => _structure_metrics(metrics, %w[open_chains]),
            'primary_action'   => nil,
            'secondary_action' => {
              'label'    => '查看问题',
              'callback' => 'view_issues',
              'enabled'  => true
            },
            'detail_filter'    => 'structure'
          }.freeze
        end
      end

      def _structure_metrics(metrics, keys)
        out = []
        keys.each do |k|
          v = metrics[k.to_s]
          v = metrics[k] if v.nil?
          next unless v.is_a?(Integer) && v.positive?
          out << { 'value' => v, 'label' => _structure_label_for(k) }
        end
        out
      end

      def _structure_label_for(k)
        case k.to_s
        when 'open_chains'   then '开放链'
        when 'closed_loops'  then '闭合轮廓'
        when 'regions'       then '区域'
        when 'holes'         then '洞'
        when 'exceptions'    then '异常'
        else k.to_s
        end
      end

      # ---- card 5: other ----------------------------------------

      # Per Blueprint §4.3 card 5 is the catch-all for
      # secondary issue classes (short_edge,
      # abnormal_large_coord, deep_nesting) that do not
      # have a dedicated repair feature. Per dispatch §7 the
      # card stays truthful: it surfaces the CURRENT
      # analysis_summary's per-issue-type counts (which are
      # the V1.0–V1.4 issue counts and represent the source
      # registry). For A1 (no orchestrator) we expose the
      # current issue-type counts so the user has a stable
      # view of secondary issues; the A2 orchestrator will
      # narrow this to "currently unresolved" in the future.
      def _build_other_card(snap, analysis_summary)
        ws = (snap['state'] || 'none').to_s
        if ws == 'none' || ws == 'discarded'
          return _card_skeleton('other', 'UNCOMPUTED',
                                '将在开始处理后自动检查', [])
        end
        if ws == 'building'
          return _card_skeleton('other', 'CHECKING',
                                '正在准备', [])
        end
        if ws == 'failed' || ws == 'stale'
          return _card_skeleton('other', 'STALE',
                                '等待重检', [])
        end
        # ws == 'ready'. Read the V1.4 `issues` per-type
        # counter map (already JSON-safe).
        issues = analysis_summary['issues']
        if !issues.is_a?(Hash) || issues.empty?
          return _card_skeleton('other', 'CLEAN',
                                '未发现短边、坐标异常等其他需检查项', [])
        end
        # Exclude the four primary issue types we already
        # cover on dedicated cards / chips.
        exclude = %w[duplicate_edge_candidate open_endpoint significant_non_zero_z gap_candidate]
        secondary = {}
        issues.each do |type, count|
          next if exclude.include?(type.to_s)
          n = count.to_i
          secondary[type.to_s] = n if n.positive?
        end
        if secondary.empty?
          return _card_skeleton('other', 'CLEAN',
                                '未发现短边、坐标异常等其他需检查项', [])
        end
        metrics = secondary.map do |type, n|
          { 'value' => n, 'label' => _other_issue_label(type) }
        end
        {
          'id'               => 'other',
          'state'            => 'REVIEW_REQUIRED',
          'state_label'      => '存在其他问题',
          'title'            => CARD_TITLES_CN['other'],
          'summary'          => '需要人工查看当前次要问题',
          'metrics'          => metrics,
          'primary_action'   => nil,
          'secondary_action' => {
            'label'    => '查看问题',
            'callback' => 'view_issues',
            'enabled'  => true
          },
          'detail_filter'    => 'other'
        }.freeze
      end

      def _other_issue_label(type)
        case type.to_s
        when 'short_edge'           then '短边'
        when 'abnormal_large_coord' then '坐标异常'
        when 'deep_nesting'         then '嵌套层级'
        else type.to_s
        end
      end

      # ---- card skeleton ----------------------------------------

      def _card_skeleton(id, state, summary, metrics)
        {
          'id'               => id,
          'state'            => state,
          'state_label'      => CARD_STATE_LABELS_CN[state] || state.to_s,
          'title'            => CARD_TITLES_CN[id] || id.to_s,
          'summary'          => summary,
          'metrics'          => metrics,
          'primary_action'   => nil,
          'secondary_action' => nil,
          'detail_filter'    => id
        }.freeze
      end

      # Card skeleton with an enabled primary action.
      def _card_with_primary_action(id, state, summary, metrics,
                                    primary_label:, primary_callback:)
        {
          'id'               => id,
          'state'            => state,
          'state_label'      => CARD_STATE_LABELS_CN[state] || state.to_s,
          'title'            => CARD_TITLES_CN[id] || id.to_s,
          'summary'          => summary,
          'metrics'          => metrics,
          'primary_action'   => {
            'label'    => primary_label,
            'callback' => primary_callback,
            'enabled'  => true
          },
          'secondary_action' => nil,
          'detail_filter'    => id
        }.freeze
      end

      def _failure_summary_text(sub, fallback)
        if sub.is_a?(Hash) && sub['reason'].is_a?(String) && !sub['reason'].empty?
          sub['reason']
        else
          fallback
        end
      end
    end
  end
end
