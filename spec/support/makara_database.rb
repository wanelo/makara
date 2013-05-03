require 'active_support/hash_with_indifferent_access'
require 'active_record'
require 'active_record/migration'

module MakaraDatabase
  class Migrator < ActiveRecord::Migration
    def up
      create_table(:users) { |t| t.string :name }
      create_table(:people) { |t| t.string :name }
    end
  end

  extend self

  def config
    @config ||= begin
      config = HashWithIndifferentAccess.new(
        'database' => "makara_test",
        'adapter' => ENV['MAKARA_ADAPTER'],
        'host' => "127.0.0.1"
      )
      ENV['MAKARA_PORT'] ? config.merge('port' => ENV['MAKARA_PORT'].to_i) : config
    end
  end

  def create
    case config['adapter']
    when nil
      return
    when /postgresql/
      ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
      ActiveRecord::Base.connection.create_database(config['database'], config.merge('encoding' => 'utf8'))
    when /mysql/
      ActiveRecord::Base.establish_connection(config.merge('database' => nil))
      ActiveRecord::Base.connection.create_database(config['database'], :charset => 'utf8', :collation => 'utf8_unicode_ci')
    end

    ActiveRecord::Base.establish_connection(config)
    Migrator.new.migrate(:up)
    ActiveRecord::Base.clear_all_connections!
  rescue => e
    raise e unless e.message.match(/(already|database) exists/)
  end

  def drop
    ActiveRecord::Base.clear_all_connections!

    case config['adapter']
    when nil
      return
    when /mysql/
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.drop_database config['database']
    when /postgresql/
      ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
      ActiveRecord::Base.connection.drop_database config['database']
    end
  end

end