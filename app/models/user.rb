class User
  include DataMapper::Resource
  
  property :id, String, :key => true
  property :password, String
  property :email, String
  property :salt, String
  property :crypted_password, String
  property :api_key, String
  property :updated_at, Time
  property :created_at, Time
  
  attr_accessor :password, :password_confirmation
  
  def login
    self.id
  end
  
  def login=(v)
    self.id = v
  end
  
  def self.authenticate(login, password)
    begin
      u = self.get!(login)
    rescue DataMapper::ObjectNotFoundError
      return nil
    else
      puts "#{u.crypted_password} | #{encrypt(password, u.salt)}"
      u && (u.crypted_password == encrypt(password, u.salt)) ? u : nil
    end
  end

  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end
  
  def set_password(password)
    return if password.blank?
    salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{self.key}--")
    self.salt = salt
    self.crypted_password = self.class.encrypt(password, salt)
  end
end