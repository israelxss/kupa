"""
database.py
============
ניהול מסד הנתונים המקומי (SQLite) עבור מנוע המחירים והמבצעים של 'קופה'.
כולל טבלאות למוצרים, סניפים, מחירים, מבצעים, ופריטי מבצעים עם אינדקסים מהירים.
"""

import os
import csv
import sqlite3
from typing import List, Dict, Optional, Any, Tuple

DEFAULT_DB_PATH = os.path.join(os.path.dirname(__file__), "kupa_offline.db")

class KupaDatabase:
    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        self.db_path = db_path
        self._init_schema()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        conn.execute("PRAGMA cache_size = -64000") # 64MB cache
        return conn

    def _init_schema(self):
        with self._get_connection() as conn:
            cur = conn.cursor()
            
            # 1. טבלת רשתות
            cur.execute("""
            CREATE TABLE IF NOT EXISTS chains (
                chain_id TEXT PRIMARY KEY,
                chain_key TEXT,
                name TEXT NOT NULL,
                dataset_id TEXT,
                stores_count INTEGER DEFAULT 0,
                last_snapshot TEXT,
                last_updated_at TEXT
            )
            """)

            # 2. טבלת סניפים
            cur.execute("""
            CREATE TABLE IF NOT EXISTS stores (
                chain_id TEXT,
                store_id TEXT,
                chain_name TEXT,
                sub_chain_name TEXT,
                store_name TEXT,
                address TEXT,
                city TEXT,
                latitude REAL,
                longitude REAL,
                PRIMARY KEY (chain_id, store_id)
            )
            """)

            # וידוא עמודות latitude / longitude / sub_chain_name אם הטבלה כבר נוצרה בעבר
            try:
                cur.execute("ALTER TABLE stores ADD COLUMN sub_chain_name TEXT")
            except Exception:
                pass
            try:
                cur.execute("ALTER TABLE stores ADD COLUMN latitude REAL")
            except Exception:
                pass
            try:
                cur.execute("ALTER TABLE stores ADD COLUMN longitude REAL")
            except Exception:
                pass

            # 3. טבלת מוצרים
            cur.execute("""
            CREATE TABLE IF NOT EXISTS products (
                item_code TEXT PRIMARY KEY,
                item_name TEXT NOT NULL,
                manufacturer_name TEXT,
                unit_of_measure TEXT
            )
            """)

            # 4. טבלת מחירי מוצרים לפי סניף
            cur.execute("""
            CREATE TABLE IF NOT EXISTS prices (
                chain_id TEXT,
                store_id TEXT,
                item_code TEXT,
                item_price REAL NOT NULL,
                unit_of_measure_price REAL,
                price_update_time TEXT,
                PRIMARY KEY (chain_id, store_id, item_code)
            )
            """)

            # 5. טבלת מבצעים
            cur.execute("""
            CREATE TABLE IF NOT EXISTS promotions (
                chain_id TEXT,
                promotion_id TEXT,
                description TEXT,
                start_date TEXT,
                end_date TEXT,
                discounted_price REAL,
                min_qty REAL,
                remarks TEXT,
                PRIMARY KEY (chain_id, promotion_id)
            )
            """)

            # 6. טבלת קישור פריטים למבצעים
            cur.execute("""
            CREATE TABLE IF NOT EXISTS promo_items (
                chain_id TEXT,
                promotion_id TEXT,
                item_code TEXT,
                PRIMARY KEY (chain_id, promotion_id, item_code)
            )
            """)

            # אינדקסים ייעודיים לביצועי שיא
            cur.execute("CREATE INDEX IF NOT EXISTS idx_prices_item ON prices(item_code)")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_prices_store ON prices(chain_id, store_id)")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_stores_city ON stores(city)")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_products_name ON products(item_name)")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_promo_items_code ON promo_items(item_code)")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_promotions_id ON promotions(promotion_id)")
            
            conn.commit()

    def has_data(self) -> bool:
        """בודק אם יש נתונים במסד המקומי"""
        if not os.path.exists(self.db_path):
            return False
        stats = self.get_stats()
        return stats["products"] > 0 or stats["prices"] > 0

    def import_stores_csv(self, csv_file_path: str, chain_id: Optional[str] = None) -> int:
        if not os.path.exists(csv_file_path):
            return 0
        batch = []
        count = 0
        with self._get_connection() as conn:
            cur = conn.cursor()
            with open(csv_file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    c_id = str(row.get("chain_id") or chain_id or "").strip()
                    s_id = str(row.get("store_id", "")).strip()
                    if not c_id or not s_id:
                        continue
                    batch.append((
                        c_id,
                        s_id,
                        row.get("chain_name", "").strip(),
                        row.get("store_name", "").strip(),
                        row.get("address", "").strip(),
                        row.get("city", "").strip(),
                    ))
                    if len(batch) >= 5000:
                        cur.executemany("""
                        INSERT OR REPLACE INTO stores (chain_id, store_id, chain_name, store_name, address, city)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """, batch)
                        count += len(batch)
                        batch.clear()

                if batch:
                    cur.executemany("""
                    INSERT OR REPLACE INTO stores (chain_id, store_id, chain_name, store_name, address, city)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, batch)
                    count += len(batch)
            conn.commit()
        return count

    def import_products_csv(self, csv_file_path: str) -> int:
        if not os.path.exists(csv_file_path):
            return 0
        batch = []
        count = 0
        with self._get_connection() as conn:
            cur = conn.cursor()
            with open(csv_file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    code = str(row.get("item_code", "")).strip()
                    name = str(row.get("item_name", "")).strip()
                    if not code or not name:
                        continue
                    batch.append((
                        code,
                        name,
                        row.get("manufacturer_name", "").strip(),
                        row.get("unit_of_measure", "").strip(),
                    ))
                    if len(batch) >= 10000:
                        cur.executemany("""
                        INSERT OR REPLACE INTO products (item_code, item_name, manufacturer_name, unit_of_measure)
                        VALUES (?, ?, ?, ?)
                        """, batch)
                        count += len(batch)
                        batch.clear()

                if batch:
                    cur.executemany("""
                    INSERT OR REPLACE INTO products (item_code, item_name, manufacturer_name, unit_of_measure)
                    VALUES (?, ?, ?, ?)
                    """, batch)
                    count += len(batch)
            conn.commit()
        return count

    def import_prices_csv(self, csv_file_path: str, chain_id: Optional[str] = None) -> int:
        if not os.path.exists(csv_file_path):
            return 0
        batch = []
        count = 0
        with self._get_connection() as conn:
            cur = conn.cursor()
            with open(csv_file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    c_id = str(row.get("chain_id") or chain_id or "").strip()
                    s_id = str(row.get("store_id", "")).strip()
                    code = str(row.get("item_code", "")).strip()
                    price_raw = row.get("item_price")
                    if not c_id or not s_id or not code or not price_raw:
                        continue
                    try:
                        price = float(price_raw)
                    except ValueError:
                        continue
                    
                    unit_price = None
                    if row.get("unit_of_measure_price"):
                        try:
                            unit_price = float(row.get("unit_of_measure_price"))
                        except ValueError:
                            pass

                    batch.append((
                        c_id,
                        s_id,
                        code,
                        price,
                        unit_price,
                        row.get("price_update_time", "").strip(),
                    ))
                    if len(batch) >= 15000:
                        cur.executemany("""
                        INSERT OR REPLACE INTO prices (chain_id, store_id, item_code, item_price, unit_of_measure_price, price_update_time)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """, batch)
                        count += len(batch)
                        batch.clear()

                if batch:
                    cur.executemany("""
                    INSERT OR REPLACE INTO prices (chain_id, store_id, item_code, item_price, unit_of_measure_price, price_update_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """, batch)
                    count += len(batch)

                # וידוא שכל ברקוד שקיים עבורו מחיר יהיה רשום גם בקטלוג המוצרים
                cur.execute("""
                INSERT OR IGNORE INTO products (item_code, item_name, manufacturer_name, unit_of_measure)
                SELECT DISTINCT item_code, 'מוצר (ברקוד ' || item_code || ')', '', ''
                FROM prices
                WHERE item_code NOT IN (SELECT item_code FROM products)
                """)
            conn.commit()
        return count

    def import_promotions_csv(self, csv_file_path: str, chain_id: Optional[str] = None) -> int:
        """ייבוא קובץ מבצעים (promotions)"""
        if not os.path.exists(csv_file_path):
            return 0
        batch = []
        count = 0
        with self._get_connection() as conn:
            cur = conn.cursor()
            with open(csv_file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    c_id = str(row.get("chain_id") or chain_id or "").strip()
                    p_id = str(row.get("promotion_id", "")).strip()
                    desc = str(row.get("description", "")).strip()
                    if not c_id or not p_id or not desc:
                        continue
                    
                    disc_price = None
                    if row.get("discounted_price"):
                        try:
                            disc_price = float(row.get("discounted_price"))
                        except ValueError:
                            pass

                    min_q = 1.0
                    if row.get("min_qty"):
                        try:
                            min_q = float(row.get("min_qty"))
                        except ValueError:
                            pass

                    batch.append((
                        c_id,
                        p_id,
                        desc,
                        row.get("start_date", "").strip(),
                        row.get("end_date", "").strip(),
                        disc_price,
                        min_q,
                        row.get("remarks", "").strip(),
                    ))
                    if len(batch) >= 5000:
                        cur.executemany("""
                        INSERT OR REPLACE INTO promotions (chain_id, promotion_id, description, start_date, end_date, discounted_price, min_qty, remarks)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """, batch)
                        count += len(batch)
                        batch.clear()

                if batch:
                    cur.executemany("""
                    INSERT OR REPLACE INTO promotions (chain_id, promotion_id, description, start_date, end_date, discounted_price, min_qty, remarks)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, batch)
                    count += len(batch)
            conn.commit()
        return count

    def import_promo_items_csv(self, csv_file_path: str, chain_id: Optional[str] = None) -> int:
        """ייבוא קישור פריטים למבצעים (promo_items)"""
        if not os.path.exists(csv_file_path):
            return 0
        batch = []
        count = 0
        with self._get_connection() as conn:
            cur = conn.cursor()
            with open(csv_file_path, "r", encoding="utf-8-sig", errors="replace") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    c_id = str(row.get("chain_id") or chain_id or "").strip()
                    p_id = str(row.get("promotion_id", "")).strip()
                    code = str(row.get("item_code", "")).strip()
                    if not c_id or not p_id or not code:
                        continue
                    batch.append((c_id, p_id, code))
                    if len(batch) >= 10000:
                        cur.executemany("""
                        INSERT OR REPLACE INTO promo_items (chain_id, promotion_id, item_code)
                        VALUES (?, ?, ?)
                        """, batch)
                        count += len(batch)
                        batch.clear()

                if batch:
                    cur.executemany("""
                    INSERT OR REPLACE INTO promo_items (chain_id, promotion_id, item_code)
                    VALUES (?, ?, ?)
                    """, batch)
                    count += len(batch)

                # הוספת ברקודים ממבצעים שעדיין אינם קיימים בקטלוג המוצרים (עם שם המבצע כשם המוצר)
                cur.execute("""
                INSERT OR IGNORE INTO products (item_code, item_name, manufacturer_name, unit_of_measure)
                SELECT pi.item_code, COALESCE(pr.description, 'מוצר במבצע ' || pi.item_code), '', ''
                FROM promo_items pi
                LEFT JOIN promotions pr ON pi.chain_id = pr.chain_id AND pi.promotion_id = pr.promotion_id
                WHERE pi.item_code NOT IN (SELECT item_code FROM products)
                GROUP BY pi.item_code
                """)
            conn.commit()
        return count

    def get_stores_without_coords(self) -> List[Dict[str, Any]]:
        """מחזיר סניפים שעדיין חסרים להם קואורדינטות"""
        with self._get_connection() as conn:
            cur = conn.cursor()
            cur.execute("""
            SELECT chain_id, store_id, chain_name, store_name, address, city
            FROM stores
            WHERE latitude IS NULL OR longitude IS NULL
            """)
            return [dict(r) for r in cur.fetchall()]

    def batch_update_store_coords(self, updates: List[Tuple[float, float, str, str]]):
        """עדכון מהיר ומרוכז של קואורדינטות (lat, lon, chain_id, store_id)"""
        if not updates:
            return
        with self._get_connection() as conn:
            cur = conn.cursor()
            cur.executemany("""
            UPDATE stores
            SET latitude = ?, longitude = ?
            WHERE chain_id = ? AND store_id = ?
            """, updates)
            conn.commit()

    def get_nearby_stores(self, user_lat: float, user_lon: float, limit: Optional[int] = None, radius_km: float = 25.0) -> List[Dict[str, Any]]:
        """
        מחזיר את כל הסניפים שנמצאים ברדיוס ממיקום המשתמש, ממוינים לפי מרחק אווירי (בק"מ).
        משתמש בנוסחת Haversine מהירה.
        """
        import math

        def haversine(lat1, lon1, lat2, lon2):
            R = 6371.0 # רדיוס כדור הארץ בק"מ
            dlat = math.radians(lat2 - lat1)
            dlon = math.radians(lon2 - lon1)
            a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
            return R * c

        with self._get_connection() as conn:
            cur = conn.cursor()
            cur.execute("""
            SELECT chain_id, store_id, chain_name, sub_chain_name, store_name, address, city, latitude, longitude
            FROM stores
            WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND latitude > 0 AND longitude > 0
            """)
            rows = cur.fetchall()

            stores_with_dist = []
            for r in rows:
                dist = haversine(user_lat, user_lon, r["latitude"], r["longitude"])
                if dist <= radius_km:
                    st = dict(r)
                    st["distance_km"] = round(dist, 2)
                    st["distance_meters"] = int(dist * 1000)
                    stores_with_dist.append(st)

            stores_with_dist.sort(key=lambda x: x["distance_km"])
            if limit:
                return stores_with_dist[:limit]
            return stores_with_dist

    def get_stats(self) -> Dict[str, int]:
        """מחזיר סטטיסטיקה מקיפה על הנתונים במסד המקומי"""
        if not os.path.exists(self.db_path):
            return {"products": 0, "stores": 0, "prices": 0, "chains": 0, "promotions": 0, "geocoded_stores": 0}
        try:
            with self._get_connection() as conn:
                cur = conn.cursor()
                cur.execute("SELECT COUNT(*) FROM products")
                products_count = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM stores")
                stores_count = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM prices")
                prices_count = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM chains")
                chains_count = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM promotions")
                promos_count = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM stores WHERE latitude IS NOT NULL")
                geocoded_count = cur.fetchone()[0]
                return {
                    "products": products_count,
                    "stores": stores_count,
                    "prices": prices_count,
                    "chains": chains_count,
                    "promotions": promos_count,
                    "geocoded_stores": geocoded_count,
                }
        except Exception:
            return {"products": 0, "stores": 0, "prices": 0, "chains": 0, "promotions": 0, "geocoded_stores": 0}
