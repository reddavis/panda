module Panda
  class ConfigError < RuntimeError; end
  
  class Setup
    class << self
      def create_s3_bucket
        S3Store.create_bucket
      end
      
      def create_sdb_domain
        if DataMapper::Adapters.const_defined?(:SimpleDBAdapter) && DataMapper.repository.adapter.is_a?(DataMapper::Adapters::SimpleDBAdapter)
          SDB_CONNECTION.create_domain(Panda::Config[:sdb_domain])
        else
          DataMapper.auto_migrate!
        end
      end
      
      # API compatibility
      alias :create_sdb_domains :create_sdb_domain
    end
  end

  class Config
    class << self
      def defaults
        @defaults ||= {
          :account_name           => "My Panda Account",
          
          :private_tmp_path       => Merb.root / "videos",
          :public_tmp_path        => Merb.root / "public" / "tmp",
          :public_tmp_url         => "/tmp",
          
          :thumbnail_height_constrain => 125,
          :choose_thumbnail       => false,
          
          :notification_retries   => 6,
          :notification_frequency => 10,
          
          :sdb_base_url           => "http://sdb.amazonaws.com/"
        }
      end
      
      def use
        @configuration ||= {}
        yield @configuration
      end

      def [](key)
        @configuration[key] || defaults[key]
      end
      
      def []=(key,val)
        @configuration[key] = val
      end
      
      def check
        check_present(:api_key, "Please specify a secret api_key")
        check_present(:upload_redirect_url)
        check_present(:state_update_url)
        
        %w{sdb_domain}.each do |d|
          check_present(d.to_sym)
        end
      end
      
      def check_present(option, message = nil)
        unless Panda::Config[option]
          m = "Missing required configuration option: #{option.to_s}"
          m += " [#{message}]" if message
          raise Panda::ConfigError, m
        end
      end
    end
  end
end