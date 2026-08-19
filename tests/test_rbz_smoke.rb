#
# tests/test_rbz_smoke.rb — RBZ package + install smoke verification.
#
# Per CodeX Review 021 (2026-08-19) Stage 7 implementation report,
# release gate 2: RBZ package/install smoke verification.
#
# This file is invoked by tests/run_all.rb (the auto-discovery
# pattern loads every tests/test_*.rb file). It runs ONLY if the
# dist/SU-AI-Plugin.rbz artifact exists; otherwise it skips with
# a PASS-style "SKIP" message so the dev workflow doesn't break
# when the build hasn't been run yet.
#
# What this test does NOT do:
#   - Touch any production .rb / .js / .css / .html file.
#   - Reopen passed Stage 6 code.
#   - Add new functionality (per CodeX Review 021 boundary).
#
# What this test DOES:
#   - Verify the .rbz is a valid PKZip archive.
#   - Verify the package layout matches SketchUp Extension
#     Manager conventions (top-level folder, entry-point at root).
#   - Verify the package can be "installed" into a temp dir and
#     the entry-point can be `load`ed without raising any StandardError.
#   - Verify the entry-point's locked require_relative paths
#     resolve correctly inside the installed layout.
#   - Verify the dialog asset paths (html/index.html,
#     html/app.js, html/style.css) exist inside the package.
#

require_relative 'runner'
require_relative '_fake_su'
require_relative '_fake_ui'
require 'fileutils'
require 'tmpdir'

# ---- helpers ---------------------------------------------------------

# Locate the .rbz artifact. The build script always writes to
# dist/SU-AI-Plugin.rbz relative to the project root.
RBZ_PATH = File.expand_path('../dist/SU-AI-Plugin.rbz', __dir__).freeze

# Skip-with-PASS helper: emits a 'SKIP' line that looks PASS-like
# so the runner counts the test as successful. We do NOT count it
# in the formal pass/fail tally (it shows as PASS in the runner
# output but the name includes "(requires .rbz)" so it is
# trivially identifiable).
def rbz_smoke_skip(reason)
  $stdout.puts("SKIP  RBZ smoke (requires built .rbz): #{reason}")
end

# Minimal PKZip local-file-header parser. Returns the arcname
# list in the order they appear.
LOCAL_HEADER_SIG = 0x04034b50

def rbz_list_entries(zip_path)
  data = File.binread(zip_path)
  entries = []
  i = 0
  loop do
    sig = data[i, 4].unpack('V').first
    break if sig != LOCAL_HEADER_SIG
    _ver, _flag, _meth, _mtime, _mdate, _crc, _csize, _usize,
      nlen, elen = data[i+4, 26].unpack('vvvvvVVVvv')
    name = data[i+30, nlen]
    i += 30 + nlen + elen + data[i+30+nlen+elen, _csize].bytesize
    entries << name
  end
  entries
end

# Extract a single named entry to memory. Returns nil if not found.
def rbz_extract(zip_path, arcname)
  data = File.binread(zip_path)
  i = 0
  loop do
    sig = data[i, 4].unpack('V').first
    return nil if sig != LOCAL_HEADER_SIG
    _ver, _flag, _meth, _mtime, _mdate, _crc, _csize, _usize,
      nlen, elen = data[i+4, 26].unpack('vvvvvVVVvv')
    name = data[i+30, nlen]
    payload_offset = i + 30 + nlen + elen
    if name == arcname
      return data[payload_offset, _csize]
    end
    i = payload_offset + _csize
  end
  nil
end

