#
# extension/issue_locator.rb — host-side glue that resolves the
# IssueLocatorPolicy target descriptors into actual SketchUp entities
# using SUCapability + Model APIs.
#
# Per CodeX Review 011..014 (2026-08-18):
#   - This module does NOT touch IssueRegistry or core data shapes.
#   - It only resolves the 6 Profile targets to actual Model entities.
#   - The policy lives in core/issue_locator_policy.rb (pure Ruby).
#   - All resolution is in extension/ (the only place allowed to
#     call Sketchup::Model APIs).
#
# Gate B proof requirements (CodeX Round 014):
#   - nested=false + complete=false + entity_id -> find_entity_by_id
#   - nested=false + complete=true -> InstPath#leaf
#   - nested=true  + complete=true -> InstPath#root
#   - nested=true  + complete=false -> skip (entityID fallback forbidden)
#

require_relative '../core/issue_locator_policy'

module SUAnalysis
  module Extension
    module IssueLocator
      module_function

      # Resolve a single Issue to a list of entities.
      # Returns LocateResult Hash:
      #   :status       :resolved | :unresolved
      #   :targets      Array<Entity>            (when :resolved)
      #   :diagnostics  Array<Hash>              (always; may be empty)
      #   :issue_id     String                   (always)
      def locate(issue, model: nil)
        result = empty_result(issue)
        descriptors = SUAnalysis::Core::IssueLocatorPolicy.targets_for(issue)
        diagnostics = []
        targets = []
        descriptors.each do |d|
          case d[:kind]
          when :skip
            diagnostics << {
              stage:           'issue_locator.skip',
              issue_id:        issue[:issue_id],
              reason:          d[:reason],
              source_pid_path: nil
            }
          when :inst_path_leaf
            entity = resolve_pid_path_leaf(model, d[:pid_path], diagnostics)
            targets << entity if entity
          when :inst_path_root
            entity = resolve_pid_path_root(model, d[:pid_path], diagnostics)
            targets << entity if entity
          when :entity_id
            entity = SUAnalysis::Compatibility::SUCapability.find_entity_by_id(
              model, d[:entity_id]
            )
            if entity.nil?
              diagnostics << {
                stage:    'issue_locator.entity_id_unresolved',
                issue_id: issue[:issue_id],
                entity_id: d[:entity_id]
              }
            end
            targets << entity if entity
          else
            diagnostics << {
              stage:    'issue_locator.unknown_descriptor',
              issue_id: issue[:issue_id],
              kind:     d[:kind].inspect
            }
          end
        end
        # Whole-entity dedup (preserve order).
        targets = targets.compact.uniq
        if targets.empty?
          result[:status] = :unresolved
          result[:diagnostics] = diagnostics
          return result
        end
        result[:status] = :resolved
        result[:targets] = targets
        result[:diagnostics] = diagnostics
        result
      end

      # Variant: apply selection.add(...) + view.zoom(...) to highlight
      # the resolved targets. NEVER mutates any model entity. Mutates
      # only Selection (view-state) and View (camera). Per CodeX Review
      # 005 §R003: NO overlay, NO entity mutation.
      def locate_and_select(issue, model: nil, view: nil)
        result = locate(issue, model: model)
        if result[:status] == :resolved
          clear_selection(model)
          add_to_selection(model, result[:targets])
          zoom_to(model, view, result[:targets]) if view
        end
        result
      end

      # ---- internals ------------------------------------------------------

      # Resolve an InstPath#leaf target. The leaf is the LAST entity
      # in the resolved InstancePath.
      def resolve_pid_path_leaf(model, pid_path, diagnostics)
        instance_path = SUAnalysis::Compatibility::SUCapability.resolve_pid_path(model, pid_path)
        if instance_path.nil?
          diagnostics << {
            stage:    'issue_locator.inst_path_unresolved',
            pid_path: pid_path
          }
          return nil
        end
        leaf = instance_path.respond_to?(:leaf) ? instance_path.leaf : nil
        if leaf.nil?
          diagnostics << {
            stage:    'issue_locator.leaf_nil',
            pid_path: pid_path
          }
          return nil
        end
        leaf
      end

      # Resolve an InstPath#root target. The root is the FIRST entity
      # in the resolved InstancePath (the occurrence of the container).
      def resolve_pid_path_root(model, pid_path, diagnostics)
        instance_path = SUAnalysis::Compatibility::SUCapability.resolve_pid_path(model, pid_path)
        if instance_path.nil?
          diagnostics << {
            stage:    'issue_locator.inst_path_unresolved',
            pid_path: pid_path
          }
          return nil
        end
        root = instance_path.respond_to?(:root) ? instance_path.root : nil
        if root.nil?
          diagnostics << {
            stage:    'issue_locator.root_nil',
            pid_path: pid_path
          }
          return nil
        end
        root
      end

      def empty_result(issue)
        {
          status:      :unresolved,
          targets:     [],
          diagnostics: [],
          issue_id:    issue[:issue_id]
        }
      end

      # clear_selection: model-level selection.clear. read-only on model.
      def clear_selection(model)
        return unless model
        return unless model.respond_to?(:selection)
        return unless model.selection.respond_to?(:clear)
        model.selection.clear
      rescue StandardError
        nil
      end

      # model.selection.add(entity). Fails closed on missing capability.
      def add_to_selection(model, targets)
        return unless model && model.respond_to?(:selection)
        sel = model.selection
        return unless sel.respond_to?(:add)
        Array(targets).each do |t|
          sel.add(t)
        end
      rescue StandardError
        nil
      end

      # view.zoom: camera zoom-to. read-only on model.
      def zoom_to(model, view, targets)
        return unless view
        return if targets.nil? || targets.empty?
        view.zoom(targets)
      rescue StandardError
        nil
      end
    end
  end
end
