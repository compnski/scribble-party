->
  'use strict'

class GameRound
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

  startDrawing: (@secret = "") =>
    @_startTimer(GameRound.roundTime)
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

class GameModel
  scores: {}
  players: []
  currentRound: null
  currentPlayerIdx: 0
  stateChangeCallback: null

  constructor: (@players, @stateChangeCallback) ->
    for player in players
      @scores[player] = 0
    @currentPlayerIdx = (@currentPlayerIdx + 1) % @players.length
    @currentRound = new GameRound(@getCardType(), '', @players[@currentPlayerIdx],
      @stateChangeCallback)

  getCardType: -> ['Person/Place/Thing', 'Difficult', 'All Play', 'Object',
    'Action', 'Pick'][Math.floor(Math.random()*6)]

  resumeDrawing: () => @currentRound.resumeDrawing()
  startDrawing: () => @currentRound.startDrawing()
  correctGuess: () => @currentRound.correctGuess()
  playerWon: (winner) => @currentRound.playerWon(winner)

  nextTurn: () =>
    @currentPlayerIdx = (@currentPlayerIdx + 1) % @players.length
    @currentRound = new GameRound(@getCardType(), '', @players[@currentPlayerIdx],
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

# The controller for Scribble Party. This class handles most UI inputs events
# and owns all the other classes.
class GameController
  # If connected mode is true, then sync round start to the server
  # so the remote client can get the secret.
  connectedMode: true
  finishRound: () =>
    #saveImage
    # logRoundStats
    imageData = @ui.drawingSurface.getImageData();
    answer = @ui.getAnswer();
    drawer = @pModel.currentRound.drawer;
    winner = @pModel.currentRound.winner;
    filename = answer + '-' + drawer + '.png';
    @netHandler.saveImage(imageData, filename, (response) =>
      imageHash = response.imageHash
      data =
        'drawer': drawer
        'winner':winner
        'imageHash':imageHash
        'answer': answer
      @netHandler.logTurn(data))
    @pModel.finishRound()
    @newRound()

  newRound: =>
    if @connectedMode
      roundData =
        drawer: @pModel.currentRound.drawer
        category: @pModel.currentRound.category
        players: @pModel.players
      @netHandler.roundStart(roundData, @lastUpdateTs, @gotRoundStart)

  waitForNetData: =>
    @netHandler.waitForData(@lastUpdateTs, @netDataHandler, @netErrorHandler)

  netDataHandler: (data) =>
    window.console.log("netDataHandler")
    window.console.log(data)
    {round, @lastUpdateTs} = data
    if round.state != @pModel.getState()
      switch round.state
        when STATE.DRAWING then @startDrawing()
        when STATE.CORRECT_GUESS then @pModel.correctGuess()
    @waitForNetData()

  netErrorHandler: (client, data) =>
    if client.status == 204 #NO-OP
      @waitForNetData()
      return
    @ui.message(MessageLevel.ERROR, "Error syncing with server")
    #@connectedMode = false

  playerWon: (playerName) =>
    if not @pModel.playerWon(playerName)
      @ui.message(MessageLevel.WARNING, 'Drawer cannot win')

  startDrawing: =>
      @pModel.startDrawing()

  gotRoundStart: (data) =>
    @lastUpdateTs = data.lastUpdateTs
    window.console.log(data)
    @pModel.currentRound.secret = data.round.secret

  buttonClickCallback: (target) =>
    [_, playerName, _...] = target.match(/player_(\w+)/) ? []
    if playerName
      @playerWon(playerName)
    switch target
      when 'startDrawing' then @startDrawing()
      when 'gotItButton' then @pModel.correctGuess()
      when 'back' then @pModel.resumeDrawing()
      when 'saveButton' then @finishRound()
      when 'changePlayerButton' then @pModel.correctGuess()

  stateChangeCallback: (state) =>
    @ui.updateOnStateChange(state)
    @ui.message(null, '')

  main: () =>
    @PLAYERS = PLAYERS
    @pModel = new GameModel(@PLAYERS, @stateChangeCallback)
    @ui = new GameUI(@pModel, document, @buttonClickCallback)
    @ui.initUi()
    @netHandler = new NetHelper("12",@ui.message)
    @waitForNetData()
    window.onbeforeunload = () -> 'Leaving will lose all game state'
    document.addEventListener('keypress', @keyboardHandler)
    @newRound()

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

main = () ->
  new GameController().main()
