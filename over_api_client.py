"""
over_api_client.py
===================
מודול לתקשורת עם מאגרי הנתונים הפתוחים של אתר 'גרסאות לעם' (over.org.il).
מבצע בדיקה של המאגרים הפעילים, זיהוי גרסאות אחרונות והורדת קבצי ה-CSV הגולמיים.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.error
from typing import List, Dict, Optional, Any

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

BASE_URL = "https://www.over.org.il"
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

class OverApiClient:
    def __init__(self, timeout: int = 20):
        self.timeout = timeout

    def _get_json(self, url: str) -> Optional[Any]:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                data = resp.read().decode("utf-8")
                return json.loads(data)
        except Exception as e:
            print(f"[שגיאה בפנייה ל-{url}]: {e}")
            return None

    def get_chains(self) -> List[Dict[str, Any]]:
        """
        שולף את רשימת כל הרשתות הפעילות ממאגר המחירים של 'גרסאות לעם'.
        מחזיר לכל רשת: שם, מזהה, dataset_id, תאריך סריקה אחרון, וכמות סניפים.
        """
        url = f"{BASE_URL}/api/prices/chains"
        data = self._get_json(url)
        if not data or "chains" not in data:
            return []
        
        chains = []
        for c in data.get("chains", []):
            chains.append({
                "chain": c.get("chain"),
                "name": c.get("name"),
                "account": c.get("account"),
                "dataset_id": c.get("dataset_id"),
                "stores_count": c.get("stores", 0),
                "latest_snapshot": c.get("latest_snapshot"),
                "last_polled_at": c.get("last_polled_at"),
                "source_url": c.get("source_url"),
            })
        return chains

    def get_latest_dataset_version(self, dataset_id: str) -> Optional[Dict[str, Any]]:
        """
        בודק ומחזיר את מטא-דאטא של הגרסה העדכנית ביותר עבור dataset_id מסוים,
        כולל רשימת ה-resources (קבצי ה-CSV של מוצרים, מחירים, סניפים, מבצעים).
        """
        if not dataset_id:
            return None
        url = f"{BASE_URL}/api/v1/datasets/{dataset_id}/versions/latest"
        version_data = self._get_json(url)
        if not version_data:
            return None

        resources = {}
        for res in version_data.get("resources", []):
            name = res.get("name", "").strip()
            download_url = res.get("download_url")
            if download_url and name:
                resources[name] = download_url

        return {
            "version_id": version_data.get("id"),
            "version_number": version_data.get("version_number"),
            "detected_at": version_data.get("detected_at"),
            "metadata_modified": version_data.get("metadata_modified"),
            "resources": resources,
        }

    def download_file(self, url: str, destination_path: str, progress_callback=None) -> bool:
        """
        מוריד קובץ (בדרך כלל CSV מ-Cloudflare R2) בצורה יעילה עם מעקב התקדמות ויזואלי.
        """
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        os.makedirs(os.path.dirname(destination_path), exist_ok=True)
        temp_dest = destination_path + ".tmp"

        try:
            with urllib.request.urlopen(req, timeout=60) as resp, open(temp_dest, "wb") as out_file:
                total_size = resp.headers.get("Content-Length")
                total_bytes = int(total_size) if total_size else None
                downloaded = 0
                chunk_size = 1024 * 64
                last_print_time = 0

                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    out_file.write(chunk)
                    downloaded += len(chunk)
                    
                    cur_time = time.time()
                    if progress_callback:
                        progress_callback(downloaded, total_bytes)
                    elif total_bytes and (cur_time - last_print_time > 0.4):
                        last_print_time = cur_time
                        pct = int((downloaded / total_bytes) * 100)
                        bar_len = 25
                        filled = int(bar_len * downloaded / total_bytes)
                        bar = "█" * filled + "░" * (bar_len - filled)
                        mb_down = downloaded / (1024 * 1024)
                        mb_tot = total_bytes / (1024 * 1024)
                        sys.stdout.write(f"\r    [{bar}] {pct}% ({mb_down:.1f}/{mb_tot:.1f} MB)")
                        sys.stdout.flush()

                if total_bytes and not progress_callback:
                    mb_tot = total_bytes / (1024 * 1024)
                    sys.stdout.write(f"\r    [█████████████████████████] 100% ({mb_tot:.1f} MB הושלמו)\n")
                    sys.stdout.flush()

            if os.path.exists(destination_path):
                os.remove(destination_path)
            os.rename(temp_dest, destination_path)
            return True
        except Exception as e:
            if os.path.exists(temp_dest):
                try:
                    os.remove(temp_dest)
                except Exception:
                    pass
            print(f"\n[שגיאת הורדה מ-{url}]: {e}")
            return False
