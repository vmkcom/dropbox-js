# Sets up / resets the database.
# This file is infrastructure, and has no dropbox.js sample code.

nconf = require 'nconf'
nconf.argv().env().file file: 'config.json'

async = require 'async'
models = require './models'

models.sequelize.sync(force: true).
  success(-> console.info 'Done').
  error(->console.info 'Table creation failed')
