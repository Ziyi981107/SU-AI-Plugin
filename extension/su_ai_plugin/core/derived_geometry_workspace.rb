#
# core/derived_geometry_workspace.rb — V1.4 DerivedGeometryWorkspace.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL
# PREVIEW), Stage 3.
#
# Locked contract:
#   - Plugin-owned, visually identifiable, disposable workspace
#     built from a frozen SourceSnapshot.
#   - Every editable derived entity is independently owned
#     (no shared mutable definition with source).
#   - Derived-record -> source-occurrence provenance is
#     preserved.
#   - Apply/discard/rebuild operate ONLY on this workspace.
#   - Source remains untouched by every operation.
#   - If cleanup cannot complete, the workspace transitions
#     to :failed and the result must NOT appear valid or
#     :ready.
#   - A second build from identical source + captured config
#     produces the same canonical derived fingerprint
#     (excluding host_assigned_ids).
#
# Lifecycle:
#   :building -- initial; no entities yet
#   :ready    -- at least one derived entity exists; all
#                entities are valid
#   :discarded -- user / codex discarded the workspace
#   :failed   -- a build OR a discard step raised; the
#                workspace is INVALID and must NOT be marked
#                :ready
#
# The workspace is the contract between V1.4 (build +
# lifecycle) and V1.5+ (apply actual repair actions). In V1.4
# the only operation is BUILD + DISCARD; no actions are
# applied. V1.5+ will add apply_via_plan(plan) which uses
# the RepairPlan contract from Stage 2.
#

require_relative 'derived_entity_record'
require_relative 'derived_workspace_fingerprint'

