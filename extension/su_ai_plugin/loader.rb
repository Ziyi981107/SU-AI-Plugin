#
# extension/loader.rb — plugin boot + UI.menu / UI::Command / UI::Toolbar
# registration.
#
# Per CodeX Round 018 BLOCK-002 / BLOCK-004:
#   - Idempotency uses a module-level sentinel (NOT submenus/items
#     introspection, which is not reliably supported on real SketchUp).
#   - register! is safe to call multiple times; second call is a no-op.
#   - show_dialog_for_selection propagates the model down to
#     DialogRunner so the controller can resolve on click.
#   - The dialog returned by DialogRunner.show is held in a module-level
#     cache for the dialog lifetime (real SketchUp convention: a
#     dialog reference must be retained or the window may close under
#     GC). Released on set_on_closed.
#
# Per V1.9A3 Blueprint (AIPM Stage Technical Blueprint
# V1.9A3 Native Toolbar & Product Entry 2026-09-07):
#   - One UI::Command (@cad_prep_command) is shared by the
#     existing menu AND the new SU AI native toolbar. The same
#     command object is attached to both surfaces (NO separate
#     menu-command / toolbar-command objects).
#   - The toolbar is created once, retained in @toolbar, and
#     populated with the SAME @cad_prep_command.
#   - Toolbar visibility respects SketchUp's remembered hidden
#     state via get_last_state / restore / show.
#   - Empty-selection UX shows a friendly SketchUp messagebox
#     instead of silently no-op'ing.
#   - Icons are local PNGs (24x24 / 32x32). No external assets,
#     no UI::Command#extension=, no UI::Command subclassing.
#
# The boot entrypoint lives in extension/su_ai_plugin.rb (NOT this
# file). SketchUp loads su_ai_plugin.rb via the standard .rbz sketchup
# registration pattern; this file is then `require_relative`'d.
#

require_relative 'analyzers_runner'
require_relative 'dialog_runner'

