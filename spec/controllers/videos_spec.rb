require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')

# describe "Videos Controller", "index action" do
#   before(:each) do
#     @controller = Videos.build(fake_request)
#     @controller.dispatch('index')
#   end
#   
#   it "should return video details in yaml" do
# 
#   end
# end
# 
# describe Videos, "show action" do
#   before(:each) do
#     # @controller = Videos.build(fake_request)
#     # @controller[:params][:id] = "123"
#     # @controller.dispatch('show')
#   end
#   
#   it "should return video details in yaml" do
#       # controller.stub!(:render)
#       # puts body.to_yaml
#       # puts status
#       # puts headers
#       # puts controller.instance_variables
#     video = Video.create
#     Video.should_receive(:find_by_token).with(video.token)
#     get("/videos/#{video.token}.yaml")
#     # puts controller.inspect
#     # puts response.inspect
#     # status.should == 404
#     controller.should be_success
#     # puts @controller.methods.sort
#   end
# end

describe Videos, "form action" do
  before(:each) do
    @video = Video.new
    @video.id = 'abc'
  end
  
  it "should return a nice error when the video can't be found" do
    Video.should_receive(:get).with('qrs').
      and_raise(DataMapper::ObjectNotFoundError)
    @c = get("/videos/qrs/form")
    @c.body.should match(/ObjectNotFoundError/)
  end
end

describe Videos, "upload action" do
  before(:each) do
    @video = mock(Video, {
      :key => "abc", 
      :filename => "abc.avi", 
      :upload_redirect_url => "http://localhost:4000/videos/abc/done"
    })
    
    @video_upload_url = "/videos/abc/upload.html"
    @video_upload_params = {
      :file => File.open(File.join( File.dirname(__FILE__), "video.avi"))
    }
    
    Video.stub!(:get).with("abc").and_return(@video)
    
    @video.stub!(:initial_processing)
  end
  
  it "should run initial processing" do
    @video.should_receive(:initial_processing)
    multipart_post(@video_upload_url, @video_upload_params) do |c|
      c.stub!(:render_then_call)
    end
  end
  
  it "should redirect (via iframe hack)" do
    multipart_post(@video_upload_url, @video_upload_params) do |c|
      c.should_receive(:render_then_call).with("<textarea>{\"location\": \"http://localhost:4000/videos/abc/done\"}</textarea>")
      c.should be_successful
    end
  end
  
  it "should run finish_processing_and_queue_encodings after response" do
    pending
    # TODO: How can we test what's called in a render_then_call block
  end
    
  # Video::NotValid / 404
  
  it "should return 404 when processing fails with Video::NotValid" do 
    @video.should_receive(:initial_processing).and_raise(Video::NotValid)
    @c = multipart_post(@video_upload_url, @video_upload_params)
    @c.body.should match(/NotValid/)
    @c.status.should == 404
  end
  
  # DataMapper::ObjectNotFoundError

  it "should raise RecordNotFoundError and return 404 when no record is found in SimpleDB" do 
    Video.stub!(:get).with("abc").and_raise(DataMapper::ObjectNotFoundError)
    @c = multipart_post(@video_upload_url, @video_upload_params)
    @c.body.should match(/ObjectNotFoundError/)
    @c.status.should == 404
  end
  
  # Videos::NoFileSubmitted
  
  it "should raise Video::NoFileSubmitted and return 500 if no file parameter is posted" do
    @video.should_receive(:initial_processing).with(nil).
      and_raise(Video::NoFileSubmitted)
    @c = post(@video_upload_url)
    @c.body.should match(/NoFileSubmitted/)
    @c.status.should == 500
  end
  
  # InternalServerError
  
  it "should raise InternalServerError and return 500 if an unknown exception is raised" do
    Video.stub!(:get).with("abc").and_raise(RuntimeError)
    @c = multipart_post(@video_upload_url, @video_upload_params)
    @c.body.should match(/InternalServerError/)
    @c.status.should == 500
  end

  it "should log error message, but do not display to user if an unkown exception is raised" do
    Video.stub!(:get).with("abc").and_raise(RuntimeError)
    Merb.logger.should_receive(:error).with(/RuntimeError/)
    @c = multipart_post(@video_upload_url, @video_upload_params)
    @c.body.should_not match(/RuntimeError/)
  end
  
  # Test iframe=true option with InternalServerError
  
  it "should return error json inside a <textarea> if iframe option is set" do
    Video.stub!(:get).with("abc").and_raise(RuntimeError)
    @c = multipart_post(@video_upload_url, @video_upload_params.merge({:iframe => true}))
    @c.body.should == %(<textarea>{"error": "InternalServerError"}</textarea>)
    @c.status.should == 500
  end
end
