describe 'Dropbox.AuthDriver.BrowserBase', ->
  beforeEach ->
    @node_js = module? and module?.exports? and require?
    @chrome_app = chrome? and (chrome.extension or chrome.app)
    @client = new Dropbox.Client testKeys

  describe 'with rememberUser: false', ->
    beforeEach (done) ->
      return done() if @node_js or @chrome_app
      @driver = new Dropbox.AuthDriver.BrowserBase rememberUser: false
      @driver.setStorageKey @client
      @driver.forgetCredentials done

    afterEach (done) ->
      return done() if @node_js or @chrome_app
      @driver.forgetCredentials done

    describe '#loadCredentials', ->
      it 'produces the credentials passed to storeCredentials', (done) ->
        return done() if @node_js or @chrome_app
        goldCredentials = @client.credentials()
        @driver.storeCredentials goldCredentials, =>
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.deep.equal goldCredentials
            done()

      it 'produces null after forgetCredentials was called', (done) ->
        return done() if @node_js or @chrome_app
        @driver.storeCredentials @client.credentials(), =>
          @driver.forgetCredentials =>
            @driver.loadCredentials (credentials) ->
              expect(credentials).to.equal null
              done()

      it 'produces null if a different scope is provided', (done) ->
        return done() if @node_js or @chrome_app
        @driver.setStorageKey @client
        @driver.storeCredentials @client.credentials(), =>
          @driver.forgetCredentials =>
            @driver.loadCredentials (credentials) ->
              expect(credentials).to.equal null
              done()

  describe '#locationStateParam', ->
    beforeEach ->
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'currentLocation'
    afterEach ->
      @stub.restore()

    it 'returns null if the location does not contain the state', ->
      @stub.returns 'http://test/file#another_state=ab%20cd&stat=e'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal null

    it 'returns null if the fragment does not contain the state', ->
      @stub.returns 'http://test/file?state=decoy#another_state=ab%20cd&stat=e'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal null

    it "extracts the state when it is the first fragment param", ->
      @stub.returns 'http://test/file#state=ab%20cd&other_param=true'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal 'ab cd'

    it "extracts the state when it is the last fragment param", ->
      @stub.returns 'http://test/file#other_param=true&state=ab%20cd'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal 'ab cd'

    it "extracts the state when it is a middle fragment param", ->
      @stub.returns 'http://test/file#param1=true&state=ab%20cd&param2=true'
      driver = new Dropbox.AuthDriver.BrowserBase
      expect(driver.locationStateParam()).to.equal 'ab cd'


describe 'Dropbox.AuthDriver.Redirect', ->
  describe '#url', ->
    beforeEach ->
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'currentLocation'

    afterEach ->
      @stub.restore()

    it 'defaults to the current location', ->
      @stub.returns 'http://test/file?a=true'
      driver = new Dropbox.AuthDriver.Redirect()
      expect(driver.url()).to.equal 'http://test/file?a=true'

    it 'removes the fragment from the location', ->
      @stub.returns 'http://test/file?a=true#deadfragment'
      driver = new Dropbox.AuthDriver.Redirect()
      expect(driver.url()).to.equal 'http://test/file?a=true'

  describe '#loadCredentials', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      return if @node_js or @chrome_app
      @client = new Dropbox.Client testKeys
      @driver = new Dropbox.AuthDriver.Redirect scope: 'some_scope'
      @driver.setStorageKey @client

    it 'produces the credentials passed to storeCredentials', (done) ->
      return done() if @node_js or @chrome_app
      goldCredentials = @client.credentials()
      @driver.storeCredentials goldCredentials, =>
        @driver = new Dropbox.AuthDriver.Redirect scope: 'some_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.deep.equal goldCredentials
          done()

    it 'produces null after forgetCredentials was called', (done) ->
      return done() if @node_js or @chrome_app
      @driver.storeCredentials @client.credentials(), =>
        @driver.forgetCredentials =>
          @driver = new Dropbox.AuthDriver.Redirect scope: 'some_scope'
          @driver.setStorageKey @client
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.equal null
            done()

    it 'produces null if a different scope is provided', (done) ->
      return done() if @node_js or @chrome_app
      @driver.setStorageKey @client
      @driver.storeCredentials @client.credentials(), =>
        @driver = new Dropbox.AuthDriver.Redirect scope: 'other_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.equal null
          done()

  describe 'integration', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      @cordova = cordova?

    it 'should work', (done) ->
      return done() if @node_js or @chrome_app or @cordova
      @timeout 30 * 1000  # Time-consuming because the user must click.

      listenerCalled = false
      listener = (event) ->
        return if listenerCalled is true
        listenerCalled = true
        data = event.data or event
        expect(data).to.match(/^\[.*\]$/)
        [error, credentials] = JSON.parse data
        expect(error).to.equal null
        expect(credentials).to.have.property 'uid'
        expect(credentials.uid).to.be.a 'string'
        expect(credentials).to.have.property 'token'
        expect(credentials.token).to.be.a 'string'
        window.removeEventListener 'message', listener
        Dropbox.AuthDriver.Popup.onMessage.removeListener listener
        done()

      window.addEventListener 'message', listener
      Dropbox.AuthDriver.Popup.onMessage.addListener listener
      (new Dropbox.AuthDriver.Popup()).openWindow(
          '/test/html/redirect_driver_test.html')

    it 'should be the default driver on browsers', ->
      return if @node_js or @chrome_app or @cordova
      client = new Dropbox.Client testKeys
      Dropbox.AuthDriver.autoConfigure client
      expect(client.driver).to.be.instanceOf Dropbox.AuthDriver.Redirect

