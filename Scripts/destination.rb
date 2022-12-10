#!/usr/bin/env ruby
gem 'json'
require 'json'
require 'optparse'

samples = JSON.parse(STDIN.read)

samples['devices'].each do |key, devices|
  next unless key =~ /^com\.apple\.CoreSimulator\.SimRuntime\.([^-]*)-(.*)$/
  platform = $1
  version = $2.gsub('-', '.')
  devices.each do |device|
    puts "#{version} #{platform} #{device["udid"]} #{device["name"]}"
  end
end
