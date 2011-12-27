PLAYERS = ["Jason", "Matt", "Alex", "Allison", "Ganz", "David"];

var context;
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

function log(s) {
		window.console.log(s);
}

function nowMs() {
		return (new Date()).valueOf();
}
function PictionaryModel(players, canvasApp) {
		this.players = players;
		this.scores = {};
		for (var i=0;i<players.length;i++) { this.scores[players[i]] = 0; }
		this.canvasApp = canvasApp;
		this.state = STATE.START;
		this.drawerIdx = 0;
		this.startTurn(0);
		this.timeLeft = MAX_TIME;
		this.sessionKey = "1";
		this.redraw();
}
/**
 * getCardType
 *
 * Returns a random card type.
 */
PictionaryModel.prototype.getCardType = function() {
		var types = ["Person/Place/Thing", "Difficult", "All Play", "Object", "Action", "Pick"];
		return types[Math.floor(Math.random()*6)];
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

/**
 * startTurn(drawerIdx)
 *
 * Starts a players turn.
 * Draws turn text.
 */
PictionaryModel.prototype.startTurn = function(drawerIdx) {
		this.state = STATE.START;
		this.canvasApp.clear();
		this.drawerIdx = drawerIdx;
		this.canvasApp.drawStatusText(this.players[drawerIdx], this.getCardType());
		this.canvasApp.setUiForState(this.state);
}

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
		this.timeLeft = MAX_TIME - ((nowMs() - this.startTimeMs) / 1000);
		this.canvasApp.setTimeLeft(this.timeLeft);

		if (this.timeLeft <= 0) {
				this.timeUp();
		} else {
				this.startTimer();
		}
}

/**
 * Tell the UI to update. (probably should dispatch events)
 *
 */
PictionaryModel.prototype.redraw = function() {
		this.canvasApp.setUiForState(this.state);
		this.canvasApp.updateScoreUi(this.scores);
		this.canvasApp.drawScoreText(this.players, this.scores);
		this.canvasApp.message(null, "");
}

PictionaryModel.prototype.startTimer = function() {
		var t = this
		setTimeout(function() {t.timerEvent()}, 9);
}

PictionaryModel.prototype.setWinningPlayer = function(name) {
		if (!name) {
				this.canvasApp.setWinningPlayerLabel("Nobody")
		} else {
				this.canvasApp.setWinningPlayerLabel(name)
		}
		this.winningPlayer = name;
}

/**
 * timeUp()
 *
 * Called when time runs out. Removes points for the drawer, updates UI.
 */
PictionaryModel.prototype.timeUp = function() {
		this.setWinningPlayer(false);
		this.state = STATE.INPUT_ANSWER;
		this.canvasApp.canDraw = false;
		this.redraw();
}

/**
 * someoneWon()
 *
 * Called when Got It is clicked, shows the player buttons, stops the timer.
 */
PictionaryModel.prototype.gotItClicked = function() {
		this.state = STATE.SOMEONE_WON;
		this.canvasApp.canDraw = false;
		this.redraw();
}

/**
 * startDrawing()
 *
 * Starts a player drawing. Starts the timer, updates the UI, unlocks canvas.
 */
PictionaryModel.prototype.startDrawing = function() {
		this.state = STATE.DRAWING;
		this.canvasApp.canDraw = true;
		this.startTimeMs = nowMs();
		this.startTimer();
		this.redraw();
}

/**
 * resumeDrawing()
 *
 * Resumes drawing at the time the timer was at.
 */
PictionaryModel.prototype.resumeDrawing = function(timeLeft) {

		this.startTimeMs = nowMs() - (MAX_TIME - this.timeLeft) * 1000;
		this.state = STATE.DRAWING;
		this.canvasApp.canDraw = true;
		this.startTimer()
		this.redraw();
}

/**
 * getCurrentDrawer()
 *
 * Returns player whos is currently drawing.
 */
PictionaryModel.prototype.getCurrentDrawer = function() {
		return this.players[this.drawerIdx];
}

/**
 * addWinnerPoints(playerName)
 *
 * Updates scores after a player has won.
 * 2 to player name passed in, 1 to current drawer.
 */
PictionaryModel.prototype.addWinnerPoints = function(name) {
		if (!(name in this.scores)) {
				this.scores[name] = 0;
		}
		this.redraw();
}

/**
 * playerWon(playerName)
 *
 * Called when a player wins. Adds points, updates the UI.
 */
PictionaryModel.prototype.playerWon = function(name) {
		if (name == this.getCurrentDrawer()) {
				this.canvasApp.message(MessageLevel.WARNING, "Drawing player cannot win");
				return;
		}
		this.state = STATE.INPUT_ANSWER;
		this.setWinningPlayer(name);
		this.redraw();
}

