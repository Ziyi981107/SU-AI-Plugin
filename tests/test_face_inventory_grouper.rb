#
# tests/test_face_inventory_grouper.rb — V1.3 FaceInventoryGrouper.
#
# Per directive 027:
#   - Aggregate face inventory by source layer in pure Ruby.
#   - Read each layer's role / role_label / visible /
#     visibility_unknown / visibility_label from the V1.1
#     LayerRecord shape; do NOT re-classify.
#   - Order buckets by V1.1 canonical layer order
#     (Dimension -> Annotation -> Guide -> Construction ->
#     Unknown; visible before hidden; name ASC).
#   - Only layers with face_count > 0 are emitted.
#   - No phantom layers.
#   - Empty + malformed inputs fail safely.
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/layer_record'
require_relative '../extension/su_ai_plugin/core/face_inventory_grouper'

include SUAnalysis::Core

def fr_layer(name, face_count: 0, faces_with_holes_count: 0,
             role: :unknown, visible: true, visibility_unknown: false)
  LayerRecord.new(name: name, face_count: face_count,
                  faces_with_holes_count: faces_with_holes_count,
                  role: role, visible: visible,
                  visibility_unknown: visibility_unknown)
end

# 1. Empty input.
test 'FaceInventoryGrouper.group: empty Array -> []' do
  assert_equal [], FaceInventoryGrouper.group([])
end

# 2. Layer with face_count > 0 is emitted; layer with 0 is skipped.
test 'FaceInventoryGrouper.group: layer with face_count > 0 emitted; 0 skipped' do
  a = fr_layer('Layer0', face_count: 0)
  b = fr_layer('DIM-XX', face_count: 2, faces_with_holes_count: 1, role: :dimension)
  result = FaceInventoryGrouper.group([a, b])
  assert_equal 1, result.length
  assert_equal 'DIM-XX', result.first[:name]
  assert_equal 2,         result.first[:face_count]
end

# 3. Bucket field set preserved end-to-end.
test 'FaceInventoryGrouper.group: bucket carries locked field set' do
  l = fr_layer('DIM-XX', face_count: 5, faces_with_holes_count: 2,
               role: :dimension, visible: true, visibility_unknown: false)
  result = FaceInventoryGrouper.group([l])
  b = result.first
  assert_equal 'DIM-XX',      b[:name]
  assert_equal 5,             b[:face_count]
  assert_equal 2,             b[:faces_with_holes_count]
  assert_equal :dimension,     b[:role]
  assert_equal 'Dimension',    b[:role_label]
  assert_equal true,          b[:visible]
  assert_equal false,         b[:visibility_unknown]
  assert_equal 'Visible',     b[:visibility_label]
end

# 4. visibility_label composition per V1.1 R011.
test 'FaceInventoryGrouper.group: visibility_label honors V1.1 R011' do
  vis     = fr_layer('A', face_count: 1, visible: true,  visibility_unknown: false)
  hidden  = fr_layer('B', face_count: 1, visible: false, visibility_unknown: false)
  unknown = fr_layer('C', face_count: 1, visible: true,  visibility_unknown: true)
  result = FaceInventoryGrouper.group([vis, hidden, unknown])
  by_name = result.each_with_object({}) { |b, h| h[b[:name]] = b }
  assert_equal 'Visible',              by_name['A'][:visibility_label]
  assert_equal 'Off-screen',           by_name['B'][:visibility_label]
  assert_equal 'Visibility: unknown', by_name['C'][:visibility_label]
end

# 5. Bucket order matches V1.1 canonical layer order.
test 'FaceInventoryGrouper.group: bucket order matches V1.1 canonical layer order' do
  layers = [
    fr_layer('XYZ-9999', face_count: 1, role: :unknown),
    fr_layer('Layer0',   face_count: 1, role: :construction),
    fr_layer('TXT-XX',   face_count: 1, role: :annotation),
    fr_layer('GUIDE-XX', face_count: 1, role: :guide),
    fr_layer('DIM-XX',   face_count: 1, role: :dimension)
  ]
  names = FaceInventoryGrouper.group(layers).map { |b| b[:name] }
  assert_equal ['DIM-XX', 'TXT-XX', 'GUIDE-XX', 'Layer0', 'XYZ-9999'], names,
               'bucket order must mirror V1.1 canonical role order'
end

# 6. Within-role order: visible before hidden.
test 'FaceInventoryGrouper.group: visible before hidden within a role' do
  layers = [
    fr_layer('DIM-HIDDEN', face_count: 1, role: :dimension, visible: false),
    fr_layer('DIM-VIS',    face_count: 1, role: :dimension, visible: true)
  ]
  names = FaceInventoryGrouper.group(layers).map { |b| b[:name] }
  assert_equal ['DIM-VIS', 'DIM-HIDDEN'], names
end

# 7. Within-role order: name ASC tiebreak when both visible.
test 'FaceInventoryGrouper.group: name ASC tiebreak within a role' do
  layers = [
    fr_layer('DIM-B', face_count: 1, role: :dimension, visible: true),
    fr_layer('DIM-A', face_count: 1, role: :dimension, visible: true)
  ]
  names = FaceInventoryGrouper.group(layers).map { |b| b[:name] }
  assert_equal ['DIM-A', 'DIM-B'], names
end

# 8. No phantom layers: missing layer names are not created.
test 'FaceInventoryGrouper.group: no phantom layers' do
  layers = [
    fr_layer('Layer0',  face_count: 1, role: :construction),
    fr_layer('DIM-XX',  face_count: 1, role: :dimension)
  ]
  # Add a phantom via input data? No — the grouper does NOT
  # synthesize layers. We assert that the output count matches
  # the input count.
  result = FaceInventoryGrouper.group(layers)
  assert_equal 2, result.length,
               'no phantom layers should appear (output == non-zero input)'
end

# 9. Malformed input (nil LayerRecord) is skipped without raising.
test 'FaceInventoryGrouper.group: nil entry is skipped safely' do
  layers = [
    nil,
    fr_layer('DIM-XX', face_count: 1, role: :dimension),
    nil
  ]
  result = FaceInventoryGrouper.group(layers)
  assert_equal 1, result.length
  assert_equal 'DIM-XX', result.first[:name]
end

# 10. Deterministic order for identical calls.
test 'FaceInventoryGrouper.group: deterministic order' do
  layers = [
    fr_layer('Layer0',   face_count: 1, role: :construction),
    fr_layer('DIM-XX',   face_count: 1, role: :dimension),
    fr_layer('TXT-XX',   face_count: 1, role: :annotation),
    fr_layer('XYZ-9999', face_count: 1, role: :unknown)
  ]
  a = FaceInventoryGrouper.group(layers).map { |b| b[:name] }
  b = FaceInventoryGrouper.group(layers).map { |b| b[:name] }
  assert_equal a, b
end