"""In-memory HTTP database STUB, not MySQL and not durable storage.

The real MySQL server required by Tasks 1-2 runs separately on private EC2.
This stub fulfills Task 3's explicit request for a dummy database container.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

FOODS = [
    {"id": 1, "name": "Margherita Pizza", "restaurant": "Campus Kitchen"},
    {"id": 2, "name": "Veg Burger", "restaurant": "Burger Corner"},
    {"id": 3, "name": "Veg Biryani", "restaurant": "Spice House"},
]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            payload = {"service": "QuickBite dummy database", "status": "ok"}
        elif self.path == "/foods":
            payload = {"foods": FOODS}
        else:
            self.send_error(404)
            return
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8001), Handler).serve_forever()
