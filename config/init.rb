# Go to http://wiki.merbivore.com/pages/init-rb

# Autoload from lib
$LOAD_PATH.unshift(Merb.root / "lib")
Merb.push_path(:lib, Merb.root / "lib") # uses **/*.rb as path glob.

require 'config/dependencies.rb'
 
use_orm :datamapper
use_test :rspec
use_template_engine :erb
 
Merb::Config.use do |c|
  c[:use_mutex] = false
  
  c[:session_id_key] = 'panda'
  c[:session_secret_key]  = '4d5e9b90d9e92c236a2300d718059aef3a9b9cbe'
  c[:session_store] = 'cookie'
end
 
Merb::BootLoader.before_app_loads do
  # This will get executed after dependencies have been loaded but before your app's classes have loaded.
  
  # Load Panda config
  require "config" / "panda_init"
  
  # Check panda config
  Panda::Config.check
  
  require 'data_mapper/types/uuid_index'
end
 
Merb::BootLoader.after_app_loads do
  # This will get executed after your app's classes have been loaded.
  
  require "config" / "aws"
  
  unless Merb.environment =~ /test/
    require "config" / "mailer" if Panda::Config[:notification_email]
  end
  
  Store = case Panda::Config[:videos_store]
  when :s3
    S3Store.new
  when :filesystem
    FileStore.new
  else
    raise RuntimeError, "You have specified an invalid videos_store configuration option. Valid options are :s3 and :filesystem"
  end
  
  LocalStore.ensure_directories_exist
  
  Profile.warn_if_no_encodings unless Merb.env =~ /test/
end