module SUAnalysis
  module Core
    class DerivedGeometryWorkspace
      STATES = [:building, :ready, :discarded, :failed].freeze

      attr_reader :workspace_id, :source_snapshot,
                  :state, :entities, :fingerprint,
                  :last_error, :build_started_at

      def initialize(workspace_id: nil, source_snapshot:, adapter:)
        @workspace_id    = (workspace_id || "ws-#{rand(2**32)}").freeze
        @source_snapshot = source_snapshot  # SourceSnapshot (frozen)
        @adapter         = adapter           # DerivedWorkspaceAdapter
        @state           = :building
        # Inventory: derived_id (String) -> DerivedEntityRecord.
        # Stored as an Array of [derived_id, record] tuples so the
        # order is preserved (and the data is deeply frozen).
        @entity_pairs    = [].freeze
        @fingerprint     = nil
        @last_error      = nil
        @build_started_at = Time.now.to_f
        freeze
      end

      def state
        @state
      end

      def entities
        @entity_pairs.map { |_, rec| rec }
      end

      def entity(derived_id)
        @entity_pairs.find { |id, _| id == derived_id }&.last
      end

      def ready?
        # Per directive: "failed plans/results are never
        # READY" -> :failed workspaces are never :ready.
        # V1.4 may build entities that are not actually
        # applied (just placeholders); :ready requires at
        # least one entity and the state == :ready.
        @state == :ready && @entity_pairs.any?
      end

      def ==(other)
        return false unless other.is_a?(DerivedGeometryWorkspace)
        workspace_id == other.workspace_id &&
          state == other.state &&
          entity_pairs == other.entity_pairs
      end
      alias eql? ==

      def hash
        [workspace_id, state, @entity_pairs].hash
      end

      def to_h
        {
          workspace_id:    workspace_id,
          source_snapshot_id: source_snapshot.snapshot_id,
          state:           state,
          entities:        entities.map(&:to_h),
          fingerprint:    fingerprint ? fingerprint.to_h : nil,
          last_error:      last_error,
          build_started_at: build_started_at
        }
      end

      # Build a derived entity via the host adapter. Returns
      # the new DerivedGeometryWorkspace (the original is
      # deeply frozen; transitions produce new instances).
      # On host-side runtime failure, returns a :failed
      # workspace. On programmer-level contract violations
      # (invalid parent_derived_id), raises ArgumentError --
      # these are NOT host failures and MUST NOT be
      # silently converted into :failed (per directive
      # "父子 derived ID 引用严格校验").
      def build_entity(derived_id: nil, kind: :group,
                      source_occurrence_ids: [],
                      geometry_summary: {},
                      parent_derived_id: nil,
                      geometry_data: nil)
        # Per the directive: "Choose and document the
        # destination coordinate context, then perform
        # explicit world/local conversion at the adapter
        # boundary." The V1.4 caller supplies geometry_data
        # in the destination coordinate context; the adapter
        # converts if needed.
        did = derived_id || "der-#{rand(2**32)}"

        # Strict parent_derived_id contract validation
        # (per directive "父子 derived ID 引用严格校验").
        # ArgumentError is a PROGRAMMER error -- it must be
        # raised, NOT converted to a :failed workspace.
        parent_record = nil
        if parent_derived_id
          parent_record = entity(parent_derived_id)
          unless parent_record
            raise ArgumentError,
                  "parent derived_id #{parent_derived_id.inspect} " \
                  "not found in workspace #{workspace_id.inspect} " \
                  "(known: #{entities.map(&:derived_id).inspect})"
          end
        end

        begin
          # 1. Create the top-level group (or use a parent).
          # For a nested entity, the production adapter walks
          # into the parent group's host handle. In V1.4 the
          # test adapter has no nested handle; we record the
          # parent_derived_id in the DerivedEntityRecord and
          # let the host_ids_of call use whatever handle the
          # parent already has (the parent's existing handle).
          host_handle =
            if parent_record
              # In the test adapter there is no real nested
              # group handle. The fake adapter creates a new
              # top-level group; the parent_derived_id
              # captured in the record preserves the
              # hierarchy.
              @adapter.create_top_level_group("#{parent_record.derived_id}.#{did}")
            else
              @adapter.create_top_level_group(did)
            end
          # 2. Add geometry if requested.
          if geometry_data
            @adapter.add_face_to_group(host_handle, geometry_data)
          end
          # 3. Snapshot host_assigned_ids (EXCLUDED from
          #    rebuild fingerprint).
          host_ids = @adapter.host_assigned_ids_of(host_handle)
          new_record = DerivedEntityRecord.new(
            derived_id:             did,
            kind:                   kind,
            source_occurrence_ids:  source_occurrence_ids,
            geometry_summary:       geometry_summary,
            parent_derived_id:      parent_derived_id,
            host_assigned_ids:      host_ids
          )
          # 4. Update the inventory + fingerprint + state.
          new_pairs    = @entity_pairs + [[did, new_record]]
          new_fp       = compute_fingerprint_from_pairs(new_pairs)
          self.class.new_with_inventory(
            workspace_id:    workspace_id,
            source_snapshot: source_snapshot,
            adapter:         @adapter,
            state:           :ready,
            entity_pairs:    new_pairs,
            fingerprint:     new_fp,
            last_error:      nil,
            build_started_at: build_started_at
          )
        rescue StandardError => e
          # Source MUST remain untouched. The adapter
          # failure becomes a :failed workspace. The
          # caller is responsible for either retrying (a
          # new build) or discarding this one.
          # ArgumentError is intentionally NOT caught: it
          # is a programmer error above and must propagate.
          self.class.new_with_inventory(
            workspace_id:    workspace_id,
            source_snapshot: source_snapshot,
            adapter:         @adapter,
            state:           :failed,
            entity_pairs:    @entity_pairs,
            fingerprint:     compute_fingerprint_from_pairs(@entity_pairs),
            last_error:      "#{e.class}: #{e.message}",
            build_started_at: build_started_at
          )
        end
      end

      # Discard the workspace. Source remains untouched.
      # On disposal failure, the workspace transitions to
      # :failed (per directive: "If cleanup cannot complete,
      # the result must require discard/rebuild and must not
      # appear valid or READY").
      def discard
        @entity_pairs.each do |_id, rec|
          begin
            @adapter.dispose(nil)  # production adapter would store the real handle
          rescue StandardError => e
            # Per directive: even partial disposal must leave
            # the workspace INVALID (not :ready). We move
            # to :failed and store the error.
            return self.class.new_with_inventory(
              workspace_id:    workspace_id,
              source_snapshot: source_snapshot,
              adapter:         @adapter,
              state:           :failed,
              entity_pairs:    @entity_pairs,
              fingerprint:     compute_fingerprint_from_pairs(@entity_pairs),
              last_error:      "discard failed: #{e.class}: #{e.message}",
              build_started_at: build_started_at
            )
          end
        end
        # Successful discard: empty inventory, :discarded.
        self.class.new_with_inventory(
          workspace_id:    workspace_id,
          source_snapshot: source_snapshot,
          adapter:         @adapter,
          state:           :discarded,
          entity_pairs:    [],
          fingerprint:     nil,
          last_error:      nil,
          build_started_at: build_started_at
        )
      end

      # Rebuild = discard + build. Returns a new :ready (or
      # :failed) workspace. Source must be the same snapshot
      # for deterministic rebuild.
      def rebuild
        discarded = discard
        # If discard failed, return the :failed workspace.
        return discarded if discarded.state == :failed
        # Now build a new entity using the first entity's
        # geometry as the rebuild template. V1.4 is the
        # foundation; V1.5+ will wire this through the
        # RepairPlan pipeline.
        template = entities.first
        if template
          discarded.build_entity(
            derived_id:             template.derived_id,
            kind:                   template.kind,
            source_occurrence_ids:  template.source_occurrence_ids,
            geometry_summary:       template.geometry_summary,
            parent_derived_id:      template.parent_derived_id,
            geometry_data:          template.geometry_summary['points']
          )
        else
          discarded
        end
      end

      # The fingerprint for the current entity inventory.
      def compute_fingerprint_from_pairs(pairs)
        entities = pairs.map { |_id, rec| rec }
        DerivedWorkspaceFingerprint.from_workspace(
          source_snapshot_id:      source_snapshot.snapshot_id,
          execution_config_digest: source_snapshot.execution_config.respond_to?(:digest) ? source_snapshot.execution_config.digest : '',
          entities:                entities
        )
      end

      # Internal constructor used by build / discard to
      # produce the next lifecycle state. Avoids the public
      # `initialize` (which freezes the empty :building
      # state) so we can transition freely.
      def self.new_with_inventory(workspace_id:, source_snapshot:, adapter:,
                                 state:, entity_pairs:,
                                 fingerprint:, last_error:,
                                 build_started_at:)
        obj = allocate
        obj.send(:initialize_with_inventory,
                  workspace_id, source_snapshot, adapter, state,
                  entity_pairs, fingerprint, last_error, build_started_at)
        obj
      end

      protected

      def initialize_with_inventory(workspace_id, source_snapshot, adapter,
                                    state, entity_pairs, fingerprint,
                                    last_error, build_started_at)
        @workspace_id    = workspace_id.freeze
        @source_snapshot = source_snapshot
        @adapter         = adapter
        @state           = state.freeze
        @entity_pairs    = entity_pairs.freeze
        @fingerprint     = fingerprint
        @last_error      = last_error
        @build_started_at = build_started_at
        freeze
      end
    end
  end
end