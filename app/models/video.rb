class Video
  include DataMapper::Resource
  include LocalStore
  
  property :id, UUIDIndex, :key => true
  property :filename, String
  property :original_filename, String
  property :parent, String
  property :status, String
  property :duration, Integer
  property :container, String
  property :width, Integer
  property :height, Integer
  property :video_codec, String
  property :video_bitrate, String
  property :fps, Integer
  property :audio_codec,String 
  property :audio_bitrate, String
  property :audio_sample_rate, String
  property :profile, String
  property :profile_title, String
  property :player, String
  property :queued_at, Time
  property :started_encoding_at, Time
  property :encoding_time, String
  property :encoded_at, String
  property :last_notification_at, Time
  # This is to fill the gap of different behavior between MySQL
  # and SimpleDB in use of null.
  # At MySQL, it won't pick up NULL: eg, notification.not 'success'
  # If you try to search non nil: eg, notification.not = nil
  # Then SimpleDB fails as Simpledb can not be searchable by nil
  # As a workaround, I forced default as empty string
  property :notification, String, :default => '', :nullable => false
  property :updated_at, Time
  property :created_at, Time
  property :thumbnail_position, String
  
  # TODO: state machine for status
  # An original video can either be 'empty' if it hasn't had the video file uploaded, or 'original' if it has
  # An encoding will have it's original attribute set to the key of the original parent, and a status of 'queued', 'processing', 'success', or 'error'
  
  def self.create_empty
    video = Video.new
    video.status = 'empty'
    video.save
    
    return video
  end
  
  def clipping(position = nil)
    Clipping.new(self, position)
  end
  
  def clippings
    self.thumbnail_percentages.map do |p|
      Clipping.new(self, p)
    end
  end
  
  # Classification
  # ==============
  
  def encoding?
    ['queued', 'processing', 'success', 'error'].include?(self.status)
  end
  
  def parent?
    ['original', 'empty'].include?(self.status)
  end
  
  # Finders
  # =======
  
  # Original videos sorted by creation date (newest first)
  def self.all_originals
    # This fails with simpledb adaptor (sort order is random it seems)
    # self.all(:status => "original", :order => [:created_at.desc])
    
    self.all(:status => "original").sort_by { |o| o.created_at }.reverse
  end
  
  def self.queued_encodings
    self.all(:status => 'queued') + self.all(:status => "processing")
    
    # TODO: Doesn't work
    # self.all(:status => ['queued', 'processing'])
  end
  
  def self.next_job
    # TODO: Doesn't work
    # self.first(:status => "queued")
    
    self.all(:status => "queued").sort_by { |o| o.created_at }.first
  end
  
  def self.outstanding_notifications
    # TODO: Do this in one query
    self.all(:notification.not => "success", :notification.not => "error", :status => "success") +
    self.all(:notification.not => "success", :notification.not => "error", :status => "error") 
  end
  
  def parent_video
    self.class.get(self.parent)
  end
  
  def encodings
    self.class.all(:parent => self.id)
  end
  
  def successful_encodings
    self.class.all(:parent => self.id, :status => "success")
  end
  
  def find_encoding_for_profile(p)
    self.class.all(:parent => self.id, :profile => p.id)
  end
  
  # Attr helpers
  # ============
  
  # Delete an original video and all it's encodings.
  def obliterate!
    # TODO: should this raise an exception if the file does not exist?
    self.delete_from_store
    self.encodings.each do |e|
      e.delete_from_store
      e.destroy
    end
    self.destroy
  end

  # Location to store video file fetched from S3 for encoding
  def tmp_filepath
    private_filepath(self.filename)
  end
  
  # Has the actual video file been uploaded for encoding?
  def empty?
    self.status == 'empty'
  end
  
  def upload_redirect_url
    Panda::Config[:upload_redirect_url].gsub(/\$id/, self.id)
  end
  
  def state_update_url
    Panda::Config[:state_update_url].gsub(/\$id/, self.id)
  end
  
  def duration_str
    s = (self.duration.to_i || 0) / 1000
    "#{sprintf("%02d", s/60)}:#{sprintf("%02d", s%60)}"
  end
  
  def resolution
    self.width ? "#{self.width}x#{self.height}" : nil
  end
  
  def video_bitrate_in_bits
    self.video_bitrate.to_i * 1024
  end
  
  def audio_bitrate_in_bits
    self.audio_bitrate.to_i * 1024
  end
  
  # Encding attr helpers
  # ====================
  
  def url
    Store.url(self.filename)
  end
  
  def embed_html
    return nil unless self.encoding?
    %(<embed src="#{Store.url('flvplayer.swf')}" width="#{self.width}" height="#{self.height}" allowfullscreen="true" allowscriptaccess="always" flashvars="&displayheight=#{self.height}&file=#{self.url}&width=#{self.width}&height=#{self.height}&image=#{self.clipping.url(:screenshot)}" />)
  end
  
  def embed_js
    return nil unless self.encoding?
  	%(
  	<div id="flash_container_#{self.id[0..4]}"><a href="http://www.macromedia.com/go/getflashplayer">Get the latest Flash Player</a> to watch this video.</div>
  	<script type="text/javascript">
      var flashvars = {};
      
      flashvars.file = "#{self.url}";
      flashvars.image = "#{self.clipping.url(:screenshot)}";
      flashvars.width = "#{self.width}";
      flashvars.height = "#{self.height}";
      flashvars.fullscreen = "true";
      flashvars.controlbar = "over";
      var params = {wmode:"transparent",allowfullscreen:"true"};
      var attributes = {};
      attributes.align = "top";
      swfobject.embedSWF("#{Store.url('player.swf')}", "flash_container_#{self.id[0..4]}", "#{self.width}", "#{self.height}", "9.0.115", "#{Store.url('expressInstall.swf')}", flashvars, params, attributes);
  	</script>
  	)
	end
  
  # Interaction with store
  # ======================
  
  def upload_to_store
    Store.set(self.filename, self.tmp_filepath)
  end
  
  def fetch_from_store
    Store.get(self.filename, self.tmp_filepath)
  end
  
  # Deletes the video file without raising an exception if the file does 
  # not exist.
  def delete_from_store
    Store.delete(self.filename)
    self.clippings.each { |c| c.delete_from_store }
    Store.delete(self.clipping.filename(:screenshot, :default => true))
    Store.delete(self.clipping.filename(:thumbnail, :default => true))
  rescue AbstractStore::FileDoesNotExistError
    false
  end
  
  # Returns configured number of 'middle points', for example [25,50,75]
  def thumbnail_percentages
    n = Panda::Config[:choose_thumbnail]
    
    return [50] if n == false
    
    # Interval length
    interval = 100.0 / (n + 1)
    # Points is [0,25,50,75,100] for example
    points = (0..(n + 1)).map { |p| p * interval }.map { |p| p.to_i }
    
    # Don't include the end points
    return points[1..-2]
  end
  
  def generate_thumbnail_selection
    self.thumbnail_percentages.each do |percentage|
      self.clipping(percentage).capture
      self.clipping(percentage).resize
    end
  end
  
  def upload_thumbnail_selection
    self.thumbnail_percentages.each do |percentage|
      self.clipping(percentage).upload_to_store
      self.clipping(percentage).delete_locally
    end
  end
  
  # Checks that video can accept new file, checks that the video is valid, 
  # reads some metadata from it, and moves video into a private tmp location.
  # 
  # File is the tempfile object supplied by merb. It looks like
  # {
  #   "content_type"=>"video/mp4", 
  #   "size"=>100, 
  #   "tempfile" => @tempfile, 
  #   "filename" => "file.mov"
  # }
  # 
  def initial_processing(file)
    raise NoFileSubmitted if !file || file.blank?
    raise NotValid unless self.empty?
    
    # Set filename and original filename
    self.filename = self.id + File.extname(file[:filename])
    # Split out any directory path Windows adds in
    self.original_filename = file[:filename].split("\\\\").last
    
    # Move file into tmp location
    FileUtils.mv file[:tempfile].path, self.tmp_filepath
    
    self.read_metadata
    self.status = "original"
    self.save
  end
  
  # Uploads video to store, generates thumbnails if required, cleans up 
  # temporary file, and adds encodings to the encoding queue.
  # 
  def finish_processing_and_queue_encodings
    self.upload_to_store
    
    # Generate thumbnails before we add to encoding queue
    self.generate_thumbnail_selection
    self.clipping(self.thumbnail_percentages.first).set_as_default
    self.upload_thumbnail_selection
    
    self.thumbnail_position = self.thumbnail_percentages.first
    self.save
    
    self.add_to_queue
    
    FileUtils.rm self.tmp_filepath
  end
  
  # Reads information about the video into attributes.
  # 
  # Raises FormatNotRecognised if the video is not valid
  # 
  def read_metadata
    Merb.logger.info "#{self.id}: Reading metadata of video file"
    
    inspector = RVideo::Inspector.new(:file => self.tmp_filepath)
    
    raise FormatNotRecognised unless inspector.valid? and inspector.video?
    
    self.duration = (inspector.duration rescue nil)
    self.container = (inspector.container rescue nil)
    self.width = (inspector.width rescue nil)
    self.height = (inspector.height rescue nil)
    
    self.video_codec = (inspector.video_codec rescue nil)
    self.video_bitrate = (inspector.bitrate rescue nil)
    self.fps = (inspector.fps rescue nil)
    
    self.audio_codec = (inspector.audio_codec rescue nil)
    self.audio_sample_rate = (inspector.audio_sample_rate rescue nil)
    
    # Don't allow videos with a duration of 0
    raise FormatNotRecognised if self.duration == 0
  end
  
  def create_encoding_for_profile(p)
    encoding = Video.new
    encoding.status = 'queued'
    encoding.filename = "#{encoding.id}.#{p.container}"
    
    # Attrs from the parent video
    encoding.parent = self.id
    [:original_filename, :duration].each do |k|
      encoding.send("#{k}=", self.attribute_get(k))
    end
    
    # Attrs from the profile
    encoding.profile = p.id
    encoding.profile_title = p.title
    [:container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_bitrate, :audio_sample_rate, :player].each do |k|
      encoding.send("#{k}=", p.attribute_get(k))
    end
    
    encoding.save
    return encoding
  end
  
  # TODO: Breakout Profile adding into a different method
  def add_to_queue
    # Die if there aren't any profiles
    if Profile.all.empty?
      Merb.logger.error "There are no encoding profiles!"
      return nil
    end
    
    # TODO: Allow manual selection of encoding profiles used in both form and api
    # For now we will just encode to all available profiles
    Profile.all.each do |p|
      if self.find_encoding_for_profile(p).empty?
        self.create_encoding_for_profile(p)
      end
    end
    return true
  end
  
  # Exceptions
  
  class VideoError < StandardError; end
  class NotificationError < StandardError; end
  
  # 404
  class NotValid < VideoError; end
  
  # 500
  class NoFileSubmitted < VideoError; end
  class FormatNotRecognised < VideoError; end
  
  # API
  # ===
  
  # Hash of paramenters for video and encodings when video.xml/yaml requested.
  # 
  # See the specs for an example of what this returns
  # 
  def show_response
    r = {
      :video => {
<<<<<<< HEAD:app/models/video.rb
        :id => self.key,
=======
        :id => self.id,
>>>>>>> newbamboo/dm:app/models/video.rb
        :status => self.status
      }
    }
    
    # Common attributes for originals and encodings
    if self.status == 'original' or self.encoding?
      [:filename, :original_filename, :width, :height, :duration].each do |k|
        r[:video][k] = self.send(k)
      end
      r[:video][:screenshot]  = self.clipping.filename(:screenshot)
      r[:video][:thumbnail]   = self.clipping.filename(:thumbnail)
    end
    
    # If the video is a parent, also return the data for all its encodings
    if self.status == 'original'
      r[:video][:encodings] = self.encodings.map {|e| e.show_response}
    end
    
    # Reutrn extra attributes if the video is an encoding
    if self.encoding?
      r[:video].merge! \
        [:parent, :profile, :profile_title, :encoded_at, :encoding_time].
          map_to_hash { |k| {k => self.send(k)} }
    end
    
    return r
  end
  
  def create_response
    {:video => {
        :id => self.id
      }
    }
  end
  
  # Notifications
  # =============
  
  def notification_wait_period
    (Panda::Config[:notification_frequency] * self.notification.to_i)
  end
  
  def time_to_send_notification?
    return true if self.last_notification_at.nil?
    Time.now > (self.last_notification_at + self.notification_wait_period)
  end
  
  def send_notification
    raise "You can only send the status of encodings" unless self.encoding?
    
    self.last_notification_at = Time.now
    begin
      self.parent_video.send_status_update_to_client
      self.notification = 'success'
      self.save
      Merb.logger.info "Notification successfull"
    rescue
      # Increment num retries
      if self.notification.to_i >= Panda::Config[:notification_retries]
        self.notification = 'error'
      else
        self.notification = self.notification.to_i + 1
      end
      self.save
      raise
    end
  end
  
  def send_status_update_to_client
    Merb.logger.info "Sending notification to #{self.state_update_url}"
    
    params = {"video" => self.show_response.to_yaml}
    
    uri = URI.parse(self.state_update_url)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Post.new(uri.path)
    if uri.user and uri.password
     req.basic_auth uri.user, uri.password
    end
    req.form_data = params
    response = http.request(req)
    
    unless response.code.to_i == 200# and response.body.match /ok/
      ErrorSender.log_and_email("notification error", "Error sending notification for parent video #{self.id} to #{self.state_update_url} (POST)

REQUEST PARAMS
#{"="*60}\n#{params.to_yaml}\n#{"="*60}

RESPONSE
#{response.code} #{response.message} (#{response.body.length})
#{"="*60}\n#{response.body}\n#{"="*60}")
      
      raise NotificationError
    end
  end
  
  # Encoding
  # ========
  
  def ffmpeg_resolution_and_padding
    # Calculate resolution and any padding
    in_w = self.parent_video.width.to_f
    in_h = self.parent_video.height.to_f
    out_w = self.width.to_f
    out_h = self.height.to_f

    begin
      aspect = in_w / in_h
    rescue
      Merb.logger.error "Couldn't do w/h to caculate aspect. Just using the output resolution now."
      return %(-s #{self.width}x#{self.height})
    end

    height = (out_w / aspect.to_f).to_i
    height -= 1 if height % 2 == 1

    opts_string = %(-s #{self.width}x#{height} )

    # Crop top and bottom is the video is too tall, but add top and bottom bars if it's too wide (aspect wise)
    if height > out_h
      crop = ((height.to_f - out_h) / 2.0).to_i
      crop -= 1 if crop % 2 == 1
      opts_string += %(-croptop #{crop} -cropbottom #{crop})
    elsif height < out_h
      pad = ((out_h - height.to_f) / 2.0).to_i
      pad -= 1 if pad % 2 == 1
      opts_string += %(-padtop #{pad} -padbottom #{pad})
    end

    return opts_string
  end
  
  def ffmpeg_resolution_and_padding_no_cropping
    # Calculate resolution and any padding
    in_w = self.parent_video.width.to_f
    in_h = self.parent_video.height.to_f
    out_w = self.width.to_f
    out_h = self.height.to_f

    begin
      aspect = in_w / in_h
      aspect_inv = in_h / in_w
    rescue
      Merb.logger.error "Couldn't do w/h to caculate aspect. Just using the output resolution now."
      return %(-s #{self.width}x#{self.height} )
    end

    height = (out_w / aspect.to_f).to_i
    height -= 1 if height % 2 == 1

    opts_string = %(-s #{self.width}x#{height} )

    # Keep the video's original width if the height
    if height > out_h
      width = (out_h / aspect_inv.to_f).to_i
      width -= 1 if width % 2 == 1

      opts_string = %(-s #{width}x#{self.height} )
      self.width = width
      self.save
    # Otherwise letterbox it
    elsif height < out_h
      pad = ((out_h - height.to_f) / 2.0).to_i
      pad -= 1 if pad % 2 == 1
      opts_string += %(-padtop #{pad} -padbottom #{pad})
    end

    return opts_string
  end
  
  def recipe_options(input_file, output_file)
    {
      :input_file => input_file,
      :output_file => output_file,
      :container => self.container, 
      :video_codec => self.video_codec,
      :video_bitrate_in_bits => self.video_bitrate_in_bits.to_s, 
      :fps => self.fps,
      :audio_codec => self.audio_codec.to_s, 
      :audio_bitrate => self.audio_bitrate.to_s, 
      :audio_bitrate_in_bits => self.audio_bitrate_in_bits.to_s, 
      :audio_sample_rate => self.audio_sample_rate.to_s, 
      :resolution => self.resolution,
      :resolution_and_padding => self.ffmpeg_resolution_and_padding_no_cropping
    }
  end
  
  def encode_flv_flash
    Merb.logger.info "Encoding with encode_flv_flash"
    transcoder = RVideo::Transcoder.new
    recipe = "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate_in_bits$ -r 24 $resolution_and_padding$ -y $output_file$"
    recipe += "\nflvtool2 -U $output_file$"
    transcoder.execute(recipe, self.recipe_options(self.parent_video.tmp_filepath, self.tmp_filepath))
  end
  
  def encode_mp4_aac_flash
    Merb.logger.info "Encoding with encode_mp4_aac_flash"
    transcoder = RVideo::Transcoder.new
    recipe = "ffmpeg -i $input_file$ -acodec libfaac -ar 48000 -ab $audio_bitrate$k -ac 2 -b $video_bitrate_in_bits$ -vcodec libx264 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 $resolution_and_padding$ -r 24 -threads 4 -y $output_file$"
    transcoder.execute(recipe, self.recipe_options(self.parent_video.tmp_filepath, self.tmp_filepath))
  end
  
  def encode_unknown_format
    Merb.logger.info "Encoding with encode_unknown_format"
    transcoder = RVideo::Transcoder.new
    recipe = "ffmpeg -i $input_file$ -f $container$ -vcodec $video_codec$ -b $video_bitrate_in_bits$ -ar $audio_sample_rate$ -ab $audio_bitrate$k -acodec $audio_codec$ -r 24 $resolution_and_padding$ -y $output_file$"
    Merb.logger.info "Unknown encoding format given but trying to encode anyway."
    transcoder.execute(recipe, recipe_options(self.parent_video.tmp_filepath, self.tmp_filepath))
  end
  
  def encode
    raise "You can only encode encodings" unless self.encoding?
    self.status = "processing"
    self.save
    
    begun_encoding = Time.now
    
    begin
      encoding = self
      parent_obj = self.parent_video
      Merb.logger.info "(#{Time.now.to_s}) Encoding #{self.id}"
    
      parent_obj.fetch_from_store

      if self.container == "flv" and self.player == "flash"
        self.encode_flv_flash
      elsif self.container == "mp4" and self.audio_codec == "aac" and self.player == "flash"
        self.encode_mp4_aac_flash
      else # Try straight ffmpeg encode
        self.encode_unknown_format
      end
      
      self.upload_to_store
      self.generate_thumbnail_selection
      self.clipping.set_as_default
      self.upload_thumbnail_selection
      
      self.notification = 0
      self.status = "success"
      self.encoded_at = Time.now
      self.encoding_time = (Time.now - begun_encoding).to_i
      self.save

      Merb.logger.info "Removing tmp video files"
      FileUtils.rm self.tmp_filepath
      FileUtils.rm parent_obj.tmp_filepath
      
      Merb.logger.info "Encoding successful"
    rescue
      self.notification = 0
      self.status = "error"
      self.save
      FileUtils.rm parent_obj.tmp_filepath
      
      Merb.logger.error "Unable to transcode file #{self.id}: #{$!.class} - #{$!.message}"
        
      raise
    end
  end

end
