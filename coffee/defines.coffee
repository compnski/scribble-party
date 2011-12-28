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