describe 'Dropbox.AuthDriver.Popup', ->
  describe '#url', ->
    beforeEach ->
      @stub = sinon.stub Dropbox.AuthDriver.BrowserBase, 'currentLocation'
      @stub.returns 'http://test:123/a/path/file.htmx'

    afterEach ->
      @stub.restore()

    it 'reflects the current page when there are no options', ->
      driver = new Dropbox.AuthDriver.Popup
      expect(driver.url('oauth token')).to.equal(
            'http://test:123/a/path/file.htmx')

    it 'replaces the current file correctly', ->
      driver = new Dropbox.AuthDriver.Popup receiverFile: 'another.file'
      expect(driver.url('oauth token')).to.equal(
          'http://test:123/a/path/another.file')

    it 'replaces an entire URL without a query correctly', ->
      driver = new Dropbox.AuthDriver.Popup
        receiverUrl: 'https://something.com/filez'
      expect(driver.url('oauth token')).to.equal(
          'https://something.com/filez')

    it 'replaces an entire URL with a query correctly', ->
      driver = new Dropbox.AuthDriver.Popup
        receiverUrl: 'https://something.com/filez?query=param'
      expect(driver.url('oauth token')).to.equal(
          'https://something.com/filez?query=param')

  describe '#loadCredentials', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      return if @node_js or @chrome_app
      @client = new Dropbox.Client testKeys
      @driver = new Dropbox.AuthDriver.Popup scope: 'some_scope'
      @driver.setStorageKey @client

    it 'produces the credentials passed to storeCredentials', (done) ->
      return done() if @node_js or @chrome_app
      goldCredentials = @client.credentials()
      @driver.storeCredentials goldCredentials, =>
        @driver = new Dropbox.AuthDriver.Popup scope: 'some_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.deep.equal goldCredentials
          done()

    it 'produces null after forgetCredentials was called', (done) ->
      return done() if @node_js or @chrome_app
      @driver.storeCredentials @client.credentials(), =>
        @driver.forgetCredentials =>
          @driver = new Dropbox.AuthDriver.Popup scope: 'some_scope'
          @driver.setStorageKey @client
          @driver.loadCredentials (credentials) ->
            expect(credentials).to.equal null
            done()

    it 'produces null if a different scope is provided', (done) ->
      return done() if @node_js or @chrome_app
      @driver.setStorageKey @client
      @driver.storeCredentials @client.credentials(), =>
        @driver = new Dropbox.AuthDriver.Popup scope: 'other_scope'
        @driver.setStorageKey @client
        @driver.loadCredentials (credentials) ->
          expect(credentials).to.equal null
          done()

  describe 'integration', ->
    beforeEach ->
      @node_js = module? and module.exports? and require?
      @chrome_app = chrome? and (chrome.extension or chrome.app?.runtime)
      @cordova = cordova?

    it 'should work with rememberUser: false', (done) ->
      return done() if @node_js or @chrome_app or @cordova
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.Popup(
          receiverFile: 'oauth_receiver.html', scope: 'popup-integration',
          rememberUser: false)
      client.authDriver authDriver
      client.authenticate (error, client) =>
        expect(error).to.equal null
        expect(client.authStep).to.equal Dropbox.Client.DONE
        # Verify that we can do API calls.
        client.getUserInfo (error, userInfo) ->
          expect(error).to.equal null
          expect(userInfo).to.be.instanceOf Dropbox.UserInfo

          # Follow-up authenticate() should restart the process.
          client.reset()
          client.authenticate interactive: false, (error, client) ->
            expect(error).to.equal null
            expect(client.authStep).to.equal Dropbox.Client.RESET
            expect(client.isAuthenticated()).to.equal false
            done()

    it 'should work with rememberUser: true', (done) ->
      return done() if @node_js or @chrome_app or @cordova
      @timeout 45 * 1000  # Time-consuming because the user must click.

      client = new Dropbox.Client testKeys
      client.reset()
      authDriver = new Dropbox.AuthDriver.Popup(
        receiverFile: 'oauth_receiver.html', scope: 'popup-integration',
        rememberUser: true)
      client.authDriver authDriver
      authDriver.setStorageKey client
      authDriver.forgetCredentials ->
        client.authenticate (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.DONE
          # Verify that we can do API calls.
          client.getUserInfo (error, userInfo) ->
            expect(error).to.equal null
            expect(userInfo).to.be.instanceOf Dropbox.UserInfo

            # Follow-up authenticate() should use stored credentials.
            client.reset()
            client.authenticate interactive: false, (error, client) ->
              expect(error).to.equal null
              expect(client.authStep).to.equal Dropbox.Client.DONE
              expect(client.isAuthenticated()).to.equal true
              # Verify that we can do API calls.
              client.getUserInfo (error, userInfo) ->
                expect(error).to.equal null
                expect(userInfo).to.be.instanceOf Dropbox.UserInfo
                done()
