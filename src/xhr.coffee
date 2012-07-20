if window?
  DropboxXhrRequest = window.XMLHttpRequest  
  # TODO: XDomain for CORS on IE <= 9
else
  # Node.js needs an adapter for the XHR API.
  DropboxXhrRequest = require('xmlhttprequest').XMLHttpRequest

# Dispatches low-level AJAX calls (XmlHttpRequests).
class DropboxXhr
  # The object used to perform XHR requests.
  @Request = DropboxXhrRequest

  # Sends off an AJAX request.
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #     'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #     that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #     request parameters
  # @param {String} authHeader the value of the Authorization header
  # @param {function(?Object, ?String)}callback called with the AJAX result;
  #     successful requests set the first parameter to an object containing the
  #     parsed result, and unsuccessful requests set the second parameter to
  #     an error string
  # @return {XMLHttpRequest} the XHR object used for this request
  @request: (method, url, params, authHeader, callback) ->
    @request2 method, url, params, authHeader, null, callback

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
  # @param {String} responseType the value that will be assigned to the XHR's
  #     responseType property
  # @param {function(?Object, ?String)}callback called with the AJAX result;
  #     successful requests set the first parameter to an object containing the
  #     parsed result, and unsuccessful requests set the second parameter to
  #     an error string
  # @return {XMLHttpRequest} the XHR object used for this request
  @request2: (method, url, params, authHeader, responseType, callback) ->
    if method is 'GET'
      queryString = DropboxXhr.urlEncode params
      if queryString.length isnt 0
        url = [url, '?', DropboxXhr.urlEncode(params)].join ''
    headers = {}
    if authHeader
      headers['Authorization'] = authHeader
    if method is 'POST'
      headers['Content-Type'] = 'application/x-www-form-urlencoded'
      body = DropboxXhr.urlEncode params
    else
      body = null
    DropboxXhr.xhrRequest method, url, headers, body, responseType, callback

  # Upload a file via a mulitpart/form-data method.
  # 
  # This is a one-off method for the abomination that is POST /files. We can't
  # use PUT because in browser environments, using it requires a pre-flight
  # request (using the OPTIONS verb) that the API server implement.
  #
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #     that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #     request parameters
  # @param {String} fieldName the name of the form field whose value is
  #     submitted in the multipart/form-data body
  # @param {String} data the file content to be uploaded
  # @param {String} authHeader the value of the Authorization header
  # @param {function(?Object, ?String)}callback called with the AJAX result;
  #     successful requests set the first parameter to an object containing the
  #     parsed result, and unsuccessful requests set the second parameter to
  #     an error string
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
    xhr.onreadystatechange = ->
      DropboxXhr.onReadyStateChange xhr, method, url, responseType, callback
    xhr.open method, url, true
    if responseType
      if responseType is 'b'
        if xhr.overrideMimeType
          xhr.overrideMimeType 'text/plain; charset=x-user-defined'
      else
        xhr.responseType = responseType
    for own header, value of headers
      xhr.setRequestHeader header, value
    if body
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
      callback null, apiError
      return true

    if responseType
      if responseType is 'b'
        dirtyText = xhr.responseText or xhr.response
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
        callback text
      else
        callback xhr.response
      return true
    
    text = xhr.responseText or xhr.response
    switch xhr.getResponseHeader('Content-Type')
       when 'application/x-www-form-urlencoded'
         callback DropboxXhr.urlDecode(text)
       when 'application/json', 'text/javascript'
         callback JSON.parse(text)
       else
          callback text
    true
