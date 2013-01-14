# Dropbox cache built on IndexedDB.
#
# This cache works in modern browsers that implement the standard IndexedDB
# specification.
class Dropbox.Caches.IndexedDb
  # Sets up an IndexedDB-backed cache.
  #
  # @param {?Object} options one or more of the advanced options below
  # @option options {String} dbName the name of the IndexedDB database used to
  #   store data; the default is 'dropbox_js_cache'
  # @option options {Number} blockSize the size of an atomic file block; the
  #   Dropbox API documentation recommends using a 4MB block size when
  #   uploading files; the default is currently 1MB
  constructor: (options) ->
    @dbName = 'dropbox_js_cache'
    @blockSize = 1 * 1024 * 1024
    if options
      if options.dbName
        @dbName = options.dbName
      if options.blockSize
        @blockSize = options.blockSize

    @_db = null
    @_dbLoadCallbacks = null
    @_iops = {}
    @onDbError = new Dropbox.EventSource
    @onStateChange = new Dropbox.EventSource

  # @property {Dropbox.EventSource<String>} fires non-cancelable events when a
  #   generic database error occurs
  #   error
  onDbError: null

  # @property {Dropbox.EventSource<DropshipFile>} non-cancelable event fired
  #   when IndexedDB file I/O makes progress, completes, or stops due to an
  #   error; this event does not fire when the file I/O is canceled
  onStateChange: null

  # Writes a file's metadata to the cache.
  #
  # @param {Dropbox.Stat} stat the metadata to be stored
  # @param {?Object} extra app-specific metadata stored along the Dropbox
  #   metadata; must be a JSON object, and should be reasonably small
  # @param {function(?DOMError)} callback called when the file's metadata is
  #   persisted; the callback argument is non-null if an error occurred
  # @return {Dropship.Caches.IndexedDb} this
  storeStat: (stat, extra, callback) ->
    if !callback and typeof extra is 'function'
      callback = extra
      extra = null

    @db (db) =>
      transaction = db.transaction 'metadata', 'readwrite'
      metadataStore = transaction.objectStore 'metadata'
      key = stat.path
      entry = stat: stat.json(), extra: extra, at: Date.now()
      request = metadataStore.put entry
      transaction.oncomplete = =>
        callback null
      transaction.onerror = (event) =>
        error = event.target.error
        @onDbError.dispatch error
        callback error
    @

  # Reads a file's metadata from the cache.
  #
  # @param {String} path the file's path, relative to the application's folder
  #   or to the user's Dropbox; this should match the path property of the
  #   Dropbox.Stat passed to storeStat
  # @param {function(?DOMError, ?Dropbox.Stat, ?Object)} callback called when
  #   the file's metadata is available; if the database operation is
  #   successful, the first callback argument will be null; if the cache does
  #   not contain the metadata for the given path, all the callback arguments
  #   will be null
  # @return {Dropship.Caches.IndexedDb} this
  loadStat: (path, callback) ->
    @db (db) =>
      transaction = db.transaction 'metadata', 'read'
      metadataStore = transaction.objectStore 'metadata'
      # TODO(pwnall): normalize path
      request = metadataStore.get path
      request.oncomplete = (event) =>
        entry = event.target.result
        if entry
          callback null, Dropbox.Stat.parse(entry.stat), entry.extra
        else
          # Entry not found.
          callback null, null, null
      request.onerror = (event) =>
        error = event.target.error
        @onDbError.dispatch error
        callback true
    @

  # Removes a file's metadata from the cache.
  #
  # @param {DropshipFile} file the file to be removed
  # @param {function(?DOMError)} callback called when the file's data is
  #   removed; the callback argument is true if an error occurred
  # @return {DropshipList} this
  dropStat: (file, callback) ->
    @db (db) =>
      transaction = db.transaction 'metadata', 'readwrite'
      metadataStore = transaction.objectStore 'metadata'
      if stat.path
        path = stat.path
      else
        # TODO(pwnall): normalize path
        path = stat
      request = metadataStore.delete path
      transaction.oncomplete = =>
        callback null
      transaction.onerror = (event) =>
        error = event.target.error
        @handleDbError event
        callback error
    @

  # Loads all the metadata in the cache.
  #
  # @param {?Object} options one or more of the advanced options below
  # @option options {String} path if set, only metadata for the contents of the
  #   file / folder at the given path is retrieved
  # @option options {Boolean} recursive if true and path is given, the metadata
  #   for files / folders and sub-folders is retrieved
  # @option options {Array} the metadata results will be appended to this
  #   array; by default, a new array will be created to hold the results
  # @param {function(?DOMError, Array<Dropbox.Stat>)} callback called when the
  #   metadata is available; the first callback argument is null if the
  #   operation was successful
  loadFiles: (options, callback) ->
    results = null
    keyRange = null
    if options
      results = options.results if options.results
      if options.path
        path = options.path  # TODO(pwnall): normalize
        if options.recursive
          keyRange = IDBKeyRange.bound path, path, true, false
        else
          # '0' is right after '/', so this covers everything
          keyRange = IDBKeyRange.bound path, path + '0', true, false

    results or= []

    @db (db) =>
      transaction = db.transaction 'metadata', 'readonly'
      metadataStore = transaction.objectStore 'metadata'
      cursor = metadataStore.openCursor null, 'next'
      cursor.onsuccess = (event) =>
        cursor = event.target.result
        if cursor and cursor.key
          request = metadataStore.get cursor.key
          request.onsuccess = (event) =>
            json = event.target.result
            file = new DropshipFile json
            results[file.uid] = file
            cursor.continue()
          request.onerror = (event) =>
            @handleDbError event
            callback true
        else
          callback false
      cursor.onerror = (event) =>
        @handleDbError event
        callback true

  # Stores a file's contents in the database.
  #
  # @param {DropshipFile} file the file whose contents changed
  # @param {Blob} blob the file's contents
  # @param {function(?Error)} callback called when the file's contents is
  #   persisted; the callback argument is true if an error occurred
  # @return {DropshipList} this
  setFileContents: (file, blob, callback) ->
    file.setSaveProgress 0

    fileOffset = 0
    blockId = 0
    blockLoop = =>
      # Special case: we store empty files as 1 empty blob.
      # This lets us distinguish between a non-existing blob and an empty one.
      done = blockId isnt 0 and fileOffset >= file.size
      if done
        file.setSaveSuccess()
        @onStateChange.dispatch file
        return callback(null)

      if fileOffset + @blockSize >= blob.size
        currentBlockSize = blob.size - fileOffset
      else
        currentBlockSize = @blockSize

      blockBlob = blob.slice fileOffset, fileOffset + currentBlockSize
      @setFileBlock file, blockId, blockBlob, (error) =>
        if error
          file.setSaveError error
          @onStateChange.dispatch file
          return callback(error)
        blockId += 1
        fileOffset += currentBlockSize
        file.setSaveProgress fileOffset
        @onStateChange.dispatch file
        blockLoop()
    blockLoop()
    @

  # Stores a block of the file's contents in the database.
  #
  # @param {DropshipFile} file the file whose contents is being stored
  # @param {Number} blockId 0-based block sequence number
  # @param {Blob} blockBlob the contents of the file blob; this is not a Blob
  #   for the entire file
  # @param {function(?Error)} callback called when the file's contents is
  #   persisted; the callback argument is non-null if an error occurred
  # @return {DropshipList} this
  setFileBlock: (file, blockId, blockBlob, callback) ->
    @db (db) =>
      blobKey = @fileBlockKey file, blockId
      transaction = db.transaction 'blocks', 'readwrite'
      blobStore = transaction.objectStore 'blocks'
      try
        request = blobStore.put blockBlob, blobKey
        transaction.oncomplete = =>
          callback null
        transaction.onerror = (event) =>
          callback event.target.error
      catch e
        # Workaround for http://crbug.com/108012
        reader = new FileReader
        reader.onloadend = =>
          return unless reader.readyState == FileReader.DONE
          string = reader.result
          transaction = db.transaction 'blocks', 'readwrite'
          blobStore = transaction.objectStore 'blocks'
          blobStore.put string, blobKey
          transaction.oncomplete = =>
            callback null
          transaction.onerror = (event) =>
            callback event.target.error
        reader.onerror = (event) =>
          callback event.target.error
        reader.readAsBinaryString blockBlob

  # Cancels any pending IndexedDB operation involing a file.
  cancelFileContents: (file, callback) ->
    # TODO(pwnall): implement
    callback()
    @

  # The IndexedDB key for a file's block.
  #
  # @param {DropshipFile} file the file that the block belongs to
  # @param {Number} blockId 0-based block sequence number
  # @return {String} the key associated with the file block in the IndexedDB
  #   "blobs" table
  fileBlockKey: (file, blockId) ->
    # Padding
    stringId = blockId.toString 36
    while stringId.length < 8
      stringId = "0" + stringId

    # - comes right before all valid fileUid symbols in ASCII.
    "#{file.uid}-#{stringId}"

  # An upper bound for the IndexedDB keys for a file's blocks.
  fileMaxBlockKey: (file) ->
    # | comes after all blockId symbols in ASCII.
    "#{file.uid}-|"

  # Retrieves a file's contents from the database.
  #
  # @param {DropshipFile} file the file whose contents will be retrieved
  # @param {function(?Error, ?Blob)} callback called when the file's contents
  #   is available; the argument will be null if the file's contents was not
  #   found in the database
  # @return {DropshipList} this
  getFileContents: (file, callback) ->
    blockBlobs = []
    fileOffset = 0
    blockId = 0
    blockLoop = =>
      # Special case: we store empty files as 1 empty blob.
      # This lets us distinguish between a non-existing blob and an empty one.
      done = blockId isnt 0 and fileOffset >= file.size
      if done
        # NOTE: not reporting save success, the fetcher is responsible for
        #       setting things up
        @onStateChange.dispatch file
        return callback(null, new Blob(blockBlobs, type: blockBlobs[0].type))

      @getFileBlock file, blockId, (error, blockBlob) =>
        if error
          # Read error.
          file.setSaveError error
          @onStateChange.dispatch file
          return callback(error)
        if blockBlob is null
          # Missing block, so report file-not-found.
          return callback(null, null)
        blockBlobs.push blockBlob
        blockId += 1
        fileOffset += blockBlob.size
        file.setSaveProgress fileOffset
        @onStateChange.dispatch file
        blockLoop()
    blockLoop()
    @

  # Retrieves a block of the file's contents from the database.
  #
  # @param {DropshipFile} file the file whose contents will be retrieved
  # @param {Number} blockId 0-based block sequence number
  # @param {function(?Error, ?Blob)} callback called when the block's contents
  #   is available; if the block is not found in the database, both the error
  #   and the blob arguments will be null
  # @return {DropshipList} this
  getFileBlock: (file, blockId, callback) ->
    @db (db) =>
      blobKey = @fileBlockKey file, blockId
      transaction = db.transaction 'blocks', 'readonly'
      blobStore = transaction.objectStore 'blocks'
      request = blobStore.get blobKey
      request.onsuccess = (event) =>
        blockBlob = event.target.result
        unless blockBlob?
          # Incomplete save.
          return callback(null, null)

        # Workaround for http://crbug.com/108012
        if typeof blockBlob is 'string'
          string = blockBlob
          view = new Uint8Array string.length
          for i in [0...string.length]
            view[i] = string.charCodeAt(i) & 0xFF
          blockBlob = new Blob [view], type: 'application/octet-stream'
        callback null, blockBlob
      request.onerror = (event) =>
        callback event.target.error

  # Removes a file's contents from the database.
  #
  # @param {DropshipFile} file the file whose contents will be removed
  # @param {function(Boolean)} callback called when the file's contents is
  #   removed from the database; the callback argument is true if an error
  #   occurred
  # @return {DropshipList} this
  removeFileContents: (file, callback) ->
    @db (db) =>
      transaction = db.transaction 'blocks', 'readwrite'
      blobStore = transaction.objectStore 'blocks'
      keyRange = IDBKeyRange.bound @fileBlockKey(file, 0),
                                   @fileMaxBlockKey(file)
      cursor = blobStore.openCursor keyRange, 'next'
      cursor.onsuccess = (event) =>
        cursor = event.target.result
        if cursor and cursor.key
          request = cursor.delete()
          request.onsuccess = (event) =>
            cursor.continue()
          request.onerror = (event) =>
            callback true
        else
          callback false
      cursor.onerror = (event) =>
        callback true

  # Removes the contents of files whose metadata is missing.
  #
  # File contents and metadata is managed separately. If an attempt to remove a
  # file's contents Blob fails, but the metadata remove succeeds, the Blob
  # becomes stranded, as it will never be accessed again. Vacuuming removes
  # stranded Blobs so the database size doesn't keep growing.
  #
  # @param {function(Boolean)} callback called when the vacuuming completes;
  #   the callback argument is true if an error occurred
  # @return {DropshopList} this
  vacuumFileContents: (callback) ->
    # TODO(pwnall): implement early exit using count() on blobs and metadata
    # TODO(pwnall): implement blob enumeration and kill dangling blobs
    @

  # @param {function(Boolean)} callback called when the vacuuming completes;
  #   the callback argument is true if an error occurred
  # @return {DropshopList} this
  removeDb: (callback) ->
    @db (db) =>
      db.close() if db
      request = indexedDB.deleteDatabase @dbName
      request.oncomplete = =>
        @_db = null
        @_files = null
        callback false
      request.onerror = (event) =>
        @onDbError.dispatch event.target.error
        @_db = null
        @_files = null
        callback true

  # The IndexedDB database caching this extension's files.
  #
  # @param {function(IDBDatabase)} callback called when the database is ready
  #   for use
  # @return {DropshipList} this
  db: (callback) ->
    if @_db
      callback @_db
      return @

    # Queue up the callbacks while the database is being opened.
    if @_dbLoadCallbacks isnt null
      @_dbLoadCallbacks.push callback
      return @
    @_dbLoadCallbacks = [callback]

    request = indexedDB.open @dbName, @dbVersion
    request.onsuccess = (event) =>
      @openedDb event.target.result
    request.onupgradeneeded = (event) =>
      db = event.target.result
      @migrateDb db, event.target.transaction, (error) =>
        if error
          @openedDb null
        else
          @openedDb db
    request.onerror = (event) =>
      @handleDbError event
      @openedDb null
    @

  # Called when the IndexedDB is available for use.
  #
  # @private Called by handlers to IndexedDB events.
  # @param {IDBDatabase} db
  # @return {DropshipList} this
  openedDb: (db) ->
    return unless @_dbLoadCallbacks

    @_db = db
    callbacks = @_dbLoadCallbacks
    @_dbLoadCallbacks = null
    callback db for callback in callbacks
    @

  # Sets up the IndexedDB schema.
  #
  # @private Called by the IndexedDB API.
  #
  # @param {IDBDatabase} db the database connection
  # @param {IDBTransaction} transaction the 'versionchange' transaction
  # @param {function()} callback called when the database is migrated to the
  #   latest schema version
  # @return {DropshipList} this
  migrateDb: (db, transaction, callback) ->
    if db.objectStoreNames.contains 'blocks'
      db.deleteObjectStore 'blocks'
    db.createObjectStore 'blocks'
    if db.objectStoreNames.contains 'metadata'
      db.deleteObjectStore 'metadata'
    db.createObjectStore 'metadata', keyPath: 'uid'
    transaction.oncomplete = =>
      callback false
    transaction.onerror = (event) =>
      @handleDbError event
      callback true
    @

  # Reports IndexedDB errors.
  #
  # The best name for this method would have been 'onDbError', but that's taken
  # by a public API element.
  #
  # @param {#target, #target.error} event the IndexedDB error event
  handleDbError: (event) ->
    error = event.target.error
    # TODO(pwnall): better error string
    errorString = "IndexedDB error: #{error}"
    @onDbError.dispatch errorString

  # IndexedDB schema version.
  dbVersion: 1
