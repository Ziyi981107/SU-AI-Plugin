#
# scripts/build_rbz.rb — build a release-candidate .rbz file for the
# SU-AI-Plugin SketchUp extension.
#
# Per CodeX Review 021 (2026-08-19) Stage 7 implementation report:
#   - Implementation COMPLETE (Stage 6 Owner PASS on SU2020).
#   - NOT PASS FOR RELEASE — two release gates remain:
#     (1) SU2017 real-host verification (Owner executes).
#     (2) RBZ package + install smoke verification (this script
#         builds the candidate; the install smoke test lives in
#         tests/test_rbz_smoke.rb).
#
# Per PI_TASK_001 §14 + AGENT.md §3 implementation boundaries:
#   - No new analyzers, repair actions, overlays, source-model
#     mutation, settings UI, or scope expansion.
#   - Do NOT reopen passed Stage 6 code.
#   - This script writes ONLY a release-candidate package; it
#     does not touch any production .rb, .js, .css, .html file.
#
# Layout:
#   The .rbz is a standard ZIP (PKZip) archive containing ONE
#   top-level folder. Per the SketchUp Extension Manager
#   convention, the folder name matches the entry-point file
#   name (sans .rb extension). The entry-point file MUST sit at
#   the root of that folder so SketchUp auto-registers it.
#
#   The dev tree has the entry-point at:
#     extension/su_ai_plugin.rb
#   Inside the .rbz the entry-point MUST be at:
#     su_ai_plugin/su_ai_plugin.rb
#   so that the `require_relative '../compatibility/su_capability'`
#   paths inside the entry-point resolve correctly.
#
# Excluded paths (dev-only, never shipped):
#   tests/, scripts/, Review/, Prompt/, AGENT.md, README.md,
#   CURRENT_STATE.md, .vendor/, .git/, .gitignore, .pi/, .codex/,
#   node_modules/, *.log, build artifacts.
#
# Usage:
#   .vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe scripts/build_rbz.rb
#
# Output:
#   dist/SU-AI-Plugin.rbz
#

require 'zlib'
require 'fileutils'

