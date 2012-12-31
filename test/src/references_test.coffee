describe 'Dropbox.PublicUrl', ->
  describe 'parse', ->
    describe 'on the /shares API example', ->
      beforeEach ->
        urlData = {
          "url": "http://db.tt/APqhX1",
          "expires": "Tue, 01 Jan 2030 00:00:00 +0000"
        }
        @url = Dropbox.PublicUrl.parse urlData, false

      it 'parses url correctly', ->
        expect(@url).to.have.property 'url'
        expect(@url.url).to.equal 'http://db.tt/APqhX1'

      it 'parses expiresAt correctly', ->
        expect(@url).to.have.property 'expiresAt'
        expect(@url.expiresAt).to.be.instanceOf Date
        expect(@url.expiresAt.toUTCString()).to.
            equal 'Tue, 01 Jan 2030 00:00:00 GMT'

      it 'parses isDirect correctly', ->
        expect(@url).to.have.property 'isDirect'
        expect(@url.isDirect).to.equal false

      it 'parses isPreview correctly', ->
        expect(@url).to.have.property 'isPreview'
        expect(@url.isPreview).to.equal true

      assertUrlEquality = (url1, url2) ->
        expect(url1.url).to.equal url2.url
        expect(url1.expiresAt.toString()).to.equal url2.expiresAt.toString()
        expect(url1.isDirect).to.equal url2.isDirect

      it 'round-trips through json / parse correctly', ->
        newUrl = Dropbox.PublicUrl.parse @url.json()
        assertUrlEquality newUrl, @url

    it 'passes null through', ->
      expect(Dropbox.PublicUrl.parse(null)).to.equal null

    it 'passes undefined through', ->
      expect(Dropbox.PublicUrl.parse(undefined)).to.equal undefined


describe 'Dropbox.CopyReference', ->
  describe 'parse', ->
    assertRefEquality = (ref1, ref2) ->
      expect(ref1.tag).to.equal ref2.tag
      expect(ref1.expiresAt.toString()).to.equal ref2.expiresAt.toString()

    describe 'on the API example', ->
      beforeEach ->
        refData = {
          "copy_ref": "z1X6ATl6aWtzOGq0c3g5Ng",
          "expires": "Fri, 31 Jan 2042 21:01:05 +0000"
        }
        @ref = Dropbox.CopyReference.parse refData

      it 'parses tag correctly', ->
        expect(@ref).to.have.property 'tag'
        expect(@ref.tag).to.equal 'z1X6ATl6aWtzOGq0c3g5Ng'

      it 'parses expiresAt correctly', ->
        expect(@ref).to.have.property 'expiresAt'
        expect(@ref.expiresAt).to.be.instanceOf Date
        expect(@ref.expiresAt.toUTCString()).to.
            equal 'Fri, 31 Jan 2042 21:01:05 GMT'

      it 'round-trips through json / parse correctly', ->
        newRef = Dropbox.CopyReference.parse @ref.json()
        assertRefEquality newRef, @ref

    describe 'on a reference string', ->
      beforeEach ->
        rawRef = 'z1X6ATl6aWtzOGq0c3g5Ng'
        @ref = Dropbox.CopyReference.parse rawRef

      it 'parses tag correctly', ->
        expect(@ref).to.have.property 'tag'
        expect(@ref.tag).to.equal 'z1X6ATl6aWtzOGq0c3g5Ng'

      it 'parses expiresAt correctly', ->
        expect(@ref).to.have.property 'expiresAt'
        expect(@ref.expiresAt).to.be.instanceOf Date
        expect(@ref.expiresAt - (new Date())).to.be.below 1000

      it 'round-trips through json / parse correctly', ->
        newRef = Dropbox.CopyReference.parse @ref.json()
        assertRefEquality newRef, @ref

    it 'passes null through', ->
      expect(Dropbox.CopyReference.parse(null)).to.equal null

    it 'passes undefined through', ->
      expect(Dropbox.CopyReference.parse(undefined)).to.equal undefined

