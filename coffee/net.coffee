


class PostRequest
  constructor: (@successCallback, @errorCallback) ->
    @client = @initRequest()

  open: (url) => @client.open('POST', url)

  send: (data) =>
    data ?= ""
    @client.setRequestHeader('Content-Size', data.length)
    @client.send(data)

  setHeader: (header, value) => @client.setRequestHeader(header, value)

  stateChange: =>
    log(@client)
    data = @client.responseText ? null
    if @client.readyState == 4
      if @client.status == 200
        @successCallback(JSON.parse(data))
      else
        @errorCallback(@client, data)

  initRequest: =>
    client = new XMLHttpRequest()
    client.onreadystatechange = @stateChange
    return client

class NetHelper
  constructor: (@sessionKey, @messageCallback) ->

  saveImage: (imageData, filename, callback) =>
    request = new PostRequest(callback,
      => @messageCallback(MessageLevel.ERROR, 'Failed to save image.'))
    request.open('saveImage')
    request.setHeader('Content-Type', 'application/image')
    request.setHeader('X-Session-Key', @sessionKey)
    request.setHeader('X-Image-Filename', filename)
    request.send(imageData)

  logTurn: (data) =>
    request = new PostRequest(-> 1
      ,
      => @messageCallback(MessageLevel.ERROR, 'Failed to log turn.'))
    request.open('logTurn')
    data = JSON.stringify(data)
    request.setHeader('X-Session-Key', @sessionKey)
    request.send(data);

  correctGuessClicked: (callback) =>
    request = new PostRequest(callback,
      => @messageCallback(MessageLevel.ERROR, 'Failed to connec to server'))
    request.open("correctGuess")
    request.setHeader('X-Session-Key', @sessionKey)
    request.send()

  secretRevealed: (callback) =>
    request = new PostRequest(callback,
      => @messageCallback(MessageLevel.ERROR, 'Failed to connec to server'))
    request.open("secretRevealed")
    request.setHeader('X-Session-Key', @sessionKey)
    request.send()

  roundStart: (roundData, lastUpdateMs, callback) =>
    request = new PostRequest(callback,
      => @messageCallback(MessageLevel.ERROR, 'Failed to connect, please start the round again.'))
    request.open("roundStart?lastUpdate=" + lastUpdateMs)
    request.setHeader('X-Session-Key', @sessionKey)
    data = JSON.stringify(roundData)
    log(data)
    request.send(data)

  waitForData: (lastUpdateMs, successCallback, errorCallback) =>
    request = new PostRequest(successCallback, errorCallback)
    request.open("waitForData?lastUpdate=" + lastUpdateMs)
    request.setHeader('X-Session-Key', @sessionKey)
    request.send()