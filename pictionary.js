PLAYERS = ["Jason", "Matt", "Alex", "Allison", "Ganz", "David"];

var isMouseDown = false;
var lastEvent;

var MAX_TIME = 60;
var STATE = {}
STATE.START = "start";
STATE.DRAWING = "drawing";
STATE.SOMEONE_WON = "someonewon";
STATE.INPUT_ANSWER = "inputanswer";

var MessageLevel = {}
MessageLevel.WARNING = "warning";
MessageLevel.ERROR = "error";
MessageLevel.OK = "ok";


PictionaryModelEvent


function log(s) {
		window.console.log(s);
}

function nowMs() {
		return (new Date()).valueOf();
}


function PictionaryModelEvent(type, data) {
		this.type = type;
		this.data = data;
}

///////// PictionaryModel

function PictionaryModel(root, players, canvasApp) {
		this.players = players;
		this.root = root;
		for (var i=0;i<players.length;i++) { this.scores[players[i]] = 0; }
		this.drawerIdx = 0;
		this.timeLeft = MAX_TIME;
		this.sessionKey = "1";
}

PictionaryModel.prototype.players = [];
PictionaryModel.prototype.scores = {};
PictionaryModel.prototype.state = STATE.START;

//////////// GETTERS

PictionaryModel.prototype.getCurrentDrawer = function() {
		return this.players[this.drawerIdx];
}
PictionaryModel.prototype.getCurrentCategory = function() {
		return this.currentCategory;
}
PictionaryModel.prototype.getWinningPlayer = function() {
		return this.winningPlayer;
}
//private
PictionaryModel.prototype.getCardType = function() {
		var types = ["Person/Place/Thing", "Difficult", "All Play", "Object", "Action", "Pick"];
		return types[Math.floor(Math.random()*6)];
}

///////////// TRANSITION FUNCTIONS

/**
 * startTurn(drawerIdx)
 *
 * Starts a players turn.
 * Draws turn text.
 */
PictionaryModel.prototype.startTurn = function(drawerIdx) {
		this.drawerIdx = drawerIdx;
		this.currentCategory = this.getCardType();
		this.changeState(STATE.START);
}
/**
 * startDrawing()
 *
 * Starts a player drawing. Starts the timer, updates the UI, unlocks canvas.
 */
PictionaryModel.prototype.startDrawing = function() {
		this.changeState(STATE.DRAWING);
		this.startTimeMs = nowMs();
		this.startTimer();
}
/**
 * gotItClicked()
 *
 * Called when Got It is clicked, shows the player buttons, stops the timer.
 */
PictionaryModel.prototype.gotItClicked = function() {
		this.changeState(STATE.SOMEONE_WON);
}
/**
 * timeUp()
 *
 * Called when time runs out. Removes points for the drawer, updates UI.
 */
PictionaryModel.prototype.timeUp = function() {
		this.winningPlayer = false;
		this.changeState(STATE.INPUT_ANSWER);
}

/**
 * resumeDrawing()
 *
 * Resumes drawing at the time the timer was at.
 */
PictionaryModel.prototype.resumeDrawing = function(timeLeft) {
		this.startTimeMs = nowMs() - (MAX_TIME - this.timeLeft) * 1000;
		this.changeState(STATE.DRAWING);
		this.startTimer()
}
/**
 * playerWon(playerName)
 *
 * Called when a player wins. Adds points, updates the UI.
 */
PictionaryModel.prototype.playerWon = function(name) {
		if (name == this.getCurrentDrawer()) {
				this.fireEvent(new PictionaryModelEvent(
						PictionaryModelEvent.MESSAGE, {'level':MessageLevel.WARNING,
																					 'text': "Drawing player cannot win"}));
				return;
		}
		this.winningPlayer = name;
		this.changeState(STATE.INPUT_ANSWER);
}
/**
 * nextDrawing()
 *
 * Advances to the next player
 */
PictionaryModel.prototype.nextDrawing = function() {
		this.drawerIdx = (this.drawerIdx + 1) % this.players.length;
		this.startTurn(this.drawerIdx);
}

///////////// UTILITY FUNCTIONS

