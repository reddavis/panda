require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe Video do
  
  before(:all) do
    Panda::Config.use do |p|
      p[:private_tmp_path] = '/tmp'
      p[:state_update_url] = "http://localhost:4000/videos/$id/status"
      p[:upload_redirect_url] = "http://localhost:4000/videos/$id/done"
      p[:videos_domain] = "videos.pandastream.com"
      p[:thumbnail_height_constrain] = 125
    end
  end
  
  before :each do
    @video = mock_video
    @profile = mock_profile(:id => 'profile1')
    
    Store.stub!(:set).and_return(true)
    Store.stub!(:delete).and_return(true)
  end
  
  describe "create_empty" do
    it "should create and save video" do
      lambda { Video.create_empty }.should change { Video.all.size }.by(1)
    end
    
    it "should return the empty video" do
      video = Video.create_empty
      video.should be_empty
    end

  end
  
  describe "clipping" do
    it "should return a clipping" do
      @video.clipping.should be_kind_of(Clipping)
    end
  end
  
  describe "clipping" do
    it "should return an array of clippings for available positions" do
      @video.clippings.should be_kind_of(Array)
      @video.clippings.first.should be_kind_of(Clipping)
    end
  end
  
  # Classification
  # ==============
  
  describe "encoding? or parent?" do
    it "should be encoding if status is queued, processing, success, error" do
      %w{queued processing success error}.each do |status|
        @video.status = status
        @video.parent?.should be_false
        @video.encoding?.should be_true
      end
    end
    
    it "should be parent if status is original, empty" do
      %w{original empty}.each do |status|
        @video.status = status
        @video.parent?.should be_true
        @video.encoding?.should be_false
      end
    end
  end
  
  describe "Finders" do
    before :all do
      @old = Time.now - 100
      @new = Time.now
      create_video(:status => 'original', :created_at => @old)
      create_video(:status => 'original', :created_at => @new)
      create_video(:status => 'pending', :created_at => @new)
      create_video(:status => 'processing', :created_at => @new)
      create_video(:status => 'queued', :created_at => @new)
    end
    
    describe "self.all_originals" do
    
      before(:all) do
        @originals = Video.all_originals
      end
      
      it "should return original video" do
        @originals.each{|r| r.status.should == 'original'}
      end
      
      it "should order by created_at (newest first)" do
        @originals.collect(&:created_at).should == 
          @originals.sort_by { |o| o.created_at }.reverse.collect(&:created_at)
      end
    end

    describe "self.queued_encodings" do
      it "should return videos in processing or queued" do
        queued = Video.queued_encodings 
        queued.each{|q| ['processing', 'queued'].should be_include(q.status)}
      end
    end
    
    describe "outstanding_notifications" do
      it "should not return videos if notification status are set" do
        lambda { 
          create_video(:status => 'success', :notification => 'success')
          create_video(:status => 'error', :notification => 'error')
        }.should_not change { Video.outstanding_notifications.size }
      end
      
      it "should return videos if notification status are empty" do
        lambda { 
          create_video(:status => 'success',:notification => '')
          create_video(:status => 'error', :notification => '')
        }.should change { Video.outstanding_notifications.size }.by(2)
      end

      it "should return videos if notification status are not set" do
        lambda { 
          create_video(:status => 'success')
          create_video(:status => 'error')
        }.should change { Video.outstanding_notifications.size }.by(2)
      end
    end

    describe "next_job" do
      it "shoould return first queued encoding ordered by created date" do
        vid2 = create_video(:status => 'queued', :created_at => 1.days.ago)
        vid1 = create_video(:status => 'queued', :created_at => 2.days.ago)
        Video.next_job.should == vid1
      end
      
      it "should retun nil if there are no queued videos" do
        Video.queued_encodings.each{|q| q.destroy}
        Video.all.size.should > 0
        Video.queued_encodings.size.should == 0
        Video.next_job.should be_nil
      end
    end
    
    describe "parent_video" do
      before(:all) do
        @parent_video = Video.all_originals.first
        @parent_video.save
      end

      it "should raise error if the video itself is parent" do
        lambda { @parent_video.parent_video }.should
         raise_error(RuntimeError, "Parent does not have parent")
      end
      
      it "should return parent video where parent id matches" do
        @video.parent = @parent_video.id
        @video.status = 'queued'
        @video.parent_video.should == @parent_video
      end
    end

    describe "encodings" do
      it "should return all videos which belongs to its parent " do 
        create_encodings(@video.id, @profile, 3)
        @video.encodings.should have(3).videos
      end
    end
    
    describe "successful_encodings" do
      it "should return successful videos which belongs to its parent"  do
        @video.id = UUID.generate
        @video.save
        create_encodings(@video.id, @profile, 3)
        # Manually changing status from "queued" to "success"
        @video.encodings.each{|v| v.status = 'success'; v.save}
        # But leave one encoding as "error".
        # NOTE: Need to convert to array (to_a) to be compatible for simpledb
        error_encording = @video.encodings.to_a.first
        error_encording.status = 'error'
        error_encording.save
        
        @video.successful_encodings.should have(2).videos
      end
    end
  end
  
  # Attr helpers
  # ============
  
  describe "obliterate!" do
    before :each do
      @encoding = Video.new
      @encoding.filename = 'abc.flv'
      
      @video.should_receive(:encodings).and_return([@encoding])
      
      @video.stub!(:destroy)
      @encoding.stub!(:destroy)
    end
    
    it "should delete the original from the store and database" do
      Store.should_receive(:delete).once.with('abc.mov')
      @video.should_receive(:destroy).once
      
      @video.obliterate!
    end
    
    it "should delete all encodings from the store database" do
      Store.should_receive(:delete).once.with('abc.flv')
      @encoding.should_receive(:destroy).once
      
      @video.obliterate!
    end
  end
    
  it "tmp_filepath" do
    @video.should_receive(:private_filepath).with('abc.mov').
      and_return('/tmp/abc.mov')
    
    @video.tmp_filepath.should == '/tmp/abc.mov'
  end

  it "empty?" do
    @video.status = 'empty'
    @video.empty?.should be_true
  end
  
  it "should put video key into update_redirect_url" do
    @video.upload_redirect_url.should == "http://localhost:4000/videos/abc/done"
  end
  
  it "should put video key into state_update_url" do
    @video.state_update_url.should == "http://localhost:4000/videos/abc/status"
  end
  
  it "should return 00:00 duration string for nil duration" do
    @video.duration_str.should == "00:00"
  end
  
  it "should return correct duration string" do
    @video.duration = 5586000
    @video.duration_str.should == "93:06"
  end
  
  it "should return nil resolution if there is no width" do
    @video.width = nil
    @video.resolution.should be_nil
  end
  
  # def set_encoded_at
  
  # Encding attr helpers
  # ====================
  
  it "url" do
    @video.url.should == "http://videos.pandastream.com/abc.mov"
  end
  
  it "should not reutrn embed_html for a parent/original video" do
    @video.status = 'original'
    @video.embed_html.should be_nil
  end
  
  it "embed_html" do
    @video.filename = 'abc.flv'
    @video.width = 320
    @video.height = 240
    @video.status = 'success'
    
    @video.embed_html.should == %(<embed src="http://videos.pandastream.com/flvplayer.swf" width="320" height="240" allowfullscreen="true" allowscriptaccess="always" flashvars="&displayheight=240&file=http://videos.pandastream.com/abc.flv&width=320&height=240&image=http://videos.pandastream.com/abc.flv.jpg" />)
  end
  
  describe "storing and fetching from the store" do
    it "should upload" do
      Store.should_receive(:set).with(@video.filename, @video.tmp_filepath)
      @video.upload_to_store
    end

    it "should fetch" do
      Store.should_receive(:get).with(@video.filename, @video.tmp_filepath)
      @video.fetch_from_store
    end
    
    describe "delete" do
      it "should delete" do
        Store.should_receive(:delete).with(@video.filename)
        @video.delete_from_store
      end
      
      it "should not raise error if delete fails" do
        Store.should_receive(:delete).
          and_raise(AbstractStore::FileDoesNotExistError)
        lambda {
          @video.delete_from_store
        }.should_not raise_error
      end
    end
  end
  
  describe "thumbnail_percentages should generate list of percentages" do
    it "should default to [50] if config option not set" do
      Panda::Config[:choose_thumbnail] = false
      @video.thumbnail_percentages.should == [50]
    end
    
    it "should be [50] if 1 thumbnail" do
      Panda::Config[:choose_thumbnail] = 1
      @video.thumbnail_percentages.should == [50]
    end
    
    it "should be [25, 50, 75] if 3 thumbnails" do
      Panda::Config[:choose_thumbnail] = 3
      @video.thumbnail_percentages.should == [25, 50, 75]
    end
    
    it "should be [20,40,60,80] if 4 thumbnails" do
      Panda::Config[:choose_thumbnail] = 4
      @video.thumbnail_percentages.should == [20,40,60,80]
    end
  end
  
  describe "generate_thumbnail_selection" do
    before :each do
      @clipping = mock(Clipping, :capture => true, :resize => true)
      @video.stub!(:clipping).and_return(@clipping)
      @video.stub!(:thumbnail_percentages).and_return([25,50,75])
    end
    
    it "should capture for each thumbnail options" do
      @clipping.should_receive(:capture).exactly(3).times
      @video.generate_thumbnail_selection
    end
    
    it "should resize for each thumbnail option" do
      @clipping.should_receive(:resize).exactly(3).times
      @video.generate_thumbnail_selection
    end
  end
  
  # Uploads
  # =======
  
  describe "initial_processing" do
    before(:each) do
      @tempfile = mock(File, :filename => "tmpfile", :path => "/tump/tmpfile")
      
      @file = Mash.new({"content_type"=>"video/mp4", "size"=>100, "tempfile" => @tempfile, "filename" => "file.mov"})
      @video.status = 'empty'
      
      FileUtils.stub!(:mv)
      @video.stub!(:read_metadata)
      @video.stub!(:save)
    end
    
    it "should raise NotValid if video is not empty" do
      @video.status = 'original'
      
      lambda {
        @video.initial_processing(@file)
      }.should raise_error(Video::NotValid)
      
      @video.status = 'empty'
      
      lambda {
        @video.initial_processing(@file)
      }.should_not raise_error(Video::NotValid)
    end
    
    it "should set filename and original_filename" do
      @video.should_receive(:id).and_return('1234')
      @video.should_receive(:filename=).with("1234.mov")
      @video.should_receive(:original_filename=).with("file.mov")
      
      @video.initial_processing(@file)
    end
    
    it "should move file to tempoary location" do
      FileUtils.should_receive(:mv).with("/tump/tmpfile", "/tmp/abc.mov")
      
      @video.initial_processing(@file)
    end
    
    it "should read metadata" do
      @video.should_receive(:read_metadata).and_return(true)
      
      @video.initial_processing(@file)
    end
    
    it "should save video" do
      @video.should_receive(:status=).with("original")
      @video.should_receive(:save)
      
      @video.initial_processing(@file)
    end
  end
  
  describe "finish_processing_and_queue_encodings" do
    
    before(:each) do
      @clipping = mock(Clipping, {
        :set_as_default => true, :changeable? => true
      })
      
      @video.status = 'original'
      @video.stub!(:upload_to_store)
      @video.stub!(:generate_thumbnail_selection)
      @video.stub!(:clipping).and_return(@clipping)
      @video.stub!(:upload_thumbnail_selection)
      @video.stub!(:save)
      @video.stub!(:add_to_queue)
      @video.stub!(:tmp_filepath).and_return('tmpfile')
      FileUtils.stub!(:rm)
    end
    
    it "should upload original to store" do
      @video.should_receive(:upload_to_store).and_return(true)
      @video.finish_processing_and_queue_encodings
    end
    
    describe "if clipping can be changed" do
      it "should generate and upload clippings" do
        Panda::Config[:choose_thumbnail] = 2
        @video.should_receive(:generate_thumbnail_selection).and_return(true)
        @video.should_receive(:upload_thumbnail_selection).and_return(true)
        @video.finish_processing_and_queue_encodings
      end
      
      it "should set the default clipping position" do
        @video.should_receive(:thumbnail_position=)
        @video.finish_processing_and_queue_encodings
      end
      
      it "should upload default clipping" do
        @clipping.should_receive(:set_as_default)
        @video.finish_processing_and_queue_encodings
      end
    end
    
    it "should add encodings to queue" do
      @video.should_receive(:add_to_queue).and_return(true)
      @video.finish_processing_and_queue_encodings
    end
    
    it "should clean up original video" do
      FileUtils.should_receive(:rm).and_return(true)
      @video.finish_processing_and_queue_encodings
    end
  end
  
  # def read_metadata
  
  describe "add_to_queue" do
    before(:each) do
      Profile.stub!(:all).and_return([mock_profile(:id => 'profile1')])
    end
    it "should die if profile is empty" do
      Profile.should_receive(:all).and_return([])
      Merb.logger.should_receive(:error).
        with("There are no encoding profiles!")

      @video.should_receive(:find_encoding_for_profile).exactly(0).times
      @video.should_receive(:create_encoding_for_profile).exactly(0).times

      @video.add_to_queue
    end

    it "should call create_encoding_for_profile if find_encoding_for_profile returns empty" do
      @video.should_receive(:find_encoding_for_profile).and_return([])
      @video.should_receive(:create_encoding_for_profile)

      @video.add_to_queue
    end

    it "should not call create_encoding_for_profile if find_encoding_for_profile returns encodings" do
      @video.should_receive(:find_encoding_for_profile).
        and_return([mock_video])
      @video.should_receive(:create_encoding_for_profile).exactly(0).times

      @video.add_to_queue
    end
  end

  describe "find_encoding_for_profile" do
    it "should return parent video with specified profile" do
      Video.should_receive(:all).
        with(:parent => @video.id, :profile => @profile.id)
      @video.find_encoding_for_profile(@profile)
    end
  end

  describe "create_encoding_for_profile" do
    before(:each) do
      # This part is required to prevent accessing database  at encoding.save
      @encoding_video = Video.new
      @encoding_video.stub!(:save)
      Video.stub!(:new).and_return(@encoding_video)
      
      @encoding = @video.create_encoding_for_profile(@profile)
    end
    it "should create queued encoding" do
      @encoding.should be_an_instance_of(Video)
      @encoding.status.should == 'queued'
      @encoding.filename.should == "#{@encoding.id}.#{@profile.container}"
    end

    it "should assign attributes from current video" do
      @encoding.original_filename.should == @video.original_filename
      @encoding.duration.should == @video.duration
    end
    
    it "should assign attributes from profile" do
      @encoding.original_filename.should == @video.original_filename
      @encoding.duration.should == @video.duration
      @encoding.container.should == @profile.container
      @encoding.width.should == @profile.width
      @encoding.height.should == @profile.height
      @encoding.video_codec.should == @profile.video_codec
      @encoding.video_bitrate.should == @profile.video_bitrate
      @encoding.fps.should == @profile.fps
      @encoding.audio_codec.should == @profile.audio_codec
      @encoding.audio_bitrate.should == @profile.audio_bitrate
      @encoding.audio_sample_rate.should == @profile.audio_sample_rate
      @encoding.player.should == @profile.player
    end
  end
  
  describe "show_response" do
    before :each do
      @encoding = Video.new
      @encoding.filename = 'abc.flv'
      @encoding.id = '1234'
      
      @video.stub!(:encodings).and_return([])
    end
    
    it "should contain a hash of parameters for the video" do
      @video.show_response.should == {
        :video => {
          :thumbnail=>"abc.mov_50_thumb.jpg", 
          :height=>360, 
          :filename=>"abc.mov", 
          :screenshot=>"abc.mov_50.jpg", 
          :status=>"original", 
          :duration=>100, 
          :original_filename=>"original_filename.mov", 
          :width=>480, 
          :encodings=> [], 
          :id=>"abc"
        }
      }
    end
    
    it "should contain an array of encodings if defined" do
      @video.stub!(:encodings).and_return([@encoding])
      
      @video.show_response[:video][:encodings].first.should == {
        :video => {
          :status=>nil, 
          :id=>"1234"
        }
      }
    end
  end
