# Information about a failed call to the Dropbox API.
class DropboxApiError
  # Wraps a failed XHR call to the Dropbox API.
  #
  # @param {String} method the HTTP verb of the API request (e.g., 'GET')
  # @param {String} url the URL of the API request
  # @param {XMLHttpRequest} xhr the XMLHttpRequest instance of the failed
  #     request
  constructor: (xhr, @method, @url) ->
    @status = xhr.status
    text = xhr.responseText or xhr.response
    if text
      @responseText = text
      try
        @response = JSON.parse text
      catch e
        @response = null
    else
      @responseText = '(no response)'
      @response = null

  # Used when the error is printed out by developers.
  toString: ->
    "Dropbox API error #{@status} from #{@method} #{@url} :: #{@responseText}"

  # Used by some testing frameworks.
  inspect: ->
    @toString()
