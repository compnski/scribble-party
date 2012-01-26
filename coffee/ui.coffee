
# DrawingSurface wraps the HTML canvas element and makes it into a drawable
# surface. Takes a canvas element and an optional function which returns true
# if the surface should be drawable.
class DrawingSurface
  canvas: null
  context: null
  isMouseDown: false
  _isPenActive: false
  canDrawCallback: -> true
  @undoStack: []

  constructor: (@canvas, @canDrawCallback = -> true) ->
    @context = @canvas.getContext('2d')
    @canvas.onmousemove =  @onMouseMove
    @canvas.onmousedown = @onMouseDown
    @canvas.onmouseup = @onMouseUp
    @canvas.onmouseout = @onMouseUp
    @canvas.onmouseover = @onMouseOver
    @canvas.oncontextmenu = @onContextMenu

    #@canvas.addEventListener('touchmove',  @onTouchMove)
    #@canvas.addEventListener('touchstart',  @onTouchStart)
    @canvas.ontouchstart = @onTouchStart
    @canvas.ontouchmove = @onTouchMove
    @canvas.ontouchend = @onMouseUp
    @canvas.ontouchcancel = @onMouseUp

  getImageData: =>
    return @canvas.toDataURL()

  clear: =>
    @canvas.width = @canvas.width
    @context.fillStyle = 'rgb(255, 255, 255)'
    @context.fillRect(0, 0, @canvas.width, @canvas.height)
    @context.fillStyle = 'rgb(0, 0, 0)'
    @context.lineWidth = 2
    @context.line = 'round'

  drawStatusText: (text) =>
    this.context.font = '12pt Helvetica'
    this.context.fillText(text,
                     10,
                     20);

  drawLineToPoint: (point) =>
    {x, y} = point
    @context.lineTo(x, y)

  strokeTimer: () =>
    @context.stroke()
    @_isPenActive = @canDrawCallback()
    setTimeout(@strokeTimer, 100) if @isMouseDown

  isPenActive: =>
    return @isMouseDown and @_isPenActive

  moveToPoint: (point) =>
    @context.moveTo(point.x, point.y)

  onContextMenu: (event) =>
    false

  onTouchMove: (event) =>
    if @isPenActive()
      @drawLineToPoxint(@getCoords(event.touches[event.touches.length-1]))

  onTouchStart: (event) =>
    @moveToPoint(@getCoords(event.touches[event.touches.length-1]))
    @isMouseDown = true
    @strokeTimer()

  getCoords: (e) ->
    if e.offsetX
      x: e.offsetX
      y: e.offsetY
     else if e.layerX
      x: e.layerX
      y: e.layerY
     else
      x: e.pageX - @canvas.offsetLeft
      y: e.pageY - @canvas.offsetTop

  onMouseMove: (event) =>
    if @isPenActive()
      @drawLineToPoint({x:event.clientX, y:event.clientY})

  onMouseUp: =>
    @isMouseDown = false

  onMouseDown: (event) =>
    @context.moveTo(event.clientX, event.clientY)
    @context.beginPath()
    @context.strokeStyle = 'black'
    @isMouseDown = true
    @strokeTimer()

  onMouseOver: (event) =>
    if event.which
      @onMouseDown(event)

