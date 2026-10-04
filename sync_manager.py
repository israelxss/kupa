"""
sync_manager.py
===============
מנהל סנכרון והורדה חכמה של מאגרי המחירים והמבצעים מאתר 'גרסאות לעם'.
מזהה חיבור לאינטרנט, מזהה שינויים ועדכונים ברשתות, מוריד ומייבא מוצרים, מחירים ומבצעים.
"""

import os
import sys
import json
import time
import urllib.request
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Optional, Any, Tuple

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
from over_api_client import OverApiClient
from database import KupaDatabase

DATA_CACHE_DIR = os.path.join(os.path.dirname(__file__), "data_cache")
STATE_FILE = os.path.join(os.path.dirname(__file__), "sync_state.json")

class SyncManager:
    def __init__(self, db: Optional[KupaDatabase] = None):
        self.api = OverApiClient()
        self.db = db or KupaDatabase()
        self.cache_dir = DATA_CACHE_DIR
        os.makedirs(self.cache_dir, exist_ok=True)
        self.state = self._load_state()

    def _load_state(self) -> Dict[str, Any]:
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {"chains": {}, "last_check": None}

    def _save_state(self):
        try:
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(self.state, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[שגיאה בשמירת מצב]: {e}")

    def check_internet_connection(self) -> Tuple[bool, str]:
        """
        בודק האם יש חיבור לאינטרנט והאם שרתי 'גרסאות לעם' נגישים.
        מחזיר (האם מחובר, הודעת סטטוס).
        """
        try:
            req = urllib.request.Request("https://www.over.org.il/favicon.svg", headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=4) as resp:
                if resp.status == 200:
                    return True, "מחובר לרשת ושרתי 'גרסאות לעם' זמינים."
        except Exception as e:
            return False, f"אין גישה לאינטרנט או ששרת 'גרסאות לעם' אינו מגיב ({e})"
        return False, "שגיאת תקשורת בלתי צפויה."

    def list_available_sources(self) -> List[Dict[str, Any]]:
        """בודק ומחזיר את כל המאגרים והרשתות הזמינים באתר"""
        chains = self.api.get_chains()
        self.state["last_check"] = time.strftime("%Y-%m-%d %H:%M:%S")
        self._save_state()
        return chains

    def check_for_updates(self) -> Dict[str, Any]:
        """
        בודק באתר האם יש גרסאות מעודכנות יותר ממה ששמור במחשב.
        מחזיר רשימת רשתות הדורשות עדכון, ורשימת רשתות מעודכנות.
        """
        is_online, msg = self.check_internet_connection()
        if not is_online:
            return {"online": False, "message": msg, "updates_available": [], "up_to_date": []}

        chains = self.list_available_sources()
        updates_available = []
        up_to_date = []

        local_chains = self.state.get("chains", {})

        for c in chains:
            ds_id = c.get("dataset_id")
            c_name = c.get("name") or c.get("account")
            if not ds_id:
                continue

            last_local = local_chains.get(ds_id)
            if not last_local:
                # רשת שמעולם לא יובאה למחשב
                updates_available.append({
                    "chain_info": c,
                    "reason": "חדש (לא יובא עדיין)",
                    "local_version": None,
                    "remote_snapshot": c.get("latest_snapshot"),
                })
            else:
                # בדיקה מול הגרסה באתר
                remote_snap = c.get("latest_snapshot")
                local_sync_time = last_local.get("last_synced_at", "")[:10]
                if remote_snap and remote_snap > local_sync_time:
                    updates_available.append({
                        "chain_info": c,
                        "reason": f"קיים עדכון מתאריך {remote_snap} (מקומי מ-{local_sync_time})",
                        "local_version": last_local.get("version_id"),
                        "remote_snapshot": remote_snap,
                    })
                else:
                    up_to_date.append({
                        "chain_info": c,
                        "local_version": last_local.get("version_id"),
                        "synced_at": last_local.get("last_synced_at"),
                    })

        return {
            "online": True,
            "message": "בדיקת העדכונים הושלמה בהצלחה.",
            "total_remote": len(chains),
            "updates_available": updates_available,
            "up_to_date": up_to_date,
        }

    def sync_all_stores_nationwide(self) -> int:
        """
        שולף את כל רשימת הסניפים של כל הרשתות בישראל (2,350+ סניפים)
        מתוך הטבלה האחידה באתר ומייבא אותם ל-SQLite המקומי.
        """
        print("🏪 מוריד ומעדכן את כל רשימת הסניפים של כל הרשתות בישראל...")
        total_imported = 0
        offset = 0
        batch_stores = []

        with self.db._get_connection() as conn:
            cur = conn.cursor()
            while True:
                url = f"https://www.over.org.il/api/prices/table/prices_stores?limit=1000&offset={offset}"
                data = self.api._get_json(url)
                if not data or "rows" not in data:
                    break
                rows = data.get("rows", [])
                if not rows:
                    break

                for r in rows:
                    chain_id = str(r.get("chain") or r.get("chain_name") or "").strip()
                    store_id = str(r.get("store_id", "")).strip()
                    if not chain_id or not store_id:
                        continue
                    
                    batch_stores.append((
                        chain_id,
                        store_id,
                        str(r.get("chain_name", "")).strip(),
                        str(r.get("sub_chain_name", "")).strip(),
                        str(r.get("store_name", "")).strip(),
                        str(r.get("address", "")).strip(),
                        str(r.get("city", "") or r.get("city_raw", "")).strip(),
                    ))

                if len(batch_stores) >= 500:
                    cur.executemany("""
                    INSERT OR REPLACE INTO stores (chain_id, store_id, chain_name, sub_chain_name, store_name, address, city)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, batch_stores)
                    total_imported += len(batch_stores)
                    batch_stores.clear()

                if not data.get("has_more"):
                    break
                offset += len(rows)

            if batch_stores:
                cur.executemany("""
                INSERT OR REPLACE INTO stores (chain_id, store_id, chain_name, sub_chain_name, store_name, address, city)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, batch_stores)
                total_imported += len(batch_stores)

            conn.commit()

        print(f"✓ סנכרון סניפים ארצי הושלם: {total_imported:,} סניפים עודכנו בהצלחה!")
        return total_imported

    def sync_chain(self, chain_info: Dict[str, Any], force: bool = False, fetch_promos: bool = True) -> bool:
        """
        מוריד ומייבא את נתוני הרשת (מוצרים, סניפים, מחירים ומבצעים).
        """
        chain_name = chain_info.get("name") or chain_info.get("account")
        dataset_id = chain_info.get("dataset_id")
        chain_id = chain_info.get("chain")

        if not dataset_id:
            print(f"⚠️ אין מזהה מאגר (dataset_id) עבור רשת {chain_name}")
            return False

        print(f"\n📦 בודק גרסה אחרונה עבור רשת '{chain_name}'...")
        version_meta = self.api.get_latest_dataset_version(dataset_id)
        if not version_meta:
            print(f"❌ לא נמצאה גרסה זמינה עבור {chain_name}")
            return False

        v_id = version_meta.get("version_id")
        last_synced_v = self.state.get("chains", {}).get(dataset_id, {}).get("version_id")

        if not force and v_id == last_synced_v:
            print(f"✅ הרשת '{chain_name}' כבר מעודכנת לגרסה האחרונה ({v_id}).")
            return True

        resources = version_meta.get("resources", {})
        chain_folder = os.path.join(self.cache_dir, chain_info.get("account") or dataset_id)
        os.makedirs(chain_folder, exist_ok=True)

        imported_stats = {}

        # 1. סניפים
        stores_url = resources.get("סניפים")
        if stores_url:
            stores_path = os.path.join(chain_folder, "stores.csv")
            print(f"  📥 מוריד קובץ סניפים...")
            if self.api.download_file(stores_url, stores_path):
                cnt = self.db.import_stores_csv(stores_path, chain_id=chain_id)
                imported_stats["stores"] = cnt
                print(f"    ✓ יובאו {cnt:,} סניפים.")

        # 2. מוצרים
        products_url = resources.get("מוצרים")
        if products_url:
            products_path = os.path.join(chain_folder, "products.csv")
            print(f"  📥 מוריד קובץ מוצרים...")
            if self.api.download_file(products_url, products_path):
                cnt = self.db.import_products_csv(products_path)
                imported_stats["products"] = cnt
                print(f"    ✓ יובאו {cnt:,} מוצרים.")

        # 3. מחירים
        prices_url = resources.get("מחירים")
        if prices_url:
            prices_path = os.path.join(chain_folder, "prices.csv")
            print(f"  📥 מוריד קובץ מחירי סניפים...")
            if self.api.download_file(prices_url, prices_path):
                cnt = self.db.import_prices_csv(prices_path, chain_id=chain_id)
                imported_stats["prices"] = cnt
                print(f"    ✓ יובאו {cnt:,} מחירי פריטים.")

        # 4. מבצעים (אם מבוקש)
        if fetch_promos:
            promos_url = resources.get("מבצעים")
            if promos_url:
                promos_path = os.path.join(chain_folder, "promotions.csv")
                print(f"  📥 מוריד קובץ מבצעים...")
                if self.api.download_file(promos_url, promos_path):
                    cnt = self.db.import_promotions_csv(promos_path, chain_id=chain_id)
                    imported_stats["promotions"] = cnt
                    print(f"    ✓ יובאו {cnt:,} מבצעים.")

            promo_items_url = resources.get("פריטי מבצעים")
            if promo_items_url:
                pitems_path = os.path.join(chain_folder, "promo_items.csv")
                print(f"  📥 מוריד קובץ פריטי מבצעים...")
                if self.api.download_file(promo_items_url, pitems_path):
                    cnt = self.db.import_promo_items_csv(pitems_path, chain_id=chain_id)
                    imported_stats["promo_items"] = cnt
                    print(f"    ✓ שויכו {cnt:,} פריטים למבצעים.")

        # עדכון מצב מקומי
        if "chains" not in self.state:
            self.state["chains"] = {}
        self.state["chains"][dataset_id] = {
            "name": chain_name,
            "chain_id": chain_id,
            "version_id": v_id,
            "last_synced_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            "stats": imported_stats,
        }
        self._save_state()
        print(f"🎉 סנכרון רשת '{chain_name}' הושלם בהצלחה!")
        return True

    def sync_chains_parallel(self, chains_list: List[Dict[str, Any]], max_workers: int = 4, force: bool = False) -> None:
        """
        מוריד ומסנכרן מספר רשתות במקביל (Multi-Threaded) למהירות שיא.
        מוריד את קובצי ה-CSV ברקע ומייבא ל-SQLite.
        """
        print(f"\n🚀 מתחיל סנכרון מקבילי עבור {len(chains_list)} רשתות (באמצעות {max_workers} תהליכים במקביל)...")
        start_t = time.time()
        
        db_write_lock = threading.Lock()

        def sync_worker(chain_info):
            chain_name = chain_info.get("name") or chain_info.get("account")
            dataset_id = chain_info.get("dataset_id")
            chain_id = chain_info.get("chain")

            if not dataset_id:
                return False

            version_meta = self.api.get_latest_dataset_version(dataset_id)
            if not version_meta:
                return False

            v_id = version_meta.get("version_id")
            last_synced_v = self.state.get("chains", {}).get(dataset_id, {}).get("version_id")
            if not force and v_id == last_synced_v:
                print(f"  • רשת '{chain_name}' כבר מעודכנת.")
                return True

            resources = version_meta.get("resources", {})
            chain_folder = os.path.join(self.cache_dir, chain_info.get("account") or dataset_id)
            os.makedirs(chain_folder, exist_ok=True)

            print(f"  📥 [התחלה] מוריד מאגרים עבור '{chain_name}'...")
            downloaded_files = {}
            for res_name, key in [("stores.csv", "סניפים"), ("products.csv", "מוצרים"), ("prices.csv", "מחירים"), ("promotions.csv", "מבצעים"), ("promo_items.csv", "פריטי מבצעים")]:
                url = resources.get(key)
                if url:
                    dest = os.path.join(chain_folder, res_name)
                    if self.api.download_file(url, dest):
                        downloaded_files[key] = dest

            # ייבוא ל-SQLite תחת נעילת כתיבה (למניעת התנגשויות נעילת DB)
            stats = {}
            with db_write_lock:
                if "סניפים" in downloaded_files:
                    stats["stores"] = self.db.import_stores_csv(downloaded_files["סניפים"], chain_id=chain_id)
                if "מוצרים" in downloaded_files:
                    stats["products"] = self.db.import_products_csv(downloaded_files["מוצרים"])
                if "מחירים" in downloaded_files:
                    stats["prices"] = self.db.import_prices_csv(downloaded_files["מחירים"], chain_id=chain_id)
                if "מבצעים" in downloaded_files:
                    stats["promotions"] = self.db.import_promotions_csv(downloaded_files["מבצעים"], chain_id=chain_id)
                if "פריטי מבצעים" in downloaded_files:
                    stats["promo_items"] = self.db.import_promo_items_csv(downloaded_files["פריטי מבצעים"], chain_id=chain_id)

                if "chains" not in self.state:
                    self.state["chains"] = {}
                self.state["chains"][dataset_id] = {
                    "name": chain_name,
                    "chain_id": chain_id,
                    "version_id": v_id,
                    "last_synced_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "stats": stats,
                }
                self._save_state()

            prods = stats.get("products", 0)
            prices = stats.get("prices", 0)
            promos = stats.get("promotions", 0)
            print(f"  ✓ [הושלם] רשת '{chain_name}': {prods:,} מוצרים | {prices:,} מחירים | {promos:,} מבצעים.")
            return True

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(sync_worker, ch) for ch in chains_list]
            for f in as_completed(futures):
                try:
                    f.result()
                except Exception as e:
                    print(f"  ⚠️ שגיאה בסנכרון: {e}")

        total_elapsed = round(time.time() - start_t, 2)
        print(f"\n🎉 כל הרשתות סונכרנו במקביל בהצלחה תוך {total_elapsed} שניות בלבד!")

        # בדיקה והוספת קואורדינטות אוטומטית לכל סניף חדש שנוסף בסנכרון
        from geocoder import ParallelGeocoder
        missing = self.db.get_stores_without_coords()
        if missing:
            print(f"\n📍 זוהו {len(missing):,} סניפים חדשים הדורשים מיפוי גיאוגרפי.")
            ParallelGeocoder(self.db, max_workers=20).run_fast_geocoding()
