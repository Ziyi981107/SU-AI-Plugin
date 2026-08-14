# frozen_string_literal: true

#
# tests/run_all.rb — entry point for the synthetic test set.
#
# Run all:
#   ruby tests/run_all.rb
#
# Run a subset (substring match on test name):
#   ruby tests/run_all.rb TC-06
#
# Exit code: 0 if all PASS, 1 otherwise.
#

require_relative 'runner'

# Auto-load every test_*.rb in lexical order.
test_files = Dir[File.expand_path('test_*.rb', __dir__)].sort
raise 'no test files found' if test_files.empty?
test_files.each { |f| load f }

result = Tests.run!(ARGV[0])
exit(result)
