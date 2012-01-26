# Scribble Party

## A local multiplayer picture drawing game for projector and tablet.

Scribble Party was written to play pictionary with friends. 

## Usage Instructions:

Edit the PLAYERS = [] array in coffee/defines.coffee.
> python main.py
> open http://localhost:8000/main.html

If you want to use the remote, then go to http://localhost:8000/remote.html
Clues don't yet work but you can use the remote to drive the interface,
but there isn't much of a point yet.

Images get saves to images/,  gamelogs to logs/.
Images and logs are saved even if the remote stops working.

## Scoring Rules:

Person Drawing:
+1 for any correct guess.
-1 if time runs out.

People Guessing:
+2 points for a correct guess.

## TODO:
* Use <button>s
* Work on drawing, look at offset
* Thicker line (Fade to sides)
* Disable right-cick (Maybe eraser?, thick eraser)
* Show eraser on screen
* Maybe show pen too
* Erase all (confirm)
* Extra z-buffers that you can toggle between
* colors
* Undo state (Either keep an extra buffer for every stroke, or the last N,
  Maybe keep a buffer that is all but the N current strokes, N = 1 to start.
  On undo, just draw the old buffer and discard the undo-state.