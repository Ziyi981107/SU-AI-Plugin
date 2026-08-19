#
# tests/stubs/extensions.rb — test stub for the SketchUp
# SketchupExtension class.
#
# Per CodeX Review 023 BLOCK-023-001: the standard SketchUp
# extension pattern uses `require 'extensions.rb'` to load the
# SketchupExtension class. In a real SU environment, this file is
# provided by the SU install. In the test env we provide a
# minimal stub that:
#   - defines a `SketchupExtension` class
#   - type-validates the constructor's `path` argument (MUST be
#     a String per the SU API; passing an Array is a contract
#     violation that the CodeX BLOCK-023-001 recheck must catch)
#   - records every constructor call so tests can assert the
#     registration contract (target string, name, etc.)
#
# tests/stubs/extensions.rb + tests/stubs/sketchup.rb together
# simulate the SU Ruby API surface that the registration loader
# requires. The test runner puts tests/stubs on $LOAD_PATH so
# `require 'sketchup.rb'` and `require 'extensions.rb'` from
# the loader resolve to these stubs.
#
# The real SU API contract is:
#   - `SketchupExtension.new(name, path)` where `path` is a
#     String (NOT an Array).
#   - `Sketchup.register_extension(extension, load_now)` is
#     called once per extension to register it with the EM.
#
# To distinguish from a fake (where the class just records),
# the stub raises on a contract violation (Array, nil, etc.)
# so test failures pinpoint the exact BLOCK-023-001 / 002 issue.
#

# Track every SketchupExtension construction + every
# Sketchup.register_extension call so tests can assert the
# exact registration contract (name, target path, call count).
$__fake_sketchup_extension_constructs = []
$__fake_sketchup_register_extension_calls = []

# A type-validating stub of the real SketchupExtension class.
# Per the SU Ruby API contract (https://developer.sketchup.com/article-creating-a-sketchup-extension):
#   - `name`: String (extension display name, also matches folder
#     base name per the standard contract).
#   - `path`: String (relative path to the main file, WITHOUT
#     the `.rb` extension, so SU can resolve either `.rb` or
#     encrypted formats).
class SketchupExtension
  attr_reader :name, :path

  def initialize(name, path)
    unless name.is_a?(String) && !name.empty?
      raise TypeError, "SketchupExtension.new(name, path): name must be a non-empty String, got #{name.inspect}"
    end
    unless path.is_a?(String) && !path.empty?
      # Per CodeX 023 BLOCK-023-001: passing an Array to the
      # second arg is a SU API contract violation. We fail loudly
      # so the test catches it.
      raise TypeError, "SketchupExtension.new(name, path): path must be a non-empty String (NOT an Array), got #{path.inspect}"
    end
    @name = name
    @path = path
    $__fake_sketchup_extension_constructs << { name: name, path: path }
  end
end

# Extend the Sketchup module (from tests/stubs/sketchup.rb) with
# the real-API-shaped register_extension. This second-arg is
# `load_now` (Boolean); the SU EM respects it to immediately
# load the registered file target.
module Sketchup
  def self.register_extension(extension, load_now)
    unless extension.is_a?(SketchupExtension)
      raise TypeError, "Sketchup.register_extension(ext, load_now): ext must be a SketchupExtension, got #{extension.inspect}"
    end
    unless [true, false].include?(load_now)
      raise TypeError, "Sketchup.register_extension(ext, load_now): load_now must be a Boolean, got #{load_now.inspect}"
    end
    $__fake_sketchup_register_extension_calls << {
      extension: extension,
      load_now: load_now
    }
    true
  end
end
