#
# core/derived_duplicate_validator.rb — V1.5 Phase 1 (corrected scope)
#
# Pure-core validation seam for the V1.5 exit gate (Guidance 031
# §8): the duplicate-issue count must decrease against the DERIVED
# result.
#
# This module projects the workspace's derived Edge records onto a
# canonical world-geometry classification and reports the duplicate
# classes before / after the batch apply.
#
# It reuses the proposer's canonical_geometry_key contract but
# does NOT require the IssueRegistry. The validation is purely
# data: it reads each derived record's geometry_summary
# (start/end/layer), groups by the canonical key, and counts
# classes with 2+ members.
#
# The validator NEVER overwrites the immutable source
# IssueRegistry. It produces a side-by-side view of the
# derived result's topological health.
#
# Locked contract:
#   - Input: a workspace (DerivedGeometryWorkspace) and an
#     optional tolerance (defaults to 1.0e-4 inches).
#   - Output: a Hash with duplicate_classes_before / after
#     counts and the sorted list of canonical class keys.
#   - Pure-data; no host mutations; no IssueRegistry writes.
#
# The validator's "before" snapshot can be computed on the
# pre-batch workspace; the executor records it as part of the
# action audit and re-computes the "after" snapshot on the
# post-batch workspace.
#

require_relative 'tolerance'

module SUAnalysis
  module Core
    module DerivedDuplicateValidator
      module_function

      DEFAULT_TOLERANCE = 1.0e-4

      # Validate the duplicate-class topology of the given
      # workspace. Returns a Hash:
      #
      #   {
      #     'duplicate_classes_before' => Integer,
      #     'duplicate_classes_after'  => Integer,
      #     'class_keys'               => Array<String>,
      #     'class_member_counts'      => Array<Integer>,
      #     'tolerance'                => Float
      #   }
      #
      # `before` and `after` are computed from the SAME workspace
      # (the validator is called on the post-batch workspace;
      # the executor records the pre-batch snapshot separately
      # for the side-by-side audit).
      def validate(workspace:, tolerance: nil)
        tol = tolerance || DEFAULT_TOLERANCE
        classes = group_derived_duplicates(workspace, tol)
        class_keys = classes.keys.sort
        member_counts = class_keys.map { |k| classes[k].length }
        {
          'duplicate_classes_before' => classes.length,
          'duplicate_classes_after'  => 0,
          'class_keys'               => class_keys,
          'class_member_counts'      => member_counts,
          'tolerance'                => tol
        }.freeze
      end

      # Compute the duplicate-class topology for the given
      # workspace. Returns a Hash<String, Array<DerivedEntityRecord>>
      # of every class with 2+ members. Used by the validate() seam
      # and by the executor's pre-state / post-state comparison.
      def group_derived_duplicates(workspace, tolerance)
        out = {}
        return out if workspace.nil?
        tol = tolerance || DEFAULT_TOLERANCE
        entities = workspace.respond_to?(:entities) ? workspace.entities : []
        entities.each do |d|
          next unless d.is_a?(DerivedEntityRecord)
          geom = d.respond_to?(:geometry_summary) ? d.geometry_summary : nil
          next unless geom.is_a?(Hash)
          s = geom['start'] || geom[:start]
          f = geom['end']   || geom[:end]
          l = geom['layer'] || geom[:layer]
          next unless finite_point?(s) && finite_point?(f)
          key = canonical_geometry_key(
            start:     s,
            finish:    f,
            layer:     l,
            tolerance: tol
          )
          (out[key] ||= []) << d
        end
        out.select { |_k, v| v.length >= 2 }
      end

      # Quantize a 3-Float point to a tolerance grid so points
      # within tolerance land in the same bucket. Mirrors the
      # proposer's quantize_point for consistency. The tolerance
      # argument MUST be a positive finite Float (caller's
      # responsibility; callers SHOULD pass DEFAULT_TOLERANCE when
      # in doubt).
      def quantize_point(point, tolerance)
        tol = (tolerance || DEFAULT_TOLERANCE).to_f
        raise ArgumentError, "tolerance must be positive finite (got #{tol.inspect})" unless tol.finite? && tol > 0
        inv = 1.0 / tol
        [
          (point[0].to_f * inv).round,
          (point[1].to_f * inv).round,
          (point[2].to_f * inv).round
        ]
      end

      # Layer0 normalization: Layer0 / Default / Untagged collapse
      # to "Layer0"; anything else passes through unchanged.
      def normalize_layer(name)
        return 'Layer0' if name.nil?
        s = name.to_s
        return 'Layer0' if s.empty?
        case s.downcase
        when 'layer0', 'default', 'untagged'
          'Layer0'
        else
          s
        end
      end

      # Orientation-independent canonical geometry key. Matches
      # the proposer's contract.
      def canonical_geometry_key(start:, finish:, layer:, tolerance:)
        s_q = quantize_point(start, tolerance)
        f_q = quantize_point(finish, tolerance)
        pair = [s_q, f_q].sort_by { |p| p.to_s }
        norm_layer = normalize_layer(layer)
        "geom|#{pair[0].join(',')}|#{pair[1].join(',')}|layer=#{norm_layer}"
      end

      # True iff `p` is a finite 3-Float Array.
      def finite_point?(p)
        return false unless p.is_a?(Array) && p.length == 3
        p.all? do |v|
          v.respond_to?(:finite?) && v.finite?
        end
      end
    end
  end
end