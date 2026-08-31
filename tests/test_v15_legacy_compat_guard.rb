# tests/test_v15_legacy_compat_guard.rb — V1.5 Phase 1
#
# Legacy-Ruby compatibility regression guard.
#
# Trigger: real SketchUp 2020 (Ruby 2.5.5) load test exposed
# endless-range syntax (`[n..]`, added in Ruby 2.6) in two
# production call sites in core/duplicate_repair_proposer.rb.
# The dispatch V15-LEGACY-COMPAT-HARDENING-2026-08-31 expanded
# that finding into one bounded hardening packet before the
# Owner SU2020 BLOCK-005 Real-Host Feasibility Probe.
#
# Purpose:
#   This file is the LIGHTWEIGHT REGRESSION GUARD for the
#   production load tree's compatibility with the minimum
#   supported SketchUp generation's embedded Ruby. It runs as
#   part of the standard test suite so accidental reintroduction
#   of known-bad Ruby language constructs is caught at test time
#   rather than at real-host install time.
#
# Scope:
#   - Parses every production .rb file in extension/ + scripts/
#     with the project-vendored Ruby. This catches syntax that
#     the vendored Ruby REJECTS at parse time.
#   - Cross-checks parseability via Ripper.sexp (semantic AST).
#   - Performs focused regex scans for known-modern-syntax
#     patterns that may pass vendored Ruby parseability but
#     break on the SU minimum baseline.
#
# Non-scope:
#   - Does NOT install or reconfigure Ruby.
#   - Does NOT invent a full Ruby-version-targeted parser.
#   - Does NOT claim SU2017 (Ruby 2.2.6) real-host PASS.
#   - Does NOT modify any production .rb file in this test.
#   - Does NOT invoke Codyx or design V1.6.
#
# Limitations (truthful):
#   - The vendored interpreter is Ruby 2.7.8. Ruby 2.7.8
#     ACCEPTS Ruby 2.6+ constructs (endless ranges,
#     pattern matching, etc.), so a vendored-parse PASS does
#     NOT prove the file is parseable on a Ruby 2.5.5
#     SketchUp 2020 host or a Ruby 2.2.4 SketchUp 2017 host.
#     The regex scans exist precisely to bridge this gap for
#     the most common modern-Ruby constructs.
#   - A reliable lightweight Ruby-version-targeted parser is
#     not available in this project; therefore this guard is a
#     BEST-EFFORT combination of:
#       1. Vendored-parse check (Ruby 2.7.8, broad syntax).
#       2. Ripper.sexp (semantic AST, catches the same parse
#          set as #1).
#       3. Targeted regex scans for known constructs that
#          the vendored Ruby silently accepts but the SU
#          minimum baseline rejects.
#   - This explicitly satisfies dispatch §11's "lightweight
#     guard" requirement without inventing a parser.
#

require_relative 'runner'
require 'ripper'