PictionaryModel.prototype.fireEvent = function(event) {
		var evt = document.createEvent("MessageEvent");
		evt.initMessageEvent("MessageEvent", true, true, event);
		this.root.dispatchEvent(evt);
		log(evt);
}

PictionaryModel.prototype.changeState = function(state) {
		this.state = state;
		this.fireEvent(new PictionaryModelEvent(PictionaryModelEvent.STATE_CHANGE, {'state': state}));
};

/**
 * timerEvent()
 *
 * Timer event handler.
 * Updates timeleft, checks for time over.
 */
PictionaryModel.prototype.timerEvent = function() {
		if (this.state != STATE.DRAWING) {
				// Once we leave the timer state, ignore timer events.
				return;
		}
		var newTimeLeft = MAX_TIME - ((nowMs() - this.startTimeMs) / 1000);
		if (int(this.timeLeft) != int(newTimeLeft)) {
				this.fireEvent(new PictionaryModelEvent(
						PictionaryModelEvent.TIMER_UPDATE, {'time': newTimeLeft}));
		}
		this.timeLeft = newTimeLeft
		if (this.timeLeft <= 0) {
				this.timeUp();
		} else {
				this.startTimer();
		}
}

PictionaryModel.prototype.startTimer = function() {
		var t = this
		setTimeout(function() {t.timerEvent()}, 9);
}

PictionaryModel.prototype.finishRound = function() {
		if (this.winningPlayer) {
				this.scores[this.winningPlayer] += 2;
				this.scores[this.getCurrentDrawer()] += 1;
		} else {
				this.scores[this.getCurrentDrawer()] -= 1;
		}

		this.nextDrawing();
}

/////////////////////////////////////////////////////////

function CanvasApp(pModel) {
		this.canvas = document.getElementById("main");
		this.context = this.canvas.getContext("2d");
		this.pModel = pModel;
		this.setTimeLeft(MAX_TIME);
}

CanvasApp.prototype.getAnswer = function() {
		return document.getElementById("answer").value;
};

CanvasApp.prototype.getImageData = function(){
    // get the image data to manipulate
    return this.canvas.toDataURL();
}

CanvasApp.prototype.setTimeLeft = function(timeLeft) {
		document.getElementById("timeLeft").innerHTML = Math.ceil(timeLeft);
};

/**
 * Tell the UI to update. (probably should dispatch events)
 *
 */
CanvasApp.prototype.redraw = function() {
		this.updateScoreUi(this.pModel.players, this.pModel.scores);
		this.message(null, "");
}

CanvasApp.prototype.updateScoreUi = function(scores) {

};

CanvasApp.prototype.clear = function() {
		this.canvas.width = this.canvas.width; // clears the canvas
		this.context.fillStyle = "rgb(255, 255, 255)";
		this.context.fillRect (0, 0, this.canvas.width, this.canvas.height);
		this.context.fillStyle = "rgb(0, 0, 0)";
};

CanvasApp.prototype.drawLineToEvent = function(event) {
		this.context.lineTo(lastEvent.clientX, lastEvent.clientY);
		this.context.stroke();
};

CanvasApp.prototype.setPenActive = function(isActive) {
		this.isMouseDown = isActive;
};

CanvasApp.prototype.isPenActive = function() {
		return this.isMouseDown && this.pModel.state == STATE.DRAWING;
};

CanvasApp.prototype.mouseMove = function(event) {
		lastEvent = event;
		if (this.isPenActive()) {
				this.drawLineToEvent(event);
		}
}

CanvasApp.prototype.mouseUp = function(event) {
		this.setPenActive(false);
};

CanvasApp.prototype.mouseDown = function(event) {
		lastEvent = event;
		this.context.moveTo(event.clientX, event.clientY);
		this.setPenActive(true);
};

CanvasApp.prototype.mouseOver = function(event) {
		if (event.which) {
				this.mouseDown(event);
		}
}

CanvasApp.prototype.fireEvent = function(event) {
		var evt = document.createEvent("MessageEvent");
		evt.initMessageEvent("MessageEvent", true, true, event);
		this.root.dispatchEvent(evt);
}

