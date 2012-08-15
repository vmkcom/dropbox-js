# Documentation for the interface to a Dropbox OAuth driver.
class DropboxAuthDriver
  # The callback URL that should be supplied to the OAuth /authorize call.
  #
  # The driver must be able to intercept redirects to the returned URL, in
  # order to know when a user has completed the authorization flow.
  #
  # @return {String} an absolute URL
  url: ->
    'https://some.url'

  # Redirects users to /authorize and waits for them to complete the flow.
  #
  # @param {String} authUrl the URL that users should be sent to in order to
  #     authorize the application's token; this points to a Web page on
  #     Dropbox' servers
  # @param {String} token the OAuth token that the user is authorizing; this
  #     will be provided by the Dropbox servers as a query parameter when the
  #     user is redirected to the URL returned by the driver's url() method 
  # @param {String} tokenSecret the secret associated with the given OAuth
  #     token; the driver may store this together with the token
  # @param {function()} callback called when users have completed the
  #     authorization flow; the driver should call this when Dropbox redirects
  #     users to the URL returned by the url() method, and the 'token' query
  #     parameter matches the value of the token parameter
  doAuthorize: (authUrl, token, tokenSecret, callback) ->
    callback 'oauth-token'

  # Supplies a token to be used instead of calling /oauth/request_token.
  #
  # @return {Array<?String>} 2-element array containing an OAuth request token
  #     and secret, or two nulls if the Dropbox server should be asked to
  #     generate a new request token
  presetToken: ->
    [null, null]


# OAuth driver that uses a redirect and localStorage to complete the flow.
class DropboxRedirectDriver
  # Sets up the redirect-based OAuth driver.
  #
  # @param {?Object} options the advanced settings below
  # @option options {String} scope embedded in the localStorage key that holds
  #     the authentication data; useful for having multiple OAuth tokens in a
  #     single application
  constructor: (options) ->
    @scope = options?.scope or 'default'
    @storageKey = "dropbox-auth:#{@scope}"
    @receiverUrl = @computeUrl options
    @tokenRe = new RegExp "(#|\\?|&)oauth_token=([^&#]+)(&|#|$)"

  # URL of the current page, since the user will be sent right back.
  url: ->
    @receiverUrl

  # Redirects to the authorize page, and waits for the user to come back.
  doAuthorize: (authUrl, token, tokenSecret, callback) ->
    [_token, _secret] = @getStoredToken()
    if _token is token
      @deleteStoredToken()
      callback()
    else
      @storeToken token, tokenSecret
      window.location.assign authUrl

  # Gets the old request token from localStorage, if it's available.
  presetToken: ->
    @getStoredToken()

  # Pre-computes the return value of url.
  computeUrl: ->
    querySuffix = "_dropboxjs_scope=#{encodeURIComponent @scope}"
    location = DropboxRedirectDriver.currentLocation()
    if location.indexOf('#') is -1
      fragment = null
    else
      locationPair = location.split '#', 2
      location = locationPair[0]
      fragment = locationPair[1]
    if location.indexOf('?') is -1
      location += "?#{querySuffix}"  # No query string in the URL.
    else
      location += "&#{querySuffix}"  # The URL already has a query string.

    if fragment
      location + '#' + fragment
    else
      location

  # Figures out if the user completed the OAuth flow based on the current URL.
  #
  # @return {?String} the OAuth token that the user just authorized, or null if
  #     the user accessed this directly, without having authorized a token
  locationToken: ->
    location = DropboxRedirectDriver.currentLocation()
    
    # Check for the scope.
    scopePattern = "_dropboxjs_scope=#{encodeURIComponent @scope}&"
    return null if location.indexOf?(scopePattern) is -1

    # Extract the token.
    match = @tokenRe.exec location
    if match then decodeURIComponent(match[2]) else null

  # Wrapper for window.location, for testing purposes.
  #
  # @return {String} the current page's URL
  @currentLocation: ->
    window.location.href

  # Stores a token and secret to localStorage.
  storeToken: (token, tokenSecret) ->
    json = token: token, secret: tokenSecret
    localStorage.setItem @storageKey, JSON.stringify json

  # Retrieves a token and secret from localStorage.
  #
  # @return {Array<?String>} 2-element array with the OAuth token and secret
  #     stored by a previous call to storeToken, or two null elements if no
  #     such token and secret were stored
  getStoredToken: ->
    jsonString = localStorage.getItem @storageKey
    return [null, null] unless jsonString

    try
      json = JSON.parse jsonString
      return [json.token, json.secret]
    catch e
      # Parse errors
      return [null, null]

  # Deletes information previously stored by a call to storeToken.
  deleteStoredToken: ->
    localStorage.removeItem @storageKey