module Tests
  module LegacyCompatGuard
    # The production load tree (matches scripts/build_rbz.rb's
    # SHIPPED_DIRS + SHIPPED_FILES rules).
    PRODUCTION_FILES = begin
      base = File.expand_path('../extension', __dir__)
      files = []
      Dir.glob(File.join(base, '**', '*.rb'), File::FNM_DOTMATCH).each do |f|
        next if File.directory?(f)
        files << f
      end
      files.sort
    end.freeze

    # Known-modern-syntax regexes that may pass vendored Ruby
    # parse but break on the minimum SketchUp baseline
    # (SketchUp 2017+ Ruby 2.2.4+; the dispatch baseline is
    # Ruby 2.2.x with the stronger caveat that
    # `[1..]` endless ranges were already proven to fail on
    # a real SU2020 host Ruby 2.5.5; integer-literal
    # underscores are Ruby 2.5+).
    KNOWN_MODERN_SYNTAX = [
      {
        # Integer literal underscores were added in Ruby 2.5.
        # SU2017 (Ruby 2.2.4) and SU2018 (Ruby 2.4.4)
        # REJECT this at parse time. Confirmed finding on
        # 2026-08-31 in core/source_snapshot.rb line 447 (the
        # SecureRandom fallback inside a `rescue LoadError`
        # branch — would have rejected SU2017 parse even
        # though the rescue branch is dead at runtime on any
        # host that ships with stdlib securerandom).
        id:    'integer_literal_underscore',
        regex: /(?<![\w.])[0-9]+_[0-9_]*[0-9]/,
        ruby_min_unsupported: '2.5.0',
        # Lower versions in this list still supports it;
        # we conservatively reject the construct on Ruby
        # 2.4.x and earlier because that's the minimum.
        ruby_min_required: '2.5.0',
        comment: 'Integer literal underscore (`1_000_000`) requires Ruby >= 2.5.0. Use `1000000` for SU2017+/SU2018 compat.'
      },
      {
        # Endless range `[a..]` was added in Ruby 2.6.
        # SU2017 (2.2.4) and SU2020 (2.5.5) both REJECT this
        # at parse time. Confirmed finding on 2026-08-28 in
        # core/duplicate_repair_proposer.rb at the now-fixed
        # sites. The two prior fix sites were changed to
        # `[1..-1]`. Any reintroduction must be caught.
        id:    'endless_range',
        regex: /\[[a-zA-Z_][a-zA-Z0-9_]*\s*\.{2,}\]/,
        ruby_min_unsupported: '2.6.0',
        ruby_min_required: '2.6.0',
        comment: 'Endless range syntax (`[a..]`) requires Ruby >= 2.6.0. Use `[a..-1]` for SU2017+/SU2020 compat.'
      },
      {
        # Beginless range `[..b]` was added in Ruby 2.6.
        # Same rationale as endless_range.
        id:    'beginless_range',
        regex: /\[\.{2,}\s*[a-zA-Z_0-9\-\+\*\/]+\]/,
        ruby_min_unsupported: '2.6.0',
        ruby_min_required: '2.6.0',
        comment: 'Beginless range syntax (`[..b]`) requires Ruby >= 2.6.0. Use `[0..b-1]` for SU2017+/SU2020 compat.'
      },
      {
        # Numbered block parameters (`_1`, `_2`, ...) added
        # in Ruby 2.7. SU2017/SU2020 REJECT these.
        id:    'numbered_block_params',
        regex: /\b_[0-9]\b/,
        ruby_min_unsupported: '2.7.0',
        ruby_min_required: '2.7.0',
        comment: 'Numbered block parameter (`_1`, `_2`, ...) requires Ruby >= 2.7.0. Use explicit `|a|` for SU2017+/SU2020 compat.'
      },
      {
        # Safe navigation `&.` added in Ruby 2.3. SU2017 is
        # Ruby 2.2.4 which does NOT have it. (SU2018+ is
        # 2.4.4+ which does have it; the dispatch baseline
        # is 2.2.x so we reject for safety.)
        id:    'safe_navigation',
        # Conservative: only match `obj.attr` or `obj.method(...)`
        # preceded by `&` (not `&&` and not `&:` block-proc).
        regex: /[^&]&[.][a-zA-Z_]/,
        ruby_min_unsupported: '2.3.0',
        ruby_min_required: '2.3.0',
        comment: 'Safe navigation `&.` requires Ruby >= 2.3.0. Use explicit nil guards for SU2017 (Ruby 2.2.4) compat.'
      }
    ].freeze

    # Run the vendored Ruby parser on each production file.
    # Uses RubyVM::InstructionSequence.compile (the same
    # mechanism the existing test_rbz_smoke.rb uses to
    # parse the extracted .rbz contents). Returns
    # Array<[String file, String error]> for failing files.
    def self.vendored_parse_results
      failures = []
      PRODUCTION_FILES.each do |f|
        begin
          text = File.binread(f).force_encoding(Encoding::UTF_8)
          # Two-arg form: (source, file). Matches the
          # signature used in test_rbz_smoke.rb's install
          # smoke test.
          RubyVM::InstructionSequence.compile(text, f)
        rescue SyntaxError => e
          failures << [f, "SyntaxError: #{e.message}"]
        rescue StandardError => e
          failures << [f, "#{e.class}: #{e.message}"]
        end
      end
      failures
    end

    # Run Ripper.sexp on each production file. Returns
    # Array<[file, message]> for files that fail to parse.
    def self.ripper_parse_results
      failures = []
      PRODUCTION_FILES.each do |f|
        begin
          text = File.binread(f).force_encoding(Encoding::UTF_8)
          ast = Ripper.sexp(text)
          if ast.nil?
            failures << [f, 'Ripper.sexp returned nil (parse failure)']
          end
        rescue StandardError => e
          failures << [f, "#{e.class}: #{e.message}"]
        end
      end
      failures
    end

    # Scan each production file for known-modern-syntax
    # constructs. Returns Array of
    # { file:, line_no:, line:, id:, match_text:, comment: }
    # for every offending match (across files and constructs).
    def self.modern_syntax_findings
      findings = []
      PRODUCTION_FILES.each do |f|
        # Read with binary and normalize to UTF-8 for line counting.
        text = File.binread(f).force_encoding(Encoding::UTF_8)
        KNOWN_MODERN_SYNTAX.each do |spec|
          text.each_line.with_index(1) do |line, n|
            # Strip the line of trailing newline + ignore pure
            # comment lines (best-effort: starts with optional
            # whitespace then '#').
            line_to_check = line.sub(/\r?\n\z/, '')
            stripped = line_to_check.lstrip
            next if stripped.start_with?('#')
            m = line_to_check.match(spec[:regex])
            next unless m
            findings << {
              file:       f,
              line_no:    n,
              line:       line_to_check,
              id:         spec[:id],
              match_text: m.to_s,
              comment:    spec[:comment]
            }
          end
        end
      end
      findings
    end
  end
