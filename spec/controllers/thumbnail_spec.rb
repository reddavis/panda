require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')

describe Thumbnail do
  
  before :each do
    @video = mock(Video)
    @video.stub!(:filename).and_return('')
    @video.stub!(:key).and_return('123')
    Video.stub!(:get).with(@video.filename).and_return(@video)
    @clipping = mock(Clipping)
    @clipping.stub!(:changeable?).and_return(true)
    @video.stub!(:clipping).and_return(@clipping)
  end

  describe "edit action" do
    it "should provide video thumbnails with various positions " do
      @video.should_receive(:thumbnail_percentages)
      dispatch_to(Thumbnail, :edit, :video_id => @video.filename ) do | c |
        c.stub!(:render)
        c.stub!(:require_login).and_return(true)
      end.should be_successful
    end
    
    it "should not allow access if the clipping cannot be changed" do
      @clipping.should_receive(:changeable?).and_return(false)
      
      dispatch_to(Thumbnail, :edit, :video_id => @video.filename ) do | c |
        c.stub!(:require_login).and_return(true)
      end.body.should == 'Thumbnail cannot be changed'
    end
  end
  
  describe "update action" do
    before(:each) do
      @video.stub!(:thumbnail_position=)
      @video.stub!(:save)
      @clipping.stub!(:set_as_default)
      
      @enc_clipping = mock(Clipping)
      @enc_clipping.stub!(:set_as_default)
      @encoding = mock(Video)
      @encoding.stub!(:clipping).and_return(@enc_clipping)
      @video.stub!(:successful_encodings).and_return([@encoding])
    end
    
    # after :each do
    #   # Wait for the run later block!
    #   sleep 0.2
    # end
    
    it "should update thumbnail position" do
      pending
      @video.should_receive(:thumbnail_position=)
      @video.should_receive(:save)
      
      dispatch
    end

    it "should upload clipping to store (for video and encodings)" do
      pending
      @clipping.should_receive(:set_as_default)
      @enc_clipping.should_receive(:set_as_default)
      
      dispatch
    end
    
    it "should redirect to video page" do
      dispatch.headers["Location"].should match(/[#{url(:video, @video.key)}]/)
    end
    
    def dispatch
      dispatch_to(Thumbnail, 
                  :update, 
                  :video_id => @video.filename, 
                  :percentage => 50 ) do |c|
        c.stub!(:render)
        c.stub!(:require_login).and_return(true)
      end
    end
  end
  
end
