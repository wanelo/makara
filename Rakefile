#!/usr/bin/env rake
require 'rake'
require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/*_spec.rb'
end
task :default => :spec

namespace :spec do
  desc "Run the tests against the abstract, mysql2, and postgresql ActiveRecord adapters"
  task :all => ['spec', 'spec:mysql', 'spec:postgres']

  desc "Run the tests against a Mysql database"
  task :mysql do
    puts "Testing against Mysql..."
    ENV['MAKARA_ADAPTER'] = 'mysql2'
    ENV['MAKARA_PORT'] ||= ENV['BOXEN_MYSQL_PORT']
    Rake::Task[:spec].reenable
    Rake::Task[:spec].invoke
    ENV['MAKARA_ADAPTER'] = nil
    ENV['MAKARA_PORT'] = nil
  end

  desc "Run the tests against a PostgreSQL database"
  task :postgres do
    puts "Testing against Postgres..."
    ENV['MAKARA_ADAPTER'] = 'postgresql'
    ENV['MAKARA_PORT'] ||= ENV['BOXEN_POSTGRESQL_PORT']
    Rake::Task[:spec].reenable
    Rake::Task[:spec].invoke
    ENV['MAKARA_ADAPTER'] = nil
    ENV['MAKARA_PORT'] = nil
  end
end