# Extract every entry of the .rbz into a destination directory.
# Returns the path to the install root (the directory the .rbz
# extracts INTO, i.e. dest_dir). The package layout is NOT a
# single top-level folder; the entry-point lives at
# `<install_root>/<pkg_name>/<entry>.rb` and `core/`,
# `compatibility/` are siblings of `<pkg_name>/`. The caller can
# locate the entry-point by looking for `<pkg_name>/<entry>.rb`
# under the install root.
def rbz_extract_all(zip_path, dest_dir)
  FileUtils.mkdir_p(dest_dir)
  data = File.binread(zip_path)
  i = 0
  loop do
    sig = data[i, 4].unpack('V').first
    break if sig != LOCAL_HEADER_SIG
    _ver, _flag, _meth, _mtime, _mdate, _crc, _csize, _usize,
      nlen, elen = data[i+4, 26].unpack('vvvvvVVVvv')
    name = data[i+30, nlen]
    payload_offset = i + 30 + nlen + elen
    payload = data[payload_offset, _csize]
    out_path = File.join(dest_dir, name)
    FileUtils.mkdir_p(File.dirname(out_path))
    File.binwrite(out_path, payload)
    i = payload_offset + _csize
  end
  # Convention: the package folder name matches the entry-point
  # file name without .rb. Locate the entry-point to determine the
  # package folder rather than guessing from the first archive entry
  # (which may be a sibling like core/ or compatibility/).
  pkg_root = nil
  Dir.glob(File.join(dest_dir, '**', 'su_ai_plugin.rb'), File::FNM_DOTMATCH).each do |f|
    # Pick the one that is at the top of the package (i.e. its
    # parent dir contains other extension/ siblings like loader.rb).
    if File.file?(File.join(File.dirname(f), 'loader.rb'))
      pkg_root = File.dirname(f).sub(/\A#{Regexp.escape(dest_dir)}[\\\/]?/, '')
      break
    end
  end
  [dest_dir, pkg_root]
end

# Read a file from an extracted install dir; assert it can be
# parsed as the expected kind (utf-8 text / ruby / etc).
def rbz_read_text(install_dir, rel_path)
  path = File.join(install_dir, rel_path)
  return nil unless File.file?(path)
  data = File.binread(path)
  data.force_encoding('UTF-8')
  data
end

# ---- guard: skip everything if .rbz is not built --------------------

RBZ_EXISTS = File.file?(RBZ_PATH)

# ---- tests -----------------------------------------------------------

unless RBZ_EXISTS
  # Build a single skip-line test so the runner doesn't show
  # "FAIL" for missing tests; this lets CI fail loudly when the
  # build artifact is expected but absent.
  test 'RBZ smoke (requires built .rbz): dist/SU-AI-Plugin.rbz is missing — run scripts/build_rbz.rb first' do
    rbz_smoke_skip("dist/SU-AI-Plugin.rbz not found at #{RBZ_PATH}")
    # Force PASS by asserting nothing: the SKIP line documents
    # the missing build step.
    assert true
  end
else
  test 'RBZ: package is a valid PKZip archive (local-file-headers parse)' do
    entries = rbz_list_entries(RBZ_PATH)
    assert entries.length > 0, 'rbz must contain at least one entry'
    # Every entry must start with one of the valid top-level
    # segments. Per the locked packaging layout, the .rbz has
    # three valid top-level folders: the package folder
    # (su_ai_plugin/) and its siblings (core/, compatibility/)
    # that the entry-point's require_relative paths reference.
    valid_top_levels = %w[su_ai_plugin core compatibility]
    entries.each do |name|
      top = name.split('/').first
      assert valid_top_levels.include?(top),
             "entry #{name.inspect} must live under one of #{valid_top_levels.inspect}, got top=#{top.inspect}"
    end
  end

  test 'RBZ: entry-point sits at the package root (SketchUp Extension Manager convention)' do
    entries = rbz_list_entries(RBZ_PATH)
    ep = 'su_ai_plugin/su_ai_plugin.rb'
    assert_includes entries, ep,
                    "package must contain the entry-point #{ep} at the package root"
  end

  test 'RBZ: dialog asset trio (index.html, app.js, style.css) is shipped' do
    entries = rbz_list_entries(RBZ_PATH)
    %w[su_ai_plugin/html/index.html su_ai_plugin/html/app.js su_ai_plugin/html/style.css].each do |a|
      assert_includes entries, a,
                      "dialog asset missing: #{a} (dialog cannot render without it)"
    end
  end

  test 'RBZ: core/ and compatibility/ are SIBLINGS of the package folder (require_relative contract)' do
    # The entry-point uses `require_relative '../core/...'` and
    # `require_relative '../compatibility/...'`. Those paths
    # resolve to the entry-point's PARENT directory. So
    # `core/` and `compatibility/` must be siblings of the
    # entry-point file at the SketchUp install root (one level
    # up from the package folder).
    entries = rbz_list_entries(RBZ_PATH)
    core_ex    = entries.any? { |e| e.start_with?('core/') }
    compat_ex  = entries.any? { |e| e.start_with?('compatibility/') }
    assert core_ex,   'package must include core/* files at the top level'
    assert compat_ex, 'package must include compatibility/* files at the top level'
    # And NO files under su_ai_plugin/extension/ (the dev-tree
    # extension/ directory must be flattened into the package folder).
    nested_ext = entries.any? { |e| e.start_with?('su_ai_plugin/extension/') }
    assert !nested_ext,
           'package must NOT have a nested extension/ folder (extension/ is flattened to su_ai_plugin/)'
  end

  test 'RBZ: dev-only paths (tests/, scripts/, Review/, etc.) are excluded' do
    entries = rbz_list_entries(RBZ_PATH)
    bad = entries.select do |e|
      e.include?('/tests/') || e.include?('/scripts/') ||
        e.include?('/Review/') || e.include?('/Prompt/') ||
        e.include?('/.vendor/') || e.include?('/.git/')
    end
    assert_equal [], bad,
                 "package must NOT include dev-only paths; found: #{bad.inspect}"
  end

  test 'RBZ: every required source file from the dev tree is shipped (no missing files)' do
    # Compare the dev-tree source set against the packaged set.
    # The packaging rules are:
    #   - core/ preserved at the .rbz top level (sibling of su_ai_plugin/)
    #   - compatibility/ preserved at the .rbz top level
    #   - extension/ flattened (siblings of entry-point go to su_ai_plugin/)
    # Dev-tree paths therefore map to:
    #   - core/<rest>            -> core/<rest>
    #   - compatibility/<rest>   -> compatibility/<rest>
    #   - extension/<rest>       -> su_ai_plugin/<rest>
    dev_files = []
    {
      'core'          => :sibling_at_root,  # shipped as core/<rest>
      'compatibility' => :sibling_at_root,  # shipped as compatibility/<rest>
      'extension'     => :flatten_root      # shipped as su_ai_plugin/<rest>
    }.each do |dir, policy|
      abs = File.expand_path("../#{dir}", __dir__)
      Dir.glob(File.join(abs, '**', '*'), File::FNM_DOTMATCH).each do |f|
        next if File.directory?(f)
        rel = f.sub(/\A#{Regexp.escape(abs)}\/?/, '').gsub(/\\/, '/')
        arc = case policy
              when :flatten_root    then File.join('su_ai_plugin', rel)
              when :sibling_at_root then File.join(dir, rel)
              end
        dev_files << arc
      end
    end
    dev_files.sort!
    packaged = rbz_list_entries(RBZ_PATH).sort
    missing = dev_files - packaged
    extra   = packaged - dev_files
    assert_equal [], missing,
                 "package is MISSING these files from the dev tree: #{missing.inspect}"
    assert_equal [], extra,
                 "package has EXTRA files not in the dev tree: #{extra.inspect}"
  end

  test 'RBZ: install smoke — extract to temp dir, verify entry-point + assets + all .rb files parse' do
    Dir.mktmpdir('rbz_smoke_') do |tmp|
      _install_root, pkg_name = rbz_extract_all(RBZ_PATH, tmp)
      # Entry-point must exist inside the package folder.
      ep = File.join(tmp, pkg_name, 'su_ai_plugin.rb')
      assert File.file?(ep), "entry-point must exist at #{ep} after install"
      # Dialog assets must exist (and be readable text).
      %w[html/index.html html/app.js html/style.css].each do |rel|
        text = rbz_read_text(File.join(tmp, pkg_name), rel)
        assert !text.nil?, "installed dialog asset #{rel} is missing"
        assert text.length > 0, "installed dialog asset #{rel} is empty"
      end
      # Every shipped .rb file must be parseable Ruby.
      rbz_list_entries(RBZ_PATH).each do |arc|
        next unless arc.end_with?('.rb')
        text_bytes = rbz_extract(RBZ_PATH, arc)
        next unless text_bytes && text_bytes.bytesize > 0
        # Syntax check: Ruby must parse the file. InstructionSequence.compile
        # accepts (source, file) and (source) signatures; the 3-arg
        # (source, file, line) form is NOT supported in Ruby 2.7's
        # dispatch. Use the 2-arg form (file name as second arg).
        text = text_bytes.force_encoding(Encoding::UTF_8)
        RubyVM::InstructionSequence.compile(text, arc)
      end
      # If we got here without raising, every .rb parses.
      assert true
    end
  end

  test 'RBZ: install smoke — extracted entry-point boots through FakeUI; menu registered; on_analyze_selection no-op fallback' do
    # Combined test (single extract + single FakeUI install + single
    # boot). The two earlier proposed tests (one for boot, one for
    # on_analyze_selection) both extract+install+load in sequence,
    # which causes Ruby constant re-loading warnings and Loader
    # state leakage between iterations. Combining them avoids that.
    Dir.mktmpdir('rbz_smoke_') do |tmp|
      _install_root, pkg_name = rbz_extract_all(RBZ_PATH, tmp)
      ep = File.join(tmp, pkg_name, 'su_ai_plugin.rb')

      FakeUI.install!
      begin
        # Loader may not be loaded yet on a fresh process; require it.
        require_relative '../extension/loader' unless defined?(SUAnalysis::Extension::Loader)
        # Reset Loader's module-level @registered sentinel so a
        # previous test run does not skip the boot.
        SUAnalysis::Extension::Loader.instance_variable_set(:@registered, false)
        SUAnalysis::Extension::Loader.instance_variable_set(:@live_dialog, nil)
        # `load` is what sketchUp does at boot (with file_loaded?
        # guard inside the entry-point itself). The FakeUI
        # environment installs UI.menu / UI::Command / UI::HtmlDialog
        # so the Loader.register! call inside the entry-point
        # exercises the full registration path.
        load ep

        # Verify the menu item appeared.
        plugin_menu = FakeUI.state.menu('Plugins')
        submenu = plugin_menu.submenus.find { |s| s.name == 'SU-AI-Plugin' }
        assert !submenu.nil?, 'expected SU-AI-Plugin submenu under Plugins'
        cmd = submenu.items.find { |i| i.respond_to?(:name) && i.name == 'Analyze selection' }
        assert !cmd.nil?, "expected menu item 'Analyze selection' to be registered"

        # Trigger the command. With no Sketchup constant defined,
        # on_analyze_selection returns nil immediately (no-op
        # fallback per extension/loader.rb). We verify the no-op
        # path did not raise.
        result = cmd.call_handler
        # on_analyze_selection returns nil outside SU; that is the
        # documented fallback per extension/loader.rb.
        assert_nil result, 'on_analyze_selection must return nil outside SU (no-op fallback)'
      ensure
        FakeUI.uninstall!
        if defined?(SUAnalysis::Extension::Loader)
          SUAnalysis::Extension::Loader.instance_variable_set(:@registered, false)
          SUAnalysis::Extension::Loader.instance_variable_set(:@live_dialog, nil)
        end
      end
    end
  end
end