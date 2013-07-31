# OAuth driver that uses a Cordova InAppBrowser to complete the flow.
class Dropbox.AuthDriver.Cordova extends Dropbox.AuthDriver.BrowserBase
  # Sets up an OAuth driver for Cordova applications.
  #
  # @param {Object} options (optional) one of the settings below
  # @option options {String} scope embedded in the localStorage key that holds
  #   the authentication data; useful for having multiple OAuth tokens in a
  #   single application
  # @option options {Boolean} rememberUser if false, the user's OAuth tokens
  #   are not saved in localStorage; true by default
  constructor: (options) ->
    super options

  # URL of the page that the user will be redirected to.
  #
  # @return {String} a page on the Dropbox site that will not redirect; this is
  #   not a new point of failure, because the OAuth flow already depends on
  #   the Dropbox site being up and reachable
  # @see Dropbox.AuthDriver#url
  url: ->
    'https://www.dropbox.com/1/oauth2/redirect_receiver'

  # Shows the authorization URL in a pop-up, waits for it to send a message.
  #
  # @see Dropbox.AuthDriver#doAuthorize
  doAuthorize: (authUrl, stateParam, client, callback) ->
    browser = window.open authUrl, '_blank', 'location=yes'
    promptPageLoaded = false
    authHost = /^[^/]*\/\/[^/]*\//.exec(authUrl)[0]
    removed = false
    onEvent = (event) =>
      return if removed
      if event.url and @locationStateParam(event.url) is stateParam
        removed = true
        browser.removeEventListener 'loadstop', onEvent
        browser.removeEventListener 'exit', onEvent
        browser.close() unless event.type is 'exit'
        callback Dropbox.Util.Oauth.queryParamsFromUrl event.url

      if event.type is 'exit'
        removed = true
        browser.removeEventListener 'loadstop', onEvent
        browser.removeEventListener 'exit', onEvent
        browser.close() unless event.type is 'exit'
        callback new AuthError(
            'error=access_denied&error_description=User+closed+browser+window')

    browser.addEventListener 'loadstop', onEvent
    browser.addEventListener 'exit', onEvent
