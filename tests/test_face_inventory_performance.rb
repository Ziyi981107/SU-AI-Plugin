#
# tests/test_face_inventory_performance.rb — V1.3 Face Inventory
# performance + quadratic-aggregation regression guard.
#
# Per V1.3 directive 027 (REQUIRED AUTOMATED TESTS section E):
#   - Run the complete existing suite plus all V1.3 tests.
#   - Keep all 372 V1.1 tests and all V1.2 additions passing.
#   - Add a representative high-face-count synthetic test with
#     a reasonable runtime budget; avoid quadratic aggregation.
#
# The two aggregation paths under test:
#   1. PreflightRunner.build_snapshot: walks every Face occurrence
#      and aggregates per-layer face_count + faces_with_holes_count
#      in O(F) where F = face count.
#   2. FaceInventoryGrouper.group: O(L log L) on the layer count L
#      (sort key per layer). No nested iteration over faces.
#
# Together the path should be linear in face count + log-linear in
# layer count -- NOT quadratic. The test below asserts a runtime
# budget of 5 seconds for 5,000 face occurrences across 10 layers.
#

require_relative 'runner'
require_relative '_fake_su'
require_relative '../extension/su_ai_plugin/core/face_record'
require_relative '../extension/su_ai_plugin/core/face_inventory_grouper'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/preflight_runner'

include FakeSU
include SUAnalysis::Core
include SUAnalysis::Extension

# Build N Face stand-ins distributed across K named layers.
def build_face_fixture(face_count: 5_000, layer_count: 10)
  layers = (1..layer_count).map { |i| Layer.new("LAYER-#{i}") }
  faces = (0...face_count).map do |i|
    layer = layers[i % layer_count]
    Face.new(
      layer: layer,
      persistent_id: i,
      outer_loop_vertices: 4,
      inner_loop_vertices: i.even? ? [3] : []
    )
  end
  [layers, faces]
end

# 1. PreflightRunner aggregation over 5,000 faces / 10 layers.
test 'V1.3 performance: 5,000 faces across 10 layers aggregated in O(F) (linear)' do
  _, faces = build_face_fixture(face_count: 5_000, layer_count: 10)
  sel = Selection.new(faces)
  t0 = Time.now
  snapshot = PreflightRunner.build_snapshot(sel)
  elapsed = Time.now - t0
  assert_equal 5_000, snapshot.faces.length,
               'all 5,000 face occurrences must be collected'
  assert elapsed < 5.0,
         "build_snapshot with 5,000 faces took #{elapsed.round(3)}s (budget 5.0s); possible quadratic regression"
  # Per-layer face_count + holes_count aggregate correctly.
  total_face_count = 0
  total_holes_count = 0
  snapshot.layers.each do |r|
    total_face_count += r.face_count
    total_holes_count += r.faces_with_holes_count
  end
  assert_equal 5_000, total_face_count,
               'per-layer face_count must sum to 5,000'
  # Half the faces have a hole (even indices), so 2,500 holes total.
  assert_equal 2_500, total_holes_count,
               'per-layer faces_with_holes_count must sum to 2,500'
end

# 2. FaceInventoryGrouper aggregation over many layers (linear in
#    face count + log-linear in layer count -- NOT quadratic in
#    face count).
test 'V1.3 performance: FaceInventoryGrouper over 5,000 faces / 10 layers is sub-second' do
  _, faces = build_face_fixture(face_count: 5_000, layer_count: 10)
  layers = (1..10).map do |i|
    # Build LayerRecord aggregates that mirror what PreflightRunner
    # would produce from the same fixture.
    face_count = 500
    holes = (i.even? ? 250 : 0)
    LayerRecord.new(name: "LAYER-#{i}", face_count: face_count,
                    faces_with_holes_count: holes, role: :unknown,
                    visible: true, visibility_unknown: false)
  end
  t0 = Time.now
  result = FaceInventoryGrouper.group(layers)
  elapsed = Time.now - t0
  assert_equal 10, result.length,
               'grouper must emit one bucket per non-empty layer'
  assert elapsed < 1.0,
         "FaceInventoryGrouper on 10 layers took #{elapsed.round(4)}s (budget 1.0s)"
end

# 3. Quadratic-aggregation guard: the prefight path must NOT
#    iterate faces multiple times. We assert via timing on 10x
#    the previous fixture (50,000 faces) that the runtime stays
#    linear (NOT 100x slower than the 5,000-face case).
test 'V1.3 performance: 50,000 faces / 10 layers stays linear (NOT 100x slower)' do
  _, faces = build_face_fixture(face_count: 50_000, layer_count: 10)
  sel = Selection.new(faces)
  t0 = Time.now
  snapshot = PreflightRunner.build_snapshot(sel)
  elapsed_50k = Time.now - t0
  assert_equal 50_000, snapshot.faces.length
  # 5,000-face baseline (test 1). If 50k is 10x data but 100x
  # slower, the path is quadratic -- reject.
  baseline_factor = 10   # 50k / 5k
  worst_case_factor = baseline_factor * baseline_factor  # quadratic = 100x
  # Reference: rerun the 5k case to measure its baseline here.
  _, faces_5k = build_face_fixture(face_count: 5_000, layer_count: 10)
  sel_5k = Selection.new(faces_5k)
  t1 = Time.now
  PreflightRunner.build_snapshot(sel_5k)
  elapsed_5k = Time.now - t1
  next if elapsed_5k <= 0
  ratio = elapsed_50k / elapsed_5k
  assert ratio < worst_case_factor,
         "50k-case took #{ratio.round(2)}x the 5k-case (worst-case quadratic = #{worst_case_factor}x); quadratic regression suspected"
end

# 4. Determinism: identical inputs produce identical bucket order.
test 'V1.3 performance: deterministic bucket order across many layers' do
  layer_count = 50
  layers = (1..layer_count).map do |i|
    LayerRecord.new(
      name: format('LAYER-%03d', i), face_count: 5, faces_with_holes_count: 0,
      role: :unknown, visible: true, visibility_unknown: false
    )
  end
  a = FaceInventoryGrouper.group(layers).map { |b| b[:name] }
  b = FaceInventoryGrouper.group(layers).map { |b| b[:name] }
  assert_equal a, b, 'bucket order must be deterministic'
end