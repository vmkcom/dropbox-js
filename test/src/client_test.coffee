describe 'DropboxClient', ->
  # Creates the global client and test directory.
  setupClient = (test, done) ->
    # True if running on node.js
    test.node_js = module? and module?.exports? and require?
    # Should only be used for fixture teardown.
    test.__client = new Dropbox.Client testKeys
    # All test data should go here.
    test.testFolder = '/js tests.' + Math.random().toString(36)
    test.__client.mkdir test.testFolder, (metadata, error) ->
      expect(error).to.not.be.ok
      done()

  # Creates the binary image file in the test directory.
  setupImageFile = (test, done) ->
    test.imageFile = "#{test.testFolder}/test-binary-image.png"
    test.imageFileData = testImageBytes
    if Blob?
      testImageServerOn()
      Dropbox.Xhr.request2('GET', testImageUrl, {}, null, 'blob',
          (blob, error) =>
            testImageServerOff()
            expect(error).to.not.be.ok
            test.__client.writeFile test.imageFile, blob, (metadata, error) ->
              expect(error).to.not.be.ok
              test.imageFileTag = metadata.rev
              done()
          )
    else
      test.__client.writeFile(test.imageFile, test.imageFileData,
          { binary: true },
          (metadata, error) ->
            expect(error).to.not.be.ok
            test.imageFileTag = metadata.rev
            done()
          )

  # Creates the plaintext file in the test directory.
  setupTextFile = (test, done) ->
    test.textFile = "#{test.testFolder}/test-file.txt"
    test.textFileData = "Plaintext test file #{Math.random().toString(36)}.\n"
    test.__client.writeFile(test.textFile, test.textFileData,
        (metadata, error) ->
          expect(error).to.not.be.ok
          test.textFileTag = metadata.rev
          done()
        )

  # Global (expensive) fixtures.
  before (done) ->
    @timeout 10 * 1000
    setupClient this, =>
      setupImageFile this, =>
        setupTextFile this, ->
          done()

  # Teardown for global fixtures.
  after (done) ->
    @__client.remove @testFolder, (metadata, error) ->
      expect(error).to.not.be.ok
      done()

  # Per-test (cheap) fixtures.
  beforeEach ->
    @timeout 8 * 1000
    @client = new Dropbox.Client testKeys

  describe 'URLs for custom API server', ->
    it 'computes the other URLs correctly', ->
      client = new Dropbox.Client
        key: testKeys.key,
        secret: testKeys.secret,
        server: 'https://api.sandbox.dropbox-proxy.com'

      expect(client.apiServer).to.equal(
        'https://api.sandbox.dropbox-proxy.com')
      expect(client.authServer).to.equal(
        'https://www.sandbox.dropbox-proxy.com')
      expect(client.fileServer).to.equal(
        'https://api-content.sandbox.dropbox-proxy.com')

  describe 'normalizePath', ->
    it "doesn't touch relative paths", ->
      expect(@client.normalizePath('aa/b/cc/dd')).to.equal 'aa/b/cc/dd'

    it 'removes the leading / from absolute paths', ->
      expect(@client.normalizePath('/aaa/b/cc/dd')).to.equal 'aaa/b/cc/dd'

    it 'removes multiple leading /s from absolute paths', ->
      expect(@client.normalizePath('///aa/b/ccc/dd')).to.equal 'aa/b/ccc/dd'

  describe 'urlEncodePath', ->
    it 'encodes each segment separately', ->
      expect(@client.urlEncodePath('a b+c/d?e"f/g&h')).to.
          equal "a%20b%2Bc/d%3Fe%22f/g%26h"
    it 'normalizes paths', ->
      expect(@client.urlEncodePath('///a b+c/g&h')).to.
          equal "a%20b%2Bc/g%26h"

  describe 'isCopyRef', ->
    it 'recognizes the copyRef in the API example', ->
      expect(@client.isCopyRef('z1X6ATl6aWtzOGq0c3g5Ng')).to.equal true

    it 'rejects paths starting with /', ->
      expect(@client.isCopyRef('/z1X6ATl6aWtzOGq0c3g5Ng')).to.equal false

    it 'rejects paths containing /', ->
      expect(@client.isCopyRef('z1X6ATl6aWtzOGq0c3g5N/g')).to.equal false

    it 'rejects paths containing .', ->
      expect(@client.isCopyRef('z1X6ATl6aWtzOGq0c3g5N.g')).to.equal false

  describe 'authenticate', ->
    it 'completes the flow', (done) ->
      @timeout 30 * 1000  # Time-consuming because the user must click.
      @client.reset()
      @client.authDriver authDriverUrl, authDriver
      @client.authenticate (uid, error) ->
        expect(error).to.not.be.ok
        expect(uid).to.be.a 'string'
        done()

  describe 'getUserInfo', ->
    it 'returns reasonable information', (done) ->
      @client.getUserInfo (userInfo, error) ->
        expect(error).to.not.be.ok
        expect(userInfo).to.have.property 'uid'
        expect(userInfo.uid.toString()).to.equal testKeys.uid
        expect(userInfo).to.have.property 'referral_link'
        expect(userInfo).to.have.property 'display_name'
        done()

  describe 'mkdir', ->
    afterEach (done) ->
      return done() unless @newFolder
      @client.remove @newFolder, (metadata, error) -> done()

    it 'creates a folder in the test folder', (done) ->
      @newFolder = "#{@testFolder}/test'folder"
      @client.mkdir @newFolder, (metadata, error) =>
        expect(error).not.to.be.ok
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal @newFolder
        @client.stat @newFolder, (metadata, error) =>
          expect(metadata).to.have.property 'is_dir'
          expect(metadata.is_dir).to.equal true
          done()

  describe 'readFile', ->
    it 'reads a text file', (done) ->
      @client.readFile @textFile, (data, error) =>
        expect(error).to.not.be.ok
        expect(data).to.equal @textFileData
        done()

    it 'reads a binary file into a string', (done) ->
      @client.readFile @imageFile, { binary: true }, (data, error) =>
        expect(error).to.not.be.ok
        expect(data).to.equal @imageFileData
        done()

    it 'reads a binary file into a Blob', (done) ->
      return done() unless Blob?
      @client.readFile @imageFile, { blob: true }, (blob, error) =>
          expect(error).to.not.be.ok
          expect(blob).to.be.instanceOf Blob
          reader = new FileReader
          reader.onloadend = =>
            return unless reader.readyState == FileReader.DONE
            expect(reader.result).to.equal @imageFileData
            done()
          reader.readAsBinaryString blob

  describe 'writeFile', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (metadata, error) -> done()

    it 'writes a new text file', (done) ->
      @newFile = "#{@testFolder}/another text file.txt"
      @newFileData = "Another plaintext file #{Math.random().toString(36)}."
      @client.writeFile @newFile, @newFileData, (metadata, error) =>
        expect(error).to.not.be.ok
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal @newFile
        @client.readFile @newFile, (data, error) =>
          expect(error).to.not.be.ok
          expect(data).to.equal @newFileData
          done()

    # TODO(pwnall): tests for writing binary files


  describe 'stat', ->
    it 'retrieves metadata for a file', (done) ->
      @client.stat @textFile, (metadata, error) =>
        expect(error).not.to.be.ok
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal @textFile
        expect(metadata).to.have.property 'is_dir'
        expect(metadata.is_dir).to.equal false
        done()

    it 'retrieves metadata for a folder', (done) ->
      @client.stat @testFolder, (metadata, error) =>
        expect(error).not.to.be.ok
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal @testFolder
        expect(metadata).to.have.property 'is_dir'
        expect(metadata.is_dir).to.equal true
        expect(metadata).not.to.have.property 'contents'
        done()

    it 'retrieves metadata and entries for a folder', (done) ->
      @client.stat @testFolder, { readDir: true }, (metadata, error) =>
        expect(error).not.to.be.ok
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal @testFolder
        expect(metadata).to.have.property 'is_dir'
        expect(metadata.is_dir).to.equal true
        expect(metadata).to.have.property 'contents'
        expect(metadata.contents).to.have.length 2
        done()


  describe 'history', ->
    it 'gets a list of revisions', (done) ->
      @client.history @textFile, (versions, error) =>
        expect(error).not.to.be.ok
        expect(versions).to.have.length 1
        expect(versions[0]).to.have.property 'path'
        expect(versions[0].path).to.equal @textFile
        expect(versions[0]).to.have.property 'rev'
        expect(versions[0].rev).to.equal @textFileTag
        done()

  describe 'copy', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (metadata, error) -> done()

    it 'copies a file given by path', (done) ->
      @newFile = "#{@testFolder}/copy of test-file.txt"
      @client.copy @textFile, @newFile, (metadata, error) =>
        expect(error).not.to.be.ok
        expect(metadata.path).to.equal @newFile
        @client.readFile @newFile, (data, error) =>
          expect(error).not.to.be.ok
          expect(data).to.equal @textFileData
          done()

  describe 'makeCopyReference', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (metadata, error) -> done()

    it 'creates a reference that can be used for copying', (done) ->
      @newFile = "#{@testFolder}/ref copy of test-file.txt"

      @client.makeCopyReference @textFile, (refInfo, error) =>
        expect(error).not.to.be.ok
        expect(refInfo).to.have.property 'copy_ref'
        expect(refInfo.copy_ref).to.be.a 'string'
        @client.copy refInfo.copy_ref, @newFile, (metadata, error) =>
          expect(error).not.to.be.ok
          expect(metadata).to.have.property 'path'
          expect(metadata.path).to.equal @newFile
          @client.readFile @newFile, (data, error) =>
            expect(error).not.to.be.ok
            expect(data).to.equal @textFileData
            done()

  describe 'move', ->
    beforeEach (done) ->
      @moveFrom = "#{@testFolder}/move source of test-file.txt"
      @client.copy @textFile, @moveFrom, (metadata, error) ->
        expect(error).not.to.be.ok
        done()

    afterEach (done) ->
      @client.remove @moveFrom, (metadata, error) =>
        return done() unless @moveTo
        @client.remove @moveTo, (metadata, error) -> done()

    it 'moves a file', (done) ->
      @moveTo = "#{@testFolder}/moved test-file.txt"
      @client.move @moveFrom, @moveTo, (metadata, error) =>
        expect(error).not.to.be.ok
        expect(metadata.path).to.equal @moveTo
        @client.readFile @moveTo, (data, error) =>
          expect(error).not.to.be.ok
          expect(data).to.equal @textFileData
          @client.readFile @moveFrom, (data, error) ->
            expect(error).to.be.ok
            expect(error).to.have.property 'status'
            if @node_js
              # Can't read errors in the browser, due to CORS server bugs.
              expect(error).status.to.equal 404
            done()

  describe 'remove', ->
    beforeEach (done) ->
      @newFolder = "#{@testFolder}/folder delete test"
      @client.mkdir @newFolder, (metadata, error) ->
        expect(error).not.to.be.ok
        done()

    afterEach (done) ->
      return done() unless @newFolder
      @client.remove @newFolder, (metadata, error) -> done()

    it 'deletes a folder', (done) ->
      @client.remove @newFolder, (metadata, error) =>
        expect(error).not.to.be.ok
        expect(metadata).to.be.an 'object'
        expect(metadata).to.have.property 'path'
        expect(metadata.path).to.equal @newFolder
        @client.stat @newFolder, (metadata, error) =>
          expect(error).not.to.be.ok
          expect(metadata).to.have.property 'is_deleted'
          expect(metadata.is_deleted).to.equal true
          ###
          expect(error).to.have.property 'status'
          if @node_js
            # Can't read errors in the browser, due to CORS server bugs.
            expect(error).status.to.equal 404
          ###
          done()

  describe 'revertFile', ->
    describe 'on a removed file', ->
      beforeEach (done) ->
        @newFile = "#{@testFolder}/file revert test.txt"
        @client.copy @textFile, @newFile, (metadata, error) =>
          expect(error).not.to.be.ok
          @client.remove @newFile, (metadata, error) =>
            expect(error).not.to.be.ok
            expect(metadata).to.have.property 'rev'
            expect(metadata.rev).to.be.a 'string'
            @versionTag = metadata.rev
            done()

      afterEach (done) ->
        return done() unless @newFile
        @client.remove @newFile, (metadata, error) -> done()

      it 'reverts the file to a previous version', (done) ->
        @client.revertFile @newFile, @versionTag, (metadata, error) =>
          expect(error).not.to.be.ok
          expect(metadata).to.have.property 'rev'
          expect(metadata.rev).to.equal @versionTag
          expect(metadata).to.have.property 'path'
          expect(metadata.path).to.equal @newFile
          @client.readFile @newFile, (data, error) =>
            expect(error).not.to.be.ok
            expect(data).to.equal @textFileData
            done()

  describe 'findByName', ->
    it 'locates the test folder given a partial name', (done) ->
      namePattern = @testFolder.substring 5
      @client.search '/', namePattern, (matches, error) =>
        expect(error).not.to.be.ok
        expect(matches).to.have.length 1
        expect(matches[0]).to.have.property 'path'
        expect(matches[0].path).to.equal @testFolder
        done()

  describe 'makeUrl for a short Web URL', ->
    it 'returns a shortened Dropbox URL', (done) ->
      @client.makeUrl @textFile, (urlData, error) ->
        expect(error).not.to.be.ok
        expect(urlData).to.have.property 'url'
        expect(urlData.url).to.contain '//db.tt/'
        done()

  describe 'makeUrl for a Web URL', ->
    it 'returns an URL to a preview page', (done) ->
      @client.makeUrl @textFile, { long: true }, (urlData, error) =>
        expect(error).not.to.be.ok
        expect(urlData).to.have.property 'url'
        
        # The contents server does not return CORS headers.
        return done() unless @nodejs
        Dropbox.Xhr.request 'GET', urlData.url, {}, null, (data, error) ->
          expect(error).not.to.be.ok
          expect(data).to.contain '<!DOCTYPE html>'
          done()

  describe 'makeUrl for a direct download URL', ->
    it 'gets a direct download URL', (done) ->
      @client.makeUrl @textFile, { download: true }, (urlData, error) =>
        expect(error).not.to.be.ok
        expect(urlData).to.have.property 'url'

        # The contents server does not return CORS headers.
        return done() unless @nodejs
        Dropbox.Xhr.request 'GET', urlData.url, {}, null, (data, error) =>
          expect(error).not.to.be.ok
          expect(data).to.equal @textFileData
          done()

  describe 'pullChanges', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (metadata, error) -> done()

    it 'gets a cursor, then it gets relevant changes', (done) ->
      @client.pullChanges (changeInfo, error) =>
        expect(error).not.to.be.ok
        expect(changeInfo).to.have.property 'reset'
        expect(changeInfo.reset).to.equal true
        expect(changeInfo).to.have.property 'cursor'
        expect(changeInfo.cursor).to.be.a 'string'
        expect(changeInfo).to.have.property 'entries'
        cursor = changeInfo.cursor

        # Calls pullChanges until it's done listing the user's Dropbox.
        @timeout 15 * 1000  # Pulling the entire Dropbox takes time :( 
        drainEntries = (client, callback) ->
          return callback() unless changeInfo.has_more
          client.pullChanges changeInfo.cursor, (_changeInfo, error) ->
            expect(error).not.to.be.ok
            changeInfo = _changeInfo
            drainEntries client, callback
        drainEntries @client, =>

          @newFile = "#{@testFolder}/delta-test.txt"
          newFileData = "This file is used to test the pullChanges method.\n"
          @client.writeFile @newFile, newFileData, (metadata, error) =>
            expect(error).not.to.be.ok
            expect(metadata).to.have.property 'path'
            expect(metadata.path).to.equal @newFile

            @client.pullChanges cursor, (changeInfo, error) =>
              expect(error).not.to.be.ok
              expect(changeInfo).to.have.property 'reset'
              expect(changeInfo.reset).to.equal false
              expect(changeInfo).to.have.property 'cursor'
              expect(changeInfo.cursor).not.to.equal cursor
              expect(changeInfo).to.have.property 'entries'
              expect(changeInfo.entries).to.have.length.greaterThan 0
              entry = changeInfo.entries.length - 1
              expect(changeInfo.entries[entry]).to.have.length 2
              expect(changeInfo.entries[entry][1]).to.have.property 'path'
              expect(changeInfo.entries[entry][1].path).to.equal @newFile
              done()

  describe 'thumbnailUrl', ->
    it 'produces an URL that contains the file name', ->
      url = @client.thumbnailUrl @imageFile, { png: true, size: 'medium' }
      expect(url).to.contain 'tests'  # Fragment of the file name.
      expect(url).to.contain 'png'
      expect(url).to.contain 'medium'

  describe 'readThumbnail', ->
    it 'reads the image into a string', (done) ->
      @client.readThumbnail @imageFile, { png: true }, (data, error) =>
        expect(error).to.not.be.ok
        expect(data).to.be.a 'string'
        expect(data).to.contain 'PNG'
        done()

    it 'reads the image into a Blob', (done) ->
      return done() unless Blob?
      options = { png: true, blob: true }
      @client.readThumbnail @imageFile, options, (blob, error) =>
          expect(error).to.not.be.ok
          expect(blob).to.be.instanceOf Blob
          reader = new FileReader
          reader.onloadend = =>
            return unless reader.readyState == FileReader.DONE
            expect(reader.result).to.contain 'PNG'
            done()
          reader.readAsBinaryString blob

