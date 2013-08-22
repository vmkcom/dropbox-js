# Controller code for the application.
# The dropbox.js sample code is here.

nconf = require 'nconf'

DbxMiddleware = require './dbx_middleware'
dbxMiddleware = DbxMiddleware(
    key: nconf.get('dropbox:key'), secret: nconf.get('dropbox:secret'))

module.exports = (app) ->
  app.get '/', (request, response) ->
    response.render 'index.toffee'

  app.get '/dropbox_oauth', dbxMiddleware, (request, response) ->
    response.render 'home.toffee', client: request.dbxClient
