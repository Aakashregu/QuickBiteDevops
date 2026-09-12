"""Dummy ordering backend. Uses only Python's standard library."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import urlopen

DATABASE_URL = os.environ.get("DATABASE_URL", "http://database:8001")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/health", "/foods"):
            self.send_error(404)
            return
        try:
            with urlopen(f"{DATABASE_URL}/foods", timeout=5) as response:
                foods = json.load(response)["foods"]
            payload = {"service": "QuickBite dummy backend", "status": "ok"}
            if self.path == "/foods":
                payload.update(database="Compose dummy database, NOT MySQL", foods=foods)
            status = 200
        except Exception:
            payload = {"service": "QuickBite dummy backend", "status": "database unavailable"}
            status = 503
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
