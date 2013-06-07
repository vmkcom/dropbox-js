# Base class for drivers that run in the browser.
#
# Inheriting from this class makes a driver use HTML5 localStorage to preserve
# OAuth tokens across page reloads.
class Dropbox.Drivers.BrowserBase
  # Sets up the OAuth driver.
  #
  # Subclasses should pass the options object they receive to the superclass
  # constructor.
  #
  # @param {?Object} options the advanced settings below
  # @option options {Boolean} rememberUser if true, the user's OAuth tokens are
  #   saved in localStorage; if you use this, you MUST provide a UI item that
  #   calls signOut() on Dropbox.Client, to let the user "log out" of the
  #   application
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  constructor: (options) ->
    @rememberUser = options?.rememberUser or false
    @scope = options?.scope or 'default'
    @storageKey = null

    @stateRe = /^[^#]+\#(.*&)?state=([^&]+)(&|$)/

  # Browser-side authentication should always use OAuth 2 Implicit Grant.
  authType: ->
    'token'

  # Persists tokens.
  onAuthStepChange: (client, callback) ->
    @setStorageKey client

    switch client.authStep
      when Dropbox.Client.RESET
        @loadCredentials (credentials) =>
          return callback() unless credentials

          client.setCredentials credentials
          if client.authStep isnt Dropbox.Client.DONE
            return callback()

          # There is an old access token. Only use it if the app supports
          # logout.
          unless @rememberUser
            return @forgetCredentials(callback)

          # Verify that the old access token still works.
          client.setCredentials credentials
          client.getUserInfo (error) =>
            if error
              client.reset()
              @forgetCredentials callback
            else
              callback()
      when Dropbox.Client.DONE
        if @rememberUser
          return @storeCredentials(client.credentials(), callback)
        @forgetCredentials callback
      when Dropbox.Client.SIGNED_OFF
        @forgetCredentials callback
      when Dropbox.Client.ERROR
        @forgetCredentials callback
      else
        callback()
        @

  # Computes the @storageKey used by loadCredentials and forgetCredentials.
  #
  # @private
  # This is called by onAuthStepChange.
  #
  # @param {Dropbox.Client} client the client instance that is running the
  #     authorization process
  # @return {Dropbox.Driver} this, for easy call chaining
  setStorageKey: (client) ->
    # NOTE: the storage key is dependent on the app hash so that multiple apps
    #       hosted off the same server don't step on eachother's toes
    @storageKey = "dropbox-auth:#{@scope}:#{client.appHash()}"
    @

  # Stores a Dropbox.Client's credentials to localStorage.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {Object} credentials the result of a Drobpox.Client#credentials call
  # @param {function()} callback called when the storing operation is complete
  # @return {Dropbox.Drivers.BrowserBase} this, for easy call chaining
  storeCredentials: (credentials, callback) ->
    localStorage.setItem @storageKey, JSON.stringify(credentials)
    callback()
    @

  # Retrieves a token and secret from localStorage.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {function(?Object)} callback supplied with the credentials object
  #   stored by a previous call to
  #   Dropbox.Drivers.BrowserBase#storeCredentials; null if no credentials were
  #   stored, or if the previously stored credentials were deleted
  # @return {Dropbox.Drivers.BrowserBase} this, for easy call chaining
  loadCredentials: (callback) ->
    jsonString = localStorage.getItem @storageKey
    unless jsonString
      callback null
      return @

    try
      callback JSON.parse(jsonString)
    catch jsonError
      # Parse errors.
      callback null
    @

  # Deletes information previously stored by a call to storeCredentials.
  #
  # @private
  # onAuthStepChange calls this method during the authentication flow.
  #
  # @param {function()} callback called after the credentials are deleted
  # @return {Dropbox.Drivers.BrowserBase} this, for easy call chaining
  forgetCredentials: (callback) ->
    localStorage.removeItem @storageKey
    callback()
    @

  # Figures out if a URL is an OAuth 2.0 /authorize redirect URL.
  #
  # @param {?String} the URL to check; if not given, the current location's URL
  #   is checked
  # @return {?String} the state parameter value received from the /authorize
  # redirect, or null if the URL is not the result of an /authorize redirect
  locationStateParam: (url) ->
    location = url or Dropbox.Drivers.BrowserBase.currentLocation()

    # Extract the state.
    match = @stateRe.exec location
    return decodeURIComponent(match[2]) if match

    null

  # Wrapper for window.location, for testing purposes.
  #
  # @return {String} the current page's URL
  @currentLocation: ->
    window.location.href


# OAuth driver that uses a redirect and localStorage to complete the flow.
class Dropbox.Drivers.Redirect extends Dropbox.Drivers.BrowserBase
  # Sets up the redirect-based OAuth driver.
  #
  # @param {?Object} options the advanced settings below
  # @option options {Boolean} rememberUser if true, the user's OAuth tokens are
  #   saved in localStorage; if you use this, you MUST provide a UI item that
  #   calls signOut() on Dropbox.Client, to let the user "log out" of the
  #   application
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  constructor: (options) ->
    super options
    @receiverUrl = Dropbox.Drivers.BrowserBase.currentLocation()

  # URL of the current page, since the user will be sent right back.
  url: ->
    @receiverUrl

  # Saves the OAuth 2 credentials, and redirects to the authorize page.
  doAuthorize: (authUrl, stateParam, client) ->
    @storeCredentials client.credentials(), ->
      window.location.assign authUrl

  # Processes a redirect.
  resumeAuthorize: (stateParam, client, callback) ->
    if @locationStateParam() is stateParam
      callback Dropbox.Oauth.queryParamsFromUrl(
        Dropbox.Drivers.BrowserBase.currentLocation())
    else
      @forgetCredentials ->
        client.reset()
        callback()

# OAuth driver that uses a popup window and postMessage to complete the flow.
class Dropbox.Drivers.Popup extends Dropbox.Drivers.BrowserBase
  # Sets up a popup-based OAuth driver.
  #
  # @param {?Object} options one of the settings below; leave out the argument
  #   to use the current location for redirecting
  # @option options {Boolean} rememberUser if true, the user's OAuth tokens are
  #   saved in localStorage; if you use this, you MUST provide a UI item that
  #   calls signOut() on Dropbox.Client, to let the user "log out" of the
  #   application
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  # @option options {String} receiverUrl URL to the page that receives the
  #   /authorize redirect and performs the postMessage
  # @option options {String} receiverFile the URL to the receiver page will be
  #   computed by replacing the file name (everything after the last /) of
  #   the current location with this parameter's value
  constructor: (options) ->
    super options
    @receiverUrl = @baseUrl(options)

  # URL of the redirect receiver page, which posts a message back to this page.
  url: ->
    @receiverUrl

  # Shows the authorization URL in a pop-up, waits for it to send a message.
  doAuthorize: (authUrl, stateParam, client, callback) ->
    console.log ['doAuthorize', stateParam, client.authStep]
    @listenForMessage stateParam, callback
    @openWindow authUrl

  # The URL of the page that will receive the OAuth callback.
  #
  # @param {Object} options the options passed to the constructor
  # @option options {String} receiverUrl URL to the page that receives the
  #   /authorize redirect and performs the postMessage
  # @option options {String} receiverFile the URL to the receiver page will be
  #   computed by replacing the file name (everything after the last /) of
  #   the current location with this parameter's value
  # @return {String} absolute URL of the receiver page
  baseUrl: (options) ->
    if options
      if options.receiverUrl
        return options.receiverUrl
      else if options.receiverFile
        fragments = Dropbox.Drivers.BrowserBase.currentLocation().split '/'
        fragments[fragments.length - 1] = options.receiverFile
        return fragments.join('/')
    Dropbox.Drivers.BrowserBase.currentLocation()

  # Creates a popup window.
  #
  # @param {String} url the URL that will be loaded in the popup window
  # @return {?DOMRef} reference to the opened window, or null if the call
  #   failed
  openWindow: (url) ->
    window.open url, '_dropboxOauthSigninWindow', @popupWindowSpec(980, 700)

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
    popupLeft = x0 if popupLeft < x0
    popupTop = y0 if popupTop < y0

    # The specification string.
    "width=#{popupWidth},height=#{popupHeight}," +
      "left=#{popupLeft},top=#{popupTop}" +
      'dialog=yes,dependent=yes,scrollbars=yes,location=yes'

  # Listens for a postMessage from a previously opened popup window.
  #
  # @param {String} stateParam the state parameter passed to the OAuth 2
  #   /authorize endpoint
  # @param {function()} called when the received message matches the token
  listenForMessage: (stateParam, callback) ->
    listener = (event) =>
      console.log ['message', event.data or event]

      if event.data
        # Message coming from postMessage.
        data = event.data
      else
        # Message coming from Dropbox.EventSource.
        data = event

      if @locationStateParam(data) is stateParam
        stateParam = false  # Avoid having this matched in the future.
        window.removeEventListener 'message', listener
        Dropbox.Drivers.Popup.onMessage.removeListener listener
        console.log ['callback', Dropbox.Oauth.queryParamsFromUrl(data)]
        callback Dropbox.Oauth.queryParamsFromUrl(data)
    window.addEventListener 'message', listener, false
    Dropbox.Drivers.Popup.onMessage.addListener listener

  # Communicates with the driver from the OAuth receiver page.
  @oauthReceiver: ->
    window.addEventListener 'load', ->
      opener = window.opener
      if window.parent isnt window.top
        opener or= window.parent
      if opener
        try
          opener.postMessage window.location.href, '*'
        catch ieError
          # IE 9 doesn't support opener.postMessage for popup windows.
        try
          # postMessage doesn't work in IE, but direct object access does.
          opener.Dropbox.Drivers.Popup.onMessage.dispatch(
              window.location.href)
        catch frameError
          # Hopefully postMessage worked.
      window.close()

  # Works around postMessage failures on Internet Explorer.
  @onMessage = new Dropbox.EventSource
