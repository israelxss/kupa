"""
local_api_server.py
===================
שרת מקומי קל משקל (Zero Dependencies - מבוסס ספריית Standard Python בלבד).
חושף ממשק REST API מקומי הזהה במדויק ל-API של 'גרסאות לעם',
כך שכל שאילתה מקבלת תשובה תוך 2-5 מילישניות מתוך מסד ה-SQLite המקומי!
"""

import json
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from offline_kupa_engine import OfflineKupaEngine
from database import KupaDatabase

engine = OfflineKupaEngine()

class KupaLocalHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        # 1. חיפוש מוצרים: /api/prices/table/prices_products?q=... או /api/prices/products?q=...
        if "/prices_products" in path or path.endswith("/products"):
            q = params.get("q", [""])[0]
            limit = int(params.get("limit", [15])[0])
            items = engine.search_products(q, limit=limit)
            return self._send_json(200, {"rows": items, "count": len(items)})

        # 2. השוואת מוצר בודד: /api/prices/compare?item_code=...&city=...
        if path.endswith("/compare"):
            item_code = params.get("item_code", [""])[0]
            city = params.get("city", [None])[0]
            res = engine.compare_item(item_code, city=city)
            return self._send_json(200, res)

        # 3. סטטיסטיקה מקומית
        if path.endswith("/stats"):
            stats = engine.db.get_stats()
            return self._send_json(200, stats)

        self._send_json(404, {"error": "Not Found", "path": path})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        # השוואת סל שלם: /api/prices/basket
        if path.endswith("/basket"):
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8")
            try:
                data = json.loads(post_body)
            except Exception:
                return self._send_json(400, {"error": "Invalid JSON"})

            items = data.get("items", [])
            city = data.get("city")
            top = int(data.get("top", 15))
            res = engine.compare_basket(items, city=city, top=top)
            return self._send_json(200, res)

        self._send_json(404, {"error": "Not Found", "path": path})

def run_server(port: int = 8080):
    server_address = ("127.0.0.1", port)
    httpd = HTTPServer(server_address, KupaLocalHandler)
    print(f"🚀 שרת 'קופה אופליין' פעיל בכתובת: http://127.0.0.1:{port}")
    print("זמין לשאילתות מקומיות באפס זמני תגובה!")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nהשרת נעצר.")

if __name__ == "__main__":
    run_server()
