#
# tests/test_core_no_host_dependency.rb
#
# Lint: every new (and re-checked) core/*.rb file MUST NOT reference
# SketchUp, UI, Geom, the compatibility/ shim, or the extension/
# adapter. Anything in core/ that does so is a hard FAIL.
#
# This test enforces the locked architecture rule: core/ is pure Ruby
# and SketchUp-importable. The host glue lives in extension/ only.
#

require_relative 'runner'

CORE_DIR = File.expand_path('../extension/su_ai_plugin/core', __dir__)
FORBIDDEN_TOKENS = [
  'Sketchup',
  'UI',
  'Geom',
  'compatibility/',
  'extension/'
].freeze

# Files that legitimately mention these tokens in COMMENTS or as
# module-name substrings are still allowed; we tokenize and check
# against actual require / reference patterns.

# Patterns: lines that *use* a forbidden token (not just mention it).
# We look for:
#   - `require` (any flavor)
#   - `::CONSTANT` access
#   - method calls like `.ui_something` (rare in core)
#   - ident part of a require path / direct literal reference

FORBIDDEN_PATTERNS = [
  /\brequire\s+['"][^'"]*Sketchup/i,
  /\brequire\s+['"][^'"]*compatibility\//i,
  /\brequire\s+['"][^'"]*extension\//i,
  /\bSketchup::/,
  /\bUI::/,                  # matches UI::HtmlDialog, UI::Command, etc.
  /\bGeom::/,                # matches Geom::Point3d, Geom::Transformation, etc.
  /\bSketchup\.\w+/,         # e.g. Sketchup.active_model
  /\bUI\.\w+/,               # bare UI call (unlikely but possible)
  /\bextension\//,           # any path reference
  /\bcompatibility\//        # any path reference
].freeze

def collect_core_files
  Dir[File.join(CORE_DIR, '*.rb')].sort
end

# Find forbidden usages per file.
def find_violations(path)
  return [] unless File.file?(path)
  violations = []
  File.foreach(path).with_index do |line, idx|
    next if line.lstrip.start_with?('#')
    FORBIDDEN_PATTERNS.each do |pat|
      if line =~ pat
        violations << { file: path, line: idx + 1, text: line.rstrip }
      end
    end
  end
  violations
end

# --- tests ---

test 'core_no_host_dependency: every core/*.rb file is checked' do
  files = collect_core_files
  assert files.length > 0, "no core/*.rb files found at #{CORE_DIR}"
end

test 'core_no_host_dependency: no file references Sketchup::' do
  files = collect_core_files
  found = []
  files.each do |f|
    find_violations(f).each do |v|
      found << v if v[:text] =~ /Sketchup::/
    end
  end
  assert_equal [], found.map { |v| "#{v[:file]}:#{v[:line]} -> #{v[:text]}" }
end

test 'core_no_host_dependency: no file requires compatibility/ or extension/' do
  files = collect_core_files
  bad = []
  files.each do |f|
    find_violations(f).each do |v|
      if v[:text] =~ /require\s+['"][^'"]*(compatibility|extension)\//
        bad << "#{v[:file]}:#{v[:line]} -> #{v[:text]}"
      end
    end
  end
  assert_equal [], bad
end

test 'core_no_host_dependency: no file references UI::, Geom::, or Sketchup.' do
  files = collect_core_files
  bad = []
  files.each do |f|
    find_violations(f).each do |v|
      if v[:text] =~ /\b(UI::|Geom::|Sketchup\.)/
        bad << "#{v[:file]}:#{v[:line]} -> #{v[:text]}"
      end
    end
  end
  if !bad.empty?
    msg = "Forbidden host-side tokens found in core/:\n  " + bad.join("\n  ")
    raise AssertionError, msg
  end
end

test 'core_no_host_dependency: lint covers expected files' do
  files = collect_core_files
  expected = %w[
    issue_registry.rb
    issue_id_assigner.rb
    issue_enricher.rb
    issue_normalizer.rb
    issue_grouper.rb
    analysis_result.rb
    issue_locator_policy.rb
    structural_facts.rb
    source_reference.rb
  ]
  missing = expected - files.map { |f| File.basename(f) }
  assert_equal [], missing
end
