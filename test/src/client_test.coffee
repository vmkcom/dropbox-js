describe 'DropboxClient', ->
  # Creates the global client and test directory.
  setupClient = (test, done) ->
    # True if running on node.js
    test.node_js = module? and module?.exports? and require?
    # Should only be used for fixture teardown.
    test.__client = new Dropbox.Client testKeys
    # All test data should go here.
    test.testFolder = '/js tests.' + Math.random().toString(36)
    test.__client.mkdir test.testFolder, (error, stat) ->
      expect(error).to.equal undefined
      done()

  # Creates the binary image file in the test directory.
  setupImageFile = (test, done) ->
    test.imageFile = "#{test.testFolder}/test-binary-image.png"
    test.imageFileData = testImageBytes
    if Blob?
      testImageServerOn()
      Dropbox.Xhr.request2('GET', testImageUrl, {}, null, 'blob',
          (error, blob) =>
            testImageServerOff()
            expect(error).to.equal undefined
            test.__client.writeFile test.imageFile, blob, (error, stat) ->
              expect(error).to.equal undefined
              test.imageFileTag = stat.rev
              done()
          )
    else
      test.__client.writeFile(test.imageFile, test.imageFileData,
          { binary: true },
          (error, stat) ->
            expect(error).to.equal undefined
            test.imageFileTag = stat.versionTag
            done()
          )

  # Creates the plaintext file in the test directory.
  setupTextFile = (test, done) ->
    test.textFile = "#{test.testFolder}/test-file.txt"
    test.textFileData = "Plaintext test file #{Math.random().toString(36)}.\n"
    test.__client.writeFile(test.textFile, test.textFileData,
        (error, stat) ->
          expect(error).to.equal undefined
          test.textFileTag = stat.versionTag
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
    @__client.remove @testFolder, (error, stat) ->
      expect(error).to.equal undefined
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
      @client.authenticate (error, uid) ->
        expect(error).to.equal undefined
        expect(uid).to.be.a 'string'
        done()

  describe 'getUserInfo', ->
    it 'returns reasonable information', (done) ->
      @client.getUserInfo (error, userInfo) ->
        expect(error).to.equal undefined
        expect(userInfo).to.have.property 'uid'
        expect(userInfo.uid.toString()).to.equal testKeys.uid
        expect(userInfo).to.have.property 'referral_link'
        expect(userInfo).to.have.property 'display_name'
        done()

  describe 'mkdir', ->
    afterEach (done) ->
      return done() unless @newFolder
      @client.remove @newFolder, (error, stat) -> done()

    it 'creates a folder in the test folder', (done) ->
      @newFolder = "#{@testFolder}/test'folder"
      @client.mkdir @newFolder, (error, stat) =>
        expect(error).to.equal undefined
        expect(stat).to.be.instanceOf Dropbox.Stat
        expect(stat.path).to.equal @newFolder
        expect(stat.isFolder).to.equal true
        @client.stat @newFolder, (error, stat) =>
          expect(error).to.equal undefined
          expect(stat.isFolder).to.equal true
          done()

  describe 'readFile', ->
    it 'reads a text file', (done) ->
      @client.readFile @textFile, (error, data, stat) =>
        expect(error).to.equal undefined
        expect(data).to.equal @textFileData
        if @node_js
          # Stat is not available in the browser due to CORS restrictions.
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @textFile
          expect(stat.isFile).to.equal true
        done()

    it 'reads a binary file into a string', (done) ->
      @client.readFile @imageFile, { binary: true }, (error, data, stat) =>
        expect(error).to.equal undefined
        expect(data).to.equal @imageFileData
        if @node_js
          # Stat is not available in the browser due to CORS restrictions.
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        done()

    it 'reads a binary file into a Blob', (done) ->
      return done() unless Blob?
      @client.readFile @imageFile, { blob: true }, (error, blob, stat) =>
        expect(error).to.equal undefined
        expect(blob).to.be.instanceOf Blob
        if @node_js
          # Stat is not available in the browser due to CORS restrictions.
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        reader = new FileReader
        reader.onloadend = =>
          return unless reader.readyState == FileReader.DONE
          expect(reader.result).to.equal @imageFileData
          done()
        reader.readAsBinaryString blob

  describe 'writeFile', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'writes a new text file', (done) ->
      @newFile = "#{@testFolder}/another text file.txt"
      @newFileData = "Another plaintext file #{Math.random().toString(36)}."
      @client.writeFile @newFile, @newFileData, (error, stat) =>
        expect(error).to.equal undefined
        expect(stat).to.be.instanceOf Dropbox.Stat
        expect(stat.path).to.equal @newFile
        expect(stat.isFile).to.equal true
        @client.readFile @newFile, (error, data, stat) =>
          expect(error).to.equal undefined
          expect(data).to.equal @newFileData
          if @node_js
            # Stat is not available in the browser due to CORS restrictions.
            expect(stat).to.be.instanceOf Dropbox.Stat
            expect(stat.path).to.equal @newFile
            expect(stat.isFile).to.equal true
          done()

    # TODO(pwnall): tests for writing binary files


  describe 'stat', ->
    it 'retrieves a Stat for a file', (done) ->
      @client.stat @textFile, (error, stat) =>
        expect(error).to.equal undefined
        expect(stat).to.be.instanceOf Dropbox.Stat
        expect(stat.path).to.equal @textFile
        expect(stat.isFile).to.equal true
        expect(stat.versionTag).to.equal @textFileTag
        expect(stat.size).to.equal @textFileData.length
        expect(stat.inAppFolder).to.equal false
        done()

    it 'retrieves a Stat for a folder', (done) ->
      @client.stat @testFolder, (error, stat, entries) =>
        expect(error).to.equal undefined
        expect(stat).to.be.instanceOf Dropbox.Stat
        expect(stat.path).to.equal @testFolder
        expect(stat.isFolder).to.equal true
        expect(stat.size).to.equal 0
        expect(stat.inAppFolder).to.equal false
        expect(entries).to.equal undefined
        done()

    it 'retrieves a Stat and entries for a folder', (done) ->
      @client.stat @testFolder, { readDir: true }, (error, stat, entries) =>
        expect(error).to.equal undefined
        expect(stat).to.be.instanceOf Dropbox.Stat
        expect(stat.path).to.equal @testFolder
        expect(stat.isFolder).to.equal true
        expect(entries).to.be.ok
        expect(entries).to.have.length 2
        expect(entries[0]).to.be.instanceOf Dropbox.Stat
        expect(entries[0].path).not.to.equal @testFolder
        expect(entries[0].path).to.have.string @testFolder
        done()


  describe 'history', ->
    it 'gets a list of revisions', (done) ->
      @client.history @textFile, (error, versions) =>
        expect(error).to.equal undefined
        expect(versions).to.have.length 1
        expect(versions[0]).to.be.instanceOf Dropbox.Stat
        expect(versions[0].path).to.equal @textFile
        expect(versions[0].size).to.equal @textFileData.length
        expect(versions[0].versionTag).to.equal @textFileTag
        done()

  describe 'copy', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'copies a file given by path', (done) ->
      @newFile = "#{@testFolder}/copy of test-file.txt"
      @client.copy @textFile, @newFile, (error, stat) =>
        expect(error).to.equal undefined
        expect(stat).to.be.instanceOf Dropbox.Stat
        expect(stat.path).to.equal @newFile
        @client.readFile @newFile, (error, data, stat) =>
          expect(error).to.equal undefined
          expect(data).to.equal @textFileData
          if @node_js
            # Stat is not available in the browser due to CORS restrictions.
            expect(stat).to.be.instanceOf Dropbox.Stat
            expect(stat.path).to.equal @newFile
          @client.readFile @textFile, (error, data, stat) =>
            expect(error).to.equal undefined
            expect(data).to.equal @textFileData
            if @node_js
              # Stat is not available in the browser due to CORS restrictions.
              expect(stat).to.be.instanceOf Dropbox.Stat
              expect(stat.path).to.equal @textFile
              expect(stat.versionTag).to.equal @textFileTag
            done()

  describe 'makeCopyReference', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'creates a reference that can be used for copying', (done) ->
      @newFile = "#{@testFolder}/ref copy of test-file.txt"

      @client.makeCopyReference @textFile, (error, refInfo) =>
        expect(error).to.equal undefined
        expect(refInfo).to.have.property 'copy_ref'
        expect(refInfo.copy_ref).to.be.a 'string'
        @client.copy refInfo.copy_ref, @newFile, (error, stat) =>
          expect(error).to.equal undefined
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @newFile
          expect(stat.isFile).to.equal true
          @client.readFile @newFile, (error, data, stat) =>
            expect(error).to.equal undefined
            expect(data).to.equal @textFileData
            if @node_js
              # Stat is not available in the browser due to CORS restrictions.
              expect(stat).to.be.instanceOf Dropbox.Stat
              expect(stat.path).to.equal @newFile
            done()

  describe 'move', ->
    beforeEach (done) ->
      @moveFrom = "#{@testFolder}/move source of test-file.txt"
      @client.copy @textFile, @moveFrom, (error, stat) ->
        expect(error).to.equal undefined
        done()

    afterEach (done) ->
      @client.remove @moveFrom, (error, stat) =>
        return done() unless @moveTo
        @client.remove @moveTo, (error, stat) -> done()

    it 'moves a file', (done) ->
      @moveTo = "#{@testFolder}/moved test-file.txt"
      @client.move @moveFrom, @moveTo, (error, stat) =>
        expect(error).to.equal undefined
        expect(stat).to.be.instanceOf Dropbox.Stat
        expect(stat.path).to.equal @moveTo
        expect(stat.isFile).to.equal true
        @client.readFile @moveTo, (error, data, stat) =>
          expect(error).to.equal undefined
          expect(data).to.equal @textFileData
          if @node_js
            # Stat is not available in the browser due to CORS restrictions.
            expect(stat).to.be.instanceOf Dropbox.Stat
            expect(stat.path).to.equal @moveTo
          @client.readFile @moveFrom, (error, data, stat) ->
            expect(error).to.be.ok
            expect(error).to.have.property 'status'
            if @node_js
              # Can't read errors in the browser, due to CORS server bugs.
              expect(error).status.to.equal 404
            expect(data).to.equal undefined
            expect(stat).to.equal undefined
            done()

  describe 'remove', ->
    beforeEach (done) ->
      @newFolder = "#{@testFolder}/folder delete test"
      @client.mkdir @newFolder, (error, stat) ->
        expect(error).to.equal undefined
        done()

    afterEach (done) ->
      return done() unless @newFolder
      @client.remove @newFolder, (error, stat) -> done()

    it 'deletes a folder', (done) ->
      @client.remove @newFolder, (error, stat) =>
        expect(error).to.equal undefined
        expect(stat).to.be.an 'object'
        expect(stat).to.have.property 'path'
        expect(stat.path).to.equal @newFolder
        @client.stat @newFolder, { removed: true }, (error, stat) =>
          expect(error).to.equal undefined
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.isRemoved).to.equal true
          done()

  describe 'revertFile', ->
    describe 'on a removed file', ->
      beforeEach (done) ->
        @newFile = "#{@testFolder}/file revert test.txt"
        @client.copy @textFile, @newFile, (error, stat) =>
          expect(error).to.equal undefined
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @newFile
          @versionTag = stat.versionTag
          @client.remove @newFile, (error, stat) =>
            expect(error).to.equal undefined
            expect(stat).to.be.instanceOf Dropbox.Stat
            expect(stat.path).to.equal @newFile
            done()

      afterEach (done) ->
        return done() unless @newFile
        @client.remove @newFile, (error, stat) -> done()

      it 'reverts the file to a previous version', (done) ->
        @client.revertFile @newFile, @versionTag, (error, stat) =>
          expect(error).to.equal undefined
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @newFile
          expect(stat.isRemoved).to.equal false
          @client.readFile @newFile, (error, data, stat) =>
            expect(error).to.equal undefined
            expect(data).to.equal @textFileData
            if @node_js
              # Stat is not available in the browser due to CORS restrictions.
              expect(stat).to.be.instanceOf Dropbox.Stat
              expect(stat.path).to.equal @newFile
              expect(stat.isRemoved).to.equal false
            done()

  describe 'findByName', ->
    it 'locates the test folder given a partial name', (done) ->
      namePattern = @testFolder.substring 5
      @client.search '/', namePattern, (error, matches) =>
        expect(error).to.equal undefined
        expect(matches).to.have.length 1
        expect(matches[0]).to.be.instanceOf Dropbox.Stat
        expect(matches[0].path).to.equal @testFolder
        expect(matches[0].isFolder).to.equal true
        done()

  describe 'makeUrl for a short Web URL', ->
    it 'returns a shortened Dropbox URL', (done) ->
      @client.makeUrl @textFile, (error, urlData) ->
        expect(error).to.equal undefined
        expect(urlData).to.have.property 'url'
        expect(urlData.url).to.contain '//db.tt/'
        done()

  describe 'makeUrl for a Web URL', ->
    it 'returns an URL to a preview page', (done) ->
      @client.makeUrl @textFile, { long: true }, (error, urlData) =>
        expect(error).to.equal undefined
        expect(urlData).to.have.property 'url'
        
        # The contents server does not return CORS headers.
        return done() unless @nodejs
        Dropbox.Xhr.request 'GET', urlData.url, {}, null, (error, data) ->
          expect(error).to.equal undefined
          expect(data).to.contain '<!DOCTYPE html>'
          done()

  describe 'makeUrl for a direct download URL', ->
    it 'gets a direct download URL', (done) ->
      @client.makeUrl @textFile, { download: true }, (error, urlData) =>
        expect(error).to.equal undefined
        expect(urlData).to.have.property 'url'

        # The contents server does not return CORS headers.
        return done() unless @nodejs
        Dropbox.Xhr.request 'GET', urlData.url, {}, null, (error, data) =>
          expect(error).to.equal undefined
          expect(data).to.equal @textFileData
          done()

  describe 'pullChanges', ->
    afterEach (done) ->
      return done() unless @newFile
      @client.remove @newFile, (error, stat) -> done()

    it 'gets a cursor, then it gets relevant changes', (done) ->
      @client.pullChanges (error, changeInfo) =>
        expect(error).to.equal undefined
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
          client.pullChanges changeInfo.cursor, (error, _changeInfo) ->
            expect(error).to.equal undefined
            changeInfo = _changeInfo
            drainEntries client, callback
        drainEntries @client, =>

          @newFile = "#{@testFolder}/delta-test.txt"
          newFileData = "This file is used to test the pullChanges method.\n"
          @client.writeFile @newFile, newFileData, (error, stat) =>
            expect(error).to.equal undefined
            expect(stat).to.have.property 'path'
            expect(stat.path).to.equal @newFile

            @client.pullChanges cursor, (error, changeInfo) =>
              expect(error).to.equal undefined
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
      @timeout 12 * 1000  # Thumbnail generation is slow.
      @client.readThumbnail @imageFile, { png: true }, (error, data, stat) =>
        expect(error).to.equal undefined
        expect(data).to.be.a 'string'
        expect(data).to.contain 'PNG'
        if @node_js
          # Stat is not available in the browser due to CORS restrictions.
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        done()

    it 'reads the image into a Blob', (done) ->
      return done() unless Blob?
      @timeout 12 * 1000  # Thumbnail generation is slow.
      options = { png: true, blob: true }
      @client.readThumbnail @imageFile, options, (error, blob, stat) =>
        expect(error).to.equal undefined
        expect(blob).to.be.instanceOf Blob
        if @node_js
          # Stat is not available in the browser due to CORS restrictions.
          expect(stat).to.be.instanceOf Dropbox.Stat
          expect(stat.path).to.equal @imageFile
          expect(stat.isFile).to.equal true
        reader = new FileReader
        reader.onloadend = =>
          return unless reader.readyState == FileReader.DONE
          expect(reader.result).to.contain 'PNG'
          done()
          reader.readAsBinaryString blob