class GameUI
  root: null
  pModel: null
  drawingSurface: null

  constructor: (@pModel, @root, @buttonClickCallback) ->
    UI_ELEMENTS =   ['winningPlayerLabel', 'scoreBar', 'statusMessage',
      'buttonBar', 'startDrawingButton', 'saveButton', 'gotItButton', 'inputAnswer'
      'drawingBar', 'changeWinnerButton', 'answerField', 'main', 'waitForDraw',
      'timeLeftLabel', 'largeTimeLeftLabel', 'statusField', 'answerField']
    for uiElem in UI_ELEMENTS
      @[uiElem] = @e(uiElem)
    @statefulBarList = @root.getElementsByClassName('statefulBar')

  e: (elem) => return @root.getElementById(elem)

  getAnswer: =>
    return @answerField.value

  updateOnStateChange: =>
    @updateScoreUi(@pModel.scores)
    @updateUiForState(@pModel.getState())
    @winningPlayerLabel.innerHTML = @pModel.currentRound.winner ? 'Nobody'

  updateScoreUi: (scores) =>
    @_clearScoreBar()
    for player, score of scores
      scoreLabel = @root.createElement('div')
      scoreLabel.className = 'scoreText'
      scoreLabel.innerHTML = player + ':' + score
      @scoreBar.appendChild(scoreLabel)

  _clearScoreBar: =>
    while @scoreBar.firstChild
      @scoreBar.removeChild(@scoreBar.firstChild)

  _setVisibility: (element, visible) ->
    element.style.display = if visible then 'inline-block' else 'none'

  clearAndFocusAnswer: () =>
    @answerField.focus()
    @answerField.value = ''

  updateUiForState: (state) =>
    for bar in @statefulBarList
      bar.style.display = 'none';
    switch state
      when STATE.START then @onStateStart()
      when STATE.DRAWING then @onStateDrawing()
      when STATE.CORRECT_GUESS then @_setVisibility(@buttonBar, true)
      when STATE.INPUT_ANSWER
        @_setVisibility(@inputAnswer, true)
        setTimeout(@clearAndFocusAnswer, 1)

  updateTimeLeft: =>
    timeLeft = @pModel.currentRound?.timeLeft
    timeLeftStr = if timeLeft > 0 then Math.floor(timeLeft) else ''
    @timeLeftLabel.innerHTML = timeLeftStr
    @largeTimeLeftLabel.innerHTML = timeLeftStr

   _timeLeftTimer : () =>
    @updateTimeLeft()
    if @pModel.getState() == STATE.DRAWING
      setTimeout(@_timeLeftTimer, 100)
    else
      @_setVisibility(@largeTimeLeftLabel, false)

   onStateDrawing: () =>
    @_setVisibility(@drawingBar, true)
    @_setVisibility(@largeTimeLeftLabel, true)
    setTimeout(@_timeLeftTimer, 100)

   onStateStart: () =>
    @_setVisibility(@waitForDraw, true)
    @drawingSurface.clear()
    @drawingSurface.drawStatusText(@pModel.currentRound.drawer + ' is drawing ' +
      @pModel.currentRound.category)

  _createPlayerButton: (id, text, keyShortcut) =>
    newButton = @root.createElement('div');
    newButton.innerHTML = text
    newButton.id = id
    newButton.classList.add('playerButton')
    newButton.classList.add('clickable')
    newButton.name = name
    if keyShortcut?
      keyShortcutLabel = document.createElement('span')
      keyShortcutLabel.classList.add('keyShortcutLabel')
      keyShortcutLabel.innerHTML = '(' + keyShortcut + ')'
      newButton.appendChild(keyShortcutLabel)
    return newButton

  initPlayersUi: (players) =>
    keyShortcut = 1
    for player in players
      button = @_createPlayerButton('player_' + player, player, keyShortcut++)
      @buttonBar.appendChild(button)

    backButton = @_createPlayerButton('back', 'Back', keyShortcut++)
    buttonBar.appendChild(backButton);

  initUi: =>
    @drawingSurface = new DrawingSurface(@main,
      () => @pModel.getState() == STATE.DRAWING)

    @initPlayersUi(@pModel.players)
    @updateUiForState(@pModel.getState())
    for button in @root.getElementsByClassName('clickable')
      button.addEventListener('click', @buttonClicked)
      button.addEventListener('keypress',
        (event) =>
          event.target.blur()
          @buttonClicked(event) if event.keyCode in [13, 32]
          event.stopPropagation()
          )

  buttonClicked: (event) =>
    target = event.target.id
    @buttonClickCallback(target)

  message: (messageLevel, messageText) =>
    switch messageLevel
      when MessageLevel.ERROR then @statusField.style.color = 'red'
      when MessageLevel.WARNING then @statusField.style.color = 'orange'
      when MessageLevel.OK then @statusField.style.color = 'green'
    @statusField.innerHTML = messageText
