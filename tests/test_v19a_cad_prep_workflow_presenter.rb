#
# tests/test_v19a_cad_prep_workflow_presenter.rb
#
# V1.9A-A1 — pure / testable presentation model unit tests.
#
# Per dispatch §13 (Presenter focused tests):
#   - idle mapping;
#   - workspace ready + planar uncomputed;
#   - planar actionable;
#   - gap actionable;
#   - structure READY;
#   - structure READY_WITH_WARNINGS;
#   - stale/failed;
#   - NOT_COMPUTED never → CLEAN;
#   - zero issue categories omitted;
#   - raw inventory absent from primary summary.
#
# These tests pin the presenter contract to the dispatch
# §13 deliverables. They do NOT require a real SketchUp
# host and do NOT load any geometry algorithm. They are
# pure / deterministic / idempotent.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/cad_prep_workflow_presenter'
require_relative '../extension/su_ai_plugin/core/issue_registry'
require_relative '../extension/su_ai_plugin/core/issue_normalizer'
require_relative '../extension/su_ai_plugin/core/issue_enricher'
require_relative '../extension/su_ai_plugin/core/analysis_result'
require 'set'

include SUAnalysis::Extension
include SUAnalysis::Core

# --- helpers --------------------------------------------------------

def v19a_make_ar(extra_summary = {})
  reg = IssueRegistry.new([])
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count, :face_count, :faces_with_holes_count).new(10, 12, 0, 0, 0, 0)
  AnalysisResult.new(preflight: pf, registry: reg,
                     selection_type: 'Group', selection_label: '别墅平面图')
end

def v19a_present(ar, snap)
  CadPrepWorkflowPresenter.present(analysis_result: ar, workspace_snapshot: snap)
end

# --- schema / payload shape -----------------------------------------

test 'v19a_presenter: payload top-level keys are exactly the locked schema' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  expected = Set.new(%w[schema_version overall_state headline subheadline selection issue_summary cards recovery])
  actual   = Set.new(payload.keys)
  assert_equal expected, actual,
               "expected top-level keys #{expected.to_a.sort}, got #{actual.to_a.sort}"
end

test 'v19a_presenter: schema_version is "1"' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  assert_equal '1', payload['schema_version']
end

test 'v19a_presenter: payload is deeply JSON-safe (no Symbol / no Time / no Class)' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  walker = ->(obj, path) {
    case obj
    when Hash
      obj.each do |k, v|
        assert k.is_a?(String), "non-String key at #{path}.#{k.inspect}"
        walker.call(v, "#{path}.#{k}")
      end
    when Array
      obj.each_with_index { |v, i| walker.call(v, "#{path}[#{i}]") }
    when String, Numeric, TrueClass, FalseClass, NilClass
      # OK
    else
      raise "non-JSON-safe value at #{path}: #{obj.class}"
    end
  }
  walker.call(payload, '$')
end

# --- IDLE ------------------------------------------------------------

test 'v19a_presenter: IDLE — workspace none — overall_state=IDLE, headline, 5 cards UNCOMPUTED, no recovery' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  assert_equal 'IDLE', payload['overall_state']
  assert_equal 'CAD 尚未处理', payload['headline']
  # V1.9A-A2 dispatch §8.1: the IDLE copy now
  # truthfully promises automatic full diagnostics
  # (the orchestrator's start path runs prepare +
  # V1.5 duplicate batch + V1.6 planar compute +
  # V1.7 gap compute + V1.8 structure compute in
  # one user click). The A1 truthful "only the V1.5
  # duplicate batch runs" copy is RETIRED because
  # the orchestrator now owns the full pipeline.
  assert_equal '开始后将创建安全工作副本并自动完成全部检查', payload['subheadline'],
               'V1.9A-A2 IDLE subheadline MUST truthfully promise automatic full diagnostics (orchestrator owns the pipeline)'
  assert_equal 5, payload['cards'].length
  payload['cards'].each do |c|
    assert_equal 'UNCOMPUTED', c['state'],
                 "IDLE card #{c['id']} must be UNCOMPUTED (not CLEAN)"
  end
  assert_nil payload['recovery']
  # Issue summary kind == empty-idle; subtitle must match the
  # truthful IDLE copy.
  assert_equal 'empty-idle', payload['issue_summary']['kind']
  assert_equal [], payload['issue_summary']['chips']
  assert_equal '点击"开始处理"以创建安全工作副本并自动完成全部检查',
               payload['issue_summary']['subtitle'],
               'V1.9A-A2 IDLE issue_summary subtitle MUST truthfully promise automatic full diagnostics (orchestrator owns the pipeline)'
end

