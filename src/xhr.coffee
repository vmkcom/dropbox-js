if window?
  if window.XDomainRequest and not ('withCredentials' of new XMLHttpRequest())
    DropboxXhrRequest = window.XDomainRequest
    DropboxXhrIeMode = true
    # IE's XDR doesn't allow setting requests' Content-Type to anything other
    # than text/plain, so it can't send _any_ forms.
    DropboxXhrCanSendForms = false
  else
    DropboxXhrRequest = window.XMLHttpRequest
    DropboxXhrIeMode = false
    # Firefox doesn't support adding named files to FormData.
    # https://bugzilla.mozilla.org/show_bug.cgi?id=690659
    DropboxXhrCanSendForms =
      window.navigator.userAgent.indexOf('Firefox') is -1
else
  # Node.js needs an adapter for the XHR API.
  DropboxXhrRequest = require('xmlhttprequest').XMLHttpRequest
  DropboxXhrIeMode = false
  # Node.js can definitely send forms, but we don't want it to, because it
  # isn't subject to CORS and the same origin policy
  DropboxXhrCanSendForms = false

# Dispatches low-level AJAX calls (XMLHttpRequests).
class DropboxXhr
  # The object used to perform AJAX requests (XMLHttpRequest).
  @Request = DropboxXhrRequest
  # Set to true when using the XDomainRequest API.
  @ieMode = DropboxXhrIeMode
  # Set to true if the browser has proper support for FormData.
  @canSendForms = DropboxXhrCanSendForms

  # Sends off a AJAX request (XMLHttpRequest).
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #     'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #     that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #     request parameters
  # @param {String} authHeader the value of the Authorization header
  # @param {function(?Dropbox.ApiError, ?Object, ?Object)} callback called when
  #     the XHR completes; if an error occurs, the first parameter will be a
  #     Dropbox.ApiError instance; otherwise, the second parameter will be an
  #     instance of the required response type (e.g., String, Blob), and the
  #     third parameter will be the JSON-parsed 'x-dropbox-metadata' header
  # @return {XMLHttpRequest} the XHR object used for this request
  @request: (method, url, params, authHeader, callback) ->
    @request2 method, url, params, authHeader, null, null, callback

  # Sends off an AJAX request and requests a custom response type.
  #
  # This method requires XHR Level 2 support, which is not available in IE
  # versions <= 9. If these browsers must be supported, it is recommended to
  # check whether window.Blob is truthy, and fallback to the plain "request"
  # method otherwise.
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #     'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #     that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #     request parameters
  # @param {String} authHeader the value of the Authorization header
  # @param {?Object} body the body to be sent in a non-GET request; should be
  #     an ArrayBuffer, Blob, or String
  # @param {String} responseType the value that will be assigned to the XHR's
  #     responseType property
  # @param {function(?Dropbox.ApiError, ?Object, ?Object)} callback called when
  #     the XHR completes; if an error occurs, the first parameter will be a
  #     Dropbox.ApiError instance; otherwise, the second parameter will be an
  #     instance of the required response type (e.g., String, Blob), and the
  #     third parameter will be the JSON-parsed 'x-dropbox-metadata' header
  # @return {XMLHttpRequest} the XHR object used for this request
  @request2: (method, url, params, authHeader, body, responseType, callback) ->
    paramsInUrl = method is 'GET' or body? or @ieMode
    if paramsInUrl
      queryString = DropboxXhr.urlEncode params
      if queryString.length isnt 0
        url = [url, '?', DropboxXhr.urlEncode(params)].join ''
    headers = {}
    if authHeader
      headers['Authorization'] = authHeader
    if body?
      if typeof body is 'string'
        headers['Content-Type'] = 'text/plain; charset=utf8'
    else if !paramsInUrl
      headers['Content-Type'] = 'application/x-www-form-urlencoded'
      body = DropboxXhr.urlEncode params
    DropboxXhr.xhrRequest method, url, headers, body, responseType, callback

  # Upload a file via a mulitpart/form-data method.
  #
  # This is a one-off method for POST /files. It is rather unwieldy, but it
  # lets us skip CORS preflight and write binary files in one HTTP request,
  # given good browser support.
  #
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #     that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #     request parameters
  # @param {String} fieldName the name of the form field whose value is
  #     submitted in the multipart/form-data body
  # @param {String} data the file content to be uploaded
  # @param {String} authHeader the value of the Authorization header
  # @param {function(?Dropbox.ApiError, ?Object, ?Object)} callback called when
  #     the XHR completes; if an error occurs, the first parameter will be a
  #     Dropbox.ApiError instance; otherwise, the second parameter will be an
  #     instance of the required response type (e.g., String, Blob), and the
  #     third parameter will be the JSON-parsed 'x-dropbox-metadata' header
  # @return {XMLHttpRequest} the XHR object used for this request
  @multipartRequest: (url, fileField, params, authHeader, callback) ->
    url = [url, '?', DropboxXhr.urlEncode(params)].join ''

    fileData = fileField.value
    useFormData = (typeof(fileData) is 'object') and
        ((Blob? and (fileField.value instanceof Blob)) or
         (File? and (fileField.value instanceof File)))

    if useFormData
      headers = {}
      body = new FormData()
      body.append fileField.name, fileData, fileField.fileName
    else
      fileType = fileField.contentType or 'application/octet-stream'
      boundary = @multipartBoundary()
      headers = { 'Content-Type': "multipart/form-data; boundary=#{boundary}" }
      body = ['--', boundary, "\r\n",
              'Content-Disposition: form-data; name="', fileField.name,
                  '"; filename="', fileField.fileName, "\"\r\n",
              'Content-Type: ', fileType, "\r\n",
              "Content-Transfer-Encoding: binary\r\n\r\n",
              fileData,
              "\r\n", '--', boundary, '--', "\r\n"].join ''
    if authHeader
      headers['Authorization'] = authHeader
    DropboxXhr.xhrRequest 'POST', url, headers, body, null, callback

  # Generates a bounday suitable for separating multipart data.
  #
  # @return {String} boundary suitable for multipart form data
  @multipartBoundary: ->
    [Date.now().toString(36),
     Math.random().toString(36)].join '----'

  # Implementation for request and multipartRequest.
  #
  # @see request2, multipartRequest
  # @return {XMLHttpRequest} the XHR object created for this request
  @xhrRequest: (method, url, headers, body, responseType, callback) ->
    xhr = new @Request()
    if @ieMode
      xhr.onload = -> DropboxXhr.onLoad xhr, method, url, callback
      xhr.onerror = -> DropboxXhr.onError xhr, method, url, callback
    else
      xhr.onreadystatechange = ->
        DropboxXhr.onReadyStateChange xhr, method, url, responseType, callback

    xhr.open method, url, true
    if responseType
      if responseType is 'b'
        if xhr.overrideMimeType
          xhr.overrideMimeType 'text/plain; charset=x-user-defined'
      else
        xhr.responseType = responseType
    unless @ieMode
      for own header, value of headers
        xhr.setRequestHeader header, value
    if body?
      xhr.send body
    else
      xhr.send()
    xhr

  # Encodes an associative array (hash) into a x-www-form-urlencoded String.
  #
  # For consistency, the keys are encoded using
  #
  # @param {Object} object the JavaScript object whose keys will be encoded
  # @return {String} the object's keys and values, encoded using
  #     x-www-form-urlencoded
  @urlEncode: (object) ->
    chunks = []
    for key, value of object
      chunks.push @urlEncodeValue(key) + '=' + @urlEncodeValue(value)
    chunks.sort().join '&'

  # Encodes an object into a x-www-form-urlencoded key or value.
  #
  # @param {Object} object the object to be encoded; the encoding calls
  #     toString() on the object to obtain its string representation
  # @return {String} encoded string, suitable for use as a key or value in an
  #     x-www-form-urlencoded string
  @urlEncodeValue: (object) ->
    encodeURIComponent(object.toString()).replace(/\!/g, '%21').
      replace(/'/g, '%27').replace(/\(/g, '%28').replace(/\)/g, '%29').
      replace(/\*/g, '%2A')

  # Decodes an x-www-form-urlencoded String into an associative array (hash).
  #
  # @param {String} string the x-www-form-urlencoded String to be decoded
  # @return {Object} an associative array whose keys and values are all strings
  @urlDecode: (string) ->
    result = {}
    for token in string.split '&'
      kvp = token.split '='
      result[decodeURIComponent(kvp[0])] = decodeURIComponent kvp[1]
    result

  # Handles the XHR readystate event.
  @onReadyStateChange: (xhr, method, url, responseType, callback) ->
    return true if xhr.readyState isnt 4  # XMLHttpRequest.DONE is 4

    if xhr.status < 200 or xhr.status >= 300
      apiError = new DropboxApiError xhr, method, url
      callback apiError
      return true

    metadataJson = xhr.getResponseHeader 'x-dropbox-metadata'
    if metadataJson?.length
      try
        metadata = JSON.parse metadataJson
      catch e
        # Make sure the app doesn't crash if the server goes crazy.
        metadata = undefined
    else
      metadata = undefined

    if responseType
      if responseType is 'b'
        dirtyText = if xhr.responseText?
          xhr.responseText
        else
          xhr.response
        ###
        jsString = ['["']
        for i in [0...dirtyText.length]
          hexByte = (dirtyText.charCodeAt(i) & 0xFF).toString(16)
          if hexByte.length is 2
            jsString.push "\\u00#{hexByte}"
          else
            jsString.push "\\u000#{hexByte}"
        jsString.push '"]'
        console.log jsString
        text = JSON.parse(jsString.join(''))[0]
        ###
        bytes = []
        for i in [0...dirtyText.length]
          bytes.push String.fromCharCode(dirtyText.charCodeAt(i) & 0xFF)
        text = bytes.join ''
        callback null, text, metadata
      else
        callback null, xhr.response, metadata
      return true

    text = if xhr.responseText? then xhr.responseText else xhr.response
    switch xhr.getResponseHeader('Content-Type')
       when 'application/x-www-form-urlencoded'
         callback null, DropboxXhr.urlDecode(text), metadata
       when 'application/json', 'text/javascript'
         callback null, JSON.parse(text), metadata
       else
          callback null, text, metadata
    true

  # Handles the XDomainRequest onload event. (IE 8, 9)
  @onLoad: (xhr, method, url, callback) ->
    text = xhr.responseText
    switch xhr.contentType
     when 'application/x-www-form-urlencoded'
       callback null, DropboxXhr.urlDecode(text), undefined
     when 'application/json', 'text/javascript'
       callback null, JSON.parse(text), undefined
     else
        callback null, text, undefined
    true

  # Handles the XDomainRequest onload event. (IE 8, 9)
  @onError: (xhr, method, url, callback) ->
    apiError = new DropboxApiError xhr, method, url
    callback apiError
    return true