module SUAnalysis
  module Scripts
    module BuildRbz
      module_function

      # ---- Config ----

      PROJECT_ROOT = File.expand_path('..', __dir__)
      DIST_DIR     = File.join(PROJECT_ROOT, 'dist')
      OUTPUT_NAME  = 'SU-AI-Plugin.rbz'
      OUTPUT_PATH  = File.join(DIST_DIR, OUTPUT_NAME)
      PKG_NAME     = 'su_ai_plugin'

      # Source directories whose contents are SHIPPED (relative to
      # PROJECT_ROOT).
      #
      # The .rbz layout MUST preserve the entry-point's locked
      # `require_relative` paths (e.g. `require_relative
      # '../compatibility/...'`). Those paths are relative to the
      # entry-point's PARENT directory (Plugins/su_ai_plugin/),
      # so `../compatibility/` resolves to Plugins/compatibility/.
      # Therefore the package MUST place `core/` and
      # `compatibility/` as SIBLINGS of the `su_ai_plugin/`
      # package folder, not as children of it.
      #
      # Final layout inside the .rbz:
      #   su_ai_plugin/
      #     su_ai_plugin.rb       (entry-point, at root)
      #     loader.rb             (sibling of entry)
      #     preflight_runner.rb
      #     analyzers_runner.rb
      #     ...
      #     html/
      #       index.html
      #       app.js
      #       style.css
      #   core/                   ( sibling of su_ai_plugin/ )
      #     tolerance.rb
      #     ...
      #     analyzers/
      #       ...
      #   compatibility/          ( sibling of su_ai_plugin/ )
      #     su_capability.rb
      #
      # After SketchUp extracts into Plugins/:
      #   Plugins/su_ai_plugin/su_ai_plugin.rb  -> require_relative
      #     '../core/...' resolves to Plugins/core/... ✓
      #     '../compatibility/...' resolves to Plugins/compatibility/... ✓
      #
      # Shipping policy:
      #   - extension/  is FLATTENED: only its direct .rb siblings of
      #     the entry-point land at the package root. extension/html/*
      #     lands at su_ai_plugin/html/*.
      #   - core/ and compatibility/  are PRESERVED at the package
      #     ROOT (NOT inside su_ai_plugin/) — they are siblings of
      #     the package folder so the entry-point's ../-style
      #     require_relative paths resolve correctly.
      SHIPPED_DIRS = {
        'extension'     => :flatten_root,    # entry siblings -> pkg root
        'core'          => :sibling_at_root, # core/ -> pkg root (sibling)
        'compatibility' => :sibling_at_root  # compatibility/ -> pkg root (sibling)
      }.freeze

      # Single files at the extension/ root that must ship alongside
      # the entry-point. (extension/su_ai_plugin.rb is the entry-point;
      # SHIPPED_DIRS above handles all other extension/ siblings.)
      SHIPPED_FILES = %w[extension/su_ai_plugin.rb].freeze

      # Top-level entries that are NEVER shipped (dev-only).
      EXCLUDED_TOP_LEVEL = %w[
        tests scripts Review Prompt AGENT.md README.md CURRENT_STATE.md
        .vendor .git .gitignore .pi .codex .minimax dist .ses node_modules
        data
      ].freeze

      # ---- Public entry ----

      def run
        FileUtils.mkdir_p(DIST_DIR)
        files = collect_files
        abort_with "no files collected" if files.empty?
        # NOTE: `collect_files` already prefixes each entry with
        # PKG_NAME (the SketchUp package top-level folder). Do NOT
        # re-prefix here, or you end up with double-prefixed paths
        # like `su_ai_plugin/su_ai_plugin/<file>`.
        write_zip(OUTPUT_PATH, files)
        report(OUTPUT_PATH, files)
      end

      # Collect (relative_path_inside_pkg, absolute_source_path) for
      # every file that should ship. The relative path uses forward
      # slashes (ZIP convention) and is rooted at PKG_NAME.
      def collect_files
        files = []
        # 1) Whole directories (with flatten/preserve policy). The
        #    entry-point file (extension/su_ai_plugin.rb) is INSIDE
        #    SHIPPED_DIRS['extension'] so it is picked up by the
        #    walk; SHIPPED_FILES is empty below to avoid duplicates.
        SHIPPED_DIRS.each do |dir, policy|
          abs_dir = File.join(PROJECT_ROOT, dir)
          unless File.directory?(abs_dir)
            abort_with "missing shipped directory: #{dir}"
          end
          walk_dir(abs_dir, dir, policy, files)
        end
        # 2) Stand-alone shipped files (none currently; reserved for
        #    future use).
        SHIPPED_FILES.each do |rel|
          abs = File.join(PROJECT_ROOT, rel)
          unless File.file?(abs)
            abort_with "missing shipped file: #{rel}"
          end
          arc = strip_dev_prefix(rel)
          files << [File.join(PKG_NAME, arc), abs]
        end
        # Dedupe (the entry-point could appear via both paths).
        files = files.uniq { |arc, _abs| arc }
        files.sort_by(&:first)
      end

      # Walk a source directory and add every file to the manifest
      # with the correct arcname based on the directory's policy.
      def walk_dir(abs_root, rel_root, policy, files)
        Dir.glob(File.join(abs_root, '**', '*'), File::FNM_DOTMATCH).each do |abs|
          next if abs == abs_root
          next if File.directory?(abs) # only files
          base = File.basename(abs)
          next if base == '.' || base == '..'
          # rel within the source dir (just the tail after abs_root).
          rel = abs.sub(/\A#{Regexp.escape(abs_root)}/, '').gsub(%r{\A[\\/]}, '')
          arc = case policy
                when :flatten_root
                  # `extension` is FLATTENED at the package ROOT:
                  # extension/foo.rb      -> su_ai_plugin/foo.rb
                  # extension/html/x.html -> su_ai_plugin/html/x.html
                  # (we ALWAYS drop the `extension/` prefix; the rest
                  # of the path is preserved.)
                  File.join(PKG_NAME, rel)
                when :sibling_at_root
                  # `core` and `compatibility` are SIBLINGS of the
                  # package folder, not children of it:
                  # core/foo.rb -> core/foo.rb
                  File.join(rel_root, rel)
                else
                  abort_with "unknown policy #{policy.inspect} for #{rel_root}"
                end
          files << [arc, abs]
        end
      end

      # Drop the "extension/" prefix when constructing the arcname,
      # so the entry-point and its siblings land at the root of
      # the .rbz top-level folder.
      def strip_dev_prefix(rel)
        if rel.start_with?('extension/')
          rel.sub(/\Aextension\//, '')
        else
          rel
        end
      end

      def to_zip_path(rel)
        rel.gsub(File::SEPARATOR, '/')
      end

      # ---- Pure-Ruby ZIP writer (STORE method, no compression) ----
      # The .rbz format is a standard ZIP (PKZip). SketchUp's
      # Extension Manager accepts STORE or DEFLATE entries. We use
      # STORE for simplicity (the package is small; build time matters
      # more than size). Zlib is used only for CRC-32.

      LOCAL_HEADER_SIG    = 0x04034b50
      CENTRAL_DIR_SIG     = 0x02014b50
      END_OF_CENTRAL_SIG  = 0x06054b50
      VERSION_NEEDED      = 20

      def write_zip(path, manifest)
        File.open(path, 'wb') do |io|
          io.set_encoding(Encoding::ASCII_8BIT)
          entries = []
          manifest.each do |arc_name, src_path|
            data = File.binread(src_path)
            crc  = Zlib.crc32(data)
            size = data.bytesize
            local_offset = io.pos
            write_local_header(io, arc_name, crc, size)
            io.write(data)
            entries << {
              name:        arc_name,
              crc:         crc,
              size:        size,
              local_offset: local_offset
            }
          end
          # Central directory.
          cd_offset = io.pos
          cd_size   = 0
          entries.each do |e|
            cd_size += write_central_header(io, e)
          end
          # End of central directory record.
          write_eocd(io, entries.length, cd_size, cd_offset)
        end
      end

      def write_local_header(io, name, crc, size)
        io.write([LOCAL_HEADER_SIG].pack('V'))
        io.write([VERSION_NEEDED, 0, 0, 0, 0].pack('vvvvv')) # ver, flag, method, time, date
        io.write([crc, size, size].pack('VVV'))
        name_bytes = name.encode(Encoding::ASCII_8BIT)
        io.write([name_bytes.bytesize, 0].pack('vv'))
        io.write(name_bytes)
      end

      def write_central_header(io, entry)
        start = io.pos
        io.write([CENTRAL_DIR_SIG].pack('V'))
        io.write([VERSION_NEEDED, VERSION_NEEDED, 0, 0, 0, 0].pack('vvvvvv'))
        io.write([entry[:crc], entry[:size], entry[:size]].pack('VVV'))
        name_bytes = entry[:name].encode(Encoding::ASCII_8BIT)
        io.write([name_bytes.bytesize, 0, 0, 0, 0, 0].pack('vvvvvV'))
        io.write([entry[:local_offset]].pack('V'))
        io.write(name_bytes)
        io.pos - start
      end

      def write_eocd(io, num_entries, cd_size, cd_offset)
        io.write([END_OF_CENTRAL_SIG].pack('V'))
        io.write([0, 0, num_entries, num_entries].pack('vvvv'))
        io.write([cd_size, cd_offset].pack('VV'))
        io.write([0].pack('v')) # comment length
      end

      def report(path, files)
        size = File.size(path)
        entry_count = files.length
        $stdout.puts("OK: wrote #{path}")
        $stdout.puts("    size: #{size} bytes")
        $stdout.puts("    entries: #{entry_count}")
        # Spot-check the entry-point layout (must be at PKG root).
        ep_arc = File.join(PKG_NAME, 'su_ai_plugin.rb')
        unless files.any? { |arc, _| arc == ep_arc }
          abort_with "missing entry-point at #{ep_arc}"
        end
        $stdout.puts("    entry-point: #{ep_arc} (OK)")
        $stdout.puts("    top-level folder: #{PKG_NAME}/ (OK)")
      end

      def abort_with(msg)
        $stderr.puts("ERROR: #{msg}")
        exit 1
      end
    end
  end
end

SUAnalysis::Scripts::BuildRbz.run if __FILE__ == $PROGRAM_NAME