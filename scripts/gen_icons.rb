#
# scripts/gen_icons.rb — deterministic PNG icon generator for the
# V1.9A3 native toolbar button.
#
# Per AIPM Blueprint V1.9A3 §7 (Icons):
#   - local only (no internet);
#   - PNG, exact pixel dimensions 24x24 / 32x32;
#   - blue-violet identity matching V1.9A UI;
#   - simple white CAD/polyline/loop motif;
#   - no tiny text;
#   - transparent background around the icon artwork.
#
# The motif: a blue-violet rounded square containing a white
# polyline/loop glyph. Legible at 24px.
#
# Usage:
#   ruby scripts/gen_icons.rb
# Writes:
#   extension/su_ai_plugin/icons/cad_prep_24.png
#   extension/su_ai_plugin/icons/cad_prep_32.png
#

require 'zlib'
require 'fileutils'

module SUAnalysis
  module Scripts
    module GenIcons
      module_function

      OUT_DIR = File.expand_path(
        '../extension/su_ai_plugin/icons', __dir__
      )

      # Brand colors (rgba 0..255). Background of the rounded square.
      BG_R = 0x5B
      BG_G = 0x4F
      BG_B = 0xE0
      BG_A = 0xFF

      # Foreground (glyph stroke). White at full opacity.
      FG_R = 0xFF
      FG_G = 0xFF
      FG_B = 0xFF
      FG_A = 0xFF

      # Soft edge for the rounded square (anti-aliasing hint). Kept
      # narrow to keep the icon crisp at 24px.
      EDGE_R = 0x3A
      EDGE_G = 0x32
      EDGE_B = 0x9B
      EDGE_A = 0xFF

      def run
        FileUtils.mkdir_p(OUT_DIR)
        write_png(24, File.join(OUT_DIR, 'cad_prep_24.png'))
        write_png(32, File.join(OUT_DIR, 'cad_prep_32.png'))
        $stdout.puts("OK: wrote #{OUT_DIR}/cad_prep_24.png")
        $stdout.puts("OK: wrote #{OUT_DIR}/cad_prep_32.png")
      end

      # Build an N x N RGBA pixel buffer for the icon, then encode
      # it as a PNG (filter type 0 / None per scanline, deflate
      # compression).
      def build_pixels(size)
        pixels = Array.new(size) { Array.new(size) { [0, 0, 0, 0] } }

        # Geometry (in icon-space coords, scaled by `size`):
        # - rounded square: corner_radius = 0.22 * size;
        # - glyph: a 3-segment polyline forming a closed loop
        #   inside the inner area (mimics CAD region/loop motif).
        radius = (size * 0.22).round
        # Inner square bounds (the rounded square outline).
        margin = ((size - 1) * 0.05).round.clamp(0, size - 2)
        inner_left   = margin
        inner_right  = size - 1 - margin
        inner_top    = margin
        inner_bottom = size - 1 - margin

        # 1) Fill the rounded square background.
        (0..(size - 1)).each do |y|
          (0..(size - 1)).each do |x|
            next if x < inner_left || x > inner_right
            next if y < inner_top || y > inner_bottom
            inside = rounded_inside?(x, y, inner_left, inner_top,
                                     inner_right, inner_bottom, radius)
            if inside == :core
              pixels[y][x] = [BG_R, BG_G, BG_B, BG_A]
            elsif inside == :edge
              pixels[y][x] = [EDGE_R, EDGE_G, EDGE_B, EDGE_A]
            end
          end
        end

        # 2) Draw the white polyline / loop glyph.
        #    Five points forming a small closed loop with a "tail"
        #    — evocative of CAD polylines and region boundaries.
        #    Coordinates are in icon-pixel space (integer).
        #    Designed to read clearly at 24px.
        glyph_thickness = [(size * 0.10).round, 1].max
        # Inset the glyph slightly inside the rounded square.
        inset = [(size * 0.18).round, 2].max
        ax = inset
        ay = inset
        bx = size - 1 - inset
        by = inset
        cx = size - 1 - inset
        cy = size - 1 - inset
        dx = inset
        dy = size - 1 - inset

        # Closing edge back to (ax, ay) — closed loop.
        draw_segment(pixels, size, ax, ay, bx, by, glyph_thickness)
        draw_segment(pixels, size, bx, by, cx, cy, glyph_thickness)
        draw_segment(pixels, size, cx, cy, dx, dy, glyph_thickness)
        draw_segment(pixels, size, dx, dy, ax, ay, glyph_thickness)
        # Diagonal "node" mark from top-left to bottom-right
        # reinforces the polyline identity without text.
        draw_segment(pixels, size, ax, ay, cx, cy, glyph_thickness)

        pixels
      end

      # Determine whether a point is inside the rounded square.
      # Returns :core (deep inside), :edge (within 1px of the
      # outline), or nil (outside).
      def rounded_inside?(x, y, left, top, right, bottom, radius)
        return nil if x < left || x > right || y < top || y > bottom
        # Corner regions.
        corners = [
          [left + radius,     top + radius],
          [right - radius,    top + radius],
          [right - radius,    bottom - radius],
          [left + radius,     bottom - radius]
        ]
        if (x <= left + radius && y <= top + radius) ||
           (x >= right - radius && y <= top + radius) ||
           (x >= right - radius && y >= bottom - radius) ||
           (x <= left + radius && y >= bottom - radius)
          cx, cy = corners.find do |ccx, ccy|
            (x <= left + radius && y <= top + radius && ccx == left + radius && ccy == top + radius) ||
              (x >= right - radius && y <= top + radius && ccx == right - radius && ccy == top + radius) ||
              (x >= right - radius && y >= bottom - radius && ccx == right - radius && ccy == bottom - radius) ||
              (x <= left + radius && y >= bottom - radius && ccx == left + radius && ccy == bottom - radius)
          end
          dx = x - cx
          dy = y - cy
          d2 = (dx * dx) + (dy * dy)
          r2 = radius * radius
          if d2 <= r2
            if d2 >= (radius - 1) * (radius - 1)
              :edge
            else
              :core
            end
          else
            nil
          end
        else
          # On the straight edges (top, bottom, left, right) we
          # mark the outermost ring as :edge for crispness.
          on_outer_ring =
            (x == left || x == right || y == top || y == bottom)
          on_outer_ring ? :edge : :core
        end
      end

      # Bresenham-style line draw with stroke thickness.
      def draw_segment(pixels, size, x0, y0, x1, y1, thickness)
        dx = (x1 - x0).abs
        dy = -(y1 - y0).abs
        sx = x0 < x1 ? 1 : -1
        sy = y0 < y1 ? 1 : -1
        err = dx + dy
        cx = x0
        cy = y0
        loop do
          stamp(pixels, size, cx, cy, thickness)
          break if cx == x1 && cy == y1
          e2 = 2 * err
          if e2 >= dy
            err += dy
            cx += sx
          end
          if e2 <= dx
            err += dx
            cy += sy
          end
        end
      end

      def stamp(pixels, size, x, y, thickness)
        r = (thickness - 1) / 2
        (-r..r).each do |dy|
          (-r..r).each do |dx|
            xx = x + dx
            yy = y + dy
            next if xx < 0 || yy < 0 || xx >= size || yy >= size
            # Circular stamp (smooths the square stamp into a dot).
            next if (dx * dx) + (dy * dy) > r * r + r
            pixels[yy][xx] = [FG_R, FG_G, FG_B, FG_A]
          end
        end
      end

      # Encode an N x N RGBA pixel buffer to a PNG file using the
      # minimal chunk set: IHDR + IDAT + IEND. Each scanline is
      # prefixed with a filter-type byte (0 = None). The IDAT is
      # deflate-compressed via Zlib.
      def write_png(size, path)
        pixels = build_pixels(size)
        raw = ''.force_encoding(Encoding::ASCII_8BIT)
        pixels.each do |row|
          raw << [0].pack('C') # filter type: None
          row.each do |rgba|
            raw << rgba.pack('C4')
          end
        end
        compressed = Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION)

        File.open(path, 'wb') do |io|
          io.set_encoding(Encoding::ASCII_8BIT)
          # PNG signature.
          io.write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack('C8'))
          # IHDR.
          io.write(chunk('IHDR', [size, size, 8, 6, 0, 0, 0].pack('NNCCCCC')))
          # IDAT.
          io.write(chunk('IDAT', compressed))
          # IEND.
          io.write(chunk('IEND', ''.dup))
        end
      end

      def chunk(type, data)
        bytes = type.to_s.dup.force_encoding(Encoding::ASCII_8BIT)
        payload = data.dup.force_encoding(Encoding::ASCII_8BIT)
        length = payload.bytesize
        crc_input = bytes + payload
        crc = Zlib.crc32(crc_input)
        [length].pack('N') + bytes + payload + [crc].pack('N')
      end
    end
  end
end

SUAnalysis::Scripts::GenIcons.run if __FILE__ == $PROGRAM_NAME
