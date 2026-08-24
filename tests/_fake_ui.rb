#
# tests/_fake_ui.rb — minimal stand-ins for SketchUp UI objects used
# by Gate B (Round 018 BLOCK-002 + BLOCK-006).
#
# The fake Sketchup::UI module is a REAL Module so that:
#   - UI::Command.new(name) { block } works (constant lookup)
#   - UI::HtmlDialog.new(opts) works (constant lookup)
#   - UI.menu(name) is an INSTANCE method (per-instance state, no
#     cross-test leakage)
#
# SketchUp's real UI module is a Module with both constants and a
# per-session menu hierarchy. The fake mirrors that shape.
#
# Usage:
#   require_relative '_fake_ui'
#   FakeUI.install!           # stubs the global UI constant
#   FakeUI.reset!             # fresh per-test state
#   FakeUI.uninstall!         # restores the no-UI world (in ensure)
#
# Inside a test:
#   FakeUI.install!
#   Loader.register!         # sees UI.menu('Plugins') as a fresh FakeMenu
#   cmd = UI.menu('Plugins').submenus[0].items[0]
#   ...
# ensure
#   FakeUI.uninstall!
#

module FakeUI
  # A sketchup::Command stand-in. The block is invoked when the
  # menu item is "clicked" via #call_handler.
  class FakeCommand
    attr_reader :name
    def initialize(name)
      @name = name.to_s
      @handler = nil
    end
    def set_handler(&block)
      @handler = block
    end
    def call_handler(*args)
      @handler.call(*args) if @handler
    end
  end

  # A sketchup::Menu stand-in. add_submenu / add_item behave like
  # the real SU API:
  #   - add_submenu(name) creates a NEW submenu every call (does NOT
  #     find-or-create by name). The real Sketchup::Menu does not
  #     guarantee create-or-return semantics across versions, and
  #     per CodeX Round 019 BLOCK-002-R2 a nonstandard find-or-create
  #     would HIDE a real duplicate. Production code MUST rely on
  #     file_loaded? + module-level @registered sentinels for
  #     idempotency, NOT on this method.
  #   - add_item(cmd) appends unconditionally.
  class FakeMenu
    attr_reader :name, :items, :submenus
    def initialize(name)
      @name = name.to_s
      @items = []
      @submenus = []
    end
    def add_item(cmd)
      @items << cmd
      cmd
    end
    def add_submenu(name)
      # Honest mirror of the real API: always creates a new submenu.
      sub = self.class.new(name)
      @submenus << sub
      sub
    end
  end

  # A sketchup::HtmlDialog stand-in. Records every lifecycle call
  # (set_file, add_action_callback, execute_script, set_on_closed,
  # show) for test inspection.
  class FakeHtmlDialog
    attr_reader :callbacks, :executed_scripts,
                :set_on_closed_blocks, :set_files
    def initialize(_opts = nil)
      @callbacks = {}
      @executed_scripts = []
      @set_on_closed_blocks = []
      @set_files = []
    end
    def set_file(path)
      @set_files << path
    end
    def add_action_callback(name, &block)
      @callbacks[name] = block
    end
    def execute_script(js)
      @executed_scripts << js
    end
    def set_on_closed(&block)
      @set_on_closed_blocks << block
    end
    def show
      true
    end
  end

  # A sketchup::Selection stand-in. Mirrors the bits the
  # extension/issue_locator.rb uses: #clear, #add, #each, #count.
  class FakeSelection
    attr_reader :items
    def initialize
      @items = []
    end
    def clear
      @items = []
      self
    end
    def add(item)
      @items << item
      self
    end
    def count
      @items.length
    end
    def each(&block)
      @items.each(&block)
    end
    def to_a
      @items.dup
    end
  end

  # FakeModel with a selection (FakeSelection) and an active_view.
  # V1.4 (per directive 030 CodeX BLOCK fix Stage 4): the fake
  # model now ALSO supports SketchUp operations
  # (start_operation / commit_operation / abort_operation) and
  # an active_entities collection that emulates
  # Sketchup::Entities#add_group + erase!. This is what makes
  # the production-adapter call chain exercisable from tests
  # WITHOUT faking the operation boundary. Tests that need
  # to verify the production contract (dialog callback ->
  # WorkingModeRunner -> workspace.build_entity -> real-adapter
  # contract) use this FakeModel via the controller.
  class FakeModel
    # A sketchup::Group-like entity in active_entities.
    class FakeGroup
      attr_reader :entities, :entityID
      attr_accessor :persistent_id
      # V1.4 CodeX V14-RUNTIME-BLOCK-003 (2026-08-22): the
      # real Sketchup::Group exposes `name` as a property
      # with a `name=` writer. The Struct-based FakeGroup
      # cannot override the auto-generated Struct writers
      # via attr_reader; we use a custom method that
      # reads + writes through @name and replaces the
      # auto-generated writer.
      def initialize(name, id_counter)
        @name = name.to_s
        @entityID = id_counter
        @persistent_id = id_counter
        @entities = FakeEntities.new(@entityID)
        @valid = true
      end
      def name
        @name
      end
      # The production adapter calls `g.name = NAME_PREFIX + name.to_s`
      # -- the recognizable derived group name assignment.
      # The real Sketchup::Group supports this property
      # writer; the FakeGroup must mirror it.
      def name=(value)
        @name = value.to_s
      end
      def valid?
        @valid == true
      end
      def erase!
        @valid = false
        @entities.invalidate_all!
        true
      end
    end
    class FakeEntities
      # V1.4 CodeX BLOCK rework (2026-08-21): the fake host
      # now distinguishes the MODEL ROOT entities (per
      # directive: "if the product contract is model root,
      # use model.entities") from the active-edit-context
      # entities. add_groups / add_face / add_edges /
      # invalidate_all mirror the real Sketchup::Entities API.
      attr_reader :groups, :next_id, :faces, :edges
      def initialize(parent_id = 0)
        @groups = []
        @faces = []
        @edges = []
        @next_id = (parent_id * 1000) + 1
        @face_id = 0
        @edge_id = 0
      end
      def add_group(*args)
        # V1.4 CodeX V14-RUNTIME-BLOCK-003 (2026-08-22):
        # match the real SketchUp::Entities#add_group contract
        # -- it takes NO arguments (or an optional Sketchup::Entity
        # to pre-populate with). Calling add_group with a
        # String is a TypeError on a real host. The test
        # stub MUST match the real signature so the test
        # suite catches the BLOCK, not mask it.
        unless args.empty?
          raise TypeError, "add_group expects 0 arguments (or 1 Sketchup::Entity); got #{args.length} (#{args.inspect})"
        end
        @next_id += 1
        g = FakeGroup.new('', @next_id)
        @groups << g
        g
      end
      # V1.4 CodeX BLOCK rework (2026-08-21): add_edges (one
      # polyline = one edge) faithfully stores the two
      # world-coordinate endpoints. Used for derived Edge
      # records (NOT for fabricating a 3-point face).
      def add_edges(points)
        unless points.is_a?(Array) && points.length == 2
          raise ArgumentError,
                "add_edges requires exactly 2 world-coordinate points; got #{points.inspect}"
        end
        s = points[0]
        e = points[1]
        unless s.is_a?(Array) && s.length == 3 && e.is_a?(Array) && e.length == 3
          raise ArgumentError,
                "add_edges requires 3-element Arrays for both endpoints"
        end
        @edge_id += 1
        # Sketchup::Entities#add_edges returns one Edge per
        # consecutive pair of points. With 2 points we get 1
        # edge. Mimic that.
        edge = FakeEdge.new(@edge_id, s.dup, e.dup)
        @edges << edge
        edge
      end
      def add_face(points)
        # Mimics Sketchup::Entities#add_face: returns a face
        # handle (a plain Object exposing the minimum face API).
        @face_id += 1
        face = Object.new
        face.define_singleton_method(:entityID) { @face_id }
        face.define_singleton_method(:persistent_id) { @face_id }
        face.define_singleton_method(:points) { Array(points).map(&:dup) }
        face.define_singleton_method(:vertices) { Array(points).map(&:dup) }
        face.define_singleton_method(:valid?) { true }
        @faces << face
        face
      end
      def invalidate_all!
        @groups.each(&:erase!)
        @edges.clear
        @faces.clear
      end
      def valid_count
        @groups.count(&:valid?)
      end
      def valid_edge_count
        @edges.size
      end
    end
    # A fake Sketchup::Edge: stores start / end / entityID /
    # persistent_id. Mimics the real API for downstream
    # assertions (per BLOCK 7 risk test: source Edge ->
    # derived Edge endpoints must be XYZ-identical).
    class FakeEdge
      attr_reader :entityID, :start, :end
      attr_accessor :persistent_id
      def initialize(entity_id, start, e)
        @entityID = entity_id
        @persistent_id = entity_id
        @start = start.dup
        @end = e.dup
      end
      def valid?
        true
      end
    end

    attr_reader :selection, :active_view, :active_entities,
                :entities, :operation_log

    def initialize
      @selection = FakeSelection.new
      @active_view = FakeView.new
      # V1.4 CodeX BLOCK rework (2026-08-21): the production
      # adapter writes at the MODEL ROOT (model.entities), not
      # active_entities. The fake model supports both; the
      # V1.4 plumbing path uses entities (root).
      @entities = FakeEntities.new
      @active_entities = FakeEntities.new(1)
      # V1.4 V14-STAGE-BLOCK-002 (2026-08-24): operation
      # wrapping uses SEQUENTIAL semantics (NOT a nestable
      # counter stack). At most ONE operation may be open
      # at a time. start_operation when one is open
      # auto-closes the previous (logged as :implicit_close);
      # commit_operation / abort_operation when no operation
      # is open raise.
      @operation_log = []
      @operation_open = false
      @current_operation_label = nil
      # V1.4 CodeX BLOCK rework (2026-08-21): edit_transform
      # support for the active-edit-context inverse transform
      # test. The default is nil (no active edit; identity).
      # When non-nil, edit_transform MUST expose `.to_a`
      # returning a 16-float Array (the canonical
      # Geom::Transformation flattened form). inject_edit_transform
      # accepts any object that responds to .to_a; the
      # dialog_runner reads the result via .to_a.
      @edit_transform = nil
    end

    # The production adapter resolves the destination via
    # `model.entities` (root). For tests, we set this up
    # in FakeModel.new by instantiating FakeEntities.
    #
    # V1.4 V14-STAGE-BLOCK-002 (2026-08-24, CodeX V1.4 Stage Review):
    # the FakeModel MUST mimic real SketchUp's SEQUENTIAL
    # operation semantics, NOT the prior nestable counter
    # stack. Per the SketchUp Ruby API: calling
    # Model#start_operation while another operation is open
    # implicitly ends the previous one. The previous
    # implementation (counter stack) hid this behavior
    # and let the workspace's per-entity begin_operation
    # calls (now removed) appear to nest cleanly. Now we
    # expose the real-SU auto-close + single-open invariant:
    # at most ONE operation may be open at a time; calling
    # start_operation when one is already open auto-closes
    # the previous (logged as :implicit_close with the
    # previous label); calling commit_operation /
    # abort_operation when no operation is open raises.
    def start_operation(label, disable_ui = false)
      if @operation_open
        # Implicit close of the previous operation
        # (real SU closes it via commit when the user
        # starts a new top-level operation; we log it
        # for diagnostic visibility).
        @operation_log << {
          kind:       :implicit_close,
          prev_label: @current_operation_label.to_s,
          new_label:  label.to_s
        }
      end
      @operation_log << { kind: :start, label: label.to_s, disable_ui: disable_ui }
      @operation_open            = true
      @current_operation_label   = label.to_s
      true
    end

    def commit_operation
      unless @operation_open
        raise 'SU commit_operation called with no matching start_operation'
      end
      @operation_log << { kind: :commit }
      @operation_open            = false
      @current_operation_label   = nil
      true
    end

    # V1.4 CodeX BLOCK rework (2026-08-21): the abort path
    # invalidates entities at the MODEL ROOT, where the V1.4
    # production adapter writes. (The previous version only
    # invalidated active_entities, which is wrong because the
    # production adapter writes to model.entities.)
    #
    # V1.4 V14-STAGE-BLOCK-002: abort invalidates the same
    # entities and logs :abort. After abort, the operation
    # stack is empty (single-open invariant holds).
    def abort_operation
      unless @operation_open
        raise 'SU abort_operation called with no matching start_operation'
      end
      invalidated_root = @entities.invalidate_all!
      invalidated_active = @active_entities.invalidate_all!
      @operation_log << {
        kind: :abort,
        invalidated_root: invalidated_root,
        invalidated_active: invalidated_active
      }
      @operation_open            = false
      @current_operation_label   = nil
      true
    end

    # Test hook: also expose the single-open invariant via a
    # predicate (cheaper than reaching into @operation_open).
    def operation_open?
      @operation_open ? true : false
    end

    # Test hook: inject an edit_transform that the
    # production adapter's inverse_world_to_local_transform
    # will read. The transform is a plain Object with
    # `.inverse` so the adapter's `transform.respond_to?(:inverse)`
    # branch picks it up.
    def inject_edit_transform(transform)
      @edit_transform = transform
    end

    def edit_transform
      @edit_transform
    end
  end

  class FakeView
    attr_reader :zoom_calls
    def initialize
      @zoom_calls = []
    end
    def zoom(targets)
      @zoom_calls << Array(targets)
    end
  end

  # The UI module stub. A real Module so UI::Command and
  # UI::HtmlDialog resolve as constants. The instance methods
  # (menu / HtmlDialog) delegate to FakeUI.state.
  module UIStub
    # ::Command and ::HtmlDialog are added via const_set below.
  end

  # Per-test UI state. Each test calls FakeUI.reset! to get a
  # fresh menu hierarchy and a fresh dialog list.
  class State
    attr_reader :menus, :dialogs
    def initialize
      @menus = {}
      @dialogs = []
    end
    def menu(name)
      @menus[name.to_s] ||= FakeMenu.new(name)
    end
    def new_dialog(opts = nil)
      d = FakeHtmlDialog.new(opts)
      @dialogs << d
      d
    end
  end

  class << self
    # Stash the previous global UI (if any) so uninstall! can
    # restore it. Tests share the install lifecycle.
    def install!
      @previous_ui = if Object.const_defined?(:UI)
                       Object.const_get(:UI)
                     else
                       :__undefined__
                     end
      Object.send(:remove_const, :UI) if Object.const_defined?(:UI)
      Object.const_set(:UI, UIStub)
      reset!
    end

    def uninstall!
      Object.send(:remove_const, :UI) if Object.const_defined?(:UI)
      case @previous_ui
      when :__undefined__
        # leave UI undefined
      when nil
        # nothing was there
      else
        Object.const_set(:UI, @previous_ui)
      end
      @previous_ui = nil
      @state = nil
    end

    def reset!
      @state = State.new
    end

    def state
      @state ||= State.new
    end
  end
end

# UIStub singleton methods: per-instance menu / HtmlDialog delegation.
module FakeUI::UIStub
  def self.menu(name)
    FakeUI.state.menu(name)
  end
end

# UI::Command constant. The loader does UI::Command.new(name) { block }.
FakeUI::UIStub.const_set(:Command, Class.new do
  def self.new(name, &block)
    cmd = FakeUI::FakeCommand.new(name)
    cmd.set_handler(&block) if block
    cmd
  end
end)

# UI::HtmlDialog constant. DialogRunner does UI::HtmlDialog.new(opts).
# Returns a FakeUI::FakeHtmlDialog recorded in FakeUI.state.dialogs.
FakeUI::UIStub.const_set(:HtmlDialog, Class.new do
  def self.new(opts = nil)
    FakeUI.state.new_dialog(opts)
  end
end)
