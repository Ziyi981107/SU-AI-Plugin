#
# tests/_fake_su.rb — minimal SketchUp stand-ins for adapter-level tests.
#
# These are NOT meant to faithfully emulate every SketchUp corner case;
# they exist to drive extension/preflight_runner.rb through the exact
# code paths the real SU adapter uses (respond_to? checks, .entities,
# .definition.entities, .transformation, .position) without needing
# SketchUp installed.
#
# Used by tests/test_preflight_runner.rb to prove:
#   S2-BLOCK-001: one source Edge -> one EdgeRecord (not 2).
#   S2-BLOCK-002: Group / ComponentInstance traversal + accumulated
#                 transform + instance_path composite identity.
#   S2-BLOCK-003: extension/preflight_runner.rb loads without &. (Ruby 2.2.4).
#   S2-BLOCK-004: mixed selection -> 'mixed' type; per-type counts preserved.
#   S2-BLOCK-005-replacement: invalid/erased entity in selection ->
#                 analysis continues, valid edges still counted.
#

module FakeSU
  # 4x4 row-major identity matrix.
  IDENTITY_4X4 = [
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 1.0]
  ]

  # Fake Geom::Point3d (test substitute).
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end

    def to_a
      [@x, @y, @z]
    end
  end

  # Fake Geom::Transformation (4x4 matrix).
  class Transformation
    attr_reader :matrix
    def initialize(matrix = IDENTITY_4X4)
      @matrix = matrix
    end

    def *(other)
      if other.is_a?(Point3d) || other.is_a?(Array)
        return FakeSU.apply(self, other)
      end
      a = @matrix
      b = other.matrix
      r = Array.new(4) { Array.new(4, 0.0) }
      4.times do |i|
        4.times do |j|
          s = 0.0
          4.times { |k| s += a[i][k] * b[k][j] }
          r[i][j] = s
        end
      end
      Transformation.new(r)
    end
  end

  # Apply this transform to a point (or 3-element array).
  def self.apply(t, point)
    if point.is_a?(Array)
      x = point[0]; y = point[1]; z = point[2]
    else
      x = point.x;   y = point.y;   z = point.z
    end
    m = t.matrix
    [m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3],
     m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3],
     m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3]]
  end

  # Helper: build a translation matrix from (dx, dy, dz).
  def self.translation(dx, dy, dz)
    Transformation.new([
      [1.0, 0.0, 0.0, dx.to_f],
      [0.0, 1.0, 0.0, dy.to_f],
      [0.0, 0.0, 1.0, dz.to_f],
      [0.0, 0.0, 0.0, 1.0]
    ])
  end

  # Helper: build a uniform-scale matrix.
  def self.scale(s)
    s = s.to_f
    Transformation.new([
      [s,  0.0, 0.0, 0.0],
      [0.0, s,  0.0, 0.0],
      [0.0, 0.0, s,  0.0],
      [0.0, 0.0, 0.0, 1.0]
    ])
  end

  # Fake Vertex (mocks Sketchup::Vertex).
  class Vertex
    attr_reader :position
    def initialize(x, y, z)
      @position = Point3d.new(x, y, z)
    end

    def position=(p)
      @position = p
    end
  end

  # Fake Layer.
  class Layer
    attr_reader :name
    def initialize(name = 'Layer0')
      @name = name.to_s
    end
  end

  # Fake ComponentDefinition (mocks Sketchup::ComponentDefinition).
  # Carries .entities (children of definition) and .name.
  class ComponentDefinition
    attr_reader :name, :children
    def initialize(name: 'Component', children: [])
      @name = name.to_s
      @children = children
    end

    def entities
      @children
    end

    def typename
      'ComponentDefinition'
    end
  end

  # Fake Group. Inherits .entities / .name; .definition returns nil (real
  # SU Groups have no definition). Use as outer container.
  class Group
    attr_reader :children, :transformation, :name
    def initialize(name: 'Group', children: [], transformation: nil, persistent_id: nil)
      @name = name.to_s
      @children = children
      @transformation = transformation || Transformation.new
      @persistent_id = persistent_id
    end

    def entities
      @children
    end

    # Group has no definition in real SU; return nil so container_label
    # falls through to .name.
    def definition
      nil
    end

    def typename
      'Group'
    end

    def persistent_id
      @persistent_id
    end

    def valid?
      true
    end

    def erased?
      false
    end

    def deleted?
      false
    end
  end

  # Fake ComponentInstance. Responds to .definition.entities (NOT
  # .entities directly — that's the S2-BLOCK-002 fix point).
  class ComponentInstance
    attr_reader :definition, :transformation
    def initialize(definition: nil, transformation: nil, persistent_id: nil)
      @definition = definition || ComponentDefinition.new
      @transformation = transformation || Transformation.new
      @persistent_id = persistent_id
    end

    def typename
      'ComponentInstance'
    end

    def persistent_id
      @persistent_id
    end

    def valid?
      true
    end

    def erased?
      false
    end

    def deleted?
      false
    end
  end

  # Fake ComponentDefinition gains persistent_id too.
  class ComponentDefinition
    attr_reader :name, :children, :persistent_id
    def initialize(name: 'Component', children: [], persistent_id: nil)
      @name = name.to_s
      @children = children
      @persistent_id = persistent_id
    end

    def entities
      @children
    end

    def typename
      'ComponentDefinition'
    end

    def valid?
      true
    end

    def erased?
      false
    end

    def deleted?
      false
    end
  end

  # Fake Edge (mocks Sketchup::Edge). Responds to .start, .end,
  # .vertices, .layer, .persistent_id, .definition (with .name).
  #
  # S2-BLOCK-005 round 2: erase! makes the Edge actually invalid by
  # clearing start/end/vertices (calling code must skip via respond_to?
  # + valid? checks before accessing them).
  class Edge
    attr_reader :start, :end, :vertices, :layer, :persistent_id_value, :definition_value
    def initialize(start:, finish: nil, end_pos: nil, layer: nil, persistent_id: nil, definition_name: 'edge')
      @start  = start
      # Accept both `finish:` (legacy / clearer) and `end_pos:` (avoids
      # reserved-word shenanigans) as the second endpoint.
      @end    = finish || end_pos
      @vertices = [start, @end]
      @layer = layer || Layer.new('Layer0')
      @persistent_id_value = persistent_id
      @definition_value = Struct.new(:name).new(definition_name)
      @erased = false
    end

    def persistent_id
      raise InvalidEntityError, 'edge is erased' if @erased
      @persistent_id_value
    end

    def definition
      raise InvalidEntityError, 'edge is erased' if @erased
      @definition_value
    end

    def start
      raise InvalidEntityError, 'edge is erased' if @erased
      @start
    end

    def end
      raise InvalidEntityError, 'edge is erased' if @erased
      @end
    end

    def vertices
      raise InvalidEntityError, 'edge is erased' if @erased
      @vertices
    end

    def typename
      'Edge'
    end

    def valid?
      !@erased
    end

    def erased?
      @erased == true
    end

    def deleted?
      false
    end

    # Erase for invalid-entity tests.
    def erase!
      @erased = true
    end
  end

  # Raised when an invalid (erased) entity is accessed. S2-BLOCK-005
  # round 2: callers (build_snapshot walk) treat this as skip-not-fail.
  class InvalidEntityError < StandardError; end

  # Fake InstancePath (used to test active edit-context + PID path
  # resolution back). Holds a sequence of PIDs and a transformation.
  class InstancePath
    attr_reader :persistent_id_path, :transformation, :leaf_pid
    def initialize(persistent_id_path: [], transformation: nil, leaf_pid: nil)
      @persistent_id_path = persistent_id_path.dup.freeze
      @transformation = transformation
      @leaf_pid = leaf_pid.nil? ? @persistent_id_path.last : leaf_pid
    end
  end

  # Fake Model. Holds entities + active_path; supports
  # instance_path_from_pid_path resolution for tests.
  class Model
    attr_reader :entities, :active_path
    def initialize(entities: [], active_path: nil)
      @entities = entities
      @active_path = active_path
    end

    # Mock resolver. Looks up by full PID path in @pid_path_to_instance;
    # returns the registered InstancePath or nil.
    def instance_path_from_pid_path(pid_path)
      return nil if pid_path.nil? || pid_path.empty?
      @pid_path_registry ||= {}
      @pid_path_registry[pid_path] || @pid_path_registry[pid_path.dup]
    end

    # Test helper: register a PID path -> InstancePath mapping.
    def register_pid_path(pid_path, instance_path)
      @pid_path_registry ||= {}
      @pid_path_registry[pid_path.dup.freeze] = instance_path
    end
  end

  # Fake Selection — Array wrapper with #count, #each, #first, #to_a.
  class Selection
    include Enumerable
    def initialize(items = [])
      @items = items
    end

    def each(&block)
      @items.each(&block)
    end

    def count
      @items.size
    end

    def first
      @items.first
    end

    def to_a
      @items.dup
    end

    def [](idx)
      @items[idx]
    end
  end
end