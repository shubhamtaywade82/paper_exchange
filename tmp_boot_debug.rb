module Kernel
  alias_method :orig_require, :require
  def require(path)
    result = orig_require(path)
    puts "REQUIRED: #{path}" if path.to_s.include?('DhanHQ') || path.to_s.include?('dhanhq')
    result
  rescue LoadError => e
    puts "FAILED: #{path} -> #{e.message}" if path.to_s.include?('DhanHQ') || path.to_s.include?('dhanhq')
    raise
  end
end
require_relative 'config/environment'
puts '--- After environment load ---'
puts "DhanHQ const: #{defined?(DhanHQ)}"
if defined?(DhanHQ)
  puts "DhanHQ.constants #{DhanHQ.constants.sort.first(10).inspect}"
  puts "defined Constants #{defined?(DhanHQ::Constants)}"
end
