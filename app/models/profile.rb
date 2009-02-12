class Profile
  include DataMapper::Resource
  
  property :id, UUIDIndex, :key => true
  property :title, String
  property :player, String
  property :container, String
  property :width, Integer
  property :height, Integer
  property :video_codec, String
  property :video_bitrate, String
  property :fps, Integer
  property :audio_codec,String 
  property :audio_bitrate, String
  property :audio_sample_rate, String
  property :position, Integer
  property :updated_at, Time
  property :created_at, Time
  
  def self.warn_if_no_encodings
    if Profile.all.empty?
      Merb.logger.info "PANDA CONFIG ERROR: There are no encoding profiles. You probably forgot to define them. Please see the getting started guide."
    end
  rescue
    # Datamapper should raise a consistent error if the domain/table does not 
    # exist. It doesn't. So rescue everything.
    Merb.logger.info "PANDA WARNING: Profile domain/table does not exist. Please check that you have created all the required domains/tables (see the getting started guide)."
  end
end
