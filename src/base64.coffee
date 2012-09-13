# node.js implementation of atob and btoa

if window?
  atob = window.atob
  btoa = window.btoa
else
  # NOTE: the npm packages atob and btoa don't do base64-encoding correctly.
  atob = (arg) ->
    buffer = new Buffer arg, 'base64'
    (String.fromCharCode(buffer[i]) for i in [0...buffer.length]).join ''
  btoa = (arg) ->
    buffer = new Buffer(arg.charCodeAt(i) for i in [0...arg.length])
    buffer.toString 'base64'
