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
  assert_equal '开始后将创建安全工作副本并完成全部检查', payload['subheadline']
  assert_equal 5, payload['cards'].length
  payload['cards'].each do |c|
    assert_equal 'UNCOMPUTED', c['state'],
                 "IDLE card #{c['id']} must be UNCOMPUTED (not CLEAN)"
  end
  assert_nil payload['recovery']
  # Issue summary kind == empty-idle
  assert_equal 'empty-idle', payload['issue_summary']['kind']
  assert_equal [], payload['issue_summary']['chips']
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
  # cards are APPLIED.
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

test 'v19a_presenter: ready workspace with all NO_CANDIDATE + structure READY -> clean summary (not empty-idle)' do
  snap = {
    'state' => 'ready',
    'planar_normalization' => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'topology_repair'      => { 'computed' => true, 'state' => 'NO_CANDIDATE' },
    'structure_reconstruction' => { 'computed' => true, 'state' => 'READY' }
  }
  payload = v19a_present(v19a_make_ar, snap)
  # ready + no actionable = clean (the user has a workspace;
  # the workspace is genuinely clean). NOT empty-idle.
  assert_equal 'clean', payload['issue_summary']['kind']
end

test 'v19a_presenter: ready + NO_CANDIDATE -> clean empty issue summary' do
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
  summary = payload['issue_summary']
  assert_equal 'clean', summary['kind']
  assert_equal [], summary['chips']
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