CanvasApp.prototype.mouseOut = function(event) {
		this.setPenActive(false);
};

CanvasApp.prototype.setWinningPlayerLabel = function(name) {
		document.getElementById("winningPlayerLabel").innerHTML = name + " won"
};

CanvasApp.prototype.drawStatusText = function (player, cardType) {
		this.context.font = "12pt Helvetica";
		this.context.fillText(player + " is drawing " + cardType + ".",
										 10,
										 20);
};

CanvasApp.prototype.updateScoreUI = function(players, scores) {
		var scoreBar = document.getElementById("scoreBar");
		while(scoreBar.firstChild) {
				scoreBar.removeChild(scoreBar.firstChild);
		}
		for(var i = 0; i < players.length; i++) {
				var player = players[i];
				var scoreLabel = document.createElement("div");
				scoreLabel.className = "scoreText";
				scoreLabel.innerHTML = player + ": " + scores[player];
				scoreBar.appendChild(scoreLabel);
		}
};

CanvasApp.prototype.setUiForState = function(state) {
		bars = this.document.getElementsByClassName("statefulBar");
		for (var i=0; i < bars.length; i++) {
				elementIdx = i;
				var elem = bars[elementIdx];
				elem.style.display = "none";
		}

		switch(state) {
		case STATE.START:
				setElementDisplay("waitForDraw", true);
				break;
		case STATE.DRAWING:
				setElementDisplay("drawingBar", true);
				break;
		case STATE.SOMEONE_WON:
				setElementDisplay("buttonBar", true);
				break;
		case STATE.INPUT_ANSWER:
				setElementDisplay("inputAnswer", true);
				setTimeout(function() {
						document.getElementById("answer").focus();
						document.getElementById("answer").value = "";
						}, 1);
				break;
		}
}

CanvasApp.prototype.initUI = function() {
		var buttonBar = document.getElementById("buttonBar");
		var playerIdx = 0;
		var pModel = this.pModel;
		for (playerIdx=0; playerIdx < players.length; ++playerIdx) {
				var name = players[playerIdx];
				var button = createButton(name, playerIdx)
				button.onclick = function() {
						pModel.playerWon(this.name);
				};
				buttonBar.appendChild(button);
		}

		var button = createButton(pModel, "Back", (playerIdx))
		button.onclick = function() { pModel.resumeDrawing() };
		buttonBar.appendChild(button);

		document.getElementById("startDrawing").onclick = function() {this.pModel.startDrawing()};
		document.getElementById("saveButton").onclick = function() {pModel.finishRound()};
		document.getElementById("gotItButton").onclick = function() {pModel.gotItClicked()};
		document.getElementById("changePlayerButton").onclick = function() {pModel.gotItClicked()};
		document.getElementById("changePlayerButton").onkeypress = function(event) {
				if (event.keyCode in {13:'', 32:''}) {
						pModel.gotItClicked()
				}
		};
}

CanvasApp.prototype.message = function(messageLevel, messageText) {
		var statusField = document.getElementById("statusMessage");
		switch (messageLevel) {
		case MessageLevel.ERROR:
				statusField.style.color = "red";
				break;
		case MessageLevel.WARNING:
				statusField.style.color = "orange";
				break;
		case MessageLevel.OK:
				statusField.style.color = "green";
				break;
		}
		statusField.innerHTML = messageText;
}

CanvasApp.prototype.createButton = function(name, index, action) {
		newButton = document.createElement("div");
		newButton.innerHTML = name;
		newButton.className = "playerButton"
		newButton.name = name;
		if (typeof index != "undefined" ) {
				indexLabel = document.createElement("span");
				indexLabel.className = "indexLabel"
				indexLabel.innerHTML = "(" + (index - - 1) + ")";
				newButton.appendChild(indexLabel);
		}
		newButton.onclick = function() { this.fireEvent(new ButtonClickedEvent(action)) };

		return newButton;
}

function setElementDisplay(elementName, active) {
		var bar = document.getElementById(elementName);
		if (active) {
				bar.style.display = "block";
		} else {
				bar.style.display = "none";
		}
}

