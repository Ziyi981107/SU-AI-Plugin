#
# core/issue_normalizer.rb — pure-Ruby normalization layer that turns the
# analyzer-emitted Hashes (Integer `kind`, String `severity`, etc.) into
# the canonical UIIssue Hashes (Symbol issue_type, canonical severity
# String, etc.) expected by the IssueRegistry.
#
# Per CodeX Review 011..014 (2026-08-18):
#   - "kind" -> "issue_type" (Symbol/String normalization)
#   - SourceReference default severity (Symbol low/medium/high) ->
#     canonical String "low"/"medium"/"high"
#   - Per-type severity mapping (R005):
#       duplicate_edge_candidate   :medium
#       short_edge                 :low
#       open_endpoint              :medium
#       gap_candidate              :medium
#       significant_non_zero_z     :medium
#       abnormal_large_coord       :high
#       deep_nesting               :low
#   - Preflight warnings are converted to UIIssue Hashes with
#     sources: [] and locatable: false.
#   - Strip / replace control characters in preflight messages.
#   - UTF-8 preserved.
#
# This module is pure Ruby. It does NOT call SketchUp or access
# compatibility/. It only transforms Hashes.
#

module SUAnalysis
  module Core
    module IssueNormalizer
      # Per CodeX Round 020 REAL-HOST BLOCK (recheck):
      #
      # The previous version used:
      #
      #     module_function
      #     # ... public API defs ...
      #     private
      #     # ... helper defs ...
      #
      # That was broken: `private` overrides the `module_function`
      # flag for subsequent methods, so the helpers became PRIVATE
      # INSTANCE METHODS only (not module methods). They could still
      # be called when the test file did `include
      # SUAnalysis::Core::IssueNormalizer` (because including M puts
      # M's private instance methods into Object's ancestor chain,
      # which is reachable from any Module object's method dispatch).
      # But on real production code paths (extension/analyzers_runner.rb
      # calls `SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)`
      # with no prior `include`), the implicit-self call inside that
      # module method to `normalize_location(...)` raised
      # `NoMethodError: undefined method 'normalize_location' for
      # SUAnalysis::Core::IssueNormalizer:Module`. The first issue
      # with a non-nil 3D location crashed the whole command.
      #
      # Fix: ALL helpers are now defined after `module_function` so
      # they ARE module singleton methods (callable both from
      # production's `M.normalize_analyzer_issue(...)` form and from
      # inside-the-module implicit-self form). Helpers are then marked
      # `private_class_method` to keep the "intended visibility"
      # (callers from outside the module should not use them
      # directly; they are internal).
      module_function

      # Per-R005 severity assignment keyed by analyzer `kind` or
      # preflight warning `code`. Anything not in this map falls back
      # to "medium" (R005 conservative default).
      SEVERITY_BY_TYPE = {
        'duplicate_edge_candidate' => 'medium',
        'short_edge'                 => 'low',
        'open_endpoint'              => 'medium',
        'gap_candidate'              => 'medium',
        'significant_non_zero_z'     => 'medium',
        'abnormal_large_coord'       => 'high',
        'deep_nesting'               => 'low'
      }.freeze

      # ----- public API (module singleton methods, callable from
      #       extension/analyzers_runner.rb's `SUAnalysis::Core::IssueNormalizer.xxx`
      #       form) -----

      # Convert an analyzer-emitted Hash (Integer kind, String
      # severity, etc.) into a NORMALIZED Hash with Symbol keys and
      # canonical string values. The output is NOT yet a UIIssue
      # Hash — it does not yet have `issue_id`, `sources`, `locatable`,
      # or `display_length`. Those are filled by IssueEnricher.
      def normalize_analyzer_issue(raw)
        return nil unless raw.is_a?(Hash)
        issue_type = raw[:kind] || raw['kind']
        return nil if issue_type.nil? || issue_type.to_s.empty?
        # Per R005: the per-type severity mapping is AUTHORITATIVE.
        # The analyzer's severity is coerced to canonical then overridden
        # by the per-type map. This guarantees R005 invariants regardless
        # of analyzer bugs.
        sev = canonical_severity(raw[:severity] || raw['severity'])
        {
          issue_type:         issue_type.to_s,
          severity:           severity_for_type(issue_type),
          confidence:         canonical_severity(raw[:confidence] || raw['confidence']),
          source_entity_ids:  Array(raw[:source_entity_ids] || raw['source_entity_ids']).map { |x| Integer(x) },
          edge_ids:           Array(raw[:edge_ids] || raw['edge_ids']).map { |x| Integer(x) },
          location:           normalize_location(raw[:location] || raw['location']),
          message:            sanitize_message(raw[:message] || raw['message']),
          metadata:           normalize_metadata(raw[:metadata] || raw['metadata'])
        }
      end

      # Convert a Preflight warning Hash (CodeX Review 007 S2-BLOCK-004)
      # into a NORMALIZED Hash. The input is the same shape embedded
      # in PreflightReport.warnings:
      #   { code: :significant_non_zero_z, message: "...", severity: :medium }
      # Returns nil for unknown codes.
      def normalize_preflight_warning(raw)
        return nil unless raw.is_a?(Hash)
        code = raw[:code] || raw['code']
        return nil if code.nil?
        issue_type = canonical_preflight_code(code)
        return nil if issue_type.nil?
        {
          issue_type:         issue_type,
          severity:          severity_for_preflight(code, raw[:severity] || raw['severity']),
          confidence:        'medium',
          source_entity_ids: [],
          edge_ids:          [],
          location:          nil,
          message:           sanitize_message(raw[:message] || raw['message']),
          metadata:          { 'code' => code.to_s }
        }
      end

      # Convert all preflight warnings. Accepts PreflightReport.warnings
      # (Array<Hash>). Returns Array<Hash> of normalized issue Hashes.
      def normalize_preflight_warnings(warnings)
        Array(warnings).map { |w| normalize_preflight_warning(w) }.compact
      end

      # Canonical severity normalization: a Symbol :low or String "low"
      # both become the canonical String "low". Anything not in the
      # canonical set is coerced to "medium" (defensive default).
      def canonical_severity(value)
        s = value.to_s
        SEVERITY_BY_TYPE.values.include?(s) ? s : 'medium'
      end

      # Per-issue-type severity, applying R005 mapping. If the
      # analyzer's severity is already canonical, respect it ONLY
      # if it matches the per-type map; otherwise fall back to the
      # canonical per-type value.
      def severity_for_type(issue_type)
        SEVERITY_BY_TYPE[issue_type.to_s] || 'medium'
      end

      # ----- private helpers (also module singleton methods so they
      #       are reachable from inside public-API module methods).
      #       Marked `private_class_method` at the bottom of this
      #       module so callers from outside cannot use them
      #       directly. -----

      def canonical_preflight_code(symbol_code)
        s = symbol_code.to_s
        case s
        when 'significant_non_zero_z' then 'significant_non_zero_z'
        when 'abnormal_large_coord'   then 'abnormal_large_coord'
        when 'deep_nesting'           then 'deep_nesting'
        else nil
        end
      end

      def severity_for_preflight(code, raw_severity)
        # Map the preflight-side Symbol severity to canonical String.
        s = raw_severity.to_s
        case s
        when 'low'    then 'low'
        when 'medium' then 'medium'
        when 'high'   then 'high'
        else severity_for_type(code)
        end
      end

      def normalize_location(loc)
        return nil if loc.nil?
        return nil unless loc.is_a?(Array) && loc.size == 3
        loc.map { |c| Float(c) }
      end

      def sanitize_message(msg)
        return '' if msg.nil?
        s = msg.to_s
        # Strip control characters except newline (\n) and tab (\t).
        # Preserve all other UTF-8 bytes verbatim.
        s.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '')
      end

      def normalize_metadata(meta)
        return {} if meta.nil? || !meta.is_a?(Hash)
        out = {}
        meta.each do |k, v|
          ks = k.to_s
          out[ks] = v.is_a?(String) || v.is_a?(Numeric) || v == true || v == false || v.nil? || v.is_a?(Array) || v.is_a?(Hash) ? v : v.to_s
        end
        out
      end

      # Mark the helpers as PRIVATE module singleton methods. They
      # remain callable from inside the module (via implicit-self
      # from public-API methods above), but external callers like
      # `SUAnalysis::Core::IssueNormalizer.normalize_location(...)`
      # now raise `NoMethodError: private method 'normalize_location'`
      # — which is the intended visibility contract. This preserves
      # the original `private` intent (helpers should not be part of
      # the module's public API surface) WITHOUT breaking the
      # module-method dispatch path.
      private_class_method :canonical_preflight_code,
                           :severity_for_preflight,
                           :normalize_location,
                           :sanitize_message,
                           :normalize_metadata
    end
  end
end
