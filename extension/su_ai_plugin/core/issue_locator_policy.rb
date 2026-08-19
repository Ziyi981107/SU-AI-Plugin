#
# core/issue_locator_policy.rb — pure-Ruby policy layer that maps a
# UIIssue's SourceToken array into a target list of policy descriptors.
#
# Per CodeX Review 011..014 (2026-08-18), Stage 6 BLOCK-001 v3/v4 + Q3:
#   - The locator policy is pure-Ruby; it does NOT touch SketchUp.
#   - The policy returns a structured descriptor per token:
#       { kind: :inst_path_leaf,  pid_path: [...] }
#       { kind: :inst_path_root,  pid_path: [...] }
#       { kind: :entity_id,       entity_id: <Integer> }
#       { kind: :skip,            reason: "..." }
#   - The actual SketchUp API glue (resolve_pid_path,
#     find_entity_by_id, etc.) lives in `extension/issue_locator.rb`
#     (Gate B scope).
#   - entity_id fallback is restricted to: nested=false,
#     pid_path_complete=false, entity_id != nil. Nested sources
#     (nested=true) ALWAYS skip — entityID alone cannot pick the
#     correct shared component occurrence.
#
# Six profiles (per §6.3 of Stage 6 plan):
#   1. complete-root                (nested=false, complete=true,
#                                    pid_path=[leaf_pid])
#   2. complete-nested              (nested=true, complete=true,
#                                    pid_path=[c, ..., leaf_pid])
#   3. incomplete-root              (nested=false, complete=false,
#                                    pid_path=[], entity_id != nil)
#   4. incomplete-nested-partial-leaf
#                                  (nested=true, complete=false,
#                                    pid_path=[leaf_pid] only)
#   5. incomplete-nested-partial-ancestry
#                                  (nested=true, complete=false,
#                                    pid_path=[])
#   6. fully-missing               (nested=false, complete=false,
#                                    pid_path=[], entity_id = nil)
#

module SUAnalysis
  module Core
    module IssueLocatorPolicy
      module_function

      # Returns an Array<Hash> of target descriptors for one issue.
      # Each descriptor is one of:
      #   { kind: :inst_path_leaf,  pid_path: [...] }
      #   { kind: :inst_path_root,  pid_path: [...] }
      #   { kind: :entity_id,       entity_id: <Integer> }
      #   { kind: :skip,            reason: "<profile>" }
      def targets_for(issue)
        return [] unless issue.is_a?(Hash)
        return [] unless issue[:locatable]
        Array(issue[:sources]).map { |t| target_for_token(t) }
      end

      # Inspect a single SourceToken and return its target descriptor.
      def target_for_token(token)
        return { kind: :skip, reason: 'no-token' } unless token.is_a?(Hash)
        nested    = token[:nested] ? true : false
        complete  = token[:pid_path_complete] ? true : false
        pid_path  = Array(token[:persistent_id_path])
        eid       = token[:entity_id]

        if complete && !nested
          # complete-root: pid_path = [leaf_pid]
          { kind: :inst_path_leaf, pid_path: pid_path.dup.freeze }
        elsif complete && nested
          # complete-nested: pid_path = [c, ..., leaf_pid]
          { kind: :inst_path_root, pid_path: pid_path.dup.freeze }
        elsif !nested && !complete && !eid.nil?
          # incomplete-root: entity_id fallback allowed
          { kind: :entity_id, entity_id: Integer(eid) }
        else
          # incomplete-nested-partial-leaf, incomplete-nested-partial-ancestry,
          # or fully-missing. ALL skip. EntityID fallback is forbidden for
          # nested sources (entityID alone cannot pick the correct shared
          # component occurrence).
          reason = if nested
                    if !pid_path.empty?
                      'incomplete-nested-partial-leaf'
                    else
                      'incomplete-nested-partial-ancestry'
                    end
                  else
                    'fully-missing'
                  end
          { kind: :skip, reason: reason }
        end
      end

      # Convenience: count of select-able targets (excluding :skip).
      def select_count(issue)
        targets_for(issue).count { |t| t[:kind] != :skip }
      end
    end
  end
end