PictionaryModel.prototype.finishRound = function() {
		if (this.winningPlayer) {
				this.scores[this.winningPlayer] += 2;
				this.scores[this.getCurrentDrawer()] += 1;
		} else {
				this.scores[this.getCurrentDrawer()] -= 1;
		}
		var imageData = this.canvasApp.getImageData();
		var answer = this.canvasApp.getAnswer();
		var filename = answer + "-" + this.getCurrentDrawer() + ".png";
		var drawer = this.getCurrentDrawer();
		var winner = this.winningPlayer;
		saveImage(this.sessionKey, imageData, filename, function(imageHash) {
				var data = {'drawer': drawer,
										'winner':winner,
										'imageHash':imageHash,
										'answer': answer
									 }
				logTurn(this.sessionKey, data);
		});

		this.redraw();
		this.nextDrawing();
		this.canvasApp.message(null, "");
}

/**
 * keyboardHandler(event)
 *
 * Handlers and farms out keyboard events.
 */
/*

}


PictionaryModel.prototype.keyAction = function() {
*/
PictionaryModel.prototype.keyboardHandler = function(event) {
		window.console.log(event);
 		switch(this.state) {
		case STATE.START:
				if (event.keyCode in {13:'',32:''}) {
						this.startDrawing();
				}
				break;
		case STATE.DRAWING:
				if (event.keyCode in {13:'',32:''}) {
						this.gotItClicked();
				}
				break;
		case STATE.SOMEONE_WON:
				if (event.keyCode >= 48 && event.keyCode <= 57) {
						var playerIdx = event.keyCode - 49;
						if (playerIdx == -1) {
								playerIdx = 10;
						}
						if (playerIdx >= this.players.length) {
								this.resumeDrawing();
						} else {
								this.playerWon(this.players[playerIdx]);
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

/////////////////////////////////////////////////////////

function CanvasApp() {
		this.canvas = document.getElementById("main");
		this.context = this.canvas.getContext("2d");
		this.canDraw = false;
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

CanvasApp.prototype.updateScoreUi = function(scores) {

};

CanvasApp.prototype.clear = function() {
		this.canvas.width = this.canvas.width; // clears the canvas
		this.context.fillStyle = "rgb(255, 255, 255)";
		this.context.fillRect (0, 0, this.canvas.width, this.canvas.height);
		this.context.fillStyle = "rgb(0, 0, 0)";
};

CanvasApp.prototype.drawLineToEvent = function(event) {
		context.lineTo(lastEvent.clientX, lastEvent.clientY);
		context.stroke();
};

CanvasApp.prototype.setPenActive = function(isActive) {
		this.isMouseDown = isActive;
};

CanvasApp.prototype.isPenActive = function() {
		return this.isMouseDown && this.canDraw;
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
		context.moveTo(event.clientX, event.clientY);
		this.setPenActive(true);
};

CanvasApp.prototype.mouseOver = function(event) {
		if (event.which) {
				this.mouseDown(event);
		}
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

CanvasApp.prototype.message = function(messageLevel, messageText) {
		message(messageLevel, messageText)
}

CanvasApp.prototype.drawScoreText = function(players, scores) {
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
		setUiForState(state);
}

function message(messageLevel, messageText) {
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

function createButton(pModel, name, index) {
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

		return newButton;
}

function initUI(players, pModel) {
		buttonBar = document.getElementById("buttonBar");
		var playerIdx = 0;
		for (playerIdx=0; playerIdx < players.length; ++playerIdx) {
				var name = players[playerIdx];
				var button = createButton(pModel, name, playerIdx)
				button.onclick = function() {
						pModel.playerWon(this.name);
				};
				buttonBar.appendChild(button);
		}

		var button = createButton(pModel, "Back", (playerIdx))
		button.onclick = function() { pModel.resumeDrawing() };
		buttonBar.appendChild(button);

		document.getElementById("startDrawing").onclick = function() {pModel.startDrawing()};
		document.getElementById("saveButton").onclick = function() {pModel.finishRound()};
		document.getElementById("gotItButton").onclick = function() {pModel.gotItClicked()};
		document.getElementById("changePlayerButton").onclick = function() {pModel.gotItClicked()};
		document.getElementById("changePlayerButton").onkeypress = function(event) {
				if (event.keyCode in {13:'', 32:''}) {
						pModel.gotItClicked()
				}
		};
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

function setUiForState(state) {
		bars = document.getElementsByClassName("statefulBar");
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

function main() {
		var players = PLAYERS;

		var canvasApp = new CanvasApp();
		var pModel = new PictionaryModel(players, canvasApp);

		document.pModel = pModel;

		var canvas = document.getElementById("main");
		context = canvas.getContext('2d');
		initUI(players, pModel);


		document.getElementById("main").addEventListener('mousemove', function(event) { canvasApp.mouseMove(event) }, false);
		document.getElementById("main").addEventListener('mouseup', function(event) { canvasApp.mouseUp(event) }, false);
		document.getElementById("main").addEventListener('mousedown', function(event) { canvasApp.mouseDown(event) }, false);
		document.getElementById("main").addEventListener('mouseover',function(event) { canvasApp.mouseOver(event) }, false);
		document.getElementById("main").addEventListener('mouseout', function(event) { canvasApp.mouseOut(event) }, false);
		document.getElementById("body").addEventListener('keypress', function(event) { pModel.keyboardHandler(event) }, false);
		setUiForState(pModel.state);

		window.onbeforeunload = function() {
				return 'Leaving will lose all game state';
		}
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
