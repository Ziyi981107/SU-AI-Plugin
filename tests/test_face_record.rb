#
# tests/test_face_record.rb — V1.3 FaceRecord validation contract.
#
# Per directive 027:
#   - FaceRecord must be immutable (no setters, freeze top-level).
#   - Validation: source must be SourceReference;
#     outer_loop_vertex_count and inner_loop_count must be
#     non-negative Integers.
#   - has_holes is DERIVED from inner_loop_count > 0 (never a
#     direct input).
#

require_relative 'runner'
require_relative '../extension/su_ai_plugin/core/source_reference'
require_relative '../extension/su_ai_plugin/core/face_record'

include SUAnalysis::Core

def fr_src
  SourceReference.new(kind: 'face', persistent_id: 42,
                      persistent_id_path: [42],
                      instance_path: ['Group:outer'],
                      structural_depth: 1, pid_path_complete: true,
                      layer_name: 'Layer0')
end

# 1. Validation: source must be a SourceReference.
test 'face_record: source must be a SourceReference (validation)' do
  assert_raises(ArgumentError) do
    FaceRecord.new(id: 0, source: { kind: 'face' }, layer: 'Layer0',
                  outer_loop_vertex_count: 4)
  end
end

# 2. Validation: outer_loop_vertex_count must be a non-negative Integer.
test 'face_record: outer_loop_vertex_count must be a non-negative Integer' do
  assert_raises(ArgumentError) do
    FaceRecord.new(id: 0, source: fr_src, layer: 'Layer0',
                  outer_loop_vertex_count: -1)
  end
  assert_raises(ArgumentError) do
    FaceRecord.new(id: 0, source: fr_src, layer: 'Layer0',
                  outer_loop_vertex_count: 4.5)
  end
  assert_raises(ArgumentError) do
    FaceRecord.new(id: 0, source: fr_src, layer: 'Layer0',
                  outer_loop_vertex_count: 'four')
  end
end

# 3. Validation: inner_loop_count must be a non-negative Integer.
test 'face_record: inner_loop_count must be a non-negative Integer' do
  assert_raises(ArgumentError) do
    FaceRecord.new(id: 0, source: fr_src, layer: 'Layer0',
                  outer_loop_vertex_count: 4, inner_loop_count: -1)
  end
end

# 4. Defaults: inner_loop_count defaults to 0; has_holes derived.
test 'face_record: inner_loop_count defaults to 0 -> has_holes is false' do
  f = FaceRecord.new(id: 0, source: fr_src, layer: 'Layer0',
                     outer_loop_vertex_count: 4)
  assert_equal 0, f.inner_loop_count
  assert_equal false, f.has_holes
end

# 5. has_holes is DERIVED from inner_loop_count > 0.
test 'face_record: has_holes == true iff inner_loop_count > 0' do
  [0, 1, 2, 5].each do |n|
    f = FaceRecord.new(id: 0, source: fr_src, layer: 'Layer0',
                       outer_loop_vertex_count: 4, inner_loop_count: n)
    assert_equal n > 0, f.has_holes,
                 "inner_loop_count=#{n}: expected has_holes=#{n > 0}"
  end
end

# 6. Layer name coerced to String.
test 'face_record: layer coerced to String' do
  f = FaceRecord.new(id: 0, source: fr_src, layer: :DIM_WALLS,
                     outer_loop_vertex_count: 4)
  assert_equal 'DIM_WALLS', f.layer
end

# 7. to_h includes the locked field set.
test 'face_record.to_h: includes id, source, layer, outer/inner, has_holes' do
  f = FaceRecord.new(id: 7, source: fr_src, layer: 'DIM-XX',
                     outer_loop_vertex_count: 4, inner_loop_count: 1)
  h = f.to_h
  assert_equal 7,                  h[:id]
  assert_equal 'DIM-XX',           h[:layer]
  assert_equal 4,                  h[:outer_loop_vertex_count]
  assert_equal 1,                  h[:inner_loop_count]
  assert_equal true,               h[:has_holes]
  # Source is the SourceReference's to_h.
  assert_kind_of Hash,             h[:source]
end

# 8. Immutability: no public setters; frozen object.
test 'face_record: no public setters' do
  f = FaceRecord.new(id: 0, source: fr_src, layer: 'Layer0',
                     outer_loop_vertex_count: 4)
  assert !f.respond_to?(:id=),                       'id must be read-only'
  assert !f.respond_to?(:source=),                   'source must be read-only'
  assert !f.respond_to?(:layer=),                    'layer must be read-only'
  assert !f.respond_to?(:outer_loop_vertex_count=),  'outer_loop_vertex_count must be read-only'
  assert !f.respond_to?(:inner_loop_count=),         'inner_loop_count must be read-only'
  assert !f.respond_to?(:has_holes=),                'has_holes must be read-only (derived)'
end