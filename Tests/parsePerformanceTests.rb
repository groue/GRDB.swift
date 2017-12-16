#!/usr/bin/env ruby
gem 'json'
require 'json'

tests = {}
STDIN.each do |line|
  if line =~ /\.([^ ]*) ([^ ]*)\]' measured \[Time, seconds\] average: ([\d.]+)/
    class_name = $1
    test_name = $2
    time = $3
    tests[class_name] ||= {}
    tests[class_name][test_name] = time.to_f
  end
end

puts tests.to_json
