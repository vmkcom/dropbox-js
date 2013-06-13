if global? and require? and module? and (not cordova?)
  # node.js
  require('source-map-support').install()

  exports = global

  exports.Dropbox = require '../../../lib/dropbox'
  exports.chai = require 'chai'
  exports.sinon = require 'sinon'
  exports.sinonChai = require 'sinon-chai'

  exports.authDriver = new Dropbox.AuthDriver.NodeServer port: 8912

  TokenStash = require './token_stash.js'
  stash = new TokenStash()
  stash.get (credentials) ->
    exports.testKeys = credentials.sandbox
    exports.testFullDropboxKeys = credentials.full

  testIconPath = './test/binary/dropbox.png'
  fs = require 'fs'
  buffer = fs.readFileSync testIconPath
  exports.testImageBytes = (buffer.readUInt8(i) for i in [0...buffer.length])
  exports.testImageUrl = 'http://localhost:8913/favicon.ico'
  imageServer = null
  exports.testImageServerOn = ->
    imageServer =
        new Dropbox.AuthDriver.NodeServer port: 8913, favicon: testIconPath
  exports.testImageServerOff = ->
    imageServer.closeServer()
    imageServer = null

  exports.testXhrServer = 'https://localhost:8912'
else
  if chrome? and chrome.runtime
    # Chrome app
    exports = window
    exports.authDriver = new Dropbox.AuthDriver.Chrome(
        receiverPath: 'test/html/chrome_oauth_receiver.html',
        scope: 'helper-chrome')
    # Hack-implement "rememberUser: false" in the Chrome driver.
    exports.authDriver.storeCredentials = (credentials, callback) -> callback()
    exports.authDriver.loadCredentials = (callback) -> callback null
    exports.testImageUrl = '../../test/binary/dropbox.png'
  else
    if typeof window is 'undefined' and typeof self isnt 'undefined'
      # Web Worker.
      exports = self
      exports.authDriver = null
      exports.testImageUrl = '../../../test/binary/dropbox.png'
    else
      exports = window
      if cordova?
        # Cordova WebView.
        exports.authDriver = new Dropbox.AuthDriver.Cordova
      else
        # Browser
        exports.authDriver = new Dropbox.AuthDriver.Popup(
            receiverFile: 'oauth_receiver.html', scope: 'helper-popup')
      exports.testImageUrl = '../../test/binary/dropbox.png'

  exports.testImageServerOn = -> null
  exports.testImageServerOff = -> null

  exports.testXhrServer = exports.location.origin

  # NOTE: browser-side apps should not use API secrets, so we remove them
  exports.testKeys.__secret = exports.testKeys.secret
  delete exports.testKeys['secret']
  exports.testFullDropboxKeys.__secret = exports.testFullDropboxKeys.secret
  delete exports.testFullDropboxKeys['secret']

# Shared setup.
exports.assert = exports.chai.assert
exports.expect = exports.chai.expect
