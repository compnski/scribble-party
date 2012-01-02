
import BaseHTTPServer
import code
import socket
import threading
import SocketServer
import os
import time
import base64
import hashlib
import json
import stat
import urlparse
from sessionmanager import SessionManager

TIMEOUT = 180
PORT = 8000

sessionManager = SessionManager()

class ThreadedTCPRequestHandler(SocketServer.BaseRequestHandler):
    def handle(self):
        data = self.request.recv(1024)
        cur_thread = threading.current_thread()
        response = "{}: {}".format(cur_thread.name, data)
        self.request.send(response)
class ThreadedTCPServer(SocketServer.ThreadingMixIn, SocketServer.TCPServer): pass


def guessContentType(filename):
    ext = os.path.splitext(filename)[1]
    print ext
    if ext == ".html":
        return 'text/html'
    if ext == ".js":
        return 'application/x-javascript'
    if ext == ".css":
        return 'text/css'
    if ext == ".coffee":
        return 'text/coffeescript'
    else:
        return "application/xml"

class CustomHTTP(BaseHTTPServer.BaseHTTPRequestHandler):
    _staticFileMap = {}
    def do_GET(self):
        filename = os.path.basename(self.path)
        filename = filename.split("?")[0]
        print self.path, filename

        if filename in CustomHTTP._staticFileMap:
            return self.handleStaticFile(filename)
        self.do_POST()

    def getCoffeeScripts(self):
        import os
        coffeeScripts = os.listdir("coffee/")
        coffeeScripts.sort()
        scripts = [open("coffee/" + script, "r").read() for script in coffeeScripts if os.path.exists("coffee/" + script)]
        return scripts

    def handle_coffeeMain(self):
        scripts = self.getCoffeeScripts()
        scripts.append("main()")
        return "\n".join(scripts)

    def handle_coffeeRemote(self):
        scripts = self.getCoffeeScripts()
        scripts.append("remote()")
        return "\n".join(scripts)

    @classmethod
    def reloadFile(cls, filename, path, lastMod):
        print "Loading %s" % filename
        cls._staticFileMap[filename] = (path, lastMod, open(path, "rb").read())

    def handleStaticFile(self, filename):
        (path, cacheLastMod, _) = CustomHTTP._staticFileMap[filename]
        try:
            lastMod = os.stat(filename)[stat.ST_MTIME]
            if lastMod > cacheLastMod:
                self.reloadFile(filename, path, lastMod)
            self.send_response(200)
            self.send_header('Content-Type', guessContentType(filename))
            self.end_headers()
            self.wfile.write(CustomHTTP._staticFileMap[filename][2])
        except OSError:
            pass

    def handle_getSessionKey():
        return hashlib.md5("%s:%s" % (time.time(), os.getpid())).hexdigest()

    def do_POST(self):
        filename = os.path.basename(self.path)
        filename = filename.split("?")[0]
        print self.path, filename

        if getattr(self, "handle_%s" % filename, False):
            response = getattr(self, "handle_%s" % filename)()
            if response is None:
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response)
            return
        self.send_error(404)

    def make_file(self, filename):
        if os.path.exists(filename):
            basename = os.path.basename(filename)
            (base,ext) = os.path.splitext(basename)
            base = base + time.time()
            basename = base + "." + ext
            filename = os.path.join(os.path.dirname(filename), basename)

        tmpdir = tempfile.gettempdir()
        tmpdir = "images/"
        return open(os.path.join(tmpdir, filename), "wb")

    def read_image_helper(self, fp, length):
        """Internal: read binary data."""
        imageParts = []
        todo = length
        if todo >= 0:
            while todo > 0:
                data = fp.read(min(todo, fp.bufsize))
                if not data:
                    self.done = -1
                    break
                todo = todo - len(data)
                data = data.split(",")[-1] #Take the second if there is
                imageParts.append(data)
        return "".join(imageParts)

    def handle_logTurn(self):
        print int(self.headers['Content-Length'])
        sessionKey = self.headers.get('X-Session-Key', "nosession")
        data = self.rfile.read(int(self.headers['Content-Length']))
        data = json.loads(data)
        with open("logs/%s.log" % sessionKey, "a") as sessionLog:
            print >>sessionLog, data
        return "[]"

    def handle_saveImage(self):
        filename = self.headers['X-Image-Filename']
        imageData = self.read_image_helper(self.rfile,
                                           int(self.headers['Content-Length']))
        imageHash = hashlib.md5(imageData).hexdigest()
        self.make_file(filename).write(base64.b64decode(imageData))
        return  """{"imageHash":"%s"}""" % imageHash

    @property
    def cgiParams(self):
        return urlparse.parse_qs(urlparse.urlparse(self.path).query)

    def handle_secretRevealed(self):
        sessionKey = self.headers.get('X-Session-Key', None)
        if not sessionKey:
            self.send_error(400)
            return None
        lastUpdateTs = self.cgiParams.get("lastUpdate", 0)
        (lastUpdateTs, session) = sessionManager.getSessionData(sessionKey)
        if session is None:
            lastUpdateTs, session = sessionManager.create(sessionKey)
        session.state = "drawing"
        sessionManager.setSessionData(sessionKey, session)

        ret = dict(round=session.toDict(),
                   lastUpdateTs=lastUpdateTs)
        return json.dumps(ret)

    def handle_roundStart(self):
        sessionKey = self.headers.get('X-Session-Key', None)
        if not sessionKey:
            self.send_error(400)
            return None
        data = self.rfile.read(int(self.headers['Content-Length']))
        if not data:
            self.send_error(400)
            self.log_error("no data")
            return None

        data = json.loads(data)
        lastUpdateTs = self.cgiParams.get("lastUpdate", 0)
        (lastUpdateTs, session) = sessionManager.getSessionData(sessionKey)
        if session is None:
            lastUpdateTs, session = sessionManager.create(sessionKey)
        session.state = "start"
        session.drawer = data.get('drawer', [])
        session.players = data.get('players', [])
        session.category = data.get('category', None)
        sessionManager.setSessionData(sessionKey, session)

        ret = dict(round=session.toDict(),
                   lastUpdateTs=lastUpdateTs)
        return json.dumps(ret)

    def handle_correctGuess(self):
        sessionKey = self.headers.get('X-Session-Key', None)
        if not sessionKey:
            self.send_error(400)
            return None
        lastUpdateTs = self.cgiParams.get("lastUpdate", 0)
        (updateTime, session) = sessionManager.getSessionData(sessionKey)
        session.state = "correctguess"
        sessionManager.setSessionData(sessionKey, session)

        return session.toJson()

    def handle_waitForData(self):
        sessionKey = self.headers.get('X-Session-Key', None)
        if not sessionKey:
            self.send_error(400)
            return None
        lastUpdateTs = self.cgiParams.get("lastUpdate", 0)
        (lastUpdateTs, session) = sessionManager.getSessionData(sessionKey, lastUpdateTs, True, 100)
        if session is None:
            print "204 "*10
            self.send_response(204)
            return None
        print lastUpdateTs, session
        ret = dict(round=session.toDict(),
                   lastUpdateTs=lastUpdateTs)
        return json.dumps(ret)


def loadFiles():
    files = ['pictionary.css','pictionary.js','pictionary.html',
             'pictionary.coffee','favicon.ico', 'remote.html', 'remote.coffee']
    for filename in files:
        try:
            lastMod = os.stat(filename)[stat.ST_MTIME]
            CustomHTTP.reloadFile(filename, filename, lastMod)
        except (IOError, OSError):
            print "File %s not found, cannot serve it." % filename

import tempfile

Handler = CustomHTTP

ThreadedTCPServer.allow_reuse_address = True

httpd = ThreadedTCPServer(("", PORT), Handler)
httpd.allow_reuse_address = True
print "serving at port", PORT

try:
    loadFiles()
    httpd.serve_forever()
except KeyboardInterrupt:
    pass
