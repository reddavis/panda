class Thumbnail < Application

  before :require_login, :only => [:edit, :update]
  before :get_video
  before :ensure_that_clipping_can_be_changed
  
  # This will be inside an iframe.
  # 
  def new
    @percentages = @video.thumbnail_percentages
    
    render :layout => :uploader
  end
  
  # This will be inside an iframe.
  # 
  # We've come from the upload form and the thumbnail will be generated when 
  # the video is encoded
  # 
  def create
    @video.thumbnail_position = params[:percentage]
    @video.save
    @video.add_to_queue
    
    redirect @video.upload_redirect_url
  end
  
  def edit
    @percentages = @video.thumbnail_percentages
    
    render
  end
  
  # HQ
  # 
  # The video is already encoded and we're changing its thumbnail
  # 
  def update
    message = {:notice => "Please give Panda a moment to finish moving your thumbnails around."}
    
    run_later do
      @video.thumbnail_position = params[:percentage]
      @video.save
      @video.clipping.set_as_default
      
      @video.successful_encodings.each do | video |
        video.clipping.set_as_default
      end
    end
    
    redirect(url(:video, @video.key), :message => message)
  end
  
  private
  
  # Throws DataMapper::ObjectNotFoundError if video cannot be found
  def get_video
    @video = Video.get!(params[:video_id])
  end
  
  def ensure_that_clipping_can_be_changed
    unless @video.clipping.changeable?
      throw :halt, 'Thumbnail cannot be changed'
    end
  end
  
end
