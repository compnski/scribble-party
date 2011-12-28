class RemoteUI
  constructor: (@secret, @root, correctGuessCallback) ->
    UI_ELEMENTS =   ['secretLabel', 'revealSecretButton', 'correctGuess',
      'drawerLabel']
    for uiElem in UI_ELEMENTS
      @[uiElem] = @root.getElementById(uiElem)
    @correctGuess.onclick = correctGuessCallback
    @revealSecretButton.onmousedown = @showSecret
    @revealSecretButton.ontouchstart = @showSecret
    @revealSecretButton.ontouchend = @hideSecret
    @revealSecretButton.onmouseup = @hideSecret
    @revealSecretButton.onmouseout = @hideSecret

  showSecret: =>
    @secretLabel.innerHTML = @secret

  hideSecret: =>
    @secretLabel.innerHTML = "&nbsp;"

  updateDrawer: (@drawer) =>
    @drawerLabel.innerHTML = @drawer


remote = () ->
  remoteUi = new RemoteUI("secret", document, () -> 5)