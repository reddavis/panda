require 'rubygems'
require 'uuid'

module DataMapper
  module Types
    class UUIDIndex < DataMapper::Type
      primitive String
      unique true
      size 36
      default lambda { 
        UUID.respond_to?(:generate) ? UUID.generate : UUID.new
      }
    end # class UUID
  end # module Types
end # module DataMapper
