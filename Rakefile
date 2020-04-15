#!/usr/bin/env rake
# frozen_string_literal: true

require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new(:spec)

task :rubocop do
  puts "rubocop"
  rubocop_output = `rubocop -a app lib test`
  print rubocop_output
  unless rubocop_output.match(/files inspected, no offenses detected/)
    exit 1
  end
end

task default: [:spec, :rubocop]