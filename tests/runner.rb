# frozen_string_literal: true

#
# tests/runner.rb — tiny dependency-free test framework for SU-AI-Plugin.
#
# Usage:
#   require_relative 'runner'    # provides Tests module + global helpers
#   test 'something' do
#     assert ...
#   end
#   Tests.run!                   # (or Tests.run!('pattern') to filter)
#
# Lives in tests/ so that core/ stays SketchUp-importable (a SketchUp
# extension will not load tests/runner.rb by accident).
#

module Tests
  class AssertionError < StandardError; end

  class TestResult
    attr_reader :name, :status, :message

    def initialize(name, status, message = nil)
      @name    = name
      @status  = status
      @message = message
    end

    def passed?;  @status == :pass;  end
    def failed?;  @status == :fail;  end
    def errored?; @status == :error; end
  end

  class TestCase
    attr_reader :name

    def initialize(name, &block)
      @name  = name
      @block = block
    end

    def run
      instance_eval(&@block)
      TestResult.new(@name, :pass)
    rescue AssertionError => e
      TestResult.new(@name, :fail, e.message)
    rescue StandardError => e
      bt = (e.backtrace || []).first(3).join("\n        ")
      TestResult.new(@name, :error, "#{e.class}: #{e.message}\n        #{bt}")
    end
  end

  def self.cases
    @cases ||= []
  end

  def self.test(name, &block)
    cases << TestCase.new(name, &block)
  end

  def self.assert(cond, msg = 'assertion failed')
    raise AssertionError, msg unless cond
  end

  def self.assert_equal(expected, actual, msg = nil)
    return if expected == actual
    raise AssertionError, msg || "expected #{expected.inspect}, got #{actual.inspect}"
  end

  def self.assert_in_delta(expected, actual, delta, msg = nil)
    diff = (expected - actual).abs
    return if diff <= delta
    raise AssertionError, msg || "expected #{expected} ± #{delta}, got #{actual} (diff #{diff})"
  end

  def self.assert_empty(coll, msg = nil)
    return if coll.respond_to?(:empty?) && coll.empty?
    raise AssertionError, msg || "expected empty, got #{coll.inspect}"
  end

  def self.assert_raises(klass, msg = nil)
    yield
    raise AssertionError, msg || "expected #{klass} to be raised"
  rescue klass
    nil
  end
end

# Top-level helpers usable inside `test 'name' do ... end` blocks.
def assert(*a, &b);        Tests.assert(*a, &b);        end
def assert_equal(*a, &b);  Tests.assert_equal(*a, &b);  end
def assert_in_delta(*a, &b); Tests.assert_in_delta(*a, &b); end
def assert_empty(*a, &b);  Tests.assert_empty(*a, &b);  end
def assert_raises(*a, &b); Tests.assert_raises(*a, &b); end
def test(*a, &b);          Tests.test(*a, &b);          end