<<<<<<< HEAD:spec/models/video_spec.rb
  
  describe "show_response" do
    before :each do
      @encoding = Video.new
      @encoding.filename = 'abc.flv'
      @encoding.key = '1234'
      
      @video.stub!(:encodings).and_return([])
    end
    
    it "should contain a hash of parameters for the video" do
      @video.show_response.should == {
        :video => {
          :thumbnail=>"abc.mov_50_thumb.jpg", 
          :height=>360, 
          :filename=>"abc.mov", 
          :screenshot=>"abc.mov_50.jpg", 
          :status=>"original", 
          :duration=>100, 
          :original_filename=>"original_filename.mov", 
          :width=>480, 
          :encodings=> [], 
          :id=>"abc"
        }
      }
    end
    
    it "should contain an array of encodings if defined" do
      @video.stub!(:encodings).and_return([@encoding])
      
      @video.show_response[:video][:encodings].first.should == {
        :video => {
          :status=>nil, 
          :id=>"1234"
        }
      }
    end
  end
=======
>>>>>>> newbamboo/dm:spec/models/video_spec.rb
  
  it "should return correct API create response hash" do
    @video.create_response.should == {:video => {:id => 'abc'}}
  end
  
  # Notifications
  # =============
  
  it "should return true if the current time is past the encoding's notification wait period" do
    t = Time.now
    encoding = mock_encoding_flv_flash(:last_notification_at => t - 50, :notification => 1)
    # Default notification_frequency is 1 second
    encoding.time_to_send_notification?.should == true
  end
  
  it "should return false if the current time is not past the encoding's notification wait period" do
    t = Time.now
    encoding = mock_encoding_flv_flash(:last_notification_at => t, :notification => 10)
    Panda::Config[:notification_frequency] = 50
    encoding.time_to_send_notification?.should == false
  end
  
  it "should send notification to client" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:send_status_update_to_client)
    
    encoding.should_receive(:last_notification_at=).with(an_instance_of(Time))
    encoding.should_receive(:notification=).with("success")
    encoding.should_receive(:save)
    
    encoding.send_notification
  end
  
  it "should increment notification retry count if sending the notification fails" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:send_status_update_to_client).and_raise(Video::NotificationError)
    
    encoding.should_receive(:last_notification_at=).with(an_instance_of(Time))
    encoding.should_receive(:notification).twice().and_return(1)
    encoding.should_receive(:notification=).with(2)
    encoding.should_receive(:save)
    
    lambda {encoding.send_notification}.should raise_error(Video::NotificationError)
  end
  
  it "should only allow notifications of encodings to be sent" do
    lambda {@video.send_notification}.should raise_error(StandardError)
  end
  
  # Encoding
  # ========
  
  # def ffmpeg_resolution_and_padding(inspector)
  
  it "should constrain video and preserve aspect ratio (no cropping or pillarboxing) if a 4:3 video is encoded with a 16:9 profile" do
    parent_video = mock_video({:width => 640, :height => 480})
    encoding = mock_encoding_flv_flash({:width => 640, :height => 360})
    encoding.should_receive(:parent_video).twice.and_return(parent_video)
    # We also need to then update the encoding's sizing to the new width
    encoding.should_receive(:width=).with(480)
    encoding.should_receive(:save)
    encoding.ffmpeg_resolution_and_padding_no_cropping.should == "-s 480x360 "
  end
  
  it "should constrain video if a 16:9 video is encoded with a 16:9 profile" do
    parent_video = mock_video({:width => 1280, :height => 720})
    encoding = mock_encoding_flv_flash({:width => 640, :height => 360})
    encoding.should_receive(:parent_video).twice.and_return(parent_video)
    encoding.ffmpeg_resolution_and_padding_no_cropping.should == "-s 640x360 "
  end
  
  it "should letterbox if a 2.40:1 (848x352) video is encoded with a 16:9 profile" do
    parent_video = mock_video({:width => 848, :height => 352})
    encoding = mock_encoding_flv_flash({:width => 640, :height => 360})
    encoding.should_receive(:parent_video).twice.and_return(parent_video)
    encoding.ffmpeg_resolution_and_padding_no_cropping.should == "-s 640x264 -padtop 48 -padbottom 48"
  end
  
  it "should return correct recipe_options hash" do
    encoding = mock_encoding_flv_flash
    encoding.should_receive(:parent_video).twice.and_return(@video)
    encoding.recipe_options('/tmp/abc.mov', '/tmp/xyz.flv').should eql_hash(
      {
        :input_file => '/tmp/abc.mov',
        :output_file => '/tmp/xyz.flv',
        :container => 'flv',
        :video_codec => '',
        :video_bitrate_in_bits => (400*1024).to_s, 
        :fps => 24,
        :audio_codec => '', 
        :audio_bitrate => '48', 
        :audio_bitrate_in_bits => (48*1024).to_s, 
        :audio_sample_rate => '', 
        :resolution => '480x360',
        :resolution_and_padding => "-s 480x360 " # encoding.ffmpeg_resolution_and_padding
      }
    )
  end
    
  it "should call encode_flv_flash when encoding an flv for the flash player" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:fetch_from_store)
  
    encoding.should_receive(:status=).with("processing")
    encoding.should_receive(:save).twice
    encoding.should_receive(:encode_flv_flash)
  
    encoding.should_receive(:upload_to_store)
    encoding.should_receive(:generate_thumbnail_selection)
    encoding.should_receive(:upload_thumbnail_selection)
    clipping = returning(mock(Clipping)) do |c|
      c.should_receive(:set_as_default)
    end
    encoding.should_receive(:clipping).and_return(clipping)
    
    encoding.should_receive(:notification=).with(0)
    encoding.should_receive(:status=).with("success")
    encoding.should_receive(:encoded_at=).with(an_instance_of(Time))
    encoding.should_receive(:encoding_time=).with(an_instance_of(Integer))
    # encoding.should_receive(:save) expected twice above
    
    FileUtils.should_receive(:rm).with('/tmp/xyz.flv')
    FileUtils.should_receive(:rm).with('/tmp/abc.mov')
  
    encoding.encode
  end
  
  it "should set the encoding's status to error if the video fails to encode correctly" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:fetch_from_store)
  
    encoding.should_receive(:status=).with("processing")
    encoding.should_receive(:save).twice
    encoding.should_receive(:encode_flv_flash).and_raise(RVideo::TranscoderError)
    encoding.should_receive(:notification=).with(0)
    encoding.should_receive(:status=).with("error")
    # encoding.should_receive(:save) expected twice above
    FileUtils.should_receive(:rm).with('/tmp/abc.mov')
  
    lambda {encoding.encode}.should raise_error(RVideo::TranscoderError)
  end

  it "should run correct ffmpeg command to encode to an flv for the flash player" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    transcoder = mock(RVideo::Transcoder)
    RVideo::Transcoder.should_receive(:new).and_return(transcoder)
    
    transcoder.should_receive(:execute).with(
      "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate_in_bits$ -r 24 $resolution_and_padding$ -y $output_file$\nflvtool2 -U $output_file$", nil)
    encoding.should_receive(:recipe_options).with('/tmp/abc.mov', '/tmp/xyz.flv')
    
    encoding.encode_flv_flash
  end
  
  it "should run correct ffmpeg command to encode to an mp4 for the flash player" do
    encoding = mock_encoding_mp4_aac_flash
    encoding.stub!(:parent_video).and_return(@video)
    transcoder = mock(RVideo::Transcoder)
    RVideo::Transcoder.should_receive(:new).and_return(transcoder)
    
    transcoder.should_receive(:execute).with(
      "ffmpeg -i $input_file$ -acodec libfaac -ar 48000 -ab $audio_bitrate$k -ac 2 -b $video_bitrate_in_bits$ -vcodec libx264 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 $resolution_and_padding$ -r 24 -threads 4 -y $output_file$", nil) # No need to test the 2nd parameter for recepie options which is tested in another test
    encoding.should_receive(:recipe_options).with('/tmp/abc.mov', '/tmp/xyz.mp4')
    
    encoding.encode_mp4_aac_flash
  end
  
  it "should run correct ffmpeg command to encode to an unknown format" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    transcoder = mock(RVideo::Transcoder)
    RVideo::Transcoder.should_receive(:new).and_return(transcoder)
    
    transcoder.should_receive(:execute).with(
      "ffmpeg -i $input_file$ -f $container$ -vcodec $video_codec$ -b $video_bitrate_in_bits$ -ar $audio_sample_rate$ -ab $audio_bitrate$k -acodec $audio_codec$ -r 24 $resolution_and_padding$ -y $output_file$", nil)
    encoding.should_receive(:recipe_options).with('/tmp/abc.mov', '/tmp/xyz.flv')
    
    encoding.encode_unknown_format
  end
  
  private
  
    def mock_profile(attrs={})
      Profile.new(
        {
          :id => 'profile1',
          :title => "Flash video HI", 
          :container => "flv", 
          :video_bitrate => 400, 
          :audio_bitrate => 48, 
          :width => 480, 
          :height => 360, 
          :fps => 24, 
          :position => 1, 
          :player => "flash"
        }.merge(attrs)
      )
    end
  
  def mock_video(attrs={})
    enc = Video.new(
      {
        :id => "abc",
        :status => 'original',
        :filename => 'abc.mov',
        :original_filename => 'original_filename.mov',
        :duration => 100,
        :video_codec => 'mp4',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => 'aac', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }.merge(attrs)
    )
  end
  
  def create_video(attrs = {})
    returning(mock_video(attrs.merge(:id => (UUID.respond_to?(:generate) ? UUID.generate : UUID.new)))) do |vid|
      vid.save
    end
  end
  
  def create_encodings(parent_id, profile, number)
    number.times do
      create_video(:parent => parent_id).create_encoding_for_profile(profile)
    end
  end
  
  def mock_encoding_flv_flash(attrs={})
    enc = Video.new(
      {
        :id => 'xyz',
        :status => 'queued',
        :filename => 'xyz.flv',
        :container => 'flv',
        :player => 'flash',
        :video_codec => '',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => '', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }.merge(attrs)
    )
  end
  
  def mock_encoding_mp4_aac_flash(attrs={})
    enc = Video.new( 
      {
        :id => 'xyz',
        :status => 'queued',
        :filename => 'xyz.mp4',
        :container => 'mp4',
        :player => 'flash',
        :video_codec => '',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => 'aac', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }
    )
  end
  
  def mock_encoding_unknown_format(attrs={})
    enc = Video.new(
      {
        :id => 'xyz',
        :status => 'queued',
        :filename => 'xyz.xxx',
        :container => 'xxx',
        :player => 'someplayer',
        :video_codec => '',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => 'yyy', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }
    )
  end
end