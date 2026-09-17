#
# compatibility/v2_sketchup_mass_adapter.rb — V2-0B SketchUp
# Mass Adapter.
#
# Per frozen V2-0B Stage Technical Blueprint
# (Prompt/AIPM_STAGE_TECHNICAL_BLUEPRINT_V2_0B_HOST_GEOMETRY_PROBE_2026-09-16.md)
# §3.2 + §8 + §9:
#
#   Real SketchUp host calls only. Resolve model and root
#   `model.entities`. Verify root edit context
#   (`model.active_path == nil`). Create an empty top-level
#   Group with `model.entities.add_group` and assign name
#   afterward. Create one Face inside `group.entities` from the
#   footprint's projected z=0 coordinates. Orient the face to
#   +Z. pushpull positive distance. Set minimal V2 ownership
#   attributes INSIDE the same operation. Post-validate real
#   generated geometry.
#
#   MUST return real Boolean operation results unchanged to the
#   guard. MUST NOT read V1 Runner private state.
#
# Files:
#   extension/su_ai_plugin/v2/host_operation_guard.rb
#   extension/su_ai_plugin/compatibility/v2_sketchup_mass_adapter.rb
#   extension/su_ai_plugin/v2/stage0b_mass_probe.rb
#

module SUAnalysis
  module Compatibility
    # V2SketchupMassAdapter is the V2-0B thin wrapper around the
    # real SketchUp geometry creation API. It owns no
    # transaction state and no PreparedCadDataset semantics; the
    # host operation guard and the Stage 0B probe own those.
    class V2SketchupMassAdapter
      # V2 ownership attribute dictionary (Blueprint §8).
      ATTR_DICTIONARY = 'SU-AI-V2'.freeze

      # V2 ownership attribute keys.
      ATTR_SCHEMA_VERSION       = 'schema_version'.freeze
      ATTR_KIND                 = 'kind'.freeze
      ATTR_FOOTPRINT_ID_FULL    = 'footprint_id_full'.freeze
      ATTR_SOURCE_CONTENT_DIGEST = 'source_content_digest'.freeze

      # Frozen attribute values.
      SCHEMA_VERSION = 'v2.host-object.v1'.freeze
      KIND           = 'stage0b_mass_probe'.freeze

      # Default SketchUp operation label (Blueprint §6 + §8).
      OPERATION_LABEL = 'SU-AI-Plugin: V2 Stage 0B Mass Probe'.freeze

      # Result status (Blueprint §10).
      STATUS_SUCCESS                  = :SUCCESS
      STATUS_CONSTRUCTION_FAILED      = :CONSTRUCTION_FAILED
      STATUS_POST_VALIDATION_FAILED   = :POST_VALIDATION_FAILED

      # Constructor. Accepts an optional model_provider so tests
      # can inject a fake model. In real SketchUp the provider
      # defaults to `Sketchup.active_model`.
      def initialize(model_provider: nil)
        @model_provider = model_provider || method(:_default_model_provider)
      end

      # Resolve the current SketchUp model. Raises a typed
      # StandardError if no model is available so callers can map
      # the failure to a blocked / context-changed result.
      def model
        m = @model_provider.call
        raise 'V2 mass adapter: no Sketchup model available' unless m
        m
      end

      # True iff the active edit context is the model root.
      # `model.active_path` returns nil outside any open group /
      # component edit. (Blueprint §5 step 3 + §8 step 1.)
      def root_context?
        m = model
        return false unless m.respond_to?(:active_path)
        m.active_path.nil?
      end

      # Build the Stage-0B probe mass. MUST be called inside an
      # already-open SketchUp operation (the operation guard
      # owns start/commit/abort). Returns a Hash with one of:
      #
      #   { status: :SUCCESS, group: host_group_handle }
      #   { status: :CONSTRUCTION_FAILED, error: 'reason' }
      #   { status: :POST_VALIDATION_FAILED, error: 'reason' }
      #
      # Required inputs:
      #   footprint      : V2-0A SemanticFootprint value record
      #                    (must carry projected_world_coordinates,
      #                     footprint_id_full, source_content_digest,
      #                     coordinate_epsilon)
      #   probe_height   : explicit Numeric, finite, > 0
      #
      # R1-03: footprint['coordinate_epsilon'] is the ONLY
      # post-validation geometry tolerance. There is NO
      # hidden fallback. Stage 0B is expected to have
      # validated the epsilon before start; this adapter
      # additionally rejects non-positive / missing values
      # defensively so the post-validation surface cannot
      # silently fall back to a default.
      def build_mass(footprint:, probe_height:)
        m = model
        unless m.respond_to?(:entities)
          return failure(STATUS_CONSTRUCTION_FAILED, 'no_model_entities')
        end
        unless root_context?
          return failure(STATUS_CONSTRUCTION_FAILED, 'not_root_context')
        end

        # R1-03: no hidden epsilon. The footprint's
        # coordinate_epsilon is the only authority.
        eps_raw = footprint['coordinate_epsilon']
        unless eps_raw.is_a?(Numeric)
          return failure(STATUS_CONSTRUCTION_FAILED,
                         'missing_or_non_numeric_coordinate_epsilon')
        end
        eps = eps_raw.to_f
        unless eps > 0.0 && (eps.respond_to?(:finite?) ? eps.finite? : true)
          return failure(STATUS_CONSTRUCTION_FAILED,
                         'non_positive_or_non_finite_coordinate_epsilon')
        end

        # 1. Empty add_group with no arguments (Blueprint §8).
        root_entities = m.entities
        group = root_entities.add_group
        return failure(STATUS_CONSTRUCTION_FAILED, 'add_group_returned_nil') unless group

        # 2. Assign recognizable name after creation (Blueprint
        #    §8 step 3).
        short_id = (footprint['footprint_id_full'] || footprint['footprint_id']).to_s
        short_id = short_id[0, 12]
        short_id = 'unknownfp' if short_id.empty?
        group.name = 'SU-AI-V2-Probe-' + short_id

        # 3. Set minimal V2 ownership attributes inside the same
        #    operation (Blueprint §8 step 4).
        # R2-02: ownership values MUST round-trip EXACTLY
        # against the CURRENT target footprint. The values
        # are stored as String (String#set_attribute is
        # the production adapter contract). The post-
        # validator below performs the strict exact-equality
        # check against the same footprint record.
        expected_schema = SCHEMA_VERSION
        expected_kind   = KIND
        expected_fpid   = footprint['footprint_id_full'].to_s
        expected_scd    = footprint['source_content_digest'].to_s
        _set_attribute(group, ATTR_SCHEMA_VERSION, expected_schema)
        _set_attribute(group, ATTR_KIND, expected_kind)
        _set_attribute(group, ATTR_FOOTPRINT_ID_FULL, expected_fpid)
        _set_attribute(group, ATTR_SOURCE_CONTENT_DIGEST, expected_scd)

        # 4. Build host points from the footprint's projected
        #    world coordinates. Do NOT change XY. Z MUST remain
        #    0.0 (Blueprint §8 step 5).
        projected = footprint['projected_world_coordinates']
        unless projected.is_a?(Array) && projected.size >= 3
          return failure(STATUS_CONSTRUCTION_FAILED, 'invalid_projected_coords')
        end
        points = []
        projected.each do |coord|
          if coord.is_a?(Array) && coord.length == 3
            x = coord[0].to_f
            y = coord[1].to_f
            z = 0.0
            if (coord[2].to_f - 0.0).abs > 1.0e-9
              return failure(STATUS_CONSTRUCTION_FAILED, 'non_zero_z_in_projected_coords')
            end
            points << _point3d(x, y, z)
          elsif coord.respond_to?(:x) && coord.respond_to?(:y) && coord.respond_to?(:z)
            points << coord
          else
            return failure(STATUS_CONSTRUCTION_FAILED, 'invalid_coord_entry')
          end
        end

        # 5. Create the face (Blueprint §8 step 6).
        face = group.entities.add_face(points)
        return failure(STATUS_CONSTRUCTION_FAILED, 'add_face_returned_nil') unless face

        # 6. Orient face to +Z. Ground-plane face may face
        #    downward regardless of vertex order (Blueprint §8
        #    step 8).
        normal = face.respond_to?(:normal) ? face.normal : nil
        unless _normal_is_z_plus(normal)
          if face.respond_to?(:reverse!)
            face.reverse!
            normal = face.respond_to?(:normal) ? face.normal : nil
          end
          unless _normal_is_z_plus(normal)
            return failure(STATUS_CONSTRUCTION_FAILED, 'orient_to_positive_z_failed')
          end
        end

        # 7. Pushpull. The Blueprint §8 step 9 + §2 fact 5 says
        #    pushpull returns nil; success MUST be validated from
        #    the resulting geometry, not from a truthy return.
        if face.respond_to?(:pushpull)
          begin
            face.pushpull(probe_height.to_f, false)
          rescue StandardError
            return failure(STATUS_CONSTRUCTION_FAILED, 'pushpull_raised')
          end
        else
          return failure(STATUS_CONSTRUCTION_FAILED, 'face_pushpull_unsupported')
        end

        # 8. Post-validate real generated geometry.
        # R2-01 + R2-02: the post-validator must know both
        # the current target model (for real SketchUp root
        # Group parent authority) and the expected current
        # footprint identity / digest (for exact ownership
        # round-trip).
        pv = _post_validate(group, probe_height.to_f, eps, m,
                             footprint)
        return failure(STATUS_POST_VALIDATION_FAILED, pv) unless pv == :ok

        { status: STATUS_SUCCESS, group: group }
      end

      private

      # Default model provider. Returns the active SketchUp
      # model when running inside real SketchUp.
      def _default_model_provider
        if defined?(Sketchup) && Sketchup.respond_to?(:active_model)
          Sketchup.active_model
        else
          nil
        end
      end

      # Build a host point. In real SketchUp this returns
      # Geom::Point3d. In host-free test environments where
      # Geom::Point3d is not defined, we fall back to a
      # minimal 3-element Array that the FakeEntities.add_face
      # stub accepts and the post-validate walker reads as a
      # 3-element coordinate.
      def _point3d(x, y, z)
        if defined?(Geom) && defined?(Geom::Point3d)
          Geom::Point3d.new(x, y, z)
        else
          [x.to_f, y.to_f, z.to_f]
        end
      end

      # True iff the supplied normal is the unit +Z direction
      # (or sufficiently close). Returns false for nil.
      def _normal_is_z_plus(normal)
        return false if normal.nil?
        n = _normal_to_a(normal)
        return false unless n.is_a?(Array) && n.length == 3
        # Accept either (0,0,1) or (0,0,~1) — strict +Z axis
        # component test only; do not require exact unit
        # length because some hosts may return normalized
        # vectors but with floating-point drift.
        n[0].to_f.abs <= 1.0e-6 &&
          n[1].to_f.abs <= 1.0e-6 &&
          n[2].to_f > 0.0
      end

      def _normal_to_a(normal)
        if normal.respond_to?(:to_a)
          normal.to_a
        elsif normal.is_a?(Array)
          normal
        else
          nil
        end
      end

      # Set one Sketchup attribute on a host entity, if the
      # entity supports attribute dictionaries.
      def _set_attribute(entity, key, value)
        return unless entity.respond_to?(:set_attribute)
        begin
          entity.set_attribute(ATTR_DICTIONARY, key, value.to_s)
        rescue StandardError
          # Attribute dictionary write failure must NOT crash
          # the host transaction; the Blueprint §9 post-
          # validation will surface the mismatch on commit.
          nil
        end
      end

      # Post-validate real generated geometry. Per Blueprint
      # §9 (R1-03 + R2-01 + R2-02):
      #
      #   - group exists and is valid/not deleted;
      #   - group is a ROOT entity under the CURRENT target
      #     model (parent authority == current model, not nil);
      #   - generated group contains at least one Face AND
      #     at least one Edge after extrusion;
      #   - at least one generated vertex is within
      #     coordinate_epsilon of z=0;
      #   - at least one generated vertex is within
      #     coordinate_epsilon of z=probe_height;
      #   - no generated vertex is below -coordinate_epsilon;
      #   - generated max-z satisfies
      #     abs(max_z - probe_height) <= coordinate_epsilon;
      #   - all FOUR ownership values round-trip EXACTLY
      #     against the CURRENT target footprint:
      #       schema_version == 'v2.host-object.v1'
      #       kind           == 'stage0b_mass_probe'
      #       footprint_id_full    == current footprint id
      #       source_content_digest == current footprint digest
      #
      # R2-01: parent authority check now requires the group
      # parent to be the current target model (real SketchUp
      # top-level Group under `model.entities` reports the
      # Model as its parent -- not nil).
      #
      # R2-02: ownership values must be EXACT equality with
      # the supplied current footprint record. Wrong-but-
      # non-empty values now fail post-validation.
      def _post_validate(group, probe_height, eps, model, footprint)
        return 'no_group' unless group
        return 'group_invalid' if group.respond_to?(:valid?) && !group.valid?
        return 'group_deleted' if group.respond_to?(:deleted?) && group.deleted?
        unless _is_root_group?(group, model)
          return 'group_not_root'
        end
        face_count = 0
        edge_count = 0
        _walk_entity_kinds(group, face_count_ref: ->(n) { face_count = n },
                               edge_count_ref: ->(n) { edge_count = n })
        return 'no_face'    if face_count < 1
        return 'no_edge'    if edge_count < 1
        vertices = _collect_vertices(group)
        return 'no_vertices' if vertices.empty?
        zs = vertices.map { |v| _z_of(v) }
        min_z = zs.min
        max_z = zs.max
        return 'min_z_below_ground' if min_z.to_f < -eps.to_f
        return 'max_z_not_near_height' if (max_z.to_f - probe_height.to_f).abs > eps.to_f
        return 'no_z0_vertex'   unless zs.any? { |z| (z.to_f - 0.0).abs <= eps.to_f }
        return 'no_zH_vertex'   unless zs.any? { |z| (z.to_f - probe_height.to_f).abs <= eps.to_f }
        # R1-03 + R2-02: all FOUR ownership values MUST
        # round-trip exactly against the CURRENT target
        # footprint. The footprint record is the freshness-
        # re-resolved record -- the same one used to write
        # the attributes. Wrong-but-non-empty values now
        # fail post-validation.
        expected_schema = SCHEMA_VERSION
        expected_kind   = KIND
        expected_fpid   = footprint ? footprint['footprint_id_full'].to_s : ''
        expected_scd    = footprint ? footprint['source_content_digest'].to_s : ''
        schema = _get_attribute(group, ATTR_SCHEMA_VERSION)
        return 'schema_version_mismatch' unless schema == expected_schema
        kind = _get_attribute(group, ATTR_KIND)
        return 'kind_mismatch' unless kind == expected_kind
        fpid = _get_attribute(group, ATTR_FOOTPRINT_ID_FULL)
        return 'footprint_id_full_mismatch' unless fpid == expected_fpid
        return 'footprint_id_full_attr_missing' if fpid.nil? || fpid.to_s.empty?
        scd  = _get_attribute(group, ATTR_SOURCE_CONTENT_DIGEST)
        return 'source_content_digest_mismatch' unless scd == expected_scd
        return 'source_content_digest_attr_missing' if scd.nil? || scd.to_s.empty?
        :ok
      end

      def _get_attribute(entity, key)
        return nil unless entity.respond_to?(:get_attribute)
        begin
          entity.get_attribute(ATTR_DICTIONARY, key)
        rescue StandardError
          nil
        end
      end

      # R2-01: Real SketchUp root-Group parent authority.
      #
      # Per the frozen V2-0B Stage Technical Blueprint §9 +
      # R2 correction packet, the real post-validation root
      # test MUST prove:
      #
      #   1. entity is a Group (typename == 'Group');
      #   2. group belongs to the current target model;
      #   3. group's parent authority is the current Model
      #      (not nil, not a nested Group / ComponentDefinition);
      #   4. nested Group / ComponentDefinition-owned Group
      #      MUST NOT pass.
      #
      # Real SketchUp top-level groups created via
      # `model.entities.add_group` report the Model itself as
      # their parent (SketchUp official Entity parent
      # contract). The previous `parent.nil?` assumption
      # incorrectly accepted some real-SU root groups whose
      # parent was reported as a non-nil but non-Model
      # container, and would also reject a correct
      # real-SU2020 root Group whose parent authority IS
      # the current Model object.
      #
      # Required contract:
      #   - parent accessor MUST exist;
      #   - parent MUST NOT be nil;
      #   - parent MUST be the same object (identity-equal)
      #     as the current target model;
      #   - additionally, if the host exposes a `model`
      #     accessor on the group, that accessor MUST also
      #     return the current target model.
      def _is_root_group?(group, model)
        return false unless group.respond_to?(:typename)
        return false unless group.typename.to_s == 'Group'
        unless group.respond_to?(:parent)
          # Hosts that do not expose a parent accessor at
          # all cannot satisfy the Blueprint §9 root-authority
          # contract for the real host. Reject rather than
          # silently accept.
          return false
        end
        parent = group.parent
        # R2-01 hard rule: nil parent is NEVER a real-root
        # criterion. A nil parent on a real-SU top-level
        # group would not satisfy "group belongs to current
        # model". Reject.
        return false if parent.nil?
        # Identity-equal to the current target model.
        # `equal?` is object identity, which is what
        # real SketchUp gives us (the parent is the very
        # Model instance the caller holds).
        unless parent.equal?(model)
          return false
        end
        # Optional additional identity check when the host
        # exposes `group.model`. A correct real SketchUp
        # top-level Group's `#model` returns the very same
        # Model object. If the accessor is available and
        # disagrees, the group does NOT belong to the
        # current model -> reject.
        if group.respond_to?(:model) && model.respond_to?(:equal?)
          gm = group.model
          return false if gm.nil?
          unless gm.equal?(model)
            return false
          end
        end
        true
      end

      # Walk the group's entities (recursively for nested
      # groups) and collect every vertex encountered.
      def _collect_vertices(root)
        out = []
        return out unless root.respond_to?(:entities)
        _walk_entities(root.entities, out)
        out
      end

      def _walk_entities(entities, out)
        return unless entities.respond_to?(:each)
        entities.each do |e|
          if e.respond_to?(:vertices)
            begin
              vs = e.vertices
              vs.each { |v| out << v } if vs.respond_to?(:each)
            rescue StandardError
              # skip invalid vertices
            end
          end
          if e.respond_to?(:entities)
            _walk_entities(e.entities, out)
          end
        end
      end

      # Walk the group's entities and accumulate face and
      # edge counts (R1-03 Blueprint §9 explicit checks).
      def _walk_entity_kinds(root, face_count_ref:, edge_count_ref:)
        return unless root.respond_to?(:entities)
        _walk_entity_kinds_inner(root.entities,
                                 face_count_ref, edge_count_ref)
      end

      def _walk_entity_kinds_inner(entities, face_ref, edge_ref)
        return unless entities.respond_to?(:each)
        fc = 0
        ec = 0
        entities.each do |e|
          tn = e.respond_to?(:typename) ? e.typename.to_s : ''
          if tn == 'Face'
            fc += 1
          elsif tn == 'Edge'
            ec += 1
          end
          if e.respond_to?(:entities)
            sub_fc = 0
            sub_ec = 0
            _walk_entity_kinds_inner(e.entities,
                                     ->(n) { sub_fc = n },
                                     ->(n) { sub_ec = n })
            fc += sub_fc
            ec += sub_ec
          end
        end
        face_ref.call(fc)
        edge_ref.call(ec)
      end

      # Resolve a z coordinate from a vertex-like object.
      # Supports real `Sketchup::Vertex#position`
      # (which exposes a Geom::Point3d), test Array coords,
      # and any Point3d-like object exposing .x .y .z.
      # R1-03: do NOT collapse to 0.0 when the host provides
      # `position` only.
      def _z_of(v)
        return v.position.z.to_f if v.respond_to?(:position) &&
                                    v.position.respond_to?(:z)
        if v.respond_to?(:z)
          v.z.to_f
        elsif v.is_a?(Array) && v.length == 3
          v[2].to_f
        else
          0.0
        end
      end

      def failure(status, reason)
        { status: status, error: reason.to_s }
      end
    end
  end
end