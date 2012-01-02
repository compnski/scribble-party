import time
from collections import defaultdict
import Queue
import json
import random

class Error(BaseException): pass
class SessionDataTimeout(Error): pass
TIMEOUT = 100
secretList = [('Person', 'George Washington'),
              ('Person', 'Grizzly Bear')]

class PictionarySession:
    def __init__(self, sessionKey, players, state = "start"):
        self.sessionKey = sessionKey
        self.players = players
        self.state = state
        self.secret = secretList[random.randint(0, len(secretList) - 1)][1]
        self.drawer = None
        self.category = None

    def toDict(self):
        return dict(state=self.state,
                    secret=self.secret,
                    category=self.category,
                    drawer=self.drawer)
    def toJson(self):
        return json.dumps(self.toDict())

class SessionManager(object):

    def create(self, sessionKey):
        data = PictionarySession(sessionKey, [])
        return self.setSessionData(sessionKey, data)

    def setSessionData(self, sessionKey, session):
        print "setSessionData", session
        data = (time.time(), session)
        self._sessionMap[sessionKey] = data
        self.publishSessionData(sessionKey, data)
        return data

    def getSessionData(self, sessionKey, lastUpdate=0, block=False, timeout=0):
        """Returns (lastUpdateMs, sessionData).
        If there is no data and block is false, returns None, None.
        If the data is older than lastUpdateMs and block is false, returns the data.
        If block is true then wait to see if someone pushes session data
        for timeout seconds.
        """
        sessionData = self._sessionMap.get(sessionKey, (None, None))
        if not block:
            return sessionData
        print "getData", sessionData[0], lastUpdate, sessionData[0] >= lastUpdate
        if sessionData[0] is None or sessionData[0] < lastUpdate:
            try:
                sessionData = self.waitForSessionData(sessionKey, timeout)
            except SessionDataTimeout:
                pass
        return sessionData

    def __init__(self):
        self._waitQueueMap = defaultdict(list)
        self._sessionMap = {}

    def waitForSessionData(self, sessionKey, timeout=TIMEOUT):
        q = Queue.Queue()
        self._waitQueueMap[sessionKey].append(q)
        try:
            return q.get(timeout=timeout)
        except Queue.Empty:
            raise SessionDataTimeout()
        finally:
            self._waitQueueMap[sessionKey].remove(q)

    def publishSessionData(self, sessionKey, data):
        if sessionKey not in self._waitQueueMap:
            return 0
        for q in self._waitQueueMap[sessionKey]:
            q.put(data)
        return len(self._waitQueueMap[sessionKey])

