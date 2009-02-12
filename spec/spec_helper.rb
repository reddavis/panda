require 'rubygems'
require 'merb-core'
require 'spec' # Satiates Autotest and anyone else not using the Rake tasks

require 'simplerdb/server'
require 'aws_sdb'

Merb.start_environment(:testing => true, :adapter => 'runner', :environment => ENV['MERB_ENV'] || 'test')

db_config =  File.open('config/database.yml'){|yf| YAML::load(yf)}[:test]
if db_config[:adapter] == 'simpledb'
  # Start up in memory simplerdb for testing. This is only used if you set up 
  # simpledb with these settings in database.yml.
  # Check for @server first or it tries to start many copies.
  @server || begin
    @server = SimplerDB::Server.new(8087)
    @thread = Thread.new { @server.start }
  end
end

Panda::Setup.create_sdb_domain

Spec::Runner.configure do |config|
  config.include(Merb::Test::ViewHelper)
  config.include(Merb::Test::RouteHelper)
  config.include(Merb::Test::ControllerHelper)
end
