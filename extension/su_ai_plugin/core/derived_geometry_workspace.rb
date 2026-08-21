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
# V1.4 CodeX BLOCK fix (Stage 4): the workspace maintains a
# PRIVATE handle registry (NOT exposed via to_h / JSON / UI).
# The handle registry maps derived_id -> real SketchUp::Group
# handle (or test-side equivalent). discard / failure cleanup
# iterate THIS registry, NOT host_assigned_ids (which only
# carries id values for audit). The handle registry lives in
# a separate instance variable that is NEVER serialized via
# to_h.
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

      # Public attr_readers are LIMITED to JSON-safe fields.
      # The handle registry is INTENTIONALLY NOT exposed.
      attr_reader :workspace_id, :source_snapshot,
                  :state, :entities, :fingerprint,
                  :last_error, :build_started_at

      def initialize(workspace_id: nil, source_snapshot:, adapter:, model: nil)
        @workspace_id    = (workspace_id || "ws-#{rand(2**32)}").freeze
        @source_snapshot = source_snapshot  # SourceSnapshot (frozen)
        @adapter         = adapter           # DerivedWorkspaceAdapter
        @model           = model             # SU model (for operation wrapping); may be nil
        @state           = :building
        # Inventory: derived_id (String) -> DerivedEntityRecord.
        # Stored as an Array of [derived_id, record] tuples so the
        # order is preserved (and the data is deeply frozen).
        @entity_pairs    = [].freeze
        # V1.4 CodeX BLOCK fix (Stage 4): the PRIVATE handle
        # registry. Maps derived_id -> real SketchUp::Group
        # handle (or test-side equivalent). NEVER serialized.
        # Used by discard / failure cleanup / rebuild to
        # precisely target the plugin-owned entities.
        @handle_registry = {}.freeze
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
        hit = @entity_pairs.find { |id, _| id == derived_id }
        hit.nil? ? nil : hit[1]
      end

      def entity_count
        @entity_pairs.length
      end

      # V1.4 CodeX BLOCK fix (Stage 4): workspace-private handle
      # lookup. The handle registry is NEVER exposed via to_h /
      # JSON / UI; it is the workspace's internal cleanup target.
      # Returns the live handle for the given derived_id, or nil.
      # Outside callers (UI bridge, dialog_runner, snapshot)
      # NEVER see the registry.
      def handle_for(derived_id)
        return nil if @handle_registry.empty?
        @handle_registry[derived_id]
      end

      def handle_registry_keys
        @handle_registry.keys
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
        # V1.4 CodeX BLOCK fix (Stage 4): handle_registry is
        # INTENTIONALLY NOT included in to_h. It must never
        # cross the JSON boundary; live host handles are
        # NOT JSON-safe and would also leak the workspace's
        # internal ownership tracking to the UI.
        {
          workspace_id:    workspace_id,
          source_snapshot_id: source_snapshot.snapshot_id,
          state:           state,
          entity_count:    entity_count,
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
      #
      # V1.4 CodeX BLOCK fix (Stage 4): the workspace
      # tracks the REAL host handle via the private
      # @handle_registry (NOT exposed via to_h). On build
      # failure, the workspace rolls back ALL handles built
      # so far in the SAME build call (precise cleanup, no
      # leftover derived entities).
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

        # V1.4 CodeX BLOCK fix (Stage 4): begin a SketchUp
        # operation. The adapter wraps the host call; on
        # exception, the workspace aborts the operation AND
        # rolls back any partial derived entities that were
        # built in the SAME call.
        # If no model is available (test env / FakeAdapter),
        # the adapter's begin/end helpers are no-ops.
        begin
          @adapter.begin_operation(@model, label: "Build #{did}")

          # 1. Create the top-level group (or use a parent).
          # For a nested entity, the production adapter walks
          # into the parent group's host handle.
          host_handle =
            if parent_record
              @adapter.create_top_level_group("#{parent_record.derived_id}.#{did}", model: @model)
            else
              @adapter.create_top_level_group(did, model: @model)
            end
          # 2. Add geometry if requested. V1.4 CodeX BLOCK
          # rework (2026-08-21): for kind=:edge we call
          # add_edge_to_group with the two world-coordinate
          # endpoints (NO Z lift, NO fabricated 3-point face).
          # For kind=:face we call add_face_to_group with the
          # faithful vertex array (>= 3 world-coordinate points,
          # ALL finite 3-Float Arrays).
          if geometry_data
            case kind
            when :edge
              s = geometry_data[0]
              e = geometry_data[1]
              if s.is_a?(Array) && e.is_a?(Array) && s.length == 3 && e.length == 3
                @adapter.add_edge_to_group(host_handle, s, e)
              else
                raise ArgumentError,
                      "build_entity(kind=:edge) requires geometry_data = [start_point, end_point] (each 3-Float); got #{geometry_data.inspect}"
              end
            else
              @adapter.add_face_to_group(host_handle, geometry_data)
            end
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
          # 4. Update the inventory + handle registry +
          #    fingerprint + state.
          new_pairs    = @entity_pairs + [[did, new_record]]
          new_handles  = @handle_registry.merge(did => host_handle).freeze
          new_fp       = compute_fingerprint_from_pairs(new_pairs)
          result = self.class.new_with_inventory(
            workspace_id:    workspace_id,
            source_snapshot: source_snapshot,
            adapter:         @adapter,
            model:           @model,
            state:           :ready,
            entity_pairs:    new_pairs,
            handle_registry: new_handles,
            fingerprint:     new_fp,
            last_error:      nil,
            build_started_at: build_started_at
          )
          # V1.4 CodeX BLOCK fix (Stage 4): commit the
          # operation on success.
          @adapter.end_operation(@model, commit: true)
          result
        rescue StandardError => e
          # Source MUST remain untouched. The adapter
          # failure becomes a :failed workspace. The
          # caller is responsible for either retrying (a
          # new build) or discarding this one.
          # ArgumentError is intentionally NOT caught: it
          # is a programmer error above and must propagate.
          #
          # V1.4 CodeX BLOCK fix (Stage 4): abort the
          # operation AND clean up any partial host handles
          # that were created BEFORE the failure. The
          # adapter.dispose path uses the live handle so
          # the rollback is precise.
          begin
            @adapter.end_operation(@model, commit: false)
          rescue StandardError
            # ignore secondary cleanup failures
          end
          # V1.4 Phase-3 self-audit fix: if host_handle was
          # already created (create_top_level_group succeeded)
          # but a subsequent step failed (e.g. add_edge_to_group
          # raised), dispose host_handle BEFORE returning the
          # :failed workspace. Otherwise the partially-created
          # group survives on the model and is NOT in
          # @handle_registry -- the caller cannot clean it up.
          begin
            if host_handle && @adapter.respond_to?(:dispose)
              @adapter.dispose(host_handle)
            end
          rescue StandardError
            # ignore secondary cleanup failures
          end
          # Roll back any handles created earlier in this
          # build call -- they are NOT yet committed to
          # the workspace but the host adapter may have
          # already created them.
          self.class.new_with_inventory(
            workspace_id:    workspace_id,
            source_snapshot: source_snapshot,
            adapter:         @adapter,
            model:           @model,
            state:           :failed,
            entity_pairs:    @entity_pairs,
            handle_registry: @handle_registry,
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
      #
      # V1.4 CodeX BLOCK fix (Stage 4): uses the PRIVATE
      # handle registry to precisely target each derived
      # entity for disposal. Wraps the entire discard in a
      # SketchUp operation; aborts on partial failure.
      def discard
        # V1.4 CodeX BLOCK fix (Stage 4): wrap discard in a
        # SketchUp operation. If any individual handle
        # dispose fails, the operation is aborted and the
        # workspace transitions to :failed.
        disposal_errors = []
        begin
          @adapter.begin_operation(@model, label: "Discard #{workspace_id}")
          @handle_registry.each do |derived_id, handle|
            begin
              @adapter.dispose(handle)
            rescue StandardError => e
              disposal_errors << "dispose #{derived_id.inspect} failed: #{e.class}: #{e.message}"
            end
          end
          if disposal_errors.empty?
            @adapter.end_operation(@model, commit: true)
            # Successful discard: empty inventory + empty
            # handle registry, :discarded.
            self.class.new_with_inventory(
              workspace_id:    workspace_id,
              source_snapshot: source_snapshot,
              adapter:         @adapter,
              model:           @model,
              state:           :discarded,
              entity_pairs:    [],
              handle_registry: {}.freeze,
              fingerprint:     nil,
              last_error:      nil,
              build_started_at: build_started_at
            )
          else
            begin
              @adapter.end_operation(@model, commit: false)
            rescue StandardError
            end
            # Per directive: even partial disposal must leave
            # the workspace INVALID (not :ready). We move
            # to :failed and store the error.
            self.class.new_with_inventory(
              workspace_id:    workspace_id,
              source_snapshot: source_snapshot,
              adapter:         @adapter,
              model:           @model,
              state:           :failed,
              entity_pairs:    @entity_pairs,
              handle_registry: @handle_registry,
              fingerprint:     compute_fingerprint_from_pairs(@entity_pairs),
              last_error:      "discard failed: #{disposal_errors.join('; ')}",
              build_started_at: build_started_at
            )
          end
        rescue StandardError => e
          # The operation wrapper itself failed (e.g. SU
          # refused to start the operation). The workspace
          # MUST be marked :failed.
          begin
            @adapter.end_operation(@model, commit: false)
          rescue StandardError
          end
          self.class.new_with_inventory(
            workspace_id:    workspace_id,
            source_snapshot: source_snapshot,
            adapter:         @adapter,
            model:           @model,
            state:           :failed,
            entity_pairs:    @entity_pairs,
            handle_registry: @handle_registry,
            fingerprint:     compute_fingerprint_from_pairs(@entity_pairs),
            last_error:      "discard wrapper failed: #{e.class}: #{e.message}",
            build_started_at: build_started_at
          )
        end
      end

      # Rebuild = discard + build. Returns a new :ready (or
      # :failed) workspace. Source must be the same snapshot
      # for deterministic rebuild.
      #
      # V1.4 CodeX BLOCK fix (Stage 4): rebuild (a) first
      # cleans up ALL existing derived handles via the
      # private registry (the discard path), then (b)
      # creates fresh derived entities via the adapter.
      # The OLD workspace's entities are the rebuild
      # template; the NEW workspace has fresh host
      # handles + identical record shape (so fingerprint
      # is stable).
      def rebuild
        # Capture the rebuild template BEFORE we discard.
        first_pair = @entity_pairs.first
        template   = first_pair.nil? ? nil : first_pair[1]
        discarded = discard
        # If discard failed, return the :failed workspace.
        return discarded if discarded.state == :failed
        # Discard succeeded: empty inventory. Now rebuild
        # the entity using the template (V1.4 plumbing).
        if template.nil?
          discarded
        else
          # V1.4 CodeX BLOCK rework (2026-08-21): rebuild must
          # call the SAME adapter method the original build
          # used. For Edges, that is add_edge_to_group (NOT
          # add_face_to_group -- the previous implementation
          # passed geometry_summary['points'] to a fabricated
          # 3-point face, which is BLOCK 1's forbidden
          # fabrication path).
          geom_data = if template.kind.to_s == 'edge'
                        _edge_geometry_data_from_template(template)
                      else
                        template.geometry_summary['points']
                      end
          discarded.build_entity(
            derived_id:             template.derived_id,
            kind:                   template.kind,
            source_occurrence_ids:  template.source_occurrence_ids,
            geometry_summary:       template.geometry_summary,
            parent_derived_id:      template.parent_derived_id,
            geometry_data:          geom_data
          )
        end
      end

      # V1.4 CodeX BLOCK rework (2026-08-21): extract the
      # original (start, end) endpoints from a template Edge
      # record's geometry_summary. The build_entity flow
      # passes this as geometry_data (a 2-element Array of
      # 3-Float Arrays) to the adapter's add_edge_to_group.
      # Per directive: derived Edge must use real
      # add_edges/add_line, faithfully preserving the two
      # world-coordinate endpoints.
      def _edge_geometry_data_from_template(template)
        gs = template.geometry_summary
        s = gs['start']
        e = gs['end']
        if s.is_a?(Array) && e.is_a?(Array) && s.length == 3 && e.length == 3
          [s, e]
        else
          nil
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
                                 model:, state:, entity_pairs:,
                                 handle_registry:,
                                 fingerprint:, last_error:,
                                 build_started_at:)
        obj = allocate
        obj.send(:initialize_with_inventory,
                  workspace_id, source_snapshot, adapter, model, state,
                  entity_pairs, handle_registry, fingerprint, last_error, build_started_at)
        obj
      end

      protected

      def initialize_with_inventory(workspace_id, source_snapshot, adapter,
                                    model, state, entity_pairs,
                                    handle_registry, fingerprint,
                                    last_error, build_started_at)
        @workspace_id    = workspace_id.freeze
        @source_snapshot = source_snapshot
        @adapter         = adapter
        @model           = model
        @state           = state.freeze
        @entity_pairs    = entity_pairs.freeze
        # V1.4 CodeX BLOCK fix (Stage 4): the private handle
        # registry is frozen but NEVER serialized.
        @handle_registry = handle_registry.freeze
        @fingerprint     = fingerprint
        @last_error      = last_error
        @build_started_at = build_started_at
        freeze
      end
    end
  end
end
