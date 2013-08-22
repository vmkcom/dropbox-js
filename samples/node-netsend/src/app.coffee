# Loads and configures the application.
# This file is infrastructure, and has no dropbox.js sample code.

nconf = require 'nconf'
nconf.argv().env().file file: 'config.json'

models = require './models'

express = require 'express'
app = express()

# Set up the express application stack.
toffee = require 'toffee'
app.engine 'toffee', toffee.__express
app.use express.favicon()
app.use express.logger()
app.use express.errorHandler()
app.use express.bodyParser()
app.use express.cookieParser(
    key: nconf.get('session:key'), secret: nconf.get('session:secret'))
app.use express.cookieSession()

require('./controllers')(app)

# Set up and start the server.
http = require 'http'
server = http.createServer app
server.listen nconf.get('server:port'), ->
  address = server.address()
  console.log "Listening on #{address.address}:#{address.port}"