# OAuth driver that uses a popup window and postMessage to complete the flow.
class DropboxPopupDriver
  # Sets up a popup-based OAuth driver.
  #
  # @param {?Object} options one of the settings below; leave out the argument
  #     to use the current location for redirecting
  # @option options {String} receiverUrl URL to the page that receives the
  #     /authorize redirect and performs the postMessage
  # @option options {String} receiverFile the URL to the receiver page will be
  #     computed by replacing the file name (everything after the last /) of
  #     the current location with this parameter's value
  constructor: (options) ->
    @receiverUrl = @computeUrl options
    @tokenRe = new RegExp "(#|\\?|&)oauth_token=([^&#]+)(&|#|$)"

  # Shows the authorization URL in a pop-up, waits for it to send a message.
  doAuthorize: (authUrl, token, tokenSecret, callback) ->
    @listenForMessage token, callback
    @openWindow authUrl

  # URL of the redirect receiver page, which posts a message back to this page.
  url: ->
    @receiverUrl

  # Pre-computes the return value of url.
  computeUrl: (options) ->
    if options
      if options.receiverUrl
        return options.receiverUrl
      else if options.receiverFile
        fragments = DropboxPopupDriver.currentLocation().split '/'
        fragments[fragments.length - 1] = options.receiverFile
        return fragments.join('/') + '#'
    DropboxPopupDriver.currentLocation()

  # Wrapper for window.location, for testing purposes.
  #
  # @return {String} the current page's URL
  @currentLocation: ->
    window.location.href

  # Creates a popup window.
  #
  # @param {String} url the URL that will be loaded in the popup window
  # @return {?DOMRef} reference to the opened window, or null if the call
  #     failed
  openWindow: (url) ->
    window.open url, '_dropboxOauthSigninWindow', @popupWindowSpec(980, 980)

  # Spec string for window.open to create a nice popup.
  #
  # @param {Number} popupWidth the desired width of the popup window
  # @param {Number} popupHeight the desired height of the popup window
  # @return {String} spec string for the popup window
  popupWindowSpec: (popupWidth, popupHeight) ->
    # Metrics for the current browser window.
    x0 = window.screenX ? window.screenLeft
    y0 = window.screenY ? window.screenTop
    width = window.outerWidth ? document.documentElement.clientWidth
    height = window.outerHeight ? document.documentElement.clientHeight

    # Computed popup window metrics.
    popupLeft = Math.round x0 + (width - popupWidth) / 2
    popupTop = Math.round y0 + (height - popupHeight) / 2.5

    # The specification string.
    "width=#{popupWidth},height=#{popupHeight}," +
      "left=#{popupLeft},top=#{popupTop}" +
      'dialog=yes,dependent=yes,scrollbars=yes,location=yes'

  # Listens for a postMessage from a previously opened popup window.
  #
  # @param {String} token the token string that must be received from the popup
  #     window
  # @param {function()} called when the received message matches the token
  listenForMessage: (token, callback) ->
    tokenRe = @tokenRe
    listener = (event) ->
      match = tokenRe.exec event.data.toString()
      if match and decodeURIComponent(match[2]) is token
        callback()
        window.removeEventListener 'message', listener
    window.addEventListener 'message', listener, false


# OAuth driver that redirects the browser to a node app to complete the flow.
#
# This is useful for testing node.js libraries and applications.
class DropboxNodeServerDriver
  # Starts up the node app that intercepts the browser redirect.
  #
  # @param {Number} port the port number to listen to for requests
  # @param {String} faviconFile the path to a file that will be served at
  #     /favicon.ico
  constructor: (@port = 8912, @faviconFile = null) ->
    # Calling require in the constructor because this doesn't work in browsers.
    @fs = require 'fs'
    @http = require 'http'
    @open = require 'open'
    
    @callbacks = {}
    @urlRe = new RegExp "^/oauth_callback\\?"
    @tokenRe = new RegExp "(\\?|&)oauth_token=([^&]+)(&|$)"
    @createApp()

  # URL to the node.js OAuth callback handler.
  url: ->
    "http://localhost:#{@port}/oauth_callback"

  # Opens the token 
  doAuthorize: (authUrl, token, tokenSecret, callback) ->
    @callbacks[token] = callback
    @openBrowser authUrl

  # Opens the given URL in a browser.
  openBrowser: (url) ->
    unless url.match /^https?:\/\//
      throw new Error("Not a http/https URL: #{url}")
    @open url

  # Creates and starts up an HTTP server that will intercept the redirect.
  createApp: ->
    @app = @http.createServer (request, response) =>
      @doRequest request, response
    @app.listen @port

  # Shuts down the HTTP server.
  #
  # The driver will become unusable after this call.
  closeServer: ->
    @app.close()

  # Reads out an /authorize callback.
  doRequest: (request, response) ->
    if @urlRe.exec request.url
      match = @tokenRe.exec request.url
      if match
        token = decodeURIComponent match[2]
        if @callbacks[token]
          @callbacks[token]()
          delete @callbacks[token]
    data = ''
    request.on 'data', (dataFragment) -> data += dataFragment
    request.on 'end', =>
      if @faviconFile and (request.url is '/favicon.ico')
        @sendFavicon response
      else
        @closeBrowser response

  # Renders a response that will close the browser window used for OAuth.
  closeBrowser: (response) ->
    closeHtml = """
                <!doctype html>
                <script type="text/javascript">window.close();</script>
                <p>Please close this window.</p>
                """
    response.writeHead(200,
      {'Content-Length': closeHtml.length, 'Content-Type': 'text/html' })
    response.write closeHtml
    response.end

  # Renders the favicon file.
  sendFavicon: (response) ->
    @fs.readFile @faviconFile, (error, data) ->
      response.writeHead(200,
        { 'Content-Length': data.length, 'Content-Type': 'image/x-icon' })
      response.write data
      response.end
