
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

  def self.assert_nil(value, msg = nil)
    return if value.nil?
    raise AssertionError, msg || "expected nil, got #{value.inspect}"
  end

  def self.refute_nil(value, msg = nil)
    return unless value.nil?
    raise AssertionError, msg || 'expected non-nil value, got nil'
  end

  def self.assert_operator(a, op, b, msg = nil)
    ok =
      case op
      when :==  then a == b
      when :!=  then a != b
      when :>   then a > b
      when :>=  then a >= b
      when :<   then a < b
      when :<=  then a <= b
      else raise ArgumentError, "assert_operator: unsupported op #{op.inspect}"
      end
    raise AssertionError, msg || "expected #{a.inspect} #{op} #{b.inspect}" unless ok
  end

  def self.refute_match(pattern, str, msg = nil)
    return unless str.is_a?(String)
    return unless pattern.is_a?(Regexp)
    return unless str.match(pattern)
    raise AssertionError, msg || "expected string NOT to match #{pattern.inspect}, but it did"
  end

  def self.assert_match(pattern, str, msg = nil)
    return unless str.is_a?(String)
    return unless pattern.is_a?(Regexp)
    return if str.match(pattern)
    raise AssertionError, msg || "expected string to match #{pattern.inspect}, got #{str.inspect[0,80]}"
  end

  def self.refute_equal(a, b, msg = nil)
    return if a != b
    raise AssertionError, msg || "expected #{a.inspect} != #{b.inspect}"
  end

  # Execute all collected test cases, print a summary, and return
  # 0 if everything passed, 1 otherwise. Accepts an optional substring
  # filter on test name (e.g. Tests.run!('TC-06')).
  def self.run!(filter = nil)
    selected = cases
    if filter && !filter.to_s.empty?
      needle = filter.to_s
      selected = selected.select { |c| c.name.include?(needle) }
      raise "no tests matched #{needle.inspect}" if selected.empty?
    end

    results = selected.map(&:run)
    passed  = results.count(&:passed?)
    failed  = results.count(&:failed?)
    errored = results.count(&:errored?)

    # Per-test lines so failures / errors are immediately readable.
    results.each do |r|
      tag = case r.status
            when :pass  then 'PASS '
            when :fail  then 'FAIL '
            when :error then 'ERROR'
            end
      line = "#{tag}  #{r.name}"
      line << "\n        #{r.message}" unless r.passed?
      puts line
    end

    summary = "--- #{results.size} tests: " \
              "#{passed} pass, #{failed} fail, #{errored} error ---"
    puts summary
    results.all?(&:passed?) ? 0 : 1
  end
end

# Top-level helpers usable inside `test 'name' do ... end` blocks.
def assert(*a, &b);        Tests.assert(*a, &b);        end
def assert_equal(*a, &b);  Tests.assert_equal(*a, &b);  end
def assert_in_delta(*a, &b); Tests.assert_in_delta(*a, &b); end
def assert_empty(*a, &b);  Tests.assert_empty(*a, &b);  end
def assert_raises(*a, &b); Tests.assert_raises(*a, &b); end
def assert_nil(*a, &b);    Tests.assert_nil(*a, &b);    end
def refute_nil(*a, &b);    Tests.refute_nil(*a, &b);    end
def assert_operator(*a, &b); Tests.assert_operator(*a, &b); end
def refute_match(*a, &b);  Tests.refute_match(*a, &b);  end
def assert_match(*a, &b);  Tests.assert_match(*a, &b);  end
def refute_equal(*a, &b); Tests.refute_equal(*a, &b); end
def test(*a, &b);          Tests.test(*a, &b);          end
