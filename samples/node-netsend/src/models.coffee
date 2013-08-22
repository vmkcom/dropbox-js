# Database persistence.
# This file is infrastructure, and has no dropbox.js sample code.

nconf = require 'nconf'
Sequelize = require 'sequelize'

sequelize = new Sequelize(nconf.get('database:url'),
  logging: nconf.get('database:logging') and console.log,
  maxConcurrentQueries: nconf.get('database:concurrency'),
  sync: false)


User = sequelize.define('User',
  id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
  dbxUid: { type: Sequelize.STRING(32), allowNull: false, unique: true },
  name: { type: Sequelize.STRING(128), allowNull: false })

Token = sequelize.define('Token',
  id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
  user_id: { type: Sequelize.INTEGER, allowNull: false},
  token: { type: Sequelize.STRING(128), allowNull: false })


exports.sequelize = sequelize
exports.Token = Token
exports.User = User
