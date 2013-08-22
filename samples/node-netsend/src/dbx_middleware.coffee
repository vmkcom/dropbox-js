# Dropbox.js middleware.
#
# TODO(pwnall): move this in separate npm package

Dropbox = require 'dropbox'

# Creates a middleware.
#
# @param {Object} options the options below
# @option {String} key
# @option {String} secret
# @return {function(Error, http.IncomingMessage, http.ServerResponse,
#   function)} a Connect middleware
dbxMiddleware = (options) ->
  key = options.key
  unless key
    throw new Error 'Missing app key'
  secret = options.secret
  unless secret
    throw new Error 'Missing app secret'

  (request, response, next) ->
    client = new Dropbox.Client key: key, secret: secret
    redirectUrl = request.protocol + '://' + request.headers.host +
                  request.originalUrl.split('?', 2)[0]
    client.authDriver
      authType: -> 'code'
      url: -> redirectUrl

    oauthState = dbxMiddleware.pullOauthState request, response
    state = request.query and request.query.state
    unless oauthState is state
      dbxMiddleware.doRedirect request, response, client
      return

    client._oauth.processRedirectParams request.query
    client.authStep = client._oauth.step()
    console.log client.authStep
    client.authenticate (error) ->
      if error
        dbxMiddleware.doRedirect request, response, client
        return

      request.dbxClient = client
      next()

# Extracts and resets the OAuth state for this user.
dbxMiddleware.pullOauthState = (request, response) ->
  if request.cookies.dropbox_js_oauth_state
    oauthState = request.cookies.dropbox_js_oauth_state
    response.clearCookie 'dropbox_js_oauth_state'
    return oauthState

  null

# Attaches the Oauth state parameter to the user's session.
dbxMiddleware.setOauthState = (request, response, state) ->
  response.cookie 'dropbox_js_oauth_state', state, httpOnly: true
  return

# No middleware.
dbxMiddleware.doRedirect = (request, response, client) ->
  client._oauth.setAuthStateParam Dropbox.Util.Oauth.randomAuthStateParam()
  dbxMiddleware.setOauthState request, response, client._oauth.authStateParam()
  response.redirect client.authorizeUrl()
  return

module.exports = dbxMiddleware
