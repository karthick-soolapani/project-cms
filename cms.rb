require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :sessions_secret, 'secret'

  set :erb, :escape_html => true
end

helpers do
  def sort_files(files)
    files.sort
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def set_content_type_header!(filename)
  extension = File.extname(filename)

  case extension
  when ".txt"
    headers "Content-Type" => "text/plain"
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def process_content(file_path)
  extension = File.extname(file_path)
  content = File.read(file_path)

  case extension
  when ".md"
    erb render_markdown(content)
  when ".txt"
    content
  end
end

def error_msg_for_doc_name(filename, files)
  if filename.empty?
    "A name is required."
  elsif files.include?(filename)
    "#{filename} already exists."
  end
end

def load_credentials
  users_path = File.expand_path("../users.yml", data_path)
  YAML.load_file(users_path)
end

def valid_credentials?(username, password)
  users = load_credentials

  return false unless users.key?(username)

  bcrypt_password = BCrypt::Password.new(users[username])
  bcrypt_password == password
end

def authentication_required_routes
  [
    { method: "GET", path: Regexp.new('^/new$') },
    { method: "POST", path: Regexp.new('^/create$') },
    { method: "POST", path: Regexp.new('^/[^/]+/delete$') },
    { method: "GET", path: Regexp.new('^/[^/]+/edit$') },
    { method: "POST", path: Regexp.new('^/[^/]+$') },
  ]
end

def authentication_required?
  authentication_required_routes.any? do |routes|
    routes[:method] == request.request_method &&
    routes[:path].match?(request.path_info)
  end
end

def signed_in?
  session.key?(:username)
end

def process_authentication
  return if signed_in?

  session[:message] = "You must be signed in to do that."
  redirect "/"
end

before do
  @user = session[:username]
  pass unless authentication_required?

  process_authentication
end

# Sign In form
get "/users/signin" do
  erb :sign_in
end

# Validate and Sign In user
post "/users/signin" do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:message] = "Invalid Credentials"
    erb :sign_in
  end
end

# Sign Out user
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."

  redirect "/"
end

# View all files
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |file| File.basename(file) }

  erb :index
end

# View a new document
get "/new" do
  erb :new_document
end

# Create a new document
post "/create" do
  filename = params[:filename].strip
  file_path = File.join(data_path, File.basename(filename))
  pattern = File.join(data_path, "*")
  files = Dir.glob(pattern).map { |file| File.basename(file) }

  error = error_msg_for_doc_name(filename, files)

  if error
    session[:message] = error
    status 422
    erb :new_document
  else
    File.new(file_path, "w+")
    session[:message] = "#{filename} was created."
    redirect "/"
  end
end

# Delete a document
post "/:filename/delete" do
  filename = params[:filename]
  file_path = File.join(data_path, File.basename(filename))

  if File.file?(file_path)
    File.delete(file_path)
    session[:message] = "#{filename} was deleted."
  else
    session[:message] = "#{filename} does not exist"
  end

  redirect "/"
end

# View a single file
get "/:filename" do
  filename = params[:filename]
  file_path = File.join(data_path, File.basename(filename))

  if File.file?(file_path)
    set_content_type_header!(filename)
    process_content(file_path)
  else
    session[:message] = "#{filename} does not exist"
    redirect "/"
  end
end

# View edit file
get "/:filename/edit" do
  @filename = params[:filename]
  file_path = File.join(data_path, File.basename(@filename))

  if File.file?(file_path)
    @content = File.read(file_path)
    erb :edit_document
  else
    session[:message] = "#{@filename} does not exist"
    redirect "/"
  end
end

# Editing a single file
post "/:filename" do
  new_content = params[:content]
  filename = params[:filename]
  file_path = File.join(data_path, File.basename(filename))

  if File.file?(file_path)
    File.write(file_path, new_content)
    session[:message] = "#{filename} has been updated"
  else
    session[:message] = "#{filename} does not exist"
  end

  redirect "/"
end