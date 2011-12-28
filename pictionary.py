
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

PORT = 8000

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
        print self.path, filename

        if filename in CustomHTTP._staticFileMap:
            return self.handleStaticFile(filename)

        if getattr(self, "handle_%s" % filename, None):
            data = getattr(self, "handle_%s" % filename)()
            self.send_response(200)
            self.send_header('Content-Type', 'application/xml')
            response = getattr(self, "handle_%s" % filename)()
            self.end_headers()
            self.wfile.write(response)
            return
        self.send_error(404)

    def handle_coffeeMain(self):
        print self.path
        import os
        coffeeScripts = os.listdir("coffee/")
        coffeeScripts.sort()
        scripts = [open("coffee/" + script, "r").read() for script in coffeeScripts]
        scripts.append("main()")
        return "\n".join(scripts)

    def handle_coffeeRemote(self):
        print self.path
        import os
        coffeeScripts = os.listdir("coffee/")
        scripts = [open(script, "r").read() for script in coffeeScripts]
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

        if getattr(self, "handle_%s" % filename):
            self.send_response(200)
            self.send_header('Content-Type', 'application/xml')
            response = getattr(self, "handle_%s" % filename)()
            self.end_headers()
            self.wfile.write(response)
            return
        self.send_error(404)

    def handle_logTurn(self):
        print int(self.headers['Content-Length'])
        sessionKey = self.headers.get('X-Session-Key', "nosession")
        data = self.rfile.read(int(self.headers['Content-Length']))
        data = json.loads(data)
        with open("logs/%s.log" % sessionKey, "a") as sessionLog:
            print >>sessionLog, data
        return "<ok/>"

    def handle_saveImage(self):
        filename = self.headers['X-Image-Filename']
        imageData = self.read_image_helper(self.rfile,
                                           int(self.headers['Content-Length']))
        imageHash = hashlib.md5(imageData).hexdigest()
        self.make_file(filename).write(base64.b64decode(imageData))

        return  """<response>
<imageHash id="imageHash">%s</imageHash>
</response>""" % imageHash

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
