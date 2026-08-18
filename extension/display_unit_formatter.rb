#
# extension/display_unit_formatter.rb — host-side unit formatter.
#
# Per CodeX Q5 Round 013: internal raw inch Float, DisplayString via
# Sketchup.format_length. Core stays unit-agnostic. This module is the
# ONLY place that calls Sketchup.format_length.
#
# In tests (non-SU environment), falls back to a deterministic
# "X.XXXX inch" formatting.
#

module SUAnalysis
  module Extension
    module DisplayUnitFormatter
      module_function

      # Format a length value (in SU internal inches) for display.
      # value: Numeric (in inches)
      # Returns: String (display)
      def format_length(value)
        return '0.0 inch' if value.nil?
        v = Float(value)
        if su_format_length_available?
          begin
            return Sketchup.format_length(v)
          rescue StandardError
            # Fall through to fallback.
          end
        end
        fallback_format(v)
      end

      # Build a { issue_id => display_length } map for an Analyzer
      # pipeline's metadata. Pure-Ruby over an Array of normalized
      # issues + an Array of Analyzer hashes. Inputs are pure Ruby;
      # only the per-value formatting goes through Sketchup.
      def format_all(issues)
        out = {}
        Array(issues).each do |iss|
          next unless iss.is_a?(Hash)
          meta = iss[:metadata] || {}
          len = meta[:length] || meta['length'] || meta[:distance] || meta['distance']
          if len.is_a?(Numeric)
            out[iss[:issue_id]] = format_length(len)
          end
        end
        out
      end

      # ---- internals ------------------------------------------------------

      def su_format_length_available?
        return false unless defined?(Sketchup)
        return false unless Sketchup.respond_to?(:format_length)
        true
      end

      def fallback_format(value)
        # Deterministic format used in tests and outside SU.
        format('%.4f inch', value)
      end
    end
  end
end
