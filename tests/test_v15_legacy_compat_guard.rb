# tests/test_v15_legacy_compat_guard.rb — V1.5 Phase 1
#
# Targeted legacy-Ruby compatibility regression guard.
#
# Trigger: real SketchUp 2020 (Ruby 2.5.5) load test exposed
# endless-range syntax (`[n..]`, added in Ruby 2.6) in two
# production call sites in core/duplicate_repair_proposer.rb
# (replaced by `sorted_ids[1..-1]` in implementation commit
# f61c352, prior chat session). The dispatch
# V15-LEGACY-COMPAT-HARDENING-2026-08-31 expanded that finding
# into one bounded hardening packet, which has since been
# corrected by the corrective dispatch
# V15-LEGACY-COMPAT-CORRECTION-2026-08-31.
#
# Purpose:
#   This file is the LIGHTWEIGHT targeted-regression guard
#   for the production load tree's known-modern-syntax
#   compatibility. It runs as part of the standard test
#   suite so accidental reintroduction of known-modern-syntax
#   constructs (whose SU-minimum-baseline support is uncertain
#   and which the project's vendored Ruby 2.7.8 silently
#   accepts) is caught at test time rather than at real-host
#   install time.
#
# CORRECTION SCOPE (per V15-LEGACY-COMPAT-CORRECTION-2026-08-31):
#   - Removed the integer_literal_underscore rule (Ruby 2.2
#     OFFICIAL SYNTAX DOCUMENTATION explicitly supports
#     underscores in numeric literals, e.g. `1_234`. The
#     prior claim that this requires Ruby 2.5+ was factually
#     incorrect and has been retracted).
#   - Removed the per-file guard pinning the
#     integer-underscore change on core/source_snapshot.rb
#     (no longer applicable after FINDING A correction).
#   - Kept the confirmed endless-range guard (which IS a
#     real Ruby 2.6+ addition and which DID cause the real
#     SU2020 load failure).
#   - Re-framed the legacy-syntax guard to say only what
#     it actually checks: "no known modern-syntax
#     constructs in production source", with each entry
#     documenting the minimum Ruby version it claims.
#   - Re-framed the parser-evidence wording to NOT claim
#     that a newer-parser PASS proves old-parser
#     compatibility. Vendored Ruby 2.7.8 is the only
#     vendored Ruby; Ruby 2.7.8 ACCEPTs everything Ruby
#     2.6 / 2.7 parse so an explicit `ruby -c` PASS does
#     NOT prove Ruby 2.5.5 / Ruby 2.2.4 parse. The
#     static-syntax guard is documented accordingly.
#
# Non-scope:
#   - Does NOT install or reconfigure Ruby.
#   - Does NOT invent a Ruby-version-targeted parser.
#   - Does NOT claim SU2017 (Ruby 2.2.4) or SU2020 (Ruby
#     2.5.5) real-host PASS.
#   - Does NOT modify any production .rb file in this test.
#   - Does NOT invoke Codex or design V1.6.
#   - Does NOT redesign compatibility architecture.
#   - Does NOT close BLOCK-005.
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

    # Known-modern-syntax regexes. Each entry:
    #   - id:  stable class identifier
    #   - regex: a deliberately TIGHT pattern (comprehensive
    #     enough to catch realistic production use of the
    #     construct, narrow enough to avoid matching
    #     ordinary Ruby code)
    #   - ruby_min_unsupported: the LOWEST-RUBY-VERSION
    #     where this construct EXISTS. We assert that the
    #     construct does not appear in production because
    #     the project targets that lower Ruby version.
    #   - ruby_min_required: same value as
    #     ruby_min_unsupported for these guards; documented
    #     so the guard's claim is precise.
    #   - comment: one-line plain-English rationale.
    #
    # IMPORTANT: do NOT add a rule without strong evidence
    # the construct requires a specific Ruby version. The
    # prior integer_literal_underscore rule was evidence-
    # wrong (Ruby 2.2 supports `1_234`) and has been removed.
    KNOWN_MODERN_SYNTAX = [
      {
        # Endless range `[a..]` was added in Ruby 2.6.
        # SU2020 (Ruby 2.5.5) and SU2017 (Ruby 2.2.4) both
        # REJECT this at parse time. CONFIRMED by real
        # SU2020 load test (the dispatch that triggered this
        # guard: endless range at two sites in
        # core/duplicate_repair_proposer.rb, replaced in
        # f61c352).
        id:    'endless_range',
        regex: /\[[a-zA-Z_0-9\+\*\/\-\s]+\.\.\]/,
        ruby_min_unsupported: '2.6.0',
        ruby_min_required: '2.6.0',
        comment: 'Endless range syntax (`[a..]`) requires Ruby >= 2.6.0. Use `[a..-1]` for SU2020 (2.5.5) and SU2017 (2.2.4) compat.'
      },
      {
        # Beginless range `[..b]` was added in Ruby 2.6.
        # Same rationale as endless_range.
        id:    'beginless_range',
        regex: /\[\.{2,}\s*[a-zA-Z_0-9\-\+\*\/]+\]/,
        ruby_min_unsupported: '2.6.0',
        ruby_min_required: '2.6.0',
        comment: 'Beginless range syntax (`[..b]`) requires Ruby >= 2.6.0. Use `[0..b-1]` for SU2020 (2.5.5) and SU2017 (2.2.4) compat.'
      },
      {
        # Numbered block parameters (`_1`, `_2`, ...) added
        # in Ruby 2.7. SU2020 (2.5.5) and SU2017 (2.2.4)
        # REJECT these.
        id:    'numbered_block_params',
        regex: /\b_[0-9]\b/,
        ruby_min_unsupported: '2.7.0',
        ruby_min_required: '2.7.0',
        comment: 'Numbered block parameter (`_1`, `_2`, ...) requires Ruby >= 2.7.0. Use explicit `|a|` for SU2020 (2.5.5) and SU2017 (2.2.4) compat.'
      },
      {
        # Safe navigation `&.` added in Ruby 2.3. SU2017
        # (Ruby 2.2.4) does NOT have it; SU2020 (2.5.5)
        # DOES have it. Project targets SU2017 baseline per
        # PROJECT_MASTER_PLAN_V1X.md, so safe-navigation
        # remains a real SU2017 incompatibility.
        id:    'safe_navigation',
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
    #
    # NOTE: The vendored parser is Ruby 2.7.8. Ruby 2.7.8
    # ACCEPTS everything Ruby 2.6/2.7 parse, so an explicit
    # compile PASS does NOT prove the file is parseable on
    # a Ruby 2.5.5 SketchUp 2020 host or a Ruby 2.2.4
    # SketchUp 2017 host. This test is documented as a
    # current-source syntax/load smoke, NOT as proof of
    # old-Ruby parseability.
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
    # Same caveat as vendored_parse_results: Ripper.sexp
    # in 2.7.8 parses as much as Ruby 2.7 parses, so
    # PASS here does NOT prove old-Ruby parseability.
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
    # Pure static-detection: the regex claims ONLY what
    # each individual entry documents. The result is NOT
    # a proof of old-Ruby parseability; it is a guard
    # against reintroduction of the specific constructs
    # in the list.
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

# Vendored-Ruby parse check on every production .rb. Acts as a
# current-source syntax/load smoke. Does NOT prove old-Ruby
# parseability (the vendored Ruby is 2.7.8; SU2020 embeds 2.5.5;
# SU2017 embeds 2.2.4). If the vendored Ruby cannot parse a
# file, the file is broken on every SU host too.
test 'LEGACY-COMPAT: vendored Ruby parses every production .rb file (current-source syntax/load smoke)' do
  failures = Tests::LegacyCompatGuard.vendored_parse_results
  if failures.any?
    msg = "vendored Ruby failed to parse #{failures.length} files:\n" +
          failures.map { |f, e| "  #{f}: #{e}" }.join("\n")
    assert false, msg
  end
end

# Ripper.sexp cross-check on every production .rb. Same
# evidence-bound caveat as the vendored parse: 2.7.8 Ripper
# accepts what 2.7 parses, NOT what 2.5.5 / 2.2.4 parse.
test 'LEGACY-COMPAT: Ripper.sexp parses every production .rb file (current-source AST smoke)' do
  failures = Tests::LegacyCompatGuard.ripper_parse_results
  if failures.any?
    msg = "Ripper.sexp failed to parse #{failures.length} files:\n" +
          failures.map { |f, e| "  #{f}: #{e}" }.join("\n")
    assert false, msg
  end
end

# Modern-syntax scan: targeted regex for the classes the
# static rule list in this file documents. Each finding
# is reported with file:line/class so the offending site
# can be located and fixed. The guard claims ONLY those
# classes and does NOT claim broad old-Ruby parseability.
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

# A focused regression for the SPECIFIC confirmed finding
# (the real SU2020 endless-range failure): endless ranges
# `[n..]` must not reappear in any production tree file.
# The dispatch that triggered this guard HARDENED two
# known offenders in core/duplicate_repair_proposer.rb;
# this test pins that fix at the tree level.
test 'LEGACY-COMPAT: no endless-range [n..] in production source (CONFIRMED-FIX-COMPAT-RANGE)' do
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
    assert false, "production source contains endless range [n..] (Ruby 2.6+ only, SU2017/SU2020 REJECT):\n#{details}"
  end
end

# Numer-underscore guard REMOVED (FINDING A from
# V15-LEGACY-COMPAT-CORRECTION-2026-08-31): Ruby 2.2 supports
# numeric literal underscores officially, including
# `1_234`. Plain numeric underscores are NOT a Ruby-2.5+
# construct and never were. The prior rule was a false
# positive. Removed; do not re-add without strong
# version-introduction evidence.
