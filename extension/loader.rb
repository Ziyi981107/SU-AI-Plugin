#
# extension/loader.rb — plugin boot: register UI::Command + UI.menu entry.
#
# Per CodeX Round 010 Q3 (R002): HtmlDialog capability is checked at
# show time. Per CodeX Round 011 BLOCK-002: registration is idempotent
# across Ruby reloads (no duplicate menu items).
#
# This is the only place that registers an "Analyze selection" command.
#

require_relative 'analyzers_runner'

module SUAnalysis
  module Extension
    module Loader
      module_function

      # Register exactly one menu item. Safe to call multiple times.
      # Returns the registered UI::Command (or nil in tests).
      def register!
        return nil unless defined?(UI)
        return nil unless UI.respond_to?(:menu)
        menu = find_or_create_plugin_menu
        return nil if menu.nil?
        # Look for an existing item with the same name to avoid duplicates.
        existing = find_existing_command(menu, 'Analyze selection')
        return existing if existing
        cmd = UI::Command.new('Analyze selection') { on_analyze_selection }
        menu.add_item(cmd)
        cmd
      end

      # Hook called by the Analyze selection menu item.
      # Inside SU: shows the HtmlDialog. Outside SU: a no-op fallback.
      def on_analyze_selection
        return nil unless defined?(Sketchup)
        return nil unless Sketchup.respond_to?(:active_model)
        model = Sketchup.active_model
        return nil if model.nil?
        selection = model.respond_to?(:selection) ? model.selection : nil
        return nil if selection.nil? || selection.count.zero?
        show_dialog_for_selection(selection, model)
      end

      # Display an actual HtmlDialog with the analysis result.
      # Per CodeX Round 004 BLOCK-004: lazy-loaded and idempotent.
      # Per CodeX Q4: external local assets via set_file absolute path.
      # Per CodeX Round 004 BLOCK-006: HtmlDialog lives in UI module.
      def show_dialog_for_selection(selection, model)
        return nil unless defined?(UI::HtmlDialog)
        return nil unless UI::HtmlDialog.respond_to?(:new)
        result = AnalyzersRunner.run(selection, model: model)
        DialogRunner.show(result)
      end

      # ---- internals ------------------------------------------------------

      def find_or_create_plugin_menu
        return nil unless UI.respond_to?(:menu)
        plugins = UI.menu('Plugins')
        return nil if plugins.nil?
        # Find existing submenu by name.
        existing = nil
        if plugins.respond_to?(:submenus)
          existing = plugins.submenus.find { |s| s.respond_to?(:name) && s.name == 'SU-AI-Plugin' }
        end
        return existing if existing
        if plugins.respond_to?(:add_submenu)
          plugins.add_submenu('SU-AI-Plugin')
        else
          nil
        end
      end

      def find_existing_command(menu, name)
        return nil unless menu.respond_to?(:items)
        menu.items.find { |i| i.respond_to?(:name) && i.name == name }
      end
    end
  end
end
