class RemoteUI
  secretRevealed: false
  constructor: (@secret, @root, @secretRevealedCallback, correctGuessCallback) ->
    UI_ELEMENTS =   ['secretLabel', 'revealSecretButton', 'correctGuess',
      'drawerLabel', 'categoryLabel']
    for uiElem in UI_ELEMENTS
      @[uiElem] = @root.getElementById(uiElem)
    @correctGuess.onclick = correctGuessCallback
    @revealSecretButton.onmousedown = @showSecret
    @revealSecretButton.ontouchstart = @showSecret
    @revealSecretButton.ontouchend = @hideSecret
    @revealSecretButton.onmouseup = @hideSecret
    @revealSecretButton.onmouseout = @hideSecret


  setSecret: (@secret) =>
    @secretRevealed = false

  showSecret: =>
    @secretLabel.innerHTML = @secret
    if not @secretRevealed
      @secretRevealedCallback()
      @secretRevealed = true

  hideSecret: =>
    @secretLabel.innerHTML = "&nbsp;"

  setDrawer: (@drawer) =>
    @drawerLabel.innerHTML = @drawer

  setCategory: (@category) =>
    @categoryLabel.innerHTML = @category

  message: (msg) =>
    alert(msg)

class RemoteController
  sessionKey: "12"
  state: STATE.START
  constructor: () ->
    @remoteUi = new RemoteUI("secret", document, @secretRevealed,
      @correctGuessClicked)
    @netHelper = new NetHelper(@sessionKey, @remoteUi.message)
    @waitForNetData()

  waitForNetData: =>
    @netHelper.waitForData(@lastUpdateTs, @netDataHandler, @netErrorHandler)

  netDataHandler: (data) =>
    window.console.log("netDataHandler")
    window.console.log(data)
    {round, @lastUpdateTs} = data
    switch round.state
      when STATE.START
        @remoteUi.setSecret(round.secret)
        @remoteUi.setDrawer(round.drawer)
        @remoteUi.setCategory(round.category)
    @currentState = round.state
    @waitForNetData()

  netErrorHandler: (client, data) =>
    window.console.log(client)
    if client.status == 204 #NO-OP
      @waitForNetData()
      return
    @remoteUi.message(MessageLevel.ERROR, "Error syncing with server")


  secretRevealed: () =>
    @netHelper.secretRevealed(=> 5)

  correctGuessClicked: () =>
    @netHelper.correctGuessClicked(=>5)


remote = () ->
  rc = new RemoteController()