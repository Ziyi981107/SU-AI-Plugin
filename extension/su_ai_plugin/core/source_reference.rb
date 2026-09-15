#
# SourceReference — lightweight token that ties an analysis record back to
# its SketchUp entity without holding a hard Ruby reference.
#
# Why not just hold the entity object?
#   - SU entities can be erased at any time; holding a reference can crash
#     when garbage collection touches them.
#   - We need to ship values over JSON / to the UI / to the registry; an
#     entity object can't be marshalled.
#
# Stability (PI_TASK_001 + Codex Q003 answer, 2026-08-14):
#   - `persistent_id` is available in SketchUp 2017+ for Edge, Vertex,
#     Group, ComponentInstance, and most entity types (NOT a SU2018+
#     feature, contrary to an earlier hypothesis).
#   - Some entities / modes return nil even on supported SketchUp versions,
#     so consumers MUST use capability detection (`respond_to?(:persistent_id)
#     && entity.persistent_id`) rather than version number branches.
#   - `stable?` returns true only when a non-nil persistent_id was obtained.
#   - `entity_id` is Ruby `object_id`, NOT stable across reload or session;
#     it is useful only as a transient in-memory key.
#
# Instance identity (per Codex S2-BLOCK-002, 2026-08-17):
#   - Two ComponentInstances sharing one definition are two distinct
#     occurrences. Each Edge inside those instances therefore needs a
#     composite source identity that includes the instance path.
#   - `instance_path` is a list of String entries describing the container
#     chain from the model root to this entity, e.g.
#       ["Group:outer", "ComponentInstance:Window#1", "Group:inner_frame"]
#   - `persistent_id_path` is the canonical machine-resolvable identity.
#     It is an Array<Integer> of container PIDs from model root to the leaf,
#     with the leaf PID last. Empty array for root-level entities.
#
# Structural identity (per CodeX Review 013, 2026-08-18):
#   - `structural_depth` is the structural depth of this entity (root
#     container = 0; +1 per nested container; +1 per active edit context
#     entity). Populated in `extension/preflight_runner.rb` alongside
#     `pid_path_complete`. The two are independent facts: structural
#     depth is the entity count; pid_path_complete is whether every
#     container pid was captured.
#   - `pid_path_complete` is true iff every structural ancestor AND the
#     leaf entity itself supplied a non-nil persistent_id.
#   - Defaults are FAIL-CLOSED: `structural_depth: 0` and
#     `pid_path_complete: false`. Production callers MUST pass both
#     explicitly. Legacy test callers that omit these fields get an
#     explicit "incomplete" marker, which is the correct behavior for
#     synthetic edges with no PID path.
#
# V1.9B1 R4 ADDITIVE EXCEPTION (per
# `Prompt/AIPM_V1_9B1_R4_SOURCE_REFERENCE_RAW_SHAPE_PROVENANCE_CLOSURE_2026-09-15.md`):
#   - Added an immutable construction-input-facts seam
#     (`attr_reader :construction_facts`) so the B1 Builder can
#     fail-closed on malformed raw constructor inputs that are
#     otherwise irreversibly normalized (entity_id: "123" -> 123,
#     pid_path_complete: "false" -> false, persistent_id_path:
#     [1, nil, 2] -> [1, 2], instance_path: "A" -> "A", etc.).
#   - This is NOT a source-identity redesign. `to_h`, `==`,
#     `eql?`, `hash`, `stable?` semantics are unchanged for VALID
#     existing production inputs. `to_h` deliberately does NOT
#     include `construction_facts` (it is B1 build-coherence
#     evidence only).
#   - Construction is now fail-closed on malformed inputs:
#     accessors fall back to a normalized value that cannot
#     masquerade as a valid exact input, while construction_facts
#     records the original shape. No exception escapes for any
#     constructor input shape.
#

