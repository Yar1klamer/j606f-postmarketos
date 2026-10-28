#!/usr/bin/env python3
"""Простой HTTP-прокси на Mac для планшета в USB-сети (у планшета нет выхода в интернет).
Только GET, только к фиксированному списку зеркал (*.apk кэшируются в out/proxy-cache/):
  /alpine/...   -> https://dl-cdn.alpinelinux.org/alpine/...
  /pmos/...     -> https://mirror.nura.eco/postmarketos/...
  /codeberg/... -> https://codeberg.org/...
  /local/...    -> файлы из каталога pmos-j606f/out/serve/ (отдача артефактов на планшет)
Запуск: python3 -I scripts/mirror_proxy.py 0.0.0.0 8080   (отвечает только клиентам 169.254.0.0/16)"""
import http.server, os, shutil, socketserver, ssl, sys, urllib.request

try:
    import certifi
    CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    CTX = ssl.create_default_context()

UPSTREAM = {
    "/alpine/": "https://dl-cdn.alpinelinux.org/alpine/",
    "/pmos/": "https://mirror.nura.eco/postmarketos/",
    "/codeberg/": "https://codeberg.org/",
}
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "proxy-cache")
# Разрешённые клиенты: USB link-local (планшет) и localhost (pmbootstrap на сборочном хосте)
ALLOWED = ("169.254.", "127.0.0.1") + tuple(x for x in os.environ.get("MIRROR_ALLOW", "").split(",") if x)
# Обход DNS-блокировки mirror.nura.eco в домашней сети: PMOS_PIN_IP=95.216.1.254 → ходим по IP с заголовком Host
PIN_IP = os.environ.get("PMOS_PIN_IP")
SERVE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "serve")


class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # только USB link-local клиенты (планшет); домашняя сеть получает 403
        if not self.client_address[0].startswith(ALLOWED):
            return self.send_error(403)
        if self.path.startswith("/local/"):
            p = os.path.realpath(os.path.join(SERVE, self.path[len("/local/"):]))
            if not p.startswith(os.path.realpath(SERVE)) or not os.path.isfile(p):
                return self.send_error(404)
            self.send_response(200)
            self.send_header("Content-Length", str(os.path.getsize(p)))
            self.end_headers()
            with open(p, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return
        for pre, up in UPSTREAM.items():
            if self.path.startswith(pre):
                url = up + self.path[len(pre):]
                break
        else:
            return self.send_error(404)
        cpath = os.path.join(CACHE, self.path.lstrip("/"))
        if self.path.endswith(".apk") and os.path.isfile(cpath):
            self.send_response(200)
            self.send_header("Content-Length", str(os.path.getsize(cpath)))
            self.end_headers()
            with open(cpath, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return
        try:
            hdrs = {"User-Agent": "j606f-port-proxy"}
            if PIN_IP and url.startswith("https://mirror.nura.eco/"):
                url = "http://" + PIN_IP + url[len("https://mirror.nura.eco"):]
                hdrs["Host"] = "mirror.nura.eco"
            req = urllib.request.Request(url, headers=hdrs)
            with urllib.request.urlopen(req, timeout=120, context=CTX) as r:
                self.send_response(r.status)
                for k in ("Content-Length", "Content-Type", "Last-Modified", "ETag"):
                    if r.headers.get(k):
                        self.send_header(k, r.headers[k])
                self.end_headers()
                if self.path.endswith(".apk"):
                    data = r.read()
                    os.makedirs(os.path.dirname(cpath), exist_ok=True)
                    with open(cpath + ".tmp", "wb") as f:
                        f.write(data)
                    os.replace(cpath + ".tmp", cpath)
                    self.wfile.write(data)
                else:
                    shutil.copyfileobj(r, self.wfile, 1 << 20)
        except urllib.error.HTTPError as e:
            self.send_error(e.code)
        except Exception as e:
            self.send_error(502, str(e)[:100])

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))


class S(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


os.makedirs(SERVE, exist_ok=True)
S((sys.argv[1], int(sys.argv[2])), H).serve_forever()
