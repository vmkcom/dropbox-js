describe 'DropboxXhr', ->
  beforeEach ->
    @node_js = module? and module?.exports? and require?

  describe '#request', ->
    it 'reports errors correctly', (done) ->
      @url = 'https://api.dropbox.com/1/oauth/request_token'
      Dropbox.Xhr.request('POST',
        @url, {}, null,
        (error, data) =>
          expect(data).to.equal undefined
          expect(error).to.be.instanceOf Dropbox.ApiError
          expect(error).to.have.property 'url'
          expect(error.url).to.equal @url
          expect(error).to.have.property 'method'
          expect(error.method).to.equal 'POST'
          expect(error).to.have.property 'status'
          expect(error).to.have.property 'responseText'
          expect(error).to.have.property 'response'
          expect(error.status).to.equal 401  # Bad OAuth request.
          expect(error.responseText).to.be.a 'string'
          expect(error.response).to.be.an 'object'
          expect(error.toString()).to.match /^Dropbox API error/
          expect(error.toString()).to.contain 'POST'
          expect(error.toString()).to.contain @url
          done()
        )

    it 'processes data correctly', (done) ->
      key = testKeys.key
      secret = testKeys.secret
      timestamp = Math.floor(Date.now() / 1000).toString()
      params =
          oauth_consumer_key: testKeys.key
          oauth_nonce: '_' + timestamp
          oauth_signature: testKeys.secret + '&'
          oauth_signature_method: 'PLAINTEXT'
          oauth_timestamp: timestamp
          oauth_version: '1.0'

      xhr = Dropbox.Xhr.request('POST',
        'https://api.dropbox.com/1/oauth/request_token',
        params,
        null,
        (error, data) ->
          expect(error).to.not.be.ok
          expect(data).to.have.property 'oauth_token'
          expect(data).to.have.property 'oauth_token_secret'
          done()
        )
      expect(xhr).to.be.instanceOf(Dropbox.Xhr.Request)

    describe 'with a binary response', ->
      beforeEach ->
        testImageServerOn()

      afterEach ->
        testImageServerOff()

    it 'sends Authorize headers correctly', (done) ->
      return done() if Dropbox.Xhr.ieMode  # IE's XDR doesn't set headers.

      key = testKeys.key
      secret = testKeys.secret
      timestamp = Math.floor(Date.now() / 1000).toString()
      oauth_header = "OAuth oauth_consumer_key=\"#{key}\",oauth_nonce=\"_#{timestamp}\",oauth_signature=\"#{secret}%26\",oauth_signature_method=\"PLAINTEXT\",oauth_timestamp=\"#{timestamp}\",oauth_version=\"1.0\""

      xhr = Dropbox.Xhr.request('POST',
          'https://api.dropbox.com/1/oauth/request_token', {}, oauth_header,
          (error, data) ->
            expect(error).to.equal null
            expect(data).to.have.property 'oauth_token'
            expect(data).to.have.property 'oauth_token_secret'
            done()
          )
      expect(xhr).to.be.instanceOf(Dropbox.Xhr.Request)

  describe '#request2', ->
    beforeEach ->
      testImageServerOn()

    afterEach ->
      testImageServerOff()

    it 'retrieves a string where each character is a byte', (done) ->
      xhr = Dropbox.Xhr.request2('GET', testImageUrl, {}, null, null, 'b',
          (error, data) ->
            expect(error).to.not.be.ok
            expect(data).to.be.a 'string'
            expect(data).to.equal testImageBytes
            done()
          )
      assert.ok xhr instanceof Dropbox.Xhr.Request,
        'Incorrect request2 return value'

    it 'retrieves a well-formed Blob', (done) ->
      # Skip this test on IE < 10.
      return done() unless Blob?
      xhr = Dropbox.Xhr.request2('GET', testImageUrl, {}, null, null, 'blob',
          (error, blob) ->
            expect(error).to.not.be.ok
            expect(blob).to.be.instanceOf Blob
            reader = new FileReader
            reader.onloadend = ->
              return unless reader.readyState == FileReader.DONE
              expect(reader.result).to.equal testImageBytes
              done()
            reader.readAsBinaryString blob
          )
      assert.ok xhr instanceof Dropbox.Xhr.Request,
        'Incorrect request2 return value'

  describe '#urlEncode', ->
    it 'iterates properly', ->
      expect(Dropbox.Xhr.urlEncode({foo: 'bar', baz: 5})).to.
        equal 'baz=5&foo=bar'
    it 'percent-encodes properly', ->
      expect(Dropbox.Xhr.urlEncode({'a +x()': "*b'"})).to.
        equal 'a%20%2Bx%28%29=%2Ab%27'

  describe '#urlDecode', ->
    it 'iterates properly', ->
      decoded = Dropbox.Xhr.urlDecode('baz=5&foo=bar')
      expect(decoded['baz']).to.equal '5'
      expect(decoded['foo']).to.equal 'bar'
    it 'percent-decodes properly', ->
      decoded = Dropbox.Xhr.urlDecode('a%20%2Bx%28%29=%2Ab%27')
      expect(decoded['a +x()']).to.equal "*b'"