module SUAnalysis
  module Core
    class SourceReference
      attr_reader :entity_id, :persistent_id, :kind, :label,
                  :persistent_id_path, :instance_path,
                  :structural_depth, :pid_path_complete,
                  :layer_name,
                  # R4: immutable construction-input facts captured
                  # BEFORE any normalization / coercion. Used by
                  # the B1 Builder for fail-closed validation.
                  :construction_facts

      def initialize(entity_id: nil, persistent_id: nil, kind: 'edge', label: nil,
                     instance_path: nil, persistent_id_path: nil,
                     structural_depth: 0, pid_path_complete: false,
                     layer_name: nil)
        # ----- R4-01: capture construction-input facts BEFORE
        # any existing normalization / coercion. These are
        # immutable evidence for B1 fail-closed validation.
        # For VALID existing production inputs every fact is
        # true; for malformed inputs the corresponding fact is
        # false so the Builder can BLOCK with the precise
        # ambiguous_incomplete_occurrence:* family. This is the
        # ONLY semantics added by R4-01.
        cf_entity_id_exact_integer =
          entity_id.is_a?(Integer)
        cf_persistent_id_integer_or_nil =
          persistent_id.nil? || persistent_id.is_a?(Integer)
        cf_pid_path_is_array =
          persistent_id_path.is_a?(Array)
        cf_pid_path_all_integer =
          cf_pid_path_is_array &&
            persistent_id_path.all? { |p| p.is_a?(Integer) }
        cf_pid_path_had_invalid_member =
          cf_pid_path_is_array &&
            persistent_id_path.any? { |p| !p.is_a?(Integer) }
        cf_instance_path_is_array =
          instance_path.is_a?(Array)
        cf_instance_path_all_string =
          cf_instance_path_is_array &&
            instance_path.all? { |p| p.is_a?(String) }
        cf_structural_depth_exact_integer =
          structural_depth.is_a?(Integer)
        cf_pid_path_complete_exact_boolean =
          (pid_path_complete == true) || (pid_path_complete == false)
        cf_layer_name_is_string =
          layer_name.is_a?(String)
        cf_kind_is_string =
          kind.is_a?(String)

        @construction_facts = {
          'entity_id_exact_integer'           => cf_entity_id_exact_integer,
          'persistent_id_integer_or_nil'      => cf_persistent_id_integer_or_nil,
          'persistent_id_path_is_array'       => cf_pid_path_is_array,
          'persistent_id_path_all_integer'    => cf_pid_path_all_integer,
          'persistent_id_path_had_invalid_member' => cf_pid_path_had_invalid_member,
          'instance_path_is_array'            => cf_instance_path_is_array,
          'instance_path_all_string'          => cf_instance_path_all_string,
          'structural_depth_exact_integer'    => cf_structural_depth_exact_integer,
          'pid_path_complete_exact_boolean'   => cf_pid_path_complete_exact_boolean,
          'layer_name_is_string'              => cf_layer_name_is_string,
          'kind_is_string'                    => cf_kind_is_string
        }.freeze

        # entity_id is optional (nil allowed for fully-missing SourceReferences
        # in test fixtures). In production, callers should always supply an
        # exact Integer. R4: any non-Integer non-nil value falls back to
        # nil so it cannot masquerade as a valid exact Integer; the
        # construction_facts.entity_id_exact_integer=false marker lets B1
        # BLOCK with ambiguous_incomplete_occurrence:entity_id_not_integer.
        @entity_id     =
          if entity_id.is_a?(Integer)
            entity_id
          elsif entity_id.nil?
            nil
          else
            nil
          end

        # persistent_id: kept as-is for nil and Integer; any other
        # class is fail-closed to nil so B1 can BLOCK via
        # construction_facts.persistent_id_integer_or_nil=false.
        @persistent_id =
          if persistent_id.nil? || persistent_id.is_a?(Integer)
            persistent_id
          else
            nil
          end

        # kind: V1.4 stable contract allows Symbol or String; do NOT
        # coerce (preserves valid existing behavior). construction_facts
        # records whether the original was a String.
        @kind          = kind
        @label         = label

        # R4-01: persistent_id_path is now fail-closed. nil => [].
        # non-Array => [] (previously would .map / .dup a non-Array,
        # which is meaningless and is now blocked at the construction
        # boundary). Array => map Integer with .compact (preserved
        # legacy semantics for VALID Integer arrays). construction_facts
        # records the original shape so B1 can BLOCK on hidden nil /
        # non-Integer members that would otherwise masquerade as a
        # valid stable path.
        @persistent_id_path =
          if persistent_id_path.is_a?(Array)
            persistent_id_path.map { |p|
              if p.nil?
                nil
              elsif p.is_a?(Integer)
                p
              else
                Integer(p) rescue nil
              end
            }.compact.freeze
          elsif persistent_id_path.nil?
            [].freeze
          else
            [].freeze
          end

        # R4-01: instance_path is now fail-closed. nil => [].
        # non-Array => [] (do NOT .dup a non-Array; that produced a
        # frozen non-Array with the wrong semantic class). Array =>
        # dup.freeze (preserved legacy semantics for VALID arrays).
        @instance_path =
          if instance_path.is_a?(Array)
            instance_path.dup.freeze
          elsif instance_path.nil?
            [].freeze
          else
            [].freeze
          end

        # R4-01: structural_depth is only trusted as an exact Integer.
        # Anything else falls back to the fail-closed neutral default
        # of 0 and construction_facts records exact_int=false so B1
        # BLOCKS with ambiguous_incomplete_occurrence:
        # structural_depth_not_integer.
        @structural_depth    =
          structural_depth.is_a?(Integer) ? structural_depth : 0

        # R4-01: pid_path_complete is only trusted as the literal
        # true/false constants. Any other class (String, Integer,
        # nil, etc.) falls back to false and construction_facts
        # records exact_boolean=false so B1 BLOCKS with
        # ambiguous_incomplete_occurrence:pid_path_complete_not_boolean.
        @pid_path_complete   = pid_path_complete == true ? true : false

        # V1.1 (per plan §12 default + R007): layer_name is captured
        # at snapshot time. The LayerIssueGrouper reads this directly
        # from the SourceReference it wraps, without re-looking-up
        # the layer from the entity. V1.0 callers do not supply
        # this; default is nil, which the grouper maps to "Layer0"
        # via the V1.0 fallback.
        #
        # R4-01: do NOT call .to_s to repair a MISSING value
        # (nil => nil, preserved). For non-nil non-String
        # values (e.g. Symbol from legacy V1.4 callers) the
        # existing .to_s coercion is preserved so the public
        # accessor still returns the same value as before;
        # construction_facts.layer_name_is_string=false lets
        # B1 BLOCK with
        # ambiguous_incomplete_occurrence:layer_name_invalid.
        @layer_name = layer_name.nil? ? nil : layer_name.to_s
      end

      def stable?
        !@persistent_id.nil?
      end

      # Returns the PID path joined by '/' for display / debugging.
      # Empty string for root-level entities.
      def persistent_id_path_string
        @persistent_id_path.map(&:to_s).join('/')
      end

      # Returns the instance_path joined by ' > ' for display purposes only.
      # Empty string for root-level entities. NOT used as canonical identity.
      def instance_path_string
        @instance_path.join(' > ')
      end

      def to_h
        {
          entity_id:          @entity_id,
          persistent_id:      @persistent_id,
          kind:               @kind,
          label:              @label,
          instance_path:      @instance_path,
          persistent_id_path: @persistent_id_path,
          structural_depth:    @structural_depth,
          pid_path_complete:   @pid_path_complete,
          layer_name:         @layer_name
        }
      end

      # V1.4 (per directive 030): value-based equality. The
      # rebuild contract requires two SourceReference instances
      # with the same data to be ==, so the SourceSnapshot can
      # be compared across rebuilds (rebuilds produce new
      # instances). All fields participate; layer_name is
      # included even when nil so two refs from the same source
      # entity on the same layer compare equal.
      #
      # R4-01: == / eql? / hash / stable? semantics are
      # UNCHANGED for VALID existing production inputs. The
      # new construction_facts attribute is intentionally NOT
      # part of equality (it is B1 build-coherence evidence
      # only and does not affect source identity).
      def ==(other)
        return false unless other.is_a?(SourceReference)
        entity_id == other.entity_id &&
          persistent_id == other.persistent_id &&
          kind == other.kind &&
          label == other.label &&
          instance_path == other.instance_path &&
          persistent_id_path == other.persistent_id_path &&
          structural_depth == other.structural_depth &&
          pid_path_complete == other.pid_path_complete &&
          layer_name == other.layer_name
      end

      def eql?(other)
        self == other
      end

      def hash
        [entity_id, persistent_id, kind, label, instance_path,
         persistent_id_path, structural_depth, pid_path_complete,
         layer_name].hash
      end
    end
  end
end