test 'v19a_presenter (A2): IDLE copy now claims full diagnosis are automatically completed' do
  # V1.9A-A2 dispatch §8.1: the IDLE copy now
  # truthfully promises automatic full diagnostics
  # because the orchestrator's start path runs
  # prepare + V1.5 duplicate + V1.6 planar compute +
  # V1.7 gap compute + V1.8 structure compute in
  # one user click. The presenter is the only
  # writer of the IDLE headline / subheadline /
  # issue_summary subtitle. Guard against future
  # drift by grepping the source for the FROZEN
  # A2 IDLE copy.
  src = File.read(File.expand_path('../extension/su_ai_plugin/cad_prep_workflow_presenter.rb', __dir__))
  # A1 truthful-but-stale copy: "duplicate batch only".
  # MUST be retired because the orchestrator now runs
  # the full pipeline on prepare.
  forbidden = [
    '点击"开始处理"以创建安全工作副本并自动清理高置信度重复线',
    '开始后将创建安全工作副本并自动清理高置信度重复线'
  ]
  forbidden.each do |frag|
    refute_includes src, frag,
                 "presenter source MUST NOT contain the retired A1 IDLE copy fragment #{frag.inspect} (A2 orchestrator owns the full pipeline)"
  end
  # A2 frozen IDLE copy MUST be present.
  assert_includes src, '点击"开始处理"以创建安全工作副本并自动完成全部检查',
                  'presenter source MUST contain the frozen A2 IDLE issue_summary subtitle'
  assert_includes src, '开始后将创建安全工作副本并自动完成全部检查',
                  'presenter source MUST contain the frozen A2 IDLE subheadline'
end

test 'v19a_presenter: IDLE — discarded workspace is treated as IDLE' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'discarded' })
  assert_equal 'IDLE', payload['overall_state']
end

# --- SCANNING --------------------------------------------------------

test 'v19a_presenter: SCANNING — workspace building — overall=SCANNING, all cards CHECKING' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'building' })
  assert_equal 'SCANNING', payload['overall_state']
  payload['cards'].each do |c|
    assert_equal 'CHECKING', c['state'],
                 "building card #{c['id']} must be CHECKING"
  end
  assert_nil payload['recovery']
end

# --- READY_FOR_VALIDATION (clean) ----------------------------------

