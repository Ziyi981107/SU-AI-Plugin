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
      attr_reader :name, :entities, :entityID
      attr_accessor :persistent_id
      def initialize(name, id_counter)
        @name = name.to_s
        @entityID = id_counter
        @persistent_id = id_counter
        @entities = FakeEntities.new(@entityID)
        @valid = true
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
      attr_reader :groups, :next_id, :faces
      def initialize(parent_id = 0)
        @groups = []
        @faces = []
        @next_id = (parent_id * 1000) + 1
        @face_id = 0
      end
      def add_group(name)
        @next_id += 1
        g = FakeGroup.new(name, @next_id)
        @groups << g
        g
      end
      def add_face(points)
        # Mimics Sketchup::Entities#add_face: returns a face
        # handle (a plain Object exposing the minimum face API).
        @face_id += 1
        face = Object.new
        face.define_singleton_method(:entityID) { @face_id }
        face.define_singleton_method(:persistent_id) { @face_id }
        face.define_singleton_method(:points) { Array(points).dup }
        face.define_singleton_method(:valid?) { true }
        @faces << face
        face
      end
      def invalidate_all!
        @groups.each(&:erase!)
      end
      def valid_count
        @groups.count(&:valid?)
      end
    end

    attr_reader :selection, :active_view, :active_entities,
                :operation_log, :open_operations

    def initialize
      @selection = FakeSelection.new
      @active_view = FakeView.new
      @active_entities = FakeEntities.new
      # V1.4: operation wrapping. Each start_operation opens a
      # new frame; commit/abort closes it. If a commit happens
      # with no matching open frame, the model raises (mirrors
      # the real SU behavior of "operation stack underflow").
      @operation_log = []
      @open_operations = 0
    end

    def start_operation(label, disable_ui = false)
      @operation_log << { kind: :start, label: label.to_s, disable_ui: disable_ui }
      @open_operations += 1
      true
    end

    def commit_operation
      raise 'SU commit_operation called with no matching start_operation' if @open_operations <= 0
      @operation_log << { kind: :commit }
      @open_operations -= 1
      true
    end

    def abort_operation
      raise 'SU abort_operation called with no matching start_operation' if @open_operations <= 0
      # Per directive: an aborted operation MUST roll back any
      # entities created within the operation. We emulate this
      # by tracking the groups created since the last
      # commit/abort and invalidating them.
      invalidated = @active_entities.invalidate_all!
      @operation_log << { kind: :abort, invalidated: invalidated }
      @open_operations -= 1
      true
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
