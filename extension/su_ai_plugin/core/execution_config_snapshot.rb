#
# core/execution_config_snapshot.rb — V1.4 captured execution config.
#
# Per V1.4 directive 030 (CodeX 030 PRE-BUILD TECHNICAL PREVIEW),
# answer to question 5:
#
#   Repair actions read only this captured context. Do not
#   scatter new thresholds or layer-name rules through
#   workspace/repair code.
#
# This class is the immutable, deterministic capture of the
# configuration that produced a given SourceSnapshot. The host
# Configuration (AnalysisConfig + Tolerance) is mutable and may
# drift; the captured snapshot is the V1.4+ rebuild input.
#
# Profile-name + live constants are NOT sufficient to reproduce
# a repair plan. The captured snapshot carries:
#   - profile identifier + version
#   - rule-set identifier + version + content digest
#   - tolerance schema/version + all effective numeric values
#   - session overrides
#   - source snapshot schema version (for forward compat)
#
# Two ExecutionConfigSnapshots are == iff every field matches
# (content equality; no host object identity involved).
#

require 'digest'
require_relative 'tolerance'

module SUAnalysis
  module Core
    class ExecutionConfigSnapshot
      # Locked field set. Any future addition is a schema bump.
      attr_reader :profile_id, :profile_version,
                  :rule_set_id, :rule_set_version, :rule_set_digest,
                  :tolerance_schema_version, :tolerance_values,
                  :session_overrides,
                  :source_snapshot_schema_version, :captured_at

      def initialize(profile_id:, profile_version:,
                     rule_set_id:, rule_set_version:, rule_set_digest:,
                     tolerance_schema_version:, tolerance_values:,
                     session_overrides:,
                     source_snapshot_schema_version:, captured_at: nil)
        @profile_id                      = profile_id.to_s
        @profile_version                 = profile_version.to_s
        @rule_set_id                     = rule_set_id.to_s
        @rule_set_version                = rule_set_version.to_s
        @rule_set_digest                 = rule_set_digest.to_s
        @tolerance_schema_version        = tolerance_schema_version.to_s
        # Defensive deep-freeze: callers must NOT mutate tolerance
        # values through the captured snapshot.
        @tolerance_values                = (tolerance_values || {}).dup.freeze
        @session_overrides               = (session_overrides || {}).dup.freeze
        @source_snapshot_schema_version = source_snapshot_schema_version.to_s
        @captured_at                     = (captured_at || self.class.default_timestamp).freeze
        # Top-level freeze: prevents any field from being
        # re-assigned after construction.
        freeze
      end

      def ==(other)
        return false unless other.is_a?(ExecutionConfigSnapshot)
        profile_id == other.profile_id &&
          profile_version == other.profile_version &&
          rule_set_id == other.rule_set_id &&
          rule_set_version == other.rule_set_version &&
          rule_set_digest == other.rule_set_digest &&
          tolerance_schema_version == other.tolerance_schema_version &&
          tolerance_values == other.tolerance_values &&
          session_overrides == other.session_overrides &&
          source_snapshot_schema_version == other.source_snapshot_schema_version
      end

      def eql?(other)
        self == other
      end

      def hash
        [
          profile_id, profile_version,
          rule_set_id, rule_set_version, rule_set_digest,
          tolerance_schema_version, tolerance_values,
          session_overrides,
          source_snapshot_schema_version
        ].hash
      end

      def to_h
        {
          profile_id:                      profile_id,
          profile_version:                 profile_version,
          rule_set_id:                     rule_set_id,
          rule_set_version:                rule_set_version,
          rule_set_digest:                 rule_set_digest,
          tolerance_schema_version:        tolerance_schema_version,
          tolerance_values:                tolerance_values,
          session_overrides:                session_overrides,
          source_snapshot_schema_version:  source_snapshot_schema_version,
          captured_at:                     captured_at
        }
      end

      # Build a snapshot from the live AnalysisConfig + Tolerance +
      # the V1.1 LayerRoleConfig rule_set. Pure-Ruby; no host calls.
      def self.from_live_config(analysis_config, rule_set_digest:, source_snapshot_schema_version:)
        tol = analysis_config.tolerance
        # Tolerance values are normalized via the public to_h so
        # the captured snapshot's tolerance_values Hash matches
        # what an external observer would see.
        tolerance_values = (tol.to_h || {}).dup
        # Derive a deterministic tolerance schema version from
        # the field set. When fields are added/renamed, the
        # schema version changes; rebuilds detect drift.
        tolerance_schema_version = 'tol-' + tolerance_values.keys.sort.join('-')
        new(
          profile_id:        'profile.' + analysis_config.profile_name.to_s,
          profile_version:   '1',
          rule_set_id:        'role.config',
          rule_set_version:   '1',
          rule_set_digest:    rule_set_digest.to_s,
          tolerance_schema_version: tolerance_schema_version,
          tolerance_values:        tolerance_values,
          session_overrides:        {},
          source_snapshot_schema_version: source_snapshot_schema_version
        )
      end

      # Default timestamp (used when the caller does not provide one).
      # Tests that need a deterministic timestamp pass it explicitly.
      def self.default_timestamp
        '1970-01-01T00:00:00Z'
      end
    end
  end
end