function setPlayerButtonDisplay(active) {
		setElementDisplay("buttonBar", active);
}

function handler(client, callback) {
		if(client.readyState == 4 && client.status == 200) {
				if(client.responseXML != null && client.responseXML.getElementById('imageHash').firstChild.data)
						callback(client.responseXML.getElementById('imageHash').firstChild.data);
				else
						message(MessageLevel.ERROR, "Failed to save image.");
		} else if (client.readyState == 4 && client.status != 200) {
				message(MessageLevel.ERROR, "Failed to save image.");
		}
}

function saveImage(sessionKey, imageData, filename, callback) {
		var client = new XMLHttpRequest();
		client.onreadystatechange = function() { handler(client, callback) };
		client.open("POST", "saveImage");
		client.setRequestHeader("Content-Type", "application/image")
		client.setRequestHeader("Content-Size", imageData.length)
		client.setRequestHeader("X-Session-Key", sessionKey);
		client.setRequestHeader("X-Image-Filename", filename);
		client.send(imageData);
}


function logTurn(sessionKey, data) {
		log('logTurn')
		var client = new XMLHttpRequest();
		data = JSON.stringify(data)
		client.open("POST", "logTurn");
		client.setRequestHeader("Content-Type", "text/json")
		client.setRequestHeader("Content-Size", data.length)
		client.setRequestHeader("X-Session-Key", sessionKey);
		client.send(data);
}

function PictionaryController(root, canvas) {

		pModel = this.pModel = new PictionaryModel(root, PLAYERS);
		canvasApp = this.canvasApp = new CanvasApp(root, this.pModel);
		this.root = root;
		this.players = PLAYERS;
		var t = this;

		canvas.addEventListener('mousemove', function(event) { canvasApp.mouseMove(event) }, false);
		canvas.addEventListener('mouseup', function(event) { canvasApp.mouseUp(event) }, false);
		canvas.addEventListener('mousedown', function(event) { canvasApp.mouseDown(event) }, false);
		canvas.addEventListener('mouseover',function(event) { canvasApp.mouseOver(event) }, false);
		canvas.addEventListener('mouseout', function(event) { canvasApp.mouseOut(event) }, false);

		root.addEventListener('keypress', function(event) { t.keyboardHandler(event) }, false);

		this.root.addEventListener('onmessage', function(event) {
				log(event)});

		pModel.startTurn(0);


		window.onbeforeunload = function() {
				return 'Leaving will lose all game state';
		}
}

PictionaryController.prototype.keyboardHandler = function(event) {
 		switch(this.pModel.state) {
		case STATE.START:
				if (event.keyCode in {13:'',32:''}) {
						this.pModel.startDrawing();
				}
				break;
		case STATE.DRAWING:
				if (event.keyCode in {13:'',32:''}) {
						this.pModel.gotItClicked();
				}
				break;
		case STATE.SOMEONE_WON:
				if (event.keyCode >= 48 && event.keyCode <= 57) {
						var playerIdx = event.keyCode - 49;
						if (playerIdx == -1) {
								playerIdx = 10;
						}
						if (playerIdx >= this.players.length) {
								this.pModel.resumeDrawing();
						} else {
								this.pModel.playerWon(this.players[playerIdx]);
						}
				}
				break;
		case STATE.INPUT_ANSWER:
				if (event.keyCode in {13:''}) {
						this.finishRound();
				}
				break;
		}
}

PictionaryController.prototype.finishRound = function() {
		pModel.finishRound();

		var imageData = this.canvasApp.getImageData();
		var answer = this.canvasApp.getAnswer();
		var drawer = this.pModel.getCurrentDrawer();
		var winner = this.pModel.getWinningPlayer();
		var filename = answer + "-" + drawer + ".png";
		saveImage(this.sessionKey, imageData, filename, function(imageHash) {
				var data = {'drawer': drawer,
										'winner':winner,
										'imageHash':imageHash,
										'answer': answer
									 }
				logTurn(this.sessionKey, data);
		});
}


function main() {
		var canvas = document.getElementById("main");
		var root = document.getElementById("body");
		var pc = new PictionaryController(root, canvas);
}