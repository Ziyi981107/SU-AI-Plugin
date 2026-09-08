#
# extension/su_ai_plugin/cad_prep_workflow_presenter.rb — V1.9A-A2.
#
# Pure / testable presentation model for the V1.9A product
# UX. This is the ONLY module that translates raw
# deterministic V1.4–V1.8 backend state into the
# product-facing `cadPrepWorkflow` payload consumed by the
# HtmlDialog frontend (app.js).
#
# Per dispatch §5 (V1.9A-A1) + §8 (V1.9A-A2):
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
# V1.9A-A2 SCOPE (this file's authoritative scope):
#
#   A2 MAY:    update the IDLE copy to truthfully promise
#              automatic full diagnostics (the orchestrator
#              runs after start_cad_prep); update the
#              primary CTA mapping (IDLE -> start_cad_prep,
#              NEEDS_ATTENTION / READY_FOR_VALIDATION ->
#              refresh_cad_prep); gate the gap repair
#              action when planar is still
#              READY_TO_NORMALIZE (gap-ordering safety,
#              dispatch §5.1); update the IDLE issue
#              summary subtitle to reflect A2 truth.
#
#   A2 MUST NOT: change the V1.6 / V1.7 / V1.8 algorithms;
#                change tolerance authority; change
#                source / derived ownership; change
#                transaction / Undo architecture; add Face
#                or Observer architecture; begin V1.9B;
#                add MCP / LLM / Agent.
#
# Frozen V1.4 / V1.5 / V1.6 / V1.7 / V1.8 contracts UNCHANGED.

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

        # Build the cards first; the overall state for a
        # `ready` workspace MUST be derived from the actual
        # rendered card states (BLOCK 2 fix). For IDLE /
        # SCANNING / STALE / FAILED the workspace state is
        # authoritative and the cards are derived from it
        # (they all read UNCOMPUTED / CHECKING / STALE).
        cards = _build_cards(snap, analysis_summary)
        overall = _compute_overall_state(snap, cards)
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
      # workspace snapshot + the ACTUAL RENDERED CARDS.
      #
      # Per AIPM source review BLOCK 2: a `ready` workspace
      # MUST NOT become READY_FOR_VALIDATION while any
      # capability card is still UNCOMPUTED / BLOCKED /
      # FAILED / REVIEW_REQUIRED. The previous implementation
      # only checked a subset of sub-snapshot raw states and
      # therefore allowed `ready + planar NOT_COMPUTED` to
      # read as "CAD 状态良好" while the cards honestly said
      # "未检查". The refactor derives the overall state from
      # the actual rendered card states instead.
      #
      # For `none` / `discarded` / `building` / `failed` the
      # workspace state is authoritative and the cards are
      # derived from it (they all read UNCOMPUTED / CHECKING /
      # STALE respectively).
      def _compute_overall_state(snap, cards)
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
        # ws == 'ready'. Derive from the actual card states.
        _overall_state_for_ready_workspace(cards)
      end

      # Derive the overall presentation state for a `ready`
      # workspace from the actual rendered capability cards.
      # The truthful rules (per AIPM source review BLOCK 2):
      #
      #   1. Any ACTIONABLE / BLOCKED / FAILED card
      #      => NEEDS_ATTENTION (the user has explicit
      #         work or a blocked stage to deal with).
      #
      #   2. Any REVIEW_REQUIRED card (incl. the `other`
      #      catch-all card surfacing secondary issues)
      #      => NEEDS_ATTENTION (the user must view it).
      #
      #   3. Any stage-bound card UNCOMPUTED
      #      => NEEDS_ATTENTION with the truthful headline
      #         "仍有未检查项" (the user has not yet
      #         triggered that diagnostic; A2 will own
      #         auto-orchestration, A1 must NOT fake it).
      #      Stage-bound cards = duplicate_cleanup,
      #      planar_normalization, gap_endpoint,
      #      structure_region. The `other` catch-all card
      #      is not stage-bound; it is allowed to render
      #      as UNCOMPUTED when there are no secondary
      #      issue types in the registry (frozen P3
      #      capability-visibility contract).
      #
      #   4. All stage-bound cards CLEAN / APPLIED AND
      #      no REVIEW_REQUIRED card AND `other` is not
      #      REVIEW_REQUIRED
      #      => READY_FOR_VALIDATION.
      def _overall_state_for_ready_workspace(cards)
        # 1) Actionable / Blocked / Failed wins immediately.
        if cards.any? { |c| %w[ACTIONABLE BLOCKED FAILED].include?(c['state']) }
          return 'NEEDS_ATTENTION'
        end
        # 2) Review-required (incl. `other` catch-all) wins.
        if cards.any? { |c| c['state'] == 'REVIEW_REQUIRED' }
          return 'NEEDS_ATTENTION'
        end
        # 3) Stage-bound UNCOMPUTED wins.
        stage_bound_ids = %w[duplicate_cleanup planar_normalization
                             gap_endpoint structure_region]
        stage_cards = cards.select { |c| stage_bound_ids.include?(c['id']) }
        if stage_cards.any? { |c| c['state'] == 'UNCOMPUTED' }
          return 'NEEDS_ATTENTION'
        end
        # 4) All stages are CLEAN / APPLIED and nothing
        #    else needs attention: ready for validation.
        'READY_FOR_VALIDATION'
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
          # V1.9A-A2 (dispatch §8.1): the IDLE copy now
          # truthfully promises automatic full diagnostics.
          # The orchestrator's start path runs prepare +
          # V1.5 duplicate batch + V1.6 planar compute +
          # V1.7 gap compute + V1.8 structure compute in
          # one user click. The A1 truthful "only the V1.5
          # duplicate batch runs" copy is retired because
          # the orchestrator now owns the full pipeline.
          return {
            'kind'        => 'empty-idle',
            'headline'    => 'CAD 尚未处理',
            'subtitle'    => '点击"开始处理"以创建安全工作副本并自动完成全部检查',
            'chips'       => [],
            'cta'         => nil,
            'cta_callback' => nil
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
              'cta'         => '重新检测',
              'cta_callback' => 'refresh_cad_prep'
            }.freeze
          end
          return {
            'kind'        => 'clean',
            'headline'    => 'CAD 状态良好',
            'subtitle'    => '未发现需要处理的问题',
            'chips'       => [],
            'cta'         => nil,
            'cta_callback' => nil
          }.freeze
        when 'STALE'
          return {
            'kind'        => 'issues',
            'headline'    => '工作副本已失效',
            'subtitle'    => '源对象已被修改或 SketchUp 撤销了一次操作',
            'chips'       => [{ 'value' => 1, 'label' => '需重新生成' }],
            'cta'         => nil,
            'cta_callback' => nil
          }.freeze
        when 'FAILED'
          # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
          # §7.2): FAILED issue summary has NO normal
          # `閲嶆柊妫€娴媊 CTA. The existing recovery banner
          # owns explicit recovery (`重新生成工作副本` /
          # `放弃工作副本`).
          return {
            'kind'        => 'issues',
            'headline'    => '处理失败',
            'subtitle'    => _failure_subtitle(snap),
            'chips'       => [{ 'value' => 1, 'label' => '失败' }],
            'cta'         => nil,
            'cta_callback' => nil
          }.freeze
        when 'SCANNING'
          return {
            'kind'        => 'empty-idle',
            'headline'    => '正在准备...',
            'subtitle'    => '正在创建安全工作副本',
            'chips'       => [],
            'cta'         => nil,
            'cta_callback' => nil
          }.freeze
        end
        # NEEDS_ATTENTION — collect chips from cards. Per
        # BLOCK 2, when NEEDS_ATTENTION is driven by stage-
        # bound UNCOMPUTED / BLOCKED / FAILED cards (rather
        # than actionable counts), the chips list may be
        # empty AND the headline MUST be truthful (no fake
        # "发现 0 类" text).
        chips = _collect_chips(cards, include_zero: false)
        stage_bound_ids = %w[duplicate_cleanup planar_normalization
                             gap_endpoint structure_region]
        stage_uncomputed = cards.any? { |c| stage_bound_ids.include?(c['id']) &&
                                            c['state'] == 'UNCOMPUTED' }
        stage_blocked    = cards.any? { |c| stage_bound_ids.include?(c['id']) &&
                                            %w[BLOCKED FAILED].include?(c['state']) }
        has_review       = cards.any? { |c| c['state'] == 'REVIEW_REQUIRED' }
        has_actionable   = cards.any? { |c| c['state'] == 'ACTIONABLE' }
        # Ruby 2.2 compatibility: Integer#positive? and
        # Array#sum were added in Ruby 2.3 / 2.4 respectively.
        # Use explicit `> 0` and inject-based reduction so the
        # presenter stays parseable on the project's legacy
        # baseline (SU2017 Ruby 2.2.4 / SU2020 Ruby 2.5.5).
        chip_total = chips.inject(0) { |acc, c| acc + c['value'].to_i }
        headline =
          if chips.length > 0
            "发现 #{chips.length} 类 · #{chip_total} 项问题"
          elsif stage_uncomputed
            '仍有未检查项'
          elsif stage_blocked
            '存在被阻塞的检查项'
          elsif has_review && !has_actionable
            '存在需人工查看的问题'
          else
            '发现需要处理的问题'
          end
        {
          'kind'        => 'issues',
          'headline'    => headline,
          'subtitle'    => nil,
          'chips'       => chips,
          'cta'         => '重新检测',
          'cta_callback' => 'refresh_cad_prep'
        }.freeze
      end

      # V1.9A-A2 ERROR BOUNDARY NARROW CORRECTION dispatch
      # §4 (A2-UX-01): the primary FAILED copy MUST stay
      # user-readable. Raw `last_error` strings / exception
      # class names / backtraces MUST NOT leak into the
      # product-facing headline / subheadline / issue
      # summary subtitle / recovery description. Technical
      # detail remains reachable via the legacy raw payload
      # (`derivedWorkspace` / 详情 data) and via the Ruby
      # Console / `_safe_invoke` log channel — those are
      # the dedicated debugging surfaces, not the primary
      # product copy.
      FAILED_SUBTITLE_CN = '检查过程中遇到错误，请重试或查看详情'.freeze

      def _failure_subtitle(_snap)
        # Primary FAILED copy is the FROZEN generic
        # Simplified Chinese product message. The technical
        # `last_error` is NOT surfaced here (it lives in the
        # raw 详情 payload / Ruby Console log). A snapshot
        # argument is accepted for backward compatibility
        # with existing call sites; it is intentionally
        # ignored.
        FAILED_SUBTITLE_CN
      end

      # Per-card metric keys that semantically represent
      # CURRENT ATTENTION (actionable counts + review-required
      # counts + FAILED counts + source-registry secondary
      # issue type counts). Frozen list — surface only these
      # as primary issue chips. CLEAN / APPLIED success metrics
      # (closed_loops, regions, holes, repaired counts, etc.)
      # MUST NOT inflate the primary issue count (P1-B
      # dispatch §2.3 truth rule).
      PROBLEM_METRIC_LABELS = %w[
        可校正
        异常点
        可安全修复
        需人工确认
        失败
        短边
        坐标异常
      ].freeze

      # Backwards-compatibility: legacy test fixtures +
      # test_v19a_cad_prep_workflow_presenter unit tests
      # pass `metric['label']` strings like '已处理' / '已
      # Those are deliberately excluded from the chip list
      # (they describe completed work, not current problems).
      # When a test asserts the OLD
      # `_collect_chips(include_zero: true)` behavior it
      # passes include_zero to control zero-suppression only.
      # The semantic filter (PROBLEM_METRIC_LABELS) is the
      # NEW correctness contract; we still preserve the
      # include_zero parameter so existing tests pass.
      def _is_problem_metric?(mm)
        return false unless mm.is_a?(Hash)
        lbl = mm['label'].to_s
        return false if lbl.empty?
        # Allow through problem-semantic labels.
        return true if PROBLEM_METRIC_LABELS.include?(lbl)
        # Allow through non-frozen labels that come from the
        # `other` catch-all card (the presenter emits them via
        # _other_issue_label which is part of the dynamic
        # IssueRegistry per-type breakdown). They are CURRENT
        # ATTENTION by definition — they exist only because
        # the registry reported non-zero counts. They use the
        # raw issue_type as the metric label (e.g. 'short_
        # edge' for legacy strings), but the presenter's
        # `_build_other_card` rewrites the labels to the CN
        # form before publishing.
        false
      end

      # Collect error-only chips from the per-card metrics.
      # Per dispatch §8 zero-value categories are hidden. Per
      # dispatch §2.3 (P1-B issue-chip semantics), only
      # metrics that semantically represent CURRENT attention
      # are surfaced as chips: closed_loops / regions / holes /
      # applied counts / repaired counts / CLEAN success
      # metrics MUST NOT inflate the issue chip list.
      #
      # Implementation strategy:
      #   1. When the cards include ACTIONABLE / REVIEW_REQUIRED /
      #      FAILED states, those cards' metric rows are
      #      CURRENT attention and may surface as chips (after
      #      zero-suppression). CLEAN / APPLIED cards' metrics
      #      describe completed work and are excluded.
      #   2. The `other` catch-all card is always REVIEW_REQUIRED
      #      when populated, so its metrics are always
      #      CURRENT attention.
      #   3. Numeric counts of closed_loops / regions / holes
      #      never appear here because they are CLEAN-state
      #      metrics and never co-occur with the problematic
      #      attention metrics on a single card. Defense-in-
      #      depth: the explicit label whitelist above
      #      PROBLEM_METRIC_LABELS guarantees success metrics
      #      can never leak.
      def _collect_chips(cards, include_zero:)
        chips = []
        cards.each do |c|
          next unless c.is_a?(Hash)
          next unless c['metrics'].is_a?(Array)
          # Filter to current-attention cards only. CLEAN /
          # APPLIED cards describe completed work; their
          # metrics MUST NOT be aggregated as problems.
          st = c['state'].to_s
          attention_states = %w[ACTIONABLE REVIEW_REQUIRED FAILED BLOCKED]
          # The `other` catch-all card is structurally always
          # REVIEW_REQUIRED when populated, but defensive
          # allow APPLIED-edges through the filter if a card
          # carries a problem label so we never lose current
          # attention.
          unless attention_states.include?(st)
            # Allow through when an explicit problem metric
            # label is present on the card (defense-in-depth).
            next unless c['metrics'].any? { |mm| _is_problem_metric?(mm) }
          end
          c['metrics'].each do |mm|
            next unless _is_problem_metric?(mm)
            v = mm['value']
            next if v.nil?
            v_int = v.to_i
            next if v_int <= 0 && !include_zero
            chips << { 'value' => v_int, 'label' => mm['label'].to_s }
          end
        end
        chips
      end

      # ---- headlines ----------------------------------------------

      def _build_headlines(overall, cards, snap, analysis_summary)
        case overall
        when 'IDLE'
          # V1.9A-A2 (dispatch §8.1): the IDLE headline +
          # subheadline now truthfully promise automatic
          # full diagnostics (the orchestrator runs after
          # start_cad_prep). The A1 truthful "only the V1.5
          # duplicate batch runs" copy is retired because
          # the orchestrator now owns the full pipeline.
          return ['CAD 尚未处理', '开始后将创建安全工作副本并自动完成全部检查']
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
        # NEEDS_ATTENTION. Per BLOCK 2 the headline must
        # distinguish WHY the user still has work to do:
        #   - ACTIONABLE   => explicit safe repair is ready
        #   - REVIEW_REQUIRED (without ACTIONABLE) =>
        #                      user must view it
        #   - stage-bound UNCOMPUTED => diagnostics not yet
        #                      run; user must trigger them
        #                      (A2 owns full auto-orchestration;
        #                      A1 must NOT fake it)
        #   - stage-bound BLOCKED / FAILED =>
        #                      configuration / host issue
        actionable_count = cards.count { |c| c['state'] == 'ACTIONABLE' }
        if actionable_count > 0
          return ['发现需要处理的问题', nil]
        end
        stage_bound_ids = %w[duplicate_cleanup planar_normalization
                             gap_endpoint structure_region]
        if cards.any? { |c| stage_bound_ids.include?(c['id']) &&
                             c['state'] == 'UNCOMPUTED' }
          return ['仍有未检查项', '请逐项检查未完成的诊断']
        end
        if cards.any? { |c| stage_bound_ids.include?(c['id']) &&
                             %w[BLOCKED FAILED].include?(c['state']) }
          return ['存在被阻塞的检查项', '请检查容差或输入数据']
        end
        # Only review-required cards remain (no actionable,
        # no UNCOMPUTED-stage-bound, no BLOCKED/FAILED).
        return ['存在需人工查看的问题', '当前未自动修复']
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
          if applied > 0
            metrics << { 'value' => applied, 'label' => '已处理' }
          end
          if skipped > 0
            metrics << { 'value' => skipped, 'label' => '跳过' }
          end
          # Surface the pre / post pair counts only when they
          # are truthful integers (tolerance was captured).
          if before.is_a?(Integer) && after.is_a?(Integer)
            metrics << { 'value' => [before - after, 0].max, 'label' => '已合并重复对' }
          end
          state_label = if applied > 0
                          "已自动处理 #{applied} 条"
                        else
                          '无重复线'
                        end
          return {
            'id'               => 'duplicate_cleanup',
            'state'            => applied > 0 ? 'APPLIED' : 'CLEAN',
            'state_label'      => state_label,
            'title'            => CARD_TITLES_CN['duplicate_cleanup'],
            'summary'          => applied > 0 ? '高置信度自动修复已应用于工作副本' : '未检测到需要清理的重复线',
            'metrics'          => metrics,
            'primary_action'   => nil,
            'secondary_action' => nil,
            'detail_filter'    => 'duplicate'
          }.freeze
        end
        # Ready but no duplicate repair has run (unusual —
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
          #
          # V1.9A FINAL BLOCK FIX P2-A (dispatch §4.1):
          # `movable_count` is the AUTHORITATIVE planar
          # proposal field. Legacy `movable` / `proposed_movable`
          # aliases remain as defensive fallback for older
          # callers / tests that publish those keys.
          proposal = pn['proposal'].is_a?(Hash) ? pn['proposal'] : {}
          movable  = _planar_count_field(proposal, 'movable_count', 'movable', 'proposed_movable')
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
          # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
          # `applied_count` is the AUTHORITATIVE planar
          # display the LOGICAL corrected-point count.
          # Prefer `logical_applied_count` (the new frozen
          # field); fall back to legacy `applied_count` only
          # when `logical_applied_count` is absent. The
          # frozen count schema (amendment §5) keeps
          # `applied_count` as a physical-count alias for
          # backward compatibility with audit consumers.
          moved = _planar_count_field(
            audit,
            'logical_applied_count',
            'applied_count',
            'moved',
            'moved_applied'
          )
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
        parts << "发现 #{movable} 个可安全校正点" if movable.is_a?(Integer) && movable > 0
        parts << "另有 #{outliers} 个异常点不会自动校正" if outliers.is_a?(Integer) && outliers > 0
        # V1.9A FINAL BLOCK FIX P2-A (dispatch §4.1):
        # READY_TO_NORMALIZE without an exact truthful count
        # MUST use a generic truthful copy ("发现可安全
        # 校正的 Z 偏差") rather than the contradictory
        # READY_TO_NORMALIZE -by definition the analyzer
        # found at least one candidate).
        return '发现可安全校正的 Z 偏差' if parts.empty?
        parts.join('，')
      end

      # Resolve a planar count field with frozen
      # authoritative key + legacy fallback aliases.
      # Returns the Integer value, or nil when no key
      # resolves. Per dispatch §4.1 (P2-A) the
      # AUTHORITATIVE keys are:
      #   - READY_TO_NORMALIZE proposal: 'movable_count'
      #   - APPLIED audit:               'applied_count'
      # Legacy aliases ('movable' / 'proposed_movable' /
      # 'moved' / 'moved_applied') remain as defensive
      # fallbacks for older tests / callers.
      def _planar_count_field(source_hash, *keys)
        return nil unless source_hash.is_a?(Hash)
        keys.each do |k|
          v = source_hash[k.to_s]
          v = source_hash[k.to_sym] if v.nil?
          return v if v.is_a?(Integer)
        end
        nil
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
          # V1.9A-A2 dispatch §5.1: gap-ordering safety.
          # When planar state is READY_TO_NORMALIZE, the
          # gap repair action MUST be disabled so the user
          # is not invited to mutate geometry known to be
          # pending a deterministic Z normalization. After
          # the user applies Z, the orchestrator's apply
          # path invalidates V1.7 state and recomputes gap;
          # if gap is still actionable, the button is
          # re-enabled by the same recompute.
          #
          # The orchestrator's apply_gap_and_refresh is the
          # defense-in-depth backstop (it refuses mutation
          # when planar is still READY_TO_NORMALIZE even
          # if a buggy UI dispatches the callback).
          planar_actionable = _planar_actionable?(snap)
          summary_text = if planar_actionable
                           ready.is_a?(Integer) ?
                             "#{ready} 处间隙可安全修复；需先完成 Z 轴校正后重新确认" :
                             '需先完成 Z 轴校正后重新确认'
                         else
                           ready.is_a?(Integer) ? "#{ready} 处间隙两端均在端点容差内" : '当前存在可安全修复的间隙'
                         end
          {
            'id'               => 'gap_endpoint',
            'state'            => 'ACTIONABLE',
            'state_label'      => '发现安全修复项',
            'title'            => CARD_TITLES_CN['gap_endpoint'],
            'summary'          => summary_text,
            'metrics'          => metrics,
            'primary_action'   => {
              'label'    => '修复间隙',
              'callback' => 'apply_gap_repair',
              # V1.9A-A2: gate the action when planar is
              # still actionable. Defense-in-depth: the
              # orchestrator ALSO refuses the mutation.
              'enabled'  => planar_actionable ? false : true
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

      # V1.9A-A2 dispatch §5.1: gap-ordering safety.
      # Returns true when the current planar state is
      # READY_TO_NORMALIZE. The gap card's primary_action
      # MUST be disabled in this state so the user is
      # not invited to mutate geometry known to be
      # pending a deterministic Z normalization.
      def _planar_actionable?(snap)
        return false if snap.nil? || !snap.is_a?(Hash)
        pn = snap['planar_normalization']
        return false unless pn.is_a?(Hash)
        pn['state'].to_s == 'READY_TO_NORMALIZE'
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
          # V1.9A FINAL BLOCK FIX P2-B (dispatch §5):
          # structure warning copy MUST be specific when
          # current evidence exists. Preferred mapping:
          #   - open_chains > 0
          #     -> summary communicates "存在未闭合轮廓"
          #   - invalid_loop_count > 0 AND loop flags include
          #     'non_planar_loop'
          #     -> summary communicates "存在非平面闭合
          #   - other known invalid-loop / unresolved reasons
          #     -> concise corresponding generic
          #        "存在无效轮廓或需确认结构"
          #   - only when no more specific evidence is
          #     available may the fallback "结构已重建，
          #     但存在需要人工查看的项" render.
          # The V1.8 reconstruction algorithm is UNCHANGED;
          # this only improves the product-facing copy.
          invalid_loop_count = _structure_invalid_loop_count(sr)
          loop_flags          = _structure_loop_flags(sr)
          # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
          # §7.1): prefer the frozen V1.8 key
          # `open_chain_count`; legacy `open_chains` remains
          # as a defensive backward-compatibility fallback.
          open_chains_count   = _structure_open_chain_count(metrics)
          metric_keys_for_chip = _structure_warning_metric_keys(
            open_chains_count, invalid_loop_count, loop_flags
          )
          summary_text = _structure_warning_summary(
            open_chains_count, invalid_loop_count, loop_flags
          )
          {
            'id'               => 'structure_region',
            'state'            => 'REVIEW_REQUIRED',
            'state_label'      => '存在需检查项',
            'title'            => CARD_TITLES_CN['structure_region'],
            'summary'          => summary_text,
            'metrics'          => _structure_metrics(metrics, metric_keys_for_chip),
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
                        _structure_metrics(metrics, %w[open_chain_count]))
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
            'metrics'          => _structure_metrics(metrics, %w[open_chain_count]),
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

      # Build the structure card's metric chips. The keys
      # list is the preferred V1.8 names
      # (`open_chain_count` / `invalid_loop_count` /
      # `closed_loops` / `regions` / `holes`). Each
      # preferred name has a small set of legacy alias
      # names that may appear in older fixtures / test
      # payloads. The chip is surfaced under the PREFERRED
      # name (so the UI label is consistent) but the
      # VALUE is read from whichever alias carries data.
      #
      # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
      # §7.1): the frozen V1.8 metric keys win; legacy
      # aliases remain as defensive backward-compatibility
      # fallbacks only.
      def _structure_metrics(metrics, keys)
        out = []
        keys.each do |k|
          v = _metric_value_with_aliases(metrics, k, *_structure_legacy_aliases(k))
          next unless v.is_a?(Integer) && v > 0
          out << { 'value' => v, 'label' => _structure_label_for(k) }
        end
        out
      end

      # Read a metric value with legacy-alias fallback.
      # Tries the preferred key (String + Symbol), then
      # each legacy alias (String + Symbol). Returns the
      # first Integer-typed value found, or nil when no
      # alias carries an Integer.
      def _metric_value_with_aliases(metrics, preferred_key, *legacy_aliases)
        return nil unless metrics.is_a?(Hash)
        candidates = [preferred_key].concat(legacy_aliases)
        candidates.each do |k|
          v = metrics[k.to_s]
          v = metrics[k.to_sym] if v.nil?
          return v if v.is_a?(Integer)
        end
        nil
      end

      # Legacy alias map for the structure card's metric
      # chips. Each frozen V1.8 preferred key may have
      # older aliases (pre-amendment fixtures /
      # pre-amendment callers) that are tolerated for
      # backward compatibility.
      #
      # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
      # §7.1): legacy aliases are read-only fallbacks;
      # the UI chip always uses the preferred key's
      # label.
      def _structure_legacy_aliases(preferred_key)
        case preferred_key.to_s
        when 'open_chain_count' then ['open_chains'].freeze
        when 'invalid_loop_count' then [].freeze
        else [].freeze
        end
      end

      # Read the invalid_loop_count from a structure_reconstruction
      # sub-snapshot. Falls back to 0 when the field is missing /
      # non-integer. The field may live under metrics, at the
      # top level, or under a nested hash depending on the
      # V1.8 audit shape.
      def _structure_invalid_loop_count(sr)
        return 0 unless sr.is_a?(Hash)
        m = sr['metrics'].is_a?(Hash) ? sr['metrics'] : (sr[:metrics].is_a?(Hash) ? sr[:metrics] : {})
        v = m['invalid_loop_count']
        v = m[:invalid_loop_count] if v.nil?
        v = sr['invalid_loop_count'] if v.nil?
        v = sr[:invalid_loop_count] if v.nil?
        v.is_a?(Integer) ? v : 0
      end

      # V1.9A P0 SHARED-VERTEX CORRECTION (amendment §7.1):
      # Read the open-chain metric. The actual V1.8 frozen
      # key is `open_chain_count` (singular + `_count`).
      # Legacy `open_chains` (plural) remains as a defensive
      # backward-compatibility fallback for older test
      # fixtures and pre-amendment callers. Returns 0 when
      # no key resolves.
      def _structure_open_chain_count(metrics)
        return 0 unless metrics.is_a?(Hash)
        v = metrics['open_chain_count']
        v = metrics[:open_chain_count] if v.nil?
        # Legacy alias -defensively tolerated.
        v = metrics['open_chains']      if v.nil?
        v = metrics[:open_chains]       if v.nil?
        v.is_a?(Integer) ? v : 0
      end

      # V1.9A P0 SHARED-VERTEX CORRECTION (amendment §7.1):
      # Read the loop unresolved_flags list. The actual V1.8
      # frozen shape publishes flags inside each
      # `closed_loops[]` record's `unresolved_flags` Array.
      # Older fixtures may carry `unresolved_flags` at the
      # top level or under metrics; tolerate those as
      # backward-compatibility fallbacks. The flattened flag
      # list is the union of ALL per-loop flag Arrays plus
      # any legacy top-level / metrics-level fallback. Returns
      # an Array<String>.
      def _structure_loop_flags(sr)
        return [] unless sr.is_a?(Hash)
        flags = []
        # Preferred shape: closed_loops[].unresolved_flags.
        closed_loops = sr['closed_loops']
        closed_loops = sr[:closed_loops] if closed_loops.nil?
        if closed_loops.is_a?(Array)
          closed_loops.each do |loop|
            next unless loop.is_a?(Hash)
            raw = loop['unresolved_flags']
            raw = loop[:unresolved_flags] if raw.nil?
            next unless raw.is_a?(Array)
            raw.each { |x| flags << x.to_s }
          end
        end
        # Backward-compatibility fallbacks (older fixtures
        # and pre-amendment V1.8 audit shapes).
        legacy = sr['unresolved_flags']
        legacy = sr[:unresolved_flags] if legacy.nil?
        legacy = sr['loop_flags']      if legacy.nil?
        legacy = sr[:loop_flags]       if legacy.nil?
        m = sr['metrics'].is_a?(Hash) ? sr['metrics'] : {}
        legacy = m['unresolved_flags'] if legacy.nil?
        legacy = m[:unresolved_flags]  if legacy.nil?
        if legacy.is_a?(Array)
          legacy.each { |x| flags << x.to_s }
        end
        flags.uniq
      end

      # Decide which metric keys are CURRENT attention chips
      # for the structure card under READY_WITH_WARNINGS.
      # open_chain_count / invalid_loop_count are problem
      # metrics. closed_loops / regions / holes are CLEAN-
      # state success metrics that MUST NOT inflate the
      # chip list (P1-B dispatch §2.3 truth rule).
      #
      # V1.9A P0 SHARED-VERTEX CORRECTION (amendment §7.1):
      # prefer the frozen V1.8 key `open_chain_count` (with
      # legacy `open_chains` fallback) for the chip
      # selection. Returns Array<String> of preferred keys.
      def _structure_warning_metric_keys(open_chains, invalid_loops, loop_flags)
        keys = []
        keys << 'open_chain_count'   if open_chains.is_a?(Integer) && open_chains > 0
        keys << 'invalid_loop_count' if invalid_loops.is_a?(Integer) && invalid_loops > 0
        keys
      end

      # Truthful specific summary copy for READY_WITH_WARNINGS.
      # Per dispatch §5, prefer specific evidence over the
      # generic fallback. The fallback ONLY renders when no
      # specific evidence is available (defense-in-depth: this
      # branch is reachable only when metrics carry no problem
      # keys, which means the user already has all the
      # information needed and the UI is just acknowledging
      # the warning state).
      def _structure_warning_summary(open_chains, invalid_loops, loop_flags)
        non_planar = loop_flags.any? { |f| f.to_s.include?('non_planar') }
        if invalid_loops.is_a?(Integer) && invalid_loops > 0 && non_planar
          return '存在非平面闭合轮廓，暂不能形成区域'
        end
        if open_chains.is_a?(Integer) && open_chains > 0
          return '存在未闭合轮廓'
        end
        if invalid_loops.is_a?(Integer) && invalid_loops > 0
          return '存在无效轮廓或需确认结构'
        end
        '结构已重建，但存在需要人工查看的项'
      end

      def _structure_label_for(k)
        case k.to_s
        # V1.9A P0 SHARED-VERTEX CORRECTION (amendment
        # §7.1): prefer the frozen V1.8 key
        # `open_chain_count` (singular + `_count`); legacy
        # `open_chains` is tolerated as a defensive alias
        # for older fixtures.
        when 'open_chain_count', 'open_chains' then '开放链'
        when 'invalid_loop_count'             then '无效轮廓'
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
          secondary[type.to_s] = n if n > 0
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
