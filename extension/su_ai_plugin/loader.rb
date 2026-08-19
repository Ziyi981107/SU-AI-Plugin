#
# extension/loader.rb — plugin boot + UI.menu / UI::Command registration.
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

      # Module-level sentinel. NOT a method on a SketchUp::Menu
      # (Round 018 BLOCK-002 finding). The Sketchup::Menu API does
      # not expose `submenus` / `items` reliably across versions.
      @registered = false

      # Module-level cache for the currently-open dialog reference.
      # Per CodeX Round 018 BLOCK-006 + official SketchUp HtmlDialog
      # guidance: keep the dialog reference alive on the Ruby side,
      # otherwise GC may close the window.
      @live_dialog = nil

      # Idempotent UI.menu / UI::Command registration. Returns the
      # registered UI::Command (or nil outside SU). Safe to call
      # multiple times: only the first call constructs the UI.
      def register!
        return @registered if @registered
        return false unless defined?(UI)
        return false unless UI.respond_to?(:menu)
        plugins = UI.menu('Plugins')
        return false if plugins.nil?
        # Find-or-create the submenu. add_submenu is the official API.
        submenu = find_or_create_submenu(plugins, 'SU-AI-Plugin')
        return false if submenu.nil?
        # Find-or-create the command.
        cmd = find_command_by_name(submenu, 'Analyze selection')
        if cmd.nil?
          cmd = UI::Command.new('Analyze selection') { on_analyze_selection }
          submenu.add_item(cmd)
        end
        @registered = true
        cmd
      end

      # Hook called by the Analyze selection menu item.
      # Inside SU: shows the HtmlDialog. Outside SU: no-op fallback.
      def on_analyze_selection
        return nil unless defined?(Sketchup)
        return nil unless Sketchup.respond_to?(:active_model)
        model = Sketchup.active_model
        return nil if model.nil?
        selection = model.respond_to?(:selection) ? model.selection : nil
        return nil if selection.nil? || selection.count.zero?
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
