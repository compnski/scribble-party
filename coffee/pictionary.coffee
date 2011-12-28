->
  'use strict'

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

# The controller for Pictionary. This class handles most UI inputs events
# and owns all the other classes.
class PictionaryController
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

main = () ->
  new PictionaryController().main()
