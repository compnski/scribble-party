->
  'use strict'
STATE = {}
STATE.START = 'start'
STATE.DRAWING = 'drawing'
STATE.CORRECT_GUESS = 'correctguess'
STATE.INPUT_ANSWER = 'inputanswer'

MessageLevel = {}
MessageLevel.WARNING = 'warning';
MessageLevel.ERROR = 'error';
MessageLevel.OK = 'ok';

log = (s) => window.console.log(s)

#log(screen.availHeight + ', ' + screen.availWidth)
#alert(screen.availHeight + ', ' + screen.availWidth)

nowMs = () => (new Date()).valueOf()


class PictionaryRound
  category: null
  secret: null
  drawer: null
  @roundTime: 60
  timeLeft: @roundTime
  roundState: STATE.START
  winner: undefined
  stateChangeCallback: null
  _endTimeMs: null
  state: STATE.START

  constructor: (@category, @secret, @drawer, @stateChangeCallback) ->

  startDrawing: =>
    @_startTimer(PictionaryRound.roundTime)
    @_changeState(STATE.DRAWING)

  correctGuess: =>
    @_changeState(STATE.CORRECT_GUESS)

  timeUp: =>
    @winner = null
    @_changeState(STATE.INPUT_ANSWER)

  resumeDrawing: =>
    if @timeLeft > 0
      @_startTimer(@timeLeft)
      @_changeState(STATE.DRAWING)
    else
      @timeUp()

  playerWon: (@winner) =>
    if @winner == @drawer
      @winner = false
      return false
    @_changeState(STATE.INPUT_ANSWER)
    return true

  _startTimer: (@timeLeft) =>
    @_endTimeMs = nowMs() + (timeLeft * 1000)
    setTimeout(@_timerHandler, 10)

  _changeState: (@state) =>
    @stateChangeCallback(state)

  _timerHandler: (event) =>
    @timeLeft = (@_endTimeMs - nowMs()) / 1000
    if nowMs() > @_endTimeMs
      @timeUp()
    else
      setTimeout(@_timerHandler, 10) if @state == STATE.DRAWING

class PictionaryGame
  scores: {}
  players: []
  currentRound: null
  currentPlayerIdx: 0
  stateChangeCallback: null

  constructor: (@players, @stateChangeCallback) ->
    for player in players
      @scores[player] = 0
    @currentPlayerIdx = (@currentPlayerIdx + 1) % @players.length
    @currentRound = new PictionaryRound(@getCardType(), '', @players[@currentPlayerIdx],
      @stateChangeCallback)

  getCardType: -> ['Person/Place/Thing', 'Difficult', 'All Play', 'Object',
    'Action', 'Pick'][Math.floor(Math.random()*6)]

  resumeDrawing: () => @currentRound.resumeDrawing()
  startDrawing: () => @currentRound.startDrawing()
  correctGuess: () => @currentRound.correctGuess()
  playerWon: (winner) => @currentRound.playerWon(winner)

  nextTurn: () =>
    @currentPlayerIdx = (@currentPlayerIdx + 1) % @players.length
    @currentRound = new PictionaryRound(@getCardType(), '', @players[@currentPlayerIdx],
      @stateChangeCallback)
    @stateChangeCallback(@currentRound.state)

  finishRound: () =>
    if @currentRound.winner in @players
      @scores[@currentRound.winner] += 2
      @scores[@currentRound.drawer] += 1
    else
      @scores[@currentRound.drawer] -= 1
    @nextTurn()

  getState: () => @currentRound.state ? STATE.START

# DrawingSurface wraps the HTML canvas element and makes it into a drawable
# surface. Takes a canvas element and an optional function which returns true
# if the surface should be drawable.
class DrawingSurface
  canvas: null
  context: null
  isMouseDown: false
  _isPenActive: false
  canDrawCallback: -> true

  constructor: (@canvas, @canDrawCallback = -> true) ->
    @context = @canvas.getContext('2d')
    @canvas.onmousemove =  @onMouseMove
    @canvas.onmousedown = @onMouseDown
    @canvas.onmouseup = @onMouseUp
    @canvas.onmouseout = @onMouseUp
    @canvas.onmouseover = @onMouseOver

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

  drawStatusText: (text) =>
    this.context.font = '12pt Helvetica';
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

  onTouchMove: (event) =>
    if @isPenActive()
      @drawLineToPoint(@getCoords(event.touches[event.touches.length-1]))

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
    @isMouseDown = true
    @strokeTimer()

  onMouseOver: (event) =>
    if event.which
      @onMouseDown(event)

class PictionaryUI
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

  getAnswer: ->
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

# The controller for Pictionary. This class handles most UI inputs events
# and owns all the other classes.
class Controller

  finishRound: () =>
    #saveImage
    # logRoundStats
    imageData = @ui.drawingSurface.getImageData();
    answer = @ui.getAnswer();
    drawer = @pModel.currentRound.drawer;
    winner = @pModel.currentRound.winner;
    filename = answer + '-' + drawer + '.png';
    @netHandler.saveImage(this.sessionKey, imageData, filename, (response) =>
      imageHash = response.getElementById('imageHash')?.firstChild?.data
      data =
        'drawer': drawer
        'winner':winner
        'imageHash':imageHash
        'answer': answer
      @netHandler.logTurn(this.sessionKey, data))
    @pModel.finishRound()

  playerWon: (playerName) =>
    if not @pModel.playerWon(playerName)
      @ui.message(MessageLevel.WARNING, 'Drawer cannot win')

  buttonClickCallback: (target) =>
    [_, playerName, _...] = target.match(/player_(\w+)/) ? []
    if playerName
      @playerWon(playerName)
    switch target
      when 'startDrawing' then @pModel.startDrawing()
      when 'gotItButton' then @pModel.correctGuess()
      when 'back' then @pModel.resumeDrawing()
      when 'saveButton' then @finishRound()
      when 'changePlayerButton' then @pModel.correctGuess()

  stateChangeCallback: (state) =>
    @ui.updateOnStateChange(state)
    @ui.message(null, '')

  main: () =>
    @PLAYERS = ['Jason', 'Matt', 'Alex', 'Allison', 'Ganz', 'David'];
    @pModel = new PictionaryGame(@PLAYERS, @stateChangeCallback)
    @ui = new PictionaryUI(@pModel, document, @buttonClickCallback)
    @ui.initUi()
    @netHandler = new NetHelper(@ui.message)
    window.onbeforeunload = () -> 'Leaving will lose all game state'
    document.addEventListener('keypress', @keyboardHandler)

  keyboardHandler: (event) =>
    switch @pModel.getState()
      when STATE.START
        if event.keyCode in [13, 32] then @pModel.startDrawing()
      when STATE.DRAWING
        if event.keyCode in [13, 32] then @pModel.correctGuess()
      when STATE.CORRECT_GUESS
        if event.keyCode in [48..58]
          playerIdx = event.keyCode - 49;
          playerIdx = 10 if playerIdx == -1
          if playerIdx >= @PLAYERS.length
            @pModel.resumeDrawing()
          else
            @playerWon(@PLAYERS[playerIdx]);
      when STATE.INPUT_ANSWER
        if event.keyCode in (13) then @finishRound()

new Controller().main()
