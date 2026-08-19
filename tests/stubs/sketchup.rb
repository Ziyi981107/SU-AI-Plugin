#
# tests/stubs/sketchup.rb — test stub for the SketchUp Ruby API.
#
# Per CodeX Review 023 BLOCK-023-001 / 002: the root registration
# loader does `require 'sketchup.rb'` (the standard SketchUp
# extension pattern). In a real SU environment, sketchup.rb is
# provided by the SU install. In the test env we provide a
# minimal stub that:
#   - defines the `Sketchup` module (so `defined?(Sketchup)` is true)
#   - does NOT define `SketchupExtension` (so the loader's
#     `if defined?(SketchupExtension)` guard stays correct)
#
# tests/stubs/extensions.rb defines `SketchupExtension` for tests
# that want to exercise the full registration path.
#
# The test runner puts tests/stubs on $LOAD_PATH via
# $LOAD_PATH.unshift so `require 'sketchup.rb'` resolves here.
#

module Sketchup
end
