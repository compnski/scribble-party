
class PostRequest
  constructor: (@successCallback, @errorCallback) ->
    @client = @initRequest()

  open: (url) => @client.open('POST', url)

  send: (data) =>
    @client.setRequestHeader('Content-Size', data.length)
    @client.send(data)

  setHeader: (header, value) => @client.setRequestHeader(header, value)

  stateChange: =>
    data = @client.responseXML ? null
    if @client.readyState == 4
      if @client.status == 200
        @successCallback(data)
      else
        @errorCallback(@client, data)

  initRequest: =>
    client = new XMLHttpRequest()
    client.onreadystatechange = @stateChange
    return client

class NetHelper
  constructor: (@messageCallback) ->

  saveImage: (sessionKey, imageData, filename, callback) =>
    request = new PostRequest(callback,
      => @messageCallback(MessageLevel.ERROR, 'Failed to save image.'))
    request.open('saveImage')
    request.setHeader('Content-Type', 'application/image')
    request.setHeader('X-Session-Key', sessionKey)
    request.setHeader('X-Image-Filename', filename)
    request.send(imageData)

  logTurn: (sessionKey, data) =>
    request = new PostRequest(-> 1
      ,
      => @messageCallback(MessageLevel.ERROR, 'Failed to log turn.'))
    request.open('logTurn')
    data = JSON.stringify(data)
    request.setHeader('X-Session-Key', sessionKey)
    request.send(data);
