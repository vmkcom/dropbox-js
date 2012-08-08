# Represents a user accessing the application.
class DropboxClient
  # Dropbox client representing an application.
  #
  # For an optimal user experience, applications should use a single client for
  # all Dropbox interactions.
  #
  # @param {Object} options the application type and API key
  # @option {Boolean} sandbox true for applications that request sandbox access
  #     (access to a single folder exclusive to the app)
  # @option {String} key the application's API key
  # @option {String} secret the application's API secret
  # @option {String} token if set, the user's access token
  # @option {String} tokenSecret if set, the secret for the user's access token
  # @option {String} uid if set, the user's Dropbox UID
  constructor: (options) ->
    @sandbox = options.sandbox or false
    @oauth = new DropboxOauth options
    @uid = options.uid or null

    @apiServer = options.server or 'https://api.dropbox.com'
    @authServer = options.authServer or @apiServer.replace('api.', 'www.')
    @fileServer = options.fileServer or
        @apiServer.replace('api.', 'api-content.')
    
    @setupUrls()

  # Plugs in the authentication driver.
  #
  # @param {String} url the URL that will be used for OAuth callback; the
  #     application must be able to intercept this URL and obtain the query
  #     string provided by Dropbox
  # @param {function(String, function(String))} driver the implementation of
  #     the authorization flow; the function should redirect the user to the
  #     URL received as the first argument, wait for the user to be redirected
  #     to the URL provded to authCallback, and then call the supplied function
  #     with
  # @return {Dropbox.Client} this, for easy call chaining
  authDriver: (url, driver) ->
    @authDriverUrl = url
    @authDriver = driver
    @

  # OAuth credentials.
  #
  # @return {Object} a plain object whose properties can be passed to the
  #     Dropbox.Client constructor to reuse this client's login credentials
  credentials: ->
    value =
      key: @oauth.key
      secret: @oauth.secret
      sandbox: @sandbox
    if @oauth.token
      value.token = @oauth.token
      value.tokenSecret = @oauth.tokenSecret
      value.uid = @uid
    value
      
  # Authenticates the app's user to Dropbox' API server.
  #
  # @param {function(?Dropbox.ApiError, ?String)} callback called when the
  #     authentication completes; if successful, the second parameter is the
  #     user's Dropbox user id, which is guaranteed to be consistent across
  #     API calls from the same application (not across applications, though),
  #     and the first parameter is undefined
  # @return {Dropbox.Client} this, for easy call chaining
  authenticate: (callback) ->
    @requestToken (error, data) =>
      if error
        callback error
        return
      token = data.oauth_token
      tokenSecret = data.oauth_token_secret
      @oauth.setToken token, tokenSecret
      @authDriver @authorizeUrl(token), (url) =>
        @getAccessToken (error, data) =>
          if error
            @reset()
            callback error
            return
          token = data.oauth_token
          tokenSecret = data.oauth_token_secret
          @oauth.setToken token, tokenSecret
          @uid = data.uid
          callback undefined, data.uid
    @

  # Retrieves information about the logged in user.
  #
  # @params {function(?Dropbox.ApiError, ?Dropbox.UserInfo)} callback called
  #     with the result of the /account/info HTTP request; if the call
  #     succeeds, the second parameter is a Dropbox.UserInfo instance, and the
  #     first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  getUserInfo: (callback) ->
    url = @urls.accountInfo
    params = @oauth.addAuthParams 'GET', url, {}
    DropboxXhr.request('GET', url, params, null,
        (error, userData) -> callback error, DropboxUserInfo.parse(userData))

  # Retrieves the contents of a file stored in Dropbox.
  #
  # @param {String} path the path of the file to be read, relative to the
  #     user's Dropbox or to the application's folder
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {String} versionTag the tag string for the desired version
  #     of the file contents; the most recent version is retrieved by default
  # @option options {String} rev alias for "versionTag" that matches the HTTP
  #     API
  # @option options {Boolean} blob if true, the file will be retrieved as a
  #     Blob, instead of a String; this requires XHR Level 2 support, which is
  #     not available in IE <= 9
  # @option options {Boolean} binary if true, the file will be retrieved as a
  #     binary string; the default is an UTF-8 encoded string
  # @param {function(?Dropbox.ApiError, ?String, ?Dropbox.Stat)} callback
  #     called with the result of the /files (GET) HTTP request; the second
  #     parameter is the contents of the file, the third parameter is a
  #     Dropbox.Stat instance describing the file, and the first parameter is
  #     undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  readFile: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    url = "#{@urls.getFile}/#{@urlEncodePath(path)}"
    
    params = {}
    responseType = null
    if options
      if options.versionTag
        params.rev = options.versionTag
      else if options.rev
        params.rev = options.rev
      if options.blob
        responseType = 'blob'
      if options.binary
        responseType = 'b'  # See the Dropbox.Xhr.request2 docs
    @oauth.addAuthParams 'GET', url, params
    # TODO: read the metadata from the x-dropbox-metadata header
    DropboxXhr.request2('GET', url, params, null, responseType,
        (error, data, metadata) ->
          callback error, data, DropboxStat.parse(metadata))

  # Store a file into a user's Dropbox.
  #
  # @param {String} path the path of the file to be created, relative to the
  #     user's Dropbox or to the application's folder
  # @param {String} data the contents to be written
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {String} lastVersionTag the identifier string for the
  #     version of the file's contents that was last read by this program, used
  #     for conflict resolution; for best results, use the versionTag attribute
  #     value from the Dropbox.Stat instance provided by readFile
  # @option options {String} parentRev alias for "lastVersionTag" that matches
  #     the HTTP API
  # @option options {Boolean} noOverwrite if set, the write will not overwrite
  #      a file with the same name that already exsits; instead the contents
  #      will be written to a similarly named file (e.g. "notes (1).txt"
  #      instead of "notes.txt")
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat)} callback called with
  #     the result of the /files (POST) HTTP request; the second paramter is a
  #     Dropbox.Stat instance describing the newly created file, and the first
  #     parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  writeFile: (path, data, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null
    
    # Break down the path into a file/folder name and the containing folder.
    slashIndex = path.lastIndexOf '/'
    if slashIndex is -1
      fileName = path
      path = ''
    else
      fileName = path.substring slashIndex
      path = path.substring 0, slashIndex

    url = "#{@urls.postFile}/#{@urlEncodePath(path)}"
    params = { file: fileName }
    if options
      if options.noOverwrite
        params.overwrite = 'false'
      if options.lastVersionTag
        params.parent_rev = options.lastVersionTag
      else if options.parentRev or options.parent_rev
        params.parent_rev = options.parentRev or options.parent_rev
    # TODO: locale support would edit the params here
    @oauth.addAuthParams 'POST', url, params
    # NOTE: the Dropbox API docs ask us to replace the 'file' parameter after
    #       signing the request; the code below works as intended
    delete params.file
    
    fileField =
      name: 'file',
      value: data,
      fileName: fileName
      contentType: 'application/octet-stream'
    DropboxXhr.multipartRequest(url, fileField, params, null,
        (error, metadata) -> callback error, DropboxStat.parse(metadata))

  # Reads the metadata of a file or folder in a user's Dropbox.
  #
  # @param {String} path the path to the file or folder whose metadata will be
  #     read, relative to the user's Dropbox or to the application's folder
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {Number} version if set, the call will return the metadata
  #     for the given revision of the file / folder; the latest version is used
  #     by default
  # @option {Boolean} removed if set to true, the results will include files
  #     and folders that were deleted from the user's Dropbox
  # @option {Boolean} deleted alias for "removed" that matches the HTTP API;
  #     using this alias is not recommended, because it may cause confusion
  #     with JavaScript's delete operation
  # @option options {Boolean, Number} readDir only meaningful when stat-ing
  #     folders; if this is set, the API call will also retrieve the folder's
  #     contents, which is passed into the callback's third parameter; if this
  #     is a number, it specifies the maximum number of files and folders that
  #     should be returned; the default limit is 10,000 items; if the limit is
  #     exceeded, the call will fail with an error
  # @option options {String} versionTag used for saving bandwidth when getting
  #     a folder's contents; if this value is specified and it matches the
  #     folder's contents, the call will fail with a 304 (Contents not changed)
  #     error code; a folder's version identifier can be obtained from the
  #     versionTag attribute of a Dropbox.Stat instance describing it
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat, ?Array<Dropbox.Stat>)}
  #     callback called with the result of the /metadata HTTP request; if the
  #     call succeeds, the second parameter is a Dropbox.Stat instance
  #     describing the file / folder, and the first parameter is undefined;
  #     if the readDir option is true and the call succeeds, the third
  #     parameter is an array of Dropbox.Stat instances describing the folder's
  #     entries
  # @return {XMLHttpRequest} the XHR object used for this API call
  stat: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    url = "#{@urls.metadata}/#{@urlEncodePath(path)}"  
    params = {}
    if options
      if options.version?
        params.rev = options.version
      if options.removed or options.deleted
        params.include_deleted = 'true'
      if options.readDir
        params.list = 'true'
        if options.readDir isnt true
          params.file_limit = options.readDir.toString()
      if options.cacheHash
        params.hash = options.cacheHash
    params.include_deleted ||= 'false'
    params.list ||= 'false'
    # TODO: locale support would edit the params here
    @oauth.addAuthParams 'GET', url, params
    DropboxXhr.request('GET', url, params, null,
        (error, metadata) ->
          stat = DropboxStat.parse metadata
          if metadata?.contents
            entries = (DropboxStat.parse(entry) for entry in metadata.contents)
          else
            entries = undefined
          callback error, stat, entries
        )

  # Lists the files and folders inside a folder in a user's Dropbox.
  #
  # @param {String} path the path to the folder whose contents will be
  #     retrieved, relative to the user's Dropbox or to the application's
  #     folder
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option {Boolean} removed if set to true, the results will include files
  #     and folders that were deleted from the user's Dropbox
  # @option {Boolean} deleted alias for "removed" that matches the HTTP API;
  #     using this alias is not recommended, because it may cause confusion
  #     with JavaScript's delete operation
  # @option options {Boolean, Number} limit the maximum number of files and
  #     folders that should be returned; the default limit is 10,000 items; if
  #     the limit is exceeded, the call will fail with an error
  # @option options {String} versionTag used for saving bandwidth; if this
  #     option is specified, and its value matches the folder's version tag,
  #     the call will fail with a 304 (Contents not changed) error code
  #     instead of returning the contents; a folder's version identifier can be
  #     obtained from the versionTag attribute of a Dropbox.Stat instance
  #     describing it
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat, ?Array<Dropbox.Stat>)}
  #     callback called with the result of the /metadata HTTP request; if the
  #     call succeeds, the second parameter is a Dropbox.Stat instance
  #     describing the file / folder, the third parameter is an array of
  #     Dropbox.Stat instances describing the folder's entries, and the first
  #     parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  readdir: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    statOptions = { readDir: true }
    if options
      if options.limit
        statOptions.readDir = options.limit
      if options.versionTag
        statOptions.versionTag = options.versionTag
    @stat path, statOptions, callback


  # Alias for "stat" that matches the HTTP API.
  metadata: (path, options, callback) ->
    @stat path, options, callback

  # Creates a publicly readable URL to a file or folder in the user's Dropbox.
  #
  # @param {String} path the path to the file or folder that will be linked to;
  #     the path is relative to the user's Dropbox or to the application's
  #     folder
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {Boolean} download if set, the URL will be a direct
  #     download URL, instead of the usual Dropbox preview URLs; direct
  #     download URLs are short-lived (currently 4 hours), whereas regular URLs
  #     virtually have no expiration date (currently set to 2030); no didrect
  #     downlaod URLs can be generated for directories
  # @option options {Boolean} long if set, the URL will not be shortened using
  #     Dropbox's shortner; direct download URLs aren't shortened by default
  # @param {function(?Dropbox.ApiError, ?Dropbox.PublicUrl)} callback called
  #     with the result of the /shares or /media HTTP request; if the call
  #     succeeds, the second parameter is a Dropbox.PublicUrl instance, and the
  #     first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  makeUrl: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null
    
    path = @urlEncodePath path
    if options and options.download
      isDirect = true
      url = "#{@urls.media}/#{path}"
    else
      isDirect = false
      url = "#{@urls.shares}/#{path}"

    if options and options.long
      params = { short_url: 'false' }
    else
      params = {}
    # TODO: locale support would edit the params here
    @oauth.addAuthParams 'POST', url, params
    DropboxXhr.request('POST', url, params, null,
        (error, urlData) ->
          callback error, DropboxPublicUrl.parse(urlData, isDirect))

  # Retrieves the revision history of a file in a user's Dropbox.
  #
  # @param {String} path the path to the file whose revision history will be
  #     retrieved, relative to the user's Dropbox or to the application's
  #     folder
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {Number} limit if specified, the call will return at most
  #     this many versions
  # @param {function(?Dropbox.ApiError, ?Array<Dropbox.Stat>)} callback called
  #     with the result of the /revisions HTTP request; if the call succeeds,
  #     the second parameter is an array with one Dropbox.Stat instance per
  #     file version, and the first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  history: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    url = "#{@urls.revisions}/#{@urlEncodePath(path)}"
    params = {}
    if options and options.limit?
      params.rev_limit = revLimit
    @oauth.addAuthParams 'GET', url, params
    DropboxXhr.request('GET', url, params, null,
        (error, versions) ->
          if versions
            stats = (DropboxStat.parse(metadata) for metadata in versions)
          else
            stats = undefined
          callback error, stats
        )

  # Alias for "history" that matches the HTTP API.
  revisions: (path, options, callback) ->
    @history path, options, callback
    

  # Computes a URL that generates a thumbnail for a file in the user's Dropbox.
  #
  # @param {String} path the path to the file whose thumbnail image URL will be
  #     computed, relative to the user's Dropbox or to the application's
  #     folder
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {Boolean} png if true, the thumbnail's image will be a PNG
  #     file; the default thumbnail format is JPEG
  # @option options {String} format value that gets passed directly to the API;
  #     this is intended for newly added formats that the API may not support;
  #     use options such as "png" when applicable
  # @option options {String} sizeCode specifies the image's dimensions; this
  #     gets passed directly to the API; currently, the following values are
  #     supported: 'small' (32x32), 'medium' (64x64), 'large' (128x128),
  #     's' (64x64), 'm' (128x128), 'l' (640x480), 'xl' (1024x768); the default
  #     value is "small"
  # @return {String} a URL to an image that can be used as the thumbnail for
  #     the given file
  thumbnailUrl: (path, options) ->
    url = "#{@urls.thumbnails}/#{@urlEncodePath(path)}"
    params = {}
    if options
      if options.format
        params.format = options.format
      else if options.png
        params.format = 'png'
      if options.size
        # Can we do something nicer here?
        params.size = options.size
    @oauth.addAuthParams 'GET', url, params
    "#{url}?#{Dropbox.Xhr.urlEncode(params)}"

  # Retrieves the image data of a thumbnail for a file in the user's Dropbox.
  #
  # This method is intended to be used with low-level painting APIs. Whenever
  # possible, it is easier to place the result of thumbnailUrl in a DOM
  # element, and rely on the browser to fetch the file.
  #
  # @param {String} path the path to the file whose thumbnail image URL will be
  #     computed, relative to the user's Dropbox or to the application's
  #     folder
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {Boolean} png if true, the thumbnail's image will be a PNG
  #     file; the default thumbnail format is JPEG
  # @option options {String} format value that gets passed directly to the API;
  #     this is intended for newly added formats that the API may not support;
  #     use options such as "png" when applicable
  # @option options {String} sizeCode specifies the image's dimensions; this
  #     gets passed directly to the API; currently, the following values are
  #     supported: 'small' (32x32), 'medium' (64x64), 'large' (128x128),
  #     's' (64x64), 'm' (128x128), 'l' (640x480), 'xl' (1024x768); the default
  #     value is "small"
  # @option options {Boolean} blob if true, the file will be retrieved as a
  #     Blob, instead of a String; this requires XHR Level 2 support, which is
  #     not available in IE <= 9
  # @param {function(?Dropbox.ApiError, ?Object, ?Dropbox.Stat)} callback
  #     called with the result of the /thumbnails HTTP request; if the call
  #     succeeds, the second parameter is the image data as a String or Blob,
  #     the third parameter is a Dropbox.Stat instance describing the
  #     thumbnailed file, and the first argument is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  readThumbnail: (path, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    url = @thumbnailUrl path, options

    responseType = 'b'
    if options
      responseType = 'blob' if options.blob
    DropboxXhr.request2('GET', url, {}, null, responseType,
        (error, data, metadata) ->
          callback error, data, DropboxStat.parse(metadata))

  # Reverts a file's contents to a previous version.
  #
  # This is an atomic, bandwidth-optimized equivalent of reading the file
  # contents at the given file version (readFile), and then using it to
  # overwrite the file (writeFile).
  #
  # @param {String} path the path to the file whose contents will be reverted
  #     to a previous version, relative to the user's Dropbox or to the
  #     application's folder
  # @param {String} versionTag the tag of the version that the file will be
  #     reverted to; maps to the "rev" parameter in the HTTP API
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat)} callback called with
  #     the result of the /restore HTTP request; if the call succeeds, the
  #     second parameter is a Dropbox.Stat instance describing the file after
  #     the revert operation, and the first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  revertFile: (path, versionTag, callback) ->
    url = "#{@urls.restore}/#{@urlEncodePath(path)}"
    params = { rev: versionTag }
    @oauth.addAuthParams 'POST', url, params
    DropboxXhr.request('POST', url, params, null,
        (error, metadata) -> callback error, DropboxStat.parse(metadata))

  # Alias for "revertFile" that matches the HTTP API.
  restore: (path, versionTag, callback) ->
    @revertFile path, versionTag, callback

  # Finds files / folders whose name match a pattern, in the user's Dropbox.
  #
  # @param {String} path the path to the file whose contents will be reverted
  #     to a previous version, relative to the user's Dropbox or to the
  #     application's folder
  # @param {String} namePattern the string that file / folder names must
  #     contain in order to match the search criteria;
  # @param {?Object} options the advanced settings below; for the default
  #     settings, skip the argument or pass null
  # @option options {Number} limit if specified, the call will return at most
  #     this many versions
  # @option {Boolean} removed if set to true, the results will include files
  #     and folders that were deleted from the user's Dropbox; the default
  #     limit is the maximum value of 1,000
  # @option {Boolean} deleted alias for "removed" that matches the HTTP API;
  #     using this alias is not recommended, because it may cause confusion
  #     with JavaScript's delete operation
  # @param {function(?Dropbox.ApiError, ?Array<Dropbox.Stat>)} callback called
  #     with the result of the /search HTTP request; if the call succeeds, the
  #     second parameter is an array with one Dropbox.Stat instance per search
  #     result, and the first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  findByName: (path, namePattern, options, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null

    url = "#{@urls.search}/#{@urlEncodePath(path)}"
    params = { query: namePattern }
    if options
      if options.limit?
        params.file_limit = limit
      if options.removed or options.deleted
        params.include_deleted = true
    @oauth.addAuthParams 'GET', url, params
    DropboxXhr.request('GET', url, params, null,
        (error, results) ->
          if results
            stats = (DropboxStat.parse(metadata) for metadata in results)
          else
            stats = undefined
          callback error, stats
        )

  # Alias for "findByName" that matches the HTTP API.
  search: (path, namePattern, options, callback) ->
    @findByName path, namePattern, options, callback

  # Creates a reference used to copy a file to another user's Dropbox.
  #
  # @param {String} path the path to the file whose contents will be
  #     referenced, relative to the uesr's Dropbox or to the application's
  #     folder
  # @param {function(?Dropbox.ApiError, ?Dropbox.CopyReference)} callback
  #     called with the result of the /copy_ref HTTP request; if the call
  #     succeeds, the second parameter is a Dropbox.CopyReference instance, and
  #     the first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  makeCopyReference: (path, callback) ->
    url = "#{@urls.copyRef}/#{@urlEncodePath(path)}"
    params = @oauth.addAuthParams 'GET', url, {}
    DropboxXhr.request('GET', url, params, null,
        (error, refData) ->
          callback error, DropboxCopyReference.parse(refData))

  # Alias for "makeCopyReference" that matches the HTTP API.
  copyRef: (path, callback) ->
    @makeCopyReference path, callback

  # Fetches a list of changes in the user's Dropbox since the last call.
  #
  # This method is intended to make full sync implementations easier and more
  # performant. Each call returns a cursor that can be used in a future call
  # to obtain all the changes that happened in the user's Dropbox (or
  # application directory) between the two calls.
  #
  # @param {Dropbox.PulledChanges, String} cursorTag the result of a previous
  #     call to pullChanges, or a string containing a tag representing the
  #     Dropbox state that is used as the baseline for the change list; this
  #     should be obtained from a previous call to pullChanges, or be set to
  #     null / ommitted on the first call to pullChanges
  # @param {function(?Dropbox.ApiError, ?Dropbox.PulledChanges)} callback
  #     called with the result of the /delta HTTP request; if the call
  #     succeeds, the second parameter is a Dropbox.PulledChanges describing
  #     the changes to the user's Dropbox since the pullChanges call that
  #     produced the given cursor, and the first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  pullChanges: (cursor, callback) ->
    if (not callback) and (typeof cursor is 'function')
      callback = cursor
      cursor = null

    url = @urls.delta
    params = {}
    if cursor
      if cursor.cursorTag
        params = { cursor: cursor.cursorTag }
      else
        params = { cursor: cursor }
    else
      params = {}
    @oauth.addAuthParams 'POST', url, params
    DropboxXhr.request('POST', url, params, null,
        (error, deltaInfo) -> callback error,
          Dropbox.PulledChanges.parse(deltaInfo))

  # Alias for "pullChanges" that matches the HTTP API.
  delta: (cursor, callback) ->
    @pullChanges cursor, callback

  # Creates a folder in a user's Dropbox.
  #
  # @param {String} path the path of the folder that will be created, relative
  #     to the user's Dropbox or to the application's folder
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat)} callback called with
  #     the result of the /fileops/create_folder HTTP request; if the call
  #     succeeds, the second parameter is a Dropbox.Stat instance describing
  #     the newly created folder, and the first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  mkdir: (path, callback) ->
    url = @urls.fileopsCreateFolder
    params = { root: @fileRoot, path: @normalizePath(path) }
    @oauth.addAuthParams 'POST', url, params
    DropboxXhr.request('POST', url, params, null,
        (error, metadata) -> callback error, DropboxStat.parse(metadata))

  # Removes a file or diretory from a user's Dropbox.
  #
  # @param {String} path the path of the file to be read, relative to the
  #     user's Dropbox or to the application's folder
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat)} callback called with
  #     the result of the /fileops/delete HTTP request; if the call succeeds,
  #     the second parameter is a Dropbox.Stat instance describing the removed
  #     file or folder, and the first parameter is undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  remove: (path, callback) ->
    url = @urls.fileopsDelete
    params = { root: @fileRoot, path: @normalizePath(path)  }
    @oauth.addAuthParams 'POST', url, params
    DropboxXhr.request('POST', url, params, null,
        (error, metadata) -> callback error, DropboxStat.parse(metadata))

  # Copies a file or folder in the user's Dropbox.
  #
  # This method's "from" parameter can be either a path or a copy reference
  # obtained by a previous call to makeCopyRef. The method uses a crude
  # heuristic to interpret the "from" string -- if it doesn't contain any
  # slash (/) or dot (.) character, it is assumed to be a copy reference. The
  # easiest way to work with it is to prepend "/" to every path passed to the
  # method. The method will process paths that start with multiple /s
  # correctly.
  #
  # @param {String, Dropbox.CopyReference} from the path of the file or folder
  #     that will be copied, or a Dropbox.CopyReference instance obtained by
  #     calling makeCopyRef or Dropbox.CopyReference.parse; if this is a path,
  #     it is relative to the user's Dropbox or to the application's folder
  # @param {String} toPath the path that the file or folder will have after
  #     the method call; the path is relative to the user's Dropbox or to the
  #     application folder
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat)} callback called with
  #     the result of the /fileops/copy HTTP request; if the call succeeds, the
  #     second parameter is a Dropbox.Stat instance describing the file or
  #     folder created by the copy operation, and the first parameter is
  #     undefined
  # @return {XMLHttpRequest} the XHR object used for this API call
  copy: (from, toPath, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null
    
    params = { root: @fileRoot, to_path: @normalizePath(toPath) }
    if from instanceof DropboxCopyReference
      params.from_copy_ref = from.tag
    else
      params.from_path = @normalizePath from
    # TODO: locale support would edit the params here

    url = @urls.fileopsCopy
    @oauth.addAuthParams 'POST', url, params
    DropboxXhr.request('POST', url, params, null,
        (error, metadata) -> callback error, DropboxStat.parse(metadata))

  # Moves a file or folder to a different location in a user's Dropbox.
  #
  # @param {String} fromPath the path of the file or folder that will be moved,
  #     relative to the user's Dropbox or to the application's folder
  # @param {String} toPath the path that the file or folder will have after
  #     the method call; the path is relative to the user's Dropbox or to the
  #     application's folder
  # @param {function(?Dropbox.ApiError, ?Dropbox.Stat)} callback called with
  #     the result of the /fileops/move HTTP request; if the call succeeds, the
  #     second parameter is a Dropbox.Stat instance describing the moved
  #     file or folder at its new location, and the first parameter is
  #     undefined 
  # @return {XMLHttpRequest} the XHR object used for this API call
  move: (fromPath, toPath, callback) ->
    if (not callback) and (typeof options is 'function')
      callback = options
      options = null
    
    fromPath = @normalizePath fromPath
    toPath = @normalizePath toPath
    url = @urls.fileopsMove
    params = { root: @fileRoot, from_path: fromPath, to_path: toPath }
    @oauth.addAuthParams 'POST', url, params
    DropboxXhr.request('POST', url, params, null,
        (error, metadata) -> callback error, DropboxStat.parse(metadata))

  # Removes all login information.
  #
  # @return {Dropbox.Client} this, for easy call chaining
  reset: ->
    @uid = null
    @oauth.setToken null, ''
    @

  # Computes the URLs of all the Dropbox API calls.
  #
  # @private
  # This is called by the constructor, and used by the other methods. It should
  # not be used directly.
  setupUrls: ->
    @fileRoot = if @sandbox then 'sandbox' else 'dropbox'
    
    @urls = 
      # Authentication.
      requestToken: "#{@apiServer}/1/oauth/request_token"
      authorize: "#{@authServer}/1/oauth/authorize"
      accessToken: "#{@apiServer}/1/oauth/access_token"
      
      # Accounts.
      accountInfo: "#{@apiServer}/1/account/info"
      
      # Files and metadata.
      getFile: "#{@fileServer}/1/files/#{@fileRoot}"
      postFile: "#{@fileServer}/1/files/#{@fileRoot}"
      putFile: "#{@fileServer}/1/files_put/#{@fileRoot}"
      metadata: "#{@apiServer}/1/metadata/#{@fileRoot}"
      delta: "#{@apiServer}/1/delta"
      revisions: "#{@apiServer}/1/revisions/#{@fileRoot}"
      restore: "#{@apiServer}/1/restore/#{@fileRoot}"
      search: "#{@apiServer}/1/search/#{@fileRoot}"
      shares: "#{@apiServer}/1/shares/#{@fileRoot}"
      media: "#{@apiServer}/1/media/#{@fileRoot}"
      copyRef: "#{@apiServer}/1/copy_ref/#{@fileRoot}"
      thumbnails: "#{@fileServer}/1/thumbnails/#{@fileRoot}"
      
      # File operations.
      fileopsCopy: "#{@apiServer}/1/fileops/copy"
      fileopsCreateFolder: "#{@apiServer}/1/fileops/create_folder"
      fileopsDelete: "#{@apiServer}/1/fileops/delete"
      fileopsMove: "#{@apiServer}/1/fileops/move" 

  # Normalizes a Dropobx path and encodes it for inclusion in a request URL.
  urlEncodePath: (path) ->
    DropboxXhr.urlEncodeValue(@normalizePath(path)).replace /%2F/gi, '/'

  # Normalizes a Dropbox path for API requests.
  #
  # @private
  # This is an internal method. It is used by all the client methods that take
  # paths as arguments.
  #
  # @param {String} path a path 
  normalizePath: (path) ->
    if path.substring(0, 1) is '/'
      i = 1
      while path.substring(i, i + 1) is '/'
        i += 1
      path.substring i
    else
      path

  # Really low-level call to /oauth/request_token
  #
  # @private
  # This a low-level method called by authorize. Users should call authorize.
  #
  # @param {function(error, data)} callback called with the result of the
  #    /oauth/request_token HTTP request
  requestToken: (callback) ->
    params = @oauth.addAuthParams 'POST', @urls.requestToken, {}
    DropboxXhr.request 'POST', @urls.requestToken, params, null, callback
  
  # The URL for /oauth/authorize, embedding the user's token.
  #
  # @private
  # This a low-level method called by authorize. Users should call authorize.
  #
  # @param {String} token the oauth_token obtained from an /oauth/request_token
  #     call
  # @return {String} the URL that the user's browser should be redirected to
  #     in order to perform an /oauth/authorize request
  authorizeUrl: (token) ->
    params = { oauth_token: token, oauth_callback: @authDriverUrl }
    "#{@urls.authorize}?" + DropboxXhr.urlEncode(params)

  # Exchanges an OAuth request token with an access token.
  #
  # @private
  # This a low-level method called by authorize. Users should call authorize.
  #
  # @param {function(error, data)} callback called with the result of the
  #    /oauth/access_token HTTP request
  getAccessToken: (callback) ->
    params = @oauth.addAuthParams 'POST', @urls.accessToken, {}
    DropboxXhr.request 'POST', @urls.accessToken, params, null, callback

