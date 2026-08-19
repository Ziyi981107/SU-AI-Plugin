
#
# tests/test_synthetic_01_through_10.rb
#
# PI_TASK_001 §16 Synthetic Test Set Test 01..10. Each test below is
# named TC-NN so the `ruby tests/run_all.rb TC-06` filtering pattern
# matches by substring.
#
# Each test runs against Geometry Core ONLY (no SketchUp runtime).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/tolerance'
require_relative '../extension/su_ai_plugin/core/analysis_config'
require_relative '../extension/su_ai_plugin/core/synthetic_factory'
require_relative '../extension/su_ai_plugin/core/analyzers/duplicate_detector'
require_relative '../extension/su_ai_plugin/core/analyzers/short_edge_detector'
require_relative '../extension/su_ai_plugin/core/analyzers/open_endpoint_detector'
require_relative '../extension/su_ai_plugin/core/analyzers/gap_candidate_detector'

include SUAnalysis::Core
include SUAnalysis::Core::Analyzers

# ---------------------------------------------------------------- TC-01
test 'TC-01: two perfectly coincident edges are flagged as duplicate' do
  e1 = SyntheticFactory.horizontal_edge(0, 0.0, 10.0, 0.0)
  e2 = SyntheticFactory.horizontal_edge(1, 0.0, 10.0, 0.0)
  snap = SyntheticFactory.snapshot([e1, e2])
  issues = DuplicateDetector.new.detect(snap)
  assert_equal 1, issues.size, "expected 1 duplicate, got #{issues.size}"
  assert_equal 'duplicate_edge_candidate', issues.first[:kind]
end

# ---------------------------------------------------------------- TC-02
test 'TC-02: reverse-direction duplicate edges are flagged (A->B == B->A)' do
  e1 = SyntheticFactory.horizontal_edge(0, 0.0, 10.0, 0.0)
  e2 = SyntheticFactory.horizontal_edge(1, 10.0, 0.0, 0.0)
  snap = SyntheticFactory.snapshot([e1, e2])
  issues = DuplicateDetector.new.detect(snap)
  assert_equal 1, issues.size, "expected 1 duplicate (direction-normalized)"
end

# ---------------------------------------------------------------- TC-03
test 'TC-03: a normal-length edge is not flagged as short' do
  e  = SyntheticFactory.horizontal_edge(0, 0.0, 10.0, 0.0)
  snap = SyntheticFactory.snapshot([e])
  issues = ShortEdgeDetector.new.detect(snap)
  assert_empty issues
end

# ---------------------------------------------------------------- TC-04
test 'TC-04: a short edge is flagged' do
  e = SyntheticFactory.horizontal_edge(0, 0.0, 0.1, 0.0)  # 0.1 < 0.5 threshold
  snap = SyntheticFactory.snapshot([e])
  issues = ShortEdgeDetector.new.detect(snap)
  assert_equal 1, issues.size
  assert_equal 'short_edge', issues.first[:kind]
end

# ---------------------------------------------------------------- TC-05
test 'TC-05: a single edge has two open endpoints' do
  e = SyntheticFactory.horizontal_edge(0, 0.0, 5.0, 0.0)
  snap = SyntheticFactory.snapshot([e])
  issues = OpenEndpointDetector.new.detect(snap)
  assert_equal 2, issues.size, "expected 2 open endpoints, got #{issues.size}"
end

# ---------------------------------------------------------------- TC-06
test 'TC-06: two near open endpoints form a gap candidate' do
  e1 = SyntheticFactory.horizontal_edge(0, 0.0, 5.0, 0.0)
  e2 = SyntheticFactory.horizontal_edge(1, 5.05, 10.0, 0.0)  # 0.05 inch gap, <= 0.1 tol
  snap = SyntheticFactory.snapshot([e1, e2])
  issues = GapCandidateDetector.new.detect(snap)
  assert_equal 1, issues.size, "expected 1 gap candidate, got #{issues.size}"
  assert_in_delta 0.05, issues.first[:metadata][:distance], 1.0e-9
end

# ---------------------------------------------------------------- TC-07
test 'TC-07: endpoints beyond gap tolerance are NOT a gap candidate' do
  e1 = SyntheticFactory.horizontal_edge(0, 0.0, 5.0, 0.0)
  e2 = SyntheticFactory.horizontal_edge(1, 5.5, 10.0, 0.0)  # 0.5 inch gap, > 0.1 tol
  snap = SyntheticFactory.snapshot([e1, e2])
  issues = GapCandidateDetector.new.detect(snap)
  assert_empty issues
end

# ---------------------------------------------------------------- TC-08
test 'TC-08: non-zero-Z geometry surfaces in preflight info' do
  e1 = SyntheticFactory.edge(0, [0, 0, 0], [5, 5, 5])
  snap = SyntheticFactory.snapshot([e1])
  assert snap.non_zero_z_count > 0,
         "expected non_zero_z_count > 0, got #{snap.non_zero_z_count}"
  _zmin, zmax = snap.z_range
  assert zmax > 0, "expected positive zmax, got #{zmax}"
  bb = snap.bounding_box
  assert_equal 5.0, bb[:max][2]
end

# ---------------------------------------------------------------- TC-09
test 'TC-09: a closed rectangle has no open endpoints' do
  edges = SyntheticFactory.rectangle([0, 0], 10, 5)
  snap  = SyntheticFactory.snapshot(edges)
  issues = OpenEndpointDetector.new.detect(snap)
  assert_empty issues, "expected 0 open endpoints on a closed rectangle, got #{issues.inspect}"
end

# ---------------------------------------------------------------- TC-10
test 'TC-10: 5000 simple edges analyzed under 5 seconds' do
  edges = (0...5000).map do |i|
    SyntheticFactory.horizontal_edge(i, i.to_f, i.to_f + 1.0, 0.0)
  end
  snap = SyntheticFactory.snapshot(edges)
  t0 = Time.now
  d = DuplicateDetector.new.detect(snap)
  s = ShortEdgeDetector.new.detect(snap)
  o = OpenEndpointDetector.new.detect(snap)
  g = GapCandidateDetector.new.detect(snap)
  elapsed = Time.now - t0
  assert elapsed < 5.0,
         "analyzer pipeline took #{format('%.2f', elapsed)}s on 5000 edges (d=#{d.size} s=#{s.size} o=#{o.size} g=#{g.size})"
end
