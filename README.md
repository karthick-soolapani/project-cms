### Summary

A light-weight Content Management web app. The front-end is an afterthought, the project is meant to showcase back-end principles and file management.

### Installation
- Ruby and Bundler(RubyGem) are required
- Clone/Download this repo
- Run `bundle install` in terminal from project directory
  (This installs the project's dependencies)
- Run `bundle exec ruby cms.rb`
- Go to `localhost:4567` or where it is listened to use the app

### Features
- User authentication (use credentials from text file)
- Document - Create, View, Update and Delete

### Possible enhancements
- New User SignUp
- History of document versions
- Duplicate document

### Tools/Extensions Used:
- Written in Ruby using Erubis and Sinatra
- BCrypt for encrypting password
- YAML to store encrypted User credentials
- Red carpet for rendering markdown files