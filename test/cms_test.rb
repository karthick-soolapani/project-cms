ENV["RACK_ENV"] = 'test'

require "fileutils"
require 'minitest/autorun'
require 'rack/test'
require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)

    create_document("about.md", "# Ruby is...")
    create_document("changes.txt", "Ruby 2.6.0 was released on Christmas Day in 2018")
    create_document("history.txt", "1995 - Ruby 0.95 released.")

    create_users
  end

  def teardown
    users_path = File.expand_path("../users.yml", data_path)

    FileUtils.rm_rf(data_path)
    FileUtils.rm_rf(users_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def create_document(filename, content = "")
    doc_path = File.join(data_path, filename)
    File.write(doc_path, content)
  end

  def create_users
    users_path = File.expand_path("../users.yml", data_path)

    users_content = <<~CONTENT.chomp
    admin: $2a$10$BDGq.QRicwadws.anifTB.TkismCykSA.nMhZ2QSHctEcfnPb48Ee
    bill: $2a$10$GNrlNU5MshleyzPDfYjyC.1It67Uyz2sGOdjcBOK9c.d/9uyjcqH.
    CONTENT

    File.write(users_path, users_content)
  end

  def test_view_sign_in_form
    get "users/signin"

    assert(last_response.ok?)
    assert_includes(last_response.body, %q(<input name="username"))
    assert_includes(last_response.body, %q(<input name="password"))
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_valid_sign_in
    post "users/signin", username: "bill", password: "billspass"
    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("Welcome!", session[:message])
    assert_equal("bill", session[:username])

    get last_response["Location"]
    assert_includes(last_response.body, "Signed in as bill")
  end

  def test_sign_in_with_bad_credentials
    post "users/signin", username: "stranger", password: "things"

    assert_equal(422, last_response.status)
    assert_nil(session[:username])
    assert_includes(last_response.body, "Invalid Credentials")
  end

  def test_user_sign_out
    get "/", {}, admin_session
    assert_includes(last_response.body, "Signed in as admin")

    post "/users/signout"
    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("You have been signed out.", session[:message])

    get last_response["Location"]
    assert_nil(session[:username])
    assert_includes(last_response.body, "Sign In")
  end

  def test_index
    get "/"

    assert(last_response.ok?)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "about.md")
    assert_includes(last_response.body, "changes.txt")
  end

  def test_new_document_link
    get "/"

    assert_includes(last_response.body, 'href="/new"')
  end

  def test_edit_document_link
    get "/"

    assert_includes(last_response.body, 'href="/changes.txt/edit"')
  end

  def test_delete_document_link
    get "/"

    assert_includes(last_response.body, 'action="/changes.txt/delete"')
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_viewing_text_document
    get "/history.txt"

    assert(last_response.ok?)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_equal("1995 - Ruby 0.95 released.", last_response.body)
  end

  def test_markdown_document
    get "/about.md"

    assert(last_response.ok?)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<h1>Ruby is...</h1>")
  end

  def test_non_existant_documents
    get "/notafile.txt"

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("notafile.txt does not exist", session[:message])
  end

  def test_clear_flash_message_on_refresh
    get "/notafile.txt"
    get last_response["Location"]

    refute_equal("notafile.txt does not exist", session[:message])
  end

  def test_editing_document
    get "/changes.txt/edit", {}, admin_session

    assert(last_response.ok?)
    assert_includes(last_response.body, "Edit content of changes.txt:")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_document_cannot_be_edited_without_sign_in
    get "/changes.txt/edit"

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_updating_document
    post "/changes.txt", { content: "new content" }, admin_session
    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("changes.txt has been updated", session[:message])

    get "/changes.txt"
    assert(last_response.ok?)
    assert_equal("new content", last_response.body)
  end

  def test_document_cannot_be_updated_without_sign_in
    post "/changes.txt"

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert(last_response.ok?)
    assert_includes(last_response.body, "Add a new document:")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_new_document_cannot_be_viewed_without_sign_in
    get "/new"

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_new_document_creation
    post "/create", { filename: "story.md" }, admin_session
    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("story.md was created.", session[:message])

    get "/"
    assert_includes(last_response.body, "story.md")
  end

  def test_new_document_cannot_be_viewed_without_sign_in
    post "/create", filename: "story.md"

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_document_without_filename
    post "/create", { filename: "" }, admin_session

    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "A name is required.")
  end

  def test_document_with_invalid_name
    post "/create", { filename: "changes.txt"}, admin_session

    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "changes.txt already exists.")
  end

  def test_document_deletion
    post "changes.txt/delete", {}, admin_session

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("changes.txt was deleted.", session[:message])
  end

  def test_deletion_with_non_existant_document
    post "/test.txt/delete",  {}, admin_session

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("test.txt does not exist", session[:message])
  end

  def test_document_cannot_be_deleted_without_sign_in
    post "/test.txt/delete"

    assert_includes((300..399), last_response.status)
    assert_equal("http://example.org/", last_response["Location"])
    assert_equal("You must be signed in to do that.", session[:message])
  end
end