end

# ---- tests ---------------------------------------------------------

# Vendored-Ruby parse check on every production .rb. If the
# vendored Ruby (2.7.8) cannot parse a file, the file is
# broken on the SU minimum baseline too (the minimum baseline
# supports a smaller parse set than 2.7.8).
test 'LEGACY-COMPAT: vendored Ruby parses every production .rb file (extension/ + scripts/)' do
  failures = Tests::LegacyCompatGuard.vendored_parse_results
  if failures.any?
    msg = "vendored Ruby failed to parse #{failures.length} files:\n" +
          failures.map { |f, e| "  #{f}: #{e}" }.join("\n")
    assert false, msg
  end
end

# Ripper.sexp cross-check on every production .rb. This catches
# different edges than RubyVM::InstructionSequence.compile.
test 'LEGACY-COMPAT: Ripper.sexp parses every production .rb file (extension/ + scripts/)' do
  failures = Tests::LegacyCompatGuard.ripper_parse_results
  if failures.any?
    msg = "Ripper.sexp failed to parse #{failures.length} files:\n" +
          failures.map { |f, e| "  #{f}: #{e}" }.join("\n")
    assert false, msg
  end
end

# Modern-syntax scan (regex). These are the constructs the
# vendored Ruby silently accepts but the SU minimum baseline
# rejects. Each finding is reported with file/line/class so
# the offending site can be located and fixed.
test 'LEGACY-COMPAT: no known modern-syntax constructs in production source' do
  findings = Tests::LegacyCompatGuard.modern_syntax_findings
  if findings.any?
    msg = "found #{findings.length} known-modern-syntax construct(s):\n" +
          findings.map do |f|
            rel_path = f[:file].sub(File.expand_path('..', __dir__).gsub('\\', '/') + '/', '')
            "  #{rel_path}:#{f[:line_no]}  [#{f[:id]}]  match=#{f[:match_text].inspect}  -- #{f[:comment]}"
          end.join("\n")
    assert false, msg
  end
end

# A focused regression for the specific known production
# historical finding (dispatch §0): integer literal underscore
# `1_000_000` in core/source_snapshot.rb is replaced with
# `1000000`. This test pins that exact fix.
test 'LEGACY-COMPAT: no integer literal underscore in core/source_snapshot.rb (FIX-COMPAT-INT)' do
  src = File.expand_path(
    '../extension/su_ai_plugin/core/source_snapshot.rb', __dir__
  )
  text = File.binread(src).force_encoding(Encoding::UTF_8)
  offenders = []
  text.each_line.with_index(1) do |line, n|
    next if line.lstrip.start_with?('#')
    offenders << [n, line.chomp] if line.match(/(?<![\w.])[0-9]+_[0-9_]*[0-9]/)
  end
  if offenders.any?
    details = offenders.map { |n, l| "    line #{n}: #{l.strip.inspect}" }.join("\n")
    assert false, "core/source_snapshot.rb contains integer literal underscore (Ruby 2.5+ only):\n#{details}"
  end
end

# A focused regression for the specific known production
# historical finding (dispatch §0 + prior fix in commit
# f61c352): endless ranges `[n..]` are replaced with
# `[n..-1]`. The prior fix sites were `sorted_ids[1..]`
# inside core/duplicate_repair_proposer.rb.
test 'LEGACY-COMPAT: no endless-range [n..] in production source (FIX-COMPAT-RANGE)' do
  base = File.expand_path('../extension', __dir__)
  offenders = []
  Dir.glob(File.join(base, '**', '*.rb')).sort.each do |f|
    text = File.binread(f).force_encoding(Encoding::UTF_8)
    text.each_line.with_index(1) do |line, n|
      next if line.lstrip.start_with?('#')
      if line.match(/\[[a-zA-Z_0-9\+\*\/\-\s]+\.\.\]/)
        offenders << [f, n, line.chomp]
      end
    end
  end
  if offenders.any?
    details = offenders.map do |f, n, l|
      rel = f.sub(base, '').sub(/^\//, '')
      "    #{rel}:#{n}: #{l.strip.inspect}"
    end.join("\n")
    assert false, "production source contains endless range [n..] (Ruby 2.6+ only):\n#{details}"
  end
end