module SUAnalysis
  module Extension
    module Loader
      module_function

      # Toolbar name (per V1.9A3 Blueprint §2). Stable identity for
      # the Sketchup-side toolbar state record.
      TOOLBAR_NAME = 'SU AI'.freeze

      # Menu text / tooltip / status bar text for the shared
      # @cad_prep_command. The dispatch requires exactly these
      # values for product UX consistency.
      COMMAND_MENU_TEXT       = 'CAD Prep'.freeze
      COMMAND_TOOLTIP         = 'SU AI · CAD Prep'.freeze
      COMMAND_STATUS_BAR_TEXT = '检查并准备当前选择的 CAD 几何'.freeze

      # Friendly no-selection message (CN, product-facing).
      # Shown by on_analyze_selection when the selection is empty
      # OR unavailable. Both menu and toolbar invoke this path
      # because they share the SAME command object.
      NO_SELECTION_MESSAGE = '请先选择需要检查和处理的 CAD 几何。'.freeze

      # Module-level sentinels. NOT methods on a Sketchup::Menu
      # (Round 018 BLOCK-002 finding). The Sketchup::Menu API does
      # not expose `submenus` / `items` reliably across versions.
      @registered = false

      # Module-level cache for the currently-open dialog reference.
      # Per CodeX Round 018 BLOCK-006 + official SketchUp HtmlDialog
      # guidance: keep the dialog reference alive on the Ruby side,
      # otherwise GC may close the window.
      @live_dialog = nil

      # V1.9A3: the ONE shared UI::Command object. Both the menu
      # item and the toolbar button invoke THIS SAME object
      # (Blueprint §4 Command Ownership). Retained for the process
      # lifetime so `cmd` is not GC'd between SketchUp sessions.
      @cad_prep_command = nil

      # V1.9A3: the retained UI::Toolbar object. Created once on
      # the first register! call; reused on every subsequent call.
      @toolbar = nil

      # Idempotent UI.menu / UI::Command / UI::Toolbar registration.
      # Returns the registered shared UI::Command (or nil outside
      # SU). Safe to call multiple times: only the first call
      # constructs the UI; subsequent calls return the SAME retained
      # command object (Blueprint §4: "the SAME UI::Command object
      # is reusable from both the menu and toolbar"). The sentinels
      # + retained references guarantee no duplicate menu item, no
      # duplicate toolbar, and no duplicate toolbar button.
      def register!
        return @cad_prep_command if @registered && !@cad_prep_command.nil?
        return false unless defined?(UI)
        return false unless UI.respond_to?(:menu)
        plugins = UI.menu('Plugins')
        return false if plugins.nil?
        # 1. Build the shared command object.
        cmd = build_cad_prep_command
        return false if cmd.nil?
        # 2. Attach the SAME command to the existing submenu.
        submenu = find_or_create_submenu(plugins, 'SU-AI-Plugin')
        return false if submenu.nil?
        add_command_to_submenu(submenu, cmd)
        # 3. Attach the SAME command to the new toolbar.
        toolbar = find_or_create_toolbar(TOOLBAR_NAME)
        return false if toolbar.nil?
        add_command_to_toolbar(toolbar, cmd)
        # 4. Apply toolbar visibility policy (Blueprint §6).
        apply_toolbar_visibility_policy(toolbar)
        @registered = true
        cmd
      end

      # Hook called by the shared @cad_prep_command (menu + toolbar).
      # Inside SU with a non-empty selection: shows the HtmlDialog.
      # With no selection (or outside SU): shows a friendly
      # SketchUp-native message and stops. Both menu and toolbar
      # share this behavior because they invoke the same command
      # block (Blueprint §3 Interaction Contract).
      def on_analyze_selection
        return nil unless defined?(Sketchup)
        return nil unless Sketchup.respond_to?(:active_model)
        model = Sketchup.active_model
        return nil if model.nil?
        selection = model.respond_to?(:selection) ? model.selection : nil
        if selection.nil? || selection.count.zero?
          show_no_selection_message
          return nil
        end
        show_dialog_for_selection(selection, model)
      end

      # Build the AnalysisResult and show the dialog. Propagates the
      # model (Round 018 BLOCK-004) so the controller can resolve
      # Locate clicks against the real model.
      def show_dialog_for_selection(selection, model)
        return nil unless defined?(UI::HtmlDialog)
        return nil unless UI::HtmlDialog.respond_to?(:new)
        result = AnalyzersRunner.run(selection, model: model)
        DialogRunner.show(result, model: model)
      end

      # Display the friendly no-selection message. Uses the stable
      # UI.messagebox API when available; degrades gracefully in
      # the test env. Per Blueprint §3 the message must NOT open
      # a half-empty dialog.
      #
      # The SketchUp UI::messagebox method takes (message, buttons)
      # where buttons is a bitflag constant (MB_OK / MB_OKCANCEL /
      # etc.). MB_OK is the standard OK-only dialog. We resolve
      # the constant defensively (defined? + Object.const_get) so
      # the test env (which lacks UI::MB_OK) does not NameError on
      # this fallback path.
      def show_no_selection_message
        if defined?(UI) && UI.respond_to?(:messagebox)
          buttons = ui_messagebox_buttons_ok
          UI.messagebox(NO_SELECTION_MESSAGE, buttons)
          return true
        end
        # Test env / no UI: emit on stdout so tests can assert it.
        $stdout.puts(NO_SELECTION_MESSAGE)
        true
      end

      # Resolve the SketchUp UI::MB_OK constant defensively. Real
      # SU defines MB_OK inside the UI module (so UI::MB_OK works).
      # Some hosts / test envs may lack the constant; we fall back
      # to nil (which is a valid messagebox argument on legacy hosts
      # that take only the message string).
      def ui_messagebox_buttons_ok
        if defined?(UI::MB_OK)
          UI::MB_OK
        elsif defined?(MB_OK)
          MB_OK
        else
          nil
        end
      end

      # Test-facing accessor for the retained shared command. The
      # Blueprint requires the SAME object be used by menu + toolbar;
      # tests assert via this accessor (and via the toolbar's
      # recorded item).
      def cad_prep_command
        @cad_prep_command
      end

      # Test-facing accessor for the retained toolbar.
      def cad_prep_toolbar
        @toolbar
      end

      # Release the held dialog reference. Called by DialogRunner via
      # set_on_closed. Idempotent.
      def release_dialog!
        @live_dialog = nil
      end

      # Hold the live dialog reference for the dialog lifetime.
      # Per CodeX Round 018 BLOCK-006 + official SketchUp HtmlDialog
      # guidance: keep the dialog reference alive on the Ruby side,
      # otherwise GC may close the window.
      def keep_dialog!(dialog)
        @live_dialog = dialog
      end

      # ---- internals ------------------------------------------------------

      # Build the shared @cad_prep_command object. Sets menu_text /
      # tooltip / status_bar_text / small_icon / large_icon per the
      # Blueprint §2 + §4 + §6 contract. The block invokes the
      # shared on_analyze_selection (Blueprint §4: "The command
      # block must call the existing on_analyze_selection").
      def build_cad_prep_command
        return @cad_prep_command unless @cad_prep_command.nil?
        return nil unless defined?(UI::Command)
        return nil unless UI::Command.respond_to?(:new)
        cmd = UI::Command.new(COMMAND_MENU_TEXT) { on_analyze_selection }
        configure_cad_prep_command(cmd)
        @cad_prep_command = cmd
        cmd
      end

      # Apply the Blueprint §2 + §6 textual + icon configuration to
      # a command. Tolerates older hosts that lack individual
      # setters (we check respond_to? defensively) so the registration
      # does not crash on the legacy baseline.
      def configure_cad_prep_command(cmd)
        return if cmd.nil?
        if cmd.respond_to?(:tooltip=)
          cmd.tooltip = COMMAND_TOOLTIP
        end
        if cmd.respond_to?(:status_bar_text=)
          cmd.status_bar_text = COMMAND_STATUS_BAR_TEXT
        end
        # Icons: local PNGs only (Blueprint §6 + §9). Use absolute
        # paths resolved against __dir__ so the icons load both in
        # the dev tree and inside the installed .rbz layout.
        small = File.join(__dir__, 'icons', 'cad_prep_24.png')
        large = File.join(__dir__, 'icons', 'cad_prep_32.png')
        if cmd.respond_to?(:small_icon=)
          cmd.small_icon = small
        end
        if cmd.respond_to?(:large_icon=)
          cmd.large_icon = large
        end
        # Per Blueprint §9: do NOT use UI::Command#extension= and
        # do NOT subclass UI::Command. These are intentionally
        # absent.
        cmd
      end

      # Attach the shared command to the existing submenu. Uses
      # add_item (the official API). Idempotency is provided by
      # the @registered sentinel, NOT by submenu introspection
      # (Round 018 BLOCK-002).
      def add_command_to_submenu(submenu, cmd)
        return nil unless submenu.respond_to?(:add_item)
        submenu.add_item(cmd)
        cmd
      end

      # Find-or-create the SU AI toolbar (Blueprint §5 Lifetime /
      # Idempotency). The retained @toolbar reference guarantees a
      # second register! call returns the SAME toolbar (no duplicate
      # `SU AI` toolbar is created).
      def find_or_create_toolbar(name)
        return @toolbar unless @toolbar.nil?
        return nil unless defined?(UI::Toolbar)
        return nil unless UI::Toolbar.respond_to?(:new)
        tb = UI::Toolbar.new(name)
        @toolbar = tb
        tb
      end

      # Attach the shared command to the toolbar. Uses add_item (the
      # official UI::Toolbar API). The @toolbar retained reference
      # ensures repeated register! does not duplicate the button.
      def add_command_to_toolbar(toolbar, cmd)
        return nil unless toolbar.respond_to?(:add_item)
        toolbar.add_item(cmd)
        cmd
      end

      # Apply the Blueprint §6 Toolbar Visibility Policy:
      #   - TB_NEVER_SHOWN: call show (first discovery path).
      #   - previously visible: call restore.
      #   - previously hidden: do NOT force-show. Restore is
      #     tolerant: the SketchUp host uses the toolbar's last
      #     state, so a hidden toolbar stays hidden.
      # We use get_last_state defensively (respond_to?) so the
      # registration does not crash on hosts that lack the API.
      def apply_toolbar_visibility_policy(toolbar)
        return if toolbar.nil?
        state = nil
        if toolbar.respond_to?(:get_last_state)
          begin
            state = toolbar.get_last_state
          rescue StandardError
            state = nil
          end
        end
        never_shown = defined?(TB_NEVER_SHOWN) &&
                      state == TB_NEVER_SHOWN
        if never_shown
          toolbar.show if toolbar.respond_to?(:show)
        elsif toolbar.respond_to?(:restore)
          toolbar.restore
        end
        true
      end

      # Find-or-create a submenu under `parent` by name. Uses add_submenu
      # which is the official Sketchup::Menu API. Avoids submenus[]
      # enumeration (Round 018 BLOCK-002 finding).
      def find_or_create_submenu(parent, name)
        return nil unless parent.respond_to?(:add_submenu)
        # The official Sketchup::Menu API does NOT expose `submenus[]`
        # reliably across versions. We create-or-return with add_submenu;
        # if it already exists, we tolerate the duplicate-submenu warning
        # and proceed.
        parent.add_submenu(name)
      rescue StandardError
        nil
      end

      # Find a command under `submenu` by name. The official API
      # does NOT expose `items[]` reliably; we degrade gracefully
      # and let register! create a new one if needed. To enforce
      # idempotency, we use a module-level sentinel, not menu
      # introspection.
      def find_command_by_name(submenu, name)
        # Best-effort: in real SketchUp, submenu.items is not a
        # standard method. We try; if it fails, treat as "not found".
        return nil unless submenu.respond_to?(:items)
        items = submenu.items
        return nil unless items.is_a?(Array)
        items.find { |i| i.respond_to?(:name) && i.name == name }
      rescue StandardError
        nil
      end
    end
  end
end