test 'v19a_presenter: READY_FOR_VALIDATION — clean ready workspace, no actionable / review' do
  snap = {
    'state' => 'ready',
    'duplicate_repair'    => { 'actions_applied' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => {
      'computed' => true, 'state' => 'READY',
      'metrics' => { 'closed_loops' => 12, 'regions' => 8 }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'READY_FOR_VALIDATION', payload['overall_state']
  assert_equal 'clean', payload['issue_summary']['kind']
  assert_nil payload['recovery']
  assert_equal 'CAD 状态良好', payload['headline']
end

# --- READY_FOR_VALIDATION (with APPLIED) ---------------------------

test 'v19a_presenter: READY_FOR_VALIDATION — ready with APPLIED cards shows headline accordingly' do
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 4 },
    'planar_normalization' => {
      'computed' => true, 'state' => 'APPLIED',
      'audit' => { 'moved' => 12 }
    },
    'topology_repair'      => { 'computed' => true, 'state' => 'APPLIED',
                                'audit' => { 'applied' => 3 } },
    'structure_reconstruction' => {
      'computed' => true, 'state' => 'READY',
      'metrics' => { 'closed_loops' => 12, 'regions' => 8 }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'READY_FOR_VALIDATION', payload['overall_state']
  # The "completed" headline includes 已应用 because some
  # cards are APPLIED. Per the existing frozen READY_FOR_VALIDATION
  # behavior, APPLIED cards surface as "已完成" (kind=issues)
  # rather than "CAD 状态良好" (kind=clean) -- so the user
  # knows safe repairs were applied.
  assert_match(/已完成/, payload['headline'])
  # Planar card state == APPLIED.
  planar = payload['cards'].find { |c| c['id'] == 'planar_normalization' }
  assert_equal 'APPLIED', planar['state']
  assert_equal '已校正', planar['state_label']
end

# --- NEEDS_ATTENTION (planar actionable) ----------------------------

test 'v19a_presenter: NEEDS_ATTENTION — planar READY_TO_NORMALIZE, action wired' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => {
      'computed' => true, 'state' => 'READY_TO_NORMALIZE',
      'proposal' => {
        'state' => 'READY_TO_NORMALIZE',
        'movable' => 12,
        'outlier_count' => 2
      }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'NEEDS_ATTENTION', payload['overall_state']
  planar = payload['cards'].find { |c| c['id'] == 'planar_normalization' }
  assert_equal 'ACTIONABLE', planar['state']
  refute_nil planar['primary_action'], 'planar ACTIONABLE MUST carry a primary_action'
  assert_equal '修复 Z 轴', planar['primary_action']['label']
  assert_equal 'apply_planar_normalization', planar['primary_action']['callback']
  assert_equal true, planar['primary_action']['enabled']
  # Issue summary carries the chips
  chips = payload['issue_summary']['chips']
  assert chips.length >= 2
  labels = chips.map { |c| c['label'] }
  assert_includes labels, '可校正'
  assert_includes labels, '异常点'
end

# --- NEEDS_ATTENTION (gap actionable) -------------------------------

test 'v19a_presenter: NEEDS_ATTENTION — gap READY_TO_REPAIR, action wired' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair' => {
      'computed' => true, 'state' => 'READY_TO_REPAIR',
      'proposal' => { 'ready_proposals' => [1, 2, 3] }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'NEEDS_ATTENTION', payload['overall_state']
  gap = payload['cards'].find { |c| c['id'] == 'gap_endpoint' }
  assert_equal 'ACTIONABLE', gap['state']
  refute_nil gap['primary_action']
  assert_equal '修复间隙', gap['primary_action']['label']
  assert_equal 'apply_gap_repair', gap['primary_action']['callback']
end

# --- NEEDS_ATTENTION (review) --------------------------------------

test 'v19a_presenter: NEEDS_ATTENTION — planar REVIEW_REQUIRED, secondary action' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => {
      'computed' => true, 'state' => 'REVIEW_REQUIRED',
      'proposal' => { 'outlier_count' => 2 }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'NEEDS_ATTENTION', payload['overall_state']
  planar = payload['cards'].find { |c| c['id'] == 'planar_normalization' }
  assert_equal 'REVIEW_REQUIRED', planar['state']
  assert_equal '需要人工确认', planar['state_label']
  refute_nil planar['secondary_action']
  assert_equal '查看问题', planar['secondary_action']['label']
end

# --- READY + planar UNCOMPUTED: card stays UNCOMPUTED, exposes 检查平面偏差 action

test 'v19a_presenter: ready workspace + planar not-yet-computed -> card UNCOMPUTED with compute action' do
  snap = {
    'state' => 'ready'
    # No planar_normalization sub-snapshot.
  }
  payload = v19a_present(v19a_make_ar, snap)
  planar = payload['cards'].find { |c| c['id'] == 'planar_normalization' }
  assert_equal 'UNCOMPUTED', planar['state'],
               'NOT_COMPUTED must NEVER be rendered as CLEAN'
  refute_nil planar['primary_action']
  assert_equal '检查平面偏差', planar['primary_action']['label']
  assert_equal 'compute_planar_normalization', planar['primary_action']['callback']
  assert_equal true, planar['primary_action']['enabled']
end

test 'v19a_presenter: ready workspace + planar state=NOT_COMPUTED -> UNCOMPUTED + compute action' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => false, 'state' => 'NOT_COMPUTED' }
  }
  payload = v19a_present(v19a_make_ar, snap)
  planar = payload['cards'].find { |c| c['id'] == 'planar_normalization' }
  assert_equal 'UNCOMPUTED', planar['state']
  refute_nil planar['primary_action']
  assert_equal 'compute_planar_normalization', planar['primary_action']['callback']
end

test 'v19a_presenter: ready workspace + gap not-yet-computed -> UNCOMPUTED + compute_gap_repair action' do
  snap = { 'state' => 'ready' }
  payload = v19a_present(v19a_make_ar, snap)
  gap = payload['cards'].find { |c| c['id'] == 'gap_endpoint' }
  assert_equal 'UNCOMPUTED', gap['state']
  refute_nil gap['primary_action']
  assert_equal 'compute_gap_repair', gap['primary_action']['callback']
end

test 'v19a_presenter: ready workspace + structure not-yet-computed -> UNCOMPUTED + compute_structure_reconstruction action' do
  snap = { 'state' => 'ready' }
  payload = v19a_present(v19a_make_ar, snap)
  sr = payload['cards'].find { |c| c['id'] == 'structure_region' }
  assert_equal 'UNCOMPUTED', sr['state']
  refute_nil sr['primary_action']
  assert_equal 'compute_structure_reconstruction', sr['primary_action']['callback']
end

# --- structure READY / READY_WITH_WARNINGS ---------------------------

test 'v19a_presenter: structure READY -> CLEAN card, headline clean' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => {
      'computed' => true, 'state' => 'READY',
      'metrics' => { 'closed_loops' => 12, 'regions' => 8 }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  sr = payload['cards'].find { |c| c['id'] == 'structure_region' }
  assert_equal 'CLEAN', sr['state']
  assert_equal '结构可用', sr['state_label']
end

test 'v19a_presenter: structure READY_WITH_WARNINGS -> REVIEW_REQUIRED card' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => {
      'computed' => true, 'state' => 'READY_WITH_WARNINGS',
      'metrics' => { 'open_chains' => 2, 'closed_loops' => 18 }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  sr = payload['cards'].find { |c| c['id'] == 'structure_region' }
  assert_equal 'REVIEW_REQUIRED', sr['state']
  assert_equal '存在需检查项', sr['state_label']
  refute_nil sr['secondary_action']
end

# --- STALE / FAILED -------------------------------------------------

test 'v19a_presenter: STALE — workspace failed + host_state_changed -> STALE overall + recovery banner' do
  snap = {
    'state' => 'failed',
    'last_error' => 'host_state_changed: prior derived handle removed by SketchUp Undo'
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'STALE', payload['overall_state']
  refute_nil payload['recovery']
  assert_equal '重新生成工作副本', payload['recovery']['primary_label']
  assert_equal 'rebuild_workspace', payload['recovery']['primary_callback']
  assert_equal '放弃工作副本', payload['recovery']['secondary_label']
  assert_equal 'discard_workspace', payload['recovery']['secondary_callback']
end

test 'v19a_presenter: FAILED — workspace failed + non-host_state reason -> FAILED overall + recovery banner' do
  snap = {
    'state' => 'failed',
    'last_error' => 'SomeError: build failed mid-way'
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'FAILED', payload['overall_state']
  refute_nil payload['recovery']
  # Failed banner uses is-failed class hint.
  assert_match(/失败/, payload['headline'])
end

# --- CRITICAL TRUTH RULE (NOT_COMPUTED must never be CLEAN) --------

test 'v19a_presenter: NOT_COMPUTED must never be CLEAN for stage-bound cards' do
  # The "stage-bound" cards are duplicate_cleanup,
  # planar_normalization, gap_endpoint, structure_region.
  # The "other" card is the catch-all and may render
  # CLEAN when no secondary issue types exist
  # (dispatch §7 P3 — frozen capability-visibility contract:
  # "the other card can visually empty in clean / P0 / P5
  # cases").
  stage_cards = %w[duplicate_cleanup planar_normalization gap_endpoint structure_region]
  cases = [
    { 'state' => 'none' },
    { 'state' => 'discarded' },
    { 'state' => 'ready' }, # all stages absent
    { 'state' => 'ready', 'planar_normalization' => { 'computed' => false, 'state' => 'NOT_COMPUTED' } },
    { 'state' => 'ready', 'topology_repair' => { 'computed' => false, 'state' => 'NOT_COMPUTED' } },
    { 'state' => 'ready', 'structure_reconstruction' => { 'computed' => false, 'state' => 'NOT_COMPUTED' } }
  ]
  cases.each do |snap|
    payload = v19a_present(v19a_make_ar, snap)
    payload['cards'].select { |c| stage_cards.include?(c['id']) }.each do |c|
      refute_equal 'CLEAN', c['state'],
                   "NOT_COMPUTED leaked to CLEAN for #{c['id']} in snap #{snap.inspect}"
    end
  end
end

# --- zero issue categories omitted (error-only summary) ------------

test 'v19a_presenter: error-only summary omits zero-value categories' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => {
      'computed' => true, 'state' => 'READY_TO_NORMALIZE',
      'proposal' => { 'movable' => 12, 'outlier_count' => 0, 'state' => 'READY_TO_NORMALIZE' }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  chips = payload['issue_summary']['chips']
  chips.each do |c|
    assert c['value'].to_i > 0,
           "issue_summary.chip must NOT include zero-value category, got #{c.inspect}"
  end
end

test 'v19a_presenter: error-only summary never carries raw inventory chips' do
  # Per dispatch §8, the primary summary (处理 tab) MUST NOT
  # carry raw inventory (edge / vertex / face / faces-with-holes
  # counts). The chips are populated only from the current
  # prepared-state actionable / review items.
  snap = { 'state' => 'none' }
  payload = v19a_present(v19a_make_ar, snap)
  summary = payload['issue_summary']
  labels = summary['chips'].map { |c| c['label'] }
  forbidden = %w[线段 顶点 面 含洞面 edges vertices faces holes]
  forbidden.each do |f|
    refute_includes labels, f,
                    "raw inventory #{f.inspect} MUST NOT appear in primary summary"
  end
end

test 'v19a_presenter: ready workspace with all stages CLEAN + duplicate ran cleanly (no APPLIED) -> clean summary' do
  # The "all clean" case requires duplicate_cleanup to have
  # actually run. With actions_applied=0 the duplicate card
  # is CLEAN (state_label "无重复线") rather than APPLIED;
  # the issue_summary kind is therefore `clean` rather than
  # the "已完成" issues-kind path.
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 0, 'duplicate_pairs_before' => 0, 'duplicate_pairs_after' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  payload = v19a_present(v19a_make_ar, snap)
  # ready + all stage-bound cards CLEAN + no review =
  # clean (the user has a workspace; the workspace is
  # genuinely clean). NOT empty-idle.
  assert_equal 'clean', payload['issue_summary']['kind'],
               'all stage-bound cards CLEAN + no review + no APPLIED -> clean summary'
  assert_equal 'READY_FOR_VALIDATION', payload['overall_state']
end

test 'v19a_presenter: ready + all stage-bound cards CLEAN + duplicate ran cleanly (no APPLIED) -> clean empty issue summary' do
  # Same as the previous test but with a non-empty structure
  # metrics payload to exercise the "CLEAN with metrics" branch
  # of _build_issue_summary under READY_FOR_VALIDATION.
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 0, 'duplicate_pairs_before' => 0, 'duplicate_pairs_after' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => {
      'computed' => true, 'state' => 'READY',
      'metrics' => { 'closed_loops' => 12, 'regions' => 8 }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  summary = payload['issue_summary']
  assert_equal 'clean', summary['kind']
  assert_equal [], summary['chips']
  assert_equal 'READY_FOR_VALIDATION', payload['overall_state']
end

# --- "其他需检查项" surfaces non-primary issue types ---------------

test 'v19a_presenter: card "other" surfaces short_edge / abnormal_large_coord / deep_nesting' do
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count, :face_count, :faces_with_holes_count).new(10, 12, 0, 0, 0, 0)
  # Build an IssueRegistry carrying the secondary issue
  # types. registry.summary aggregates by Symbol key
  # `:issue_type`, and AnalysisResult#summary then exposes
  # these under the `issues` key (String-keyed downstream).
  reg = IssueRegistry.new([
    { issue_id: 'short_edge|1|1',               issue_type: 'short_edge',               severity: 'low',  confidence: 'high',
      sources: [], source_entity_ids: [], edge_ids: [], location: nil, message: 'm', metadata: {}, locatable: false, display_length: nil },
    { issue_id: 'short_edge|2|1',               issue_type: 'short_edge',               severity: 'low',  confidence: 'high',
      sources: [], source_entity_ids: [], edge_ids: [], location: nil, message: 'm', metadata: {}, locatable: false, display_length: nil },
    { issue_id: 'abnormal_large_coord|1|1',     issue_type: 'abnormal_large_coord',     severity: 'low',  confidence: 'high',
      sources: [], source_entity_ids: [], edge_ids: [], location: nil, message: 'm', metadata: {}, locatable: false, display_length: nil },
    { issue_id: 'duplicate_edge_candidate|1|1', issue_type: 'duplicate_edge_candidate', severity: 'medium', confidence: 'high',
      sources: [], source_entity_ids: [], edge_ids: [], location: nil, message: 'm', metadata: {}, locatable: false, display_length: nil },
    { issue_id: 'duplicate_edge_candidate|2|1', issue_type: 'duplicate_edge_candidate', severity: 'medium', confidence: 'high',
      sources: [], source_entity_ids: [], edge_ids: [], location: nil, message: 'm', metadata: {}, locatable: false, display_length: nil }
  ])
  ar = AnalysisResult.new(preflight: pf, registry: reg,
                         selection_type: 'Group', selection_label: 'x')
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  payload = v19a_present(ar, snap)
  other = payload['cards'].find { |c| c['id'] == 'other' }
  assert_equal 'REVIEW_REQUIRED', other['state'],
               'card "other" must surface as REVIEW_REQUIRED when secondary issue types exist'
  labels = other['metrics'].map { |m| m['label'] }
  assert_includes labels, '短边', 'short_edge must surface on the other card'
  assert_includes labels, '坐标异常', 'abnormal_large_coord must surface on the other card'
  # duplicate_edge_candidate is excluded (handled on its own card).
  refute_includes labels, '重复线'
end

# --- card order (frozen) --------------------------------------------

test 'v19a_presenter: cards always emitted in the locked order duplicate / planar / gap / structure / other' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  assert_equal %w[duplicate_cleanup planar_normalization gap_endpoint structure_region other],
               payload['cards'].map { |c| c['id'] }
end

# --- BLOCK 2 regression tests (AIPM source review) -----------------
#
# Per dispatch §0 (re-issued 2026-09-04 by AIPM after A1
# source review): a `ready` workspace MUST NOT become
# READY_FOR_VALIDATION while any capability card is still
# UNCOMPUTED / BLOCKED / FAILED / REVIEW_REQUIRED. The
# overall presentation state must reflect the actual rendered
# card states.

test 'v19a_presenter (BLOCK 2): ready + all stage snapshots absent -> overall != READY_FOR_VALIDATION' do
  # No duplicate_repair / planar / gap / structure sub-snapshots.
  # All 4 stage-bound cards will render UNCOMPUTED. The previous
  # bug allowed overall = READY_FOR_VALIDATION in this case.
  snap = { 'state' => 'ready' }
  payload = v19a_present(v19a_make_ar, snap)
  refute_equal 'READY_FOR_VALIDATION', payload['overall_state'],
               'ready + all stages UNCOMPUTED MUST NOT be READY_FOR_VALIDATION'
  assert_equal 'NEEDS_ATTENTION', payload['overall_state'],
               'ready + all stages UNCOMPUTED MUST be NEEDS_ATTENTION'
  assert_equal '仍有未检查项', payload['headline'],
               'ready + all stages UNCOMPUTED headline MUST be 仍有未检查项'
  assert_equal '请逐项检查未完成的诊断', payload['subheadline']
  # The issue summary headline must match the truthful copy.
  assert_equal '仍有未检查项', payload['issue_summary']['headline']
end

test 'v19a_presenter (BLOCK 2): ready + planar NOT_COMPUTED -> overall != READY_FOR_VALIDATION' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => false, 'state' => 'NOT_COMPUTED' }
  }
  payload = v19a_present(v19a_make_ar, snap)
  refute_equal 'READY_FOR_VALIDATION', payload['overall_state'],
               'ready + planar NOT_COMPUTED MUST NOT be READY_FOR_VALIDATION'
  assert_equal 'NEEDS_ATTENTION', payload['overall_state']
  assert_equal '仍有未检查项', payload['headline']
  # Planar card is UNCOMPUTED (truth rule).
  planar = payload['cards'].find { |c| c['id'] == 'planar_normalization' }
  assert_equal 'UNCOMPUTED', planar['state']
end

test 'v19a_presenter (BLOCK 2): ready + structure FAILED -> overall = NEEDS_ATTENTION' do
  # duplicate_repair is APPLIED (so duplicate is NOT
  # stage-bound UNCOMPUTED and the BLOCKED/FAILED headline
  # path is reachable).
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 4, 'duplicate_pairs_before' => 8, 'duplicate_pairs_after' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => {
      'computed' => true, 'state' => 'FAILED',
      'reason'   => 'some-segment-conflict-failure'
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'NEEDS_ATTENTION', payload['overall_state']
  # Headline reflects a blocked/failed stage (no UNCOMPUTED
  # stage-bound cards because duplicate has APPLIED).
  assert_equal '存在被阻塞的检查项', payload['headline']
  # Structure card is FAILED.
  sr = payload['cards'].find { |c| c['id'] == 'structure_region' }
  assert_equal 'FAILED', sr['state']
end

test 'v19a_presenter (BLOCK 2): ready + secondary issue causing other REVIEW_REQUIRED -> overall = NEEDS_ATTENTION' do
  # Build an AnalysisResult whose registry.summary carries
  # short_edge / abnormal_large_coord counts (the `other`
  # catch-all card surfaces them as REVIEW_REQUIRED).
  pf = Struct.new(:edge_count, :vertex_count, :non_zero_z_vertex_count, :warning_count, :face_count, :faces_with_holes_count).new(10, 12, 0, 0, 0, 0)
  reg = IssueRegistry.new([
    { issue_id: 'short_edge|1|1',           issue_type: 'short_edge',           severity: 'low', confidence: 'high',
      sources: [], source_entity_ids: [], edge_ids: [], location: nil, message: 'm', metadata: {}, locatable: false, display_length: nil },
    { issue_id: 'abnormal_large_coord|1|1', issue_type: 'abnormal_large_coord', severity: 'low', confidence: 'high',
      sources: [], source_entity_ids: [], edge_ids: [], location: nil, message: 'm', metadata: {}, locatable: false, display_length: nil }
  ])
  ar = AnalysisResult.new(preflight: pf, registry: reg,
                         selection_type: 'Group', selection_label: 'x')
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 4, 'duplicate_pairs_before' => 8, 'duplicate_pairs_after' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  payload = v19a_present(ar, snap)
  other = payload['cards'].find { |c| c['id'] == 'other' }
  assert_equal 'REVIEW_REQUIRED', other['state'],
               '`other` card MUST be REVIEW_REQUIRED when secondary issue types exist'
  assert_equal 'NEEDS_ATTENTION', payload['overall_state'],
               'ready + `other` REVIEW_REQUIRED MUST surface as NEEDS_ATTENTION'
end

test 'v19a_presenter (BLOCK 2): all required stages genuinely CLEAN + no review + no APPLIED -> READY_FOR_VALIDATION (clean)' do
  # The truly-clean case: no APPLIED cards (only NO_CANDIDATE
  # / READY). The existing frozen logic surfaces this as
  # kind=clean / "CAD 状态良好" because no safe repair was
  # applied — the workspace was simply clean from the start.
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 0, 'duplicate_pairs_before' => 0, 'duplicate_pairs_after' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal 'READY_FOR_VALIDATION', payload['overall_state']
  assert_equal 'clean', payload['issue_summary']['kind']
  assert_equal 'CAD 状态良好', payload['headline']
end

test 'v19a_presenter (BLOCK 2 + A2): IDLE copy now truthfully promises automatic full diagnostics' do
  # V1.9A-A2 dispatch §8.1: the IDLE copy now
  # truthfully promises automatic full diagnostics.
  # The orchestrator's start path runs prepare +
  # V1.5 duplicate batch + V1.6 planar compute +
  # V1.7 gap compute + V1.8 structure compute in
  # one user click. The A1 truthful "only the V1.5
  # duplicate batch runs" copy is RETIRED because
  # the orchestrator now owns the full pipeline.
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  assert_includes payload['subheadline'], '完成全部检查',
                  'V1.9A-A2 IDLE subheadline MUST truthfully promise automatic full diagnostics (orchestrator owns the pipeline)'
  assert_includes payload['issue_summary']['subtitle'], '完成全部检查',
                  'V1.9A-A2 IDLE issue_summary subtitle MUST truthfully promise automatic full diagnostics'
  # Guard against future copy drift by pinning the
  # exact frozen subheadline string.
  assert_equal '开始后将创建安全工作副本并自动完成全部检查', payload['subheadline'],
               'V1.9A-A2 IDLE subheadline string is frozen by the orchestrator contract'
  # The issue_summary subtitle is a user-action prompt
  # ("点击 开始处理 以...") and follows the same A2
  # truth contract: it tells the user the click will
  # trigger automatic full diagnostics. The string is
  # FROZEN (no future drift without an AIPM
  # re-dispatch).
  assert_equal '点击"开始处理"以创建安全工作副本并自动完成全部检查', payload['issue_summary']['subtitle'],
               'V1.9A-A2 IDLE issue_summary subtitle is frozen by the orchestrator contract'
end

test 'v19a_presenter (BLOCK 2): NEEDS_ATTENTION headline distinguishes actionable / uncomputed / blocked' do
  # Three cases that all surface NEEDS_ATTENTION but with
  # different truthful copy.
  # 1) actionable present -> "发现需要处理的问题"
  snap_a = { 'state' => 'ready',
            'duplicate_repair' => { 'actions_applied' => 4, 'duplicate_pairs_before' => 8, 'duplicate_pairs_after' => 0 },
            'planar_normalization' => {
              'computed' => true, 'state' => 'READY_TO_NORMALIZE',
              'proposal' => { 'movable' => 5 }
            } }
  pa = v19a_present(v19a_make_ar, snap_a)
  assert_equal 'NEEDS_ATTENTION', pa['overall_state']
  assert_equal '发现需要处理的问题', pa['headline']
  # 2) stage-bound UNCOMPUTED only -> "仍有未检查项"
  #    No duplicate / planar / gap / structure sub-snapshot.
  snap_b = { 'state' => 'ready' }
  pb = v19a_present(v19a_make_ar, snap_b)
  assert_equal 'NEEDS_ATTENTION', pb['overall_state']
  assert_equal '仍有未检查项', pb['headline']
  assert_equal '请逐项检查未完成的诊断', pb['subheadline']
  # 3) stage-bound BLOCKED only -> "存在被阻塞的检查项"
  #    All other stages CLEAN/APPLIED so the BLOCKED/FAILED
  #    headline path is reachable.
  snap_c = { 'state' => 'ready',
             'duplicate_repair' => { 'actions_applied' => 4, 'duplicate_pairs_before' => 8, 'duplicate_pairs_after' => 0 },
             'planar_normalization' => { 'computed' => true, 'state' => 'INVALID_TOLERANCE' },
             'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
             'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' } }
  pc = v19a_present(v19a_make_ar, snap_c)
  assert_equal 'NEEDS_ATTENTION', pc['overall_state']
  assert_equal '存在被阻塞的检查项', pc['headline']
end

# --- selection shape ------------------------------------------------

test 'v19a_presenter: selection carries the analysis_result selection_type / selection_label' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  assert_equal 'Group', payload['selection']['type']
  assert_equal '别墅平面图', payload['selection']['label']
end

test 'v19a_presenter: nil analysis_result -> selection has empty type and 尚未选择 label' do
  payload = v19a_present(nil, { 'state' => 'none' })
  assert_equal '', payload['selection']['type']
  assert_equal '尚未选择', payload['selection']['label']
end

# --- idempotency / determinism -------------------------------------

test 'v19a_presenter: identical inputs produce deep-equal cadPrepWorkflow (idempotent)' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => {
      'computed' => true, 'state' => 'READY_TO_NORMALIZE',
      'proposal' => { 'movable' => 12, 'outlier_count' => 2 }
    }
  }
  a = v19a_present(v19a_make_ar, snap)
  b = v19a_present(v19a_make_ar, snap)
  assert_equal a, b
end

test 'v19a_presenter: no live Sketchup object sneaks into the payload' do
  class FakeSketchup
  end
  fake = FakeSketchup.new
  snap = { 'state' => 'ready', 'planar_normalization' => { 'computed' => true, 'state' => 'READY_TO_NORMALIZE' } }
  payload = v19a_present(v19a_make_ar, snap)
  # Note: presenter never takes live Sketchup; this test
  # verifies the presenter does NOT magically introduce one.
  refute payload['cards'].any? { |c| c.class != Hash }
  refute payload['recovery'].is_a?(FakeSketchup) if payload['recovery']
  refute payload['cards'].first['primary_action'].is_a?(FakeSketchup) if payload['cards'].first['primary_action']
end


# ===========================================================
# V1.9A-A2 ONE-CLICK DIAGNOSTICS ORCHESTRATOR focused
# presenter tests (dispatch §12.2).
# ===========================================================

# --- IDLE / NEEDS_ATTENTION / READY_FOR_VALIDATION CTA wiring ---

# Per dispatch §8.2, the presenter does NOT own the
# CTA mapping; the frontend owns the IDLE / SCANNING /
# NEEDS_ATTENTION / READY_FOR_VALIDATION / STALE /
# FAILED CTA table. The presenter only ships the
# overall_state enum. This test pins the LOCKED CN
# labels (per Blueprint §4.4) so the front-end map
# never has to invent them.
test 'v19a_presenter (A2): overall_state labels are frozen CN strings (front-end CTA table dependency)' do
  payload = v19a_present(v19a_make_ar, { 'state' => 'none' })
  # IDLE label is part of the headline (per A2 truth
  # rule; see IDLE test above).
  assert_equal 'CAD 尚未处理', payload['headline']
  # The overall_state enum is what the front-end uses
  # to look up the CTA mapping; the raw enum MUST be
  # present even when no CTA is rendered server-side.
  assert_equal 'IDLE', payload['overall_state']
end

# --- Planar actionable + gap actionable -> gap repair disabled ---

# Per dispatch §5.1: when planar state is
# READY_TO_NORMALIZE, gap repair action MUST be
# disabled so the user is not invited to mutate
# geometry known to be pending a deterministic Z
# normalization. The defense-in-depth (orchestrator
# refusal) is in the orchestrator tests; this test
# pins the presenter gate.
test 'v19a_presenter (A2): planar READY_TO_NORMALIZE + gap READY_TO_REPAIR -> gap repair action disabled' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => {
      'computed' => true, 'state' => 'READY_TO_NORMALIZE',
      'proposal' => { 'movable' => 5, 'outlier_count' => 0, 'state' => 'READY_TO_NORMALIZE' }
    },
    'topology_repair' => {
      'computed' => true, 'state' => 'READY_TO_REPAIR',
      'proposal' => { 'ready_proposals' => [1, 2, 3] }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  gap = payload['cards'].find { |c| c['id'] == 'gap_endpoint' }
  refute_nil gap['primary_action'], 'gap card MUST carry a primary_action when READY_TO_REPAIR'
  assert_equal '修复间隙', gap['primary_action']['label']
  assert_equal 'apply_gap_repair', gap['primary_action']['callback']
  # The gap-ordering safety gate: when planar is
  # READY_TO_NORMALIZE, the gap primary_action MUST be
  # disabled.
  assert_equal false, gap['primary_action']['enabled'],
               'gap primary_action MUST be disabled when planar is READY_TO_NORMALIZE (gap-ordering safety)'
  # The summary copy MUST truthfully tell the user
  # the gap is pending Z repair.
  assert_match(/Z 轴/, gap['summary'],
               'gap summary MUST mention Z axis when gap is gated by Z repair')
end

# After Z is resolved (e.g. APPLIED), the gap repair
# action is re-enabled.
test 'v19a_presenter (A2): planar APPLIED + gap READY_TO_REPAIR -> gap repair action enabled' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => {
      'computed' => true, 'state' => 'APPLIED',
      'audit' => { 'moved' => 5 }
    },
    'topology_repair' => {
      'computed' => true, 'state' => 'READY_TO_REPAIR',
      'proposal' => { 'ready_proposals' => [1, 2] }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  gap = payload['cards'].find { |c| c['id'] == 'gap_endpoint' }
  refute_nil gap['primary_action']
  assert_equal true, gap['primary_action']['enabled'],
               'gap primary_action MUST be enabled after planar is APPLIED (gap-ordering safety released)'
end

# Planar REVIEW_REQUIRED (non-actionable warning) does
# NOT block the gap repair (V1.7's own conservative
# safety rules remain authoritative).
test 'v19a_presenter (A2): planar REVIEW_REQUIRED + gap READY_TO_REPAIR -> gap repair action enabled' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => {
      'computed' => true, 'state' => 'REVIEW_REQUIRED',
      'proposal' => { 'outlier_count' => 2 }
    },
    'topology_repair' => {
      'computed' => true, 'state' => 'READY_TO_REPAIR',
      'proposal' => { 'ready_proposals' => [1] }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  gap = payload['cards'].find { |c| c['id'] == 'gap_endpoint' }
  refute_nil gap['primary_action']
  assert_equal true, gap['primary_action']['enabled'],
               'gap primary_action MUST be enabled when planar is REVIEW_REQUIRED (non-actionable warning, no gate)'
end

# Planar NO_CANDIDATE + gap READY_TO_REPAIR -> gap
# repair action enabled (the common case where Z is
# already clean).
test 'v19a_presenter (A2): planar NO_CANDIDATE + gap READY_TO_REPAIR -> gap repair action enabled' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair' => {
      'computed' => true, 'state' => 'READY_TO_REPAIR',
      'proposal' => { 'ready_proposals' => [1, 2] }
    }
  }
  payload = v19a_present(v19a_make_ar, snap)
  gap = payload['cards'].find { |c| c['id'] == 'gap_endpoint' }
  refute_nil gap['primary_action']
  assert_equal true, gap['primary_action']['enabled'],
               'gap primary_action MUST be enabled when planar is NO_CANDIDATE (clean Z, no gate)'
end

# --- Card order (frozen) is preserved in the A2 path ---

# Per dispatch §8.4: 5 cards in the LOCKED order
# duplicate / planar / gap / structure / other. The
# A2 orchestrator does not change the card list or
# the order; the presenter's frozen order is the
# authoritative contract.
test 'v19a_presenter (A2): cards remain in frozen order under orchestrator-driven snapshots' do
  # A "normal" post-Start snapshot where all four
  # stage-bound cards have been computed.
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  payload = v19a_present(v19a_make_ar, snap)
  assert_equal %w[duplicate_cleanup planar_normalization gap_endpoint structure_region other],
               payload['cards'].map { |c| c['id'] },
               'A2 orchestrator-driven snapshot MUST preserve the frozen 5-card order'
end

# --- NOT_COMPUTED must never render as CLEAN in A2 path ---

# The A2 truth rule: after a Start call, no main
# capability card should remain UNCOMPUTED. The
# presenter continues to enforce the truth rule
# (NOT_COMPUTED never becomes CLEAN) even in the
# post-A2 normal path.
test 'v19a_presenter (A2): post-Start normal snapshot has no UNCOMPUTED stage-bound cards' do
  snap = {
    'state' => 'ready',
    'duplicate_repair' => { 'actions_applied' => 0, 'duplicate_pairs_before' => 0, 'duplicate_pairs_after' => 0 },
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  payload = v19a_present(v19a_make_ar, snap)
  stage_cards = %w[duplicate_cleanup planar_normalization gap_endpoint structure_region]
  stage_cards.each do |id|
    card = payload['cards'].find { |c| c['id'] == id }
    refute_equal 'UNCOMPUTED', card['state'],
                 "A2 post-Start #{id} MUST NOT remain UNCOMPUTED"
  end
  # And the overall is READY_FOR_VALIDATION (the
  # A2 success state).
  assert_equal 'READY_FOR_VALIDATION', payload['overall_state']
end
