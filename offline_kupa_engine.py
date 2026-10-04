"""
offline_kupa_engine.py
======================
מנוע השוואת מחירים, מבצעים, אלטרנטיבות וסלי קניות הפועל 100% אופליין.
מממש חיפוש מהיר, שליפת מבצעים פעילים, הצעת אלטרנטיבות זולות יותר וחישוב סל שלם.
"""

from typing import List, Dict, Optional, Any
from database import KupaDatabase

class OfflineKupaEngine:
    def __init__(self, db: Optional[KupaDatabase] = None):
        self.db = db or KupaDatabase()

    def search_products(self, query: str, limit: int = 200) -> List[Dict[str, Any]]:
        clean_q = query.strip()
        if not clean_q:
            return []

        with self.db._get_connection() as conn:
            cur = conn.cursor()
            
            if clean_q.isdigit():
                cur.execute("""
                SELECT item_code, item_name, manufacturer_name, unit_of_measure
                FROM products
                WHERE item_code = ?
                """, (clean_q,))
                row = cur.fetchone()
                if row:
                    return [{
                        "item_code": row["item_code"],
                        "item_name": row["item_name"],
                        "manufacturer_name": row["manufacturer_name"] or "",
                        "unit_of_measure": row["unit_of_measure"] or "",
                    }]

            search_param = f"%{clean_q}%"
            cur.execute("""
            SELECT item_code, item_name, manufacturer_name, unit_of_measure
            FROM products
            WHERE item_name LIKE ? OR item_code LIKE ?
            ORDER BY 
                CASE 
                    WHEN item_code = ? THEN 1
                    WHEN item_name LIKE ? THEN 2
                    ELSE 3
                END
            LIMIT ?
            """, (search_param, search_param, clean_q, f"{clean_q}%", limit))
            
            results = []
            for r in cur.fetchall():
                results.append({
                    "item_code": r["item_code"],
                    "item_name": r["item_name"],
                    "manufacturer_name": r["manufacturer_name"] or "",
                    "unit_of_measure": r["unit_of_measure"] or "",
                })
            return results

    def get_product_promotions(self, item_code: str, chain_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        שולף את כל המבצעים הפעילים הקיימים עבור מוצר מסוים.
        """
        code = item_code.strip()
        with self.db._get_connection() as conn:
            cur = conn.cursor()
            query = """
            SELECT 
                p.chain_id,
                p.promotion_id,
                p.description,
                p.start_date,
                p.end_date,
                p.discounted_price,
                p.min_qty,
                p.remarks,
                c.name as chain_name
            FROM promo_items pi
            JOIN promotions p ON pi.chain_id = p.chain_id AND pi.promotion_id = p.promotion_id
            LEFT JOIN chains c ON p.chain_id = c.chain_id
            WHERE pi.item_code = ?
            """
            params = [code]
            if chain_id:
                query += " AND pi.chain_id = ?"
                params.append(chain_id)

            cur.execute(query, params)
            rows = cur.fetchall()

            promos = []
            for r in rows:
                promos.append({
                    "chain_id": r["chain_id"],
                    "chain_name": r["chain_name"] or r["chain_id"],
                    "promotion_id": r["promotion_id"],
                    "description": r["description"],
                    "start_date": r["start_date"],
                    "end_date": r["end_date"],
                    "discounted_price": r["discounted_price"],
                    "min_qty": r["min_qty"],
                    "remarks": r["remarks"],
                })
            return promos

    def find_alternatives(self, item_code: str, limit: int = 4) -> List[Dict[str, Any]]:
        """
        מוצא מוצרים אלטרנטיביים דומים (לפי מילות מפתח בשם או יצרן)
        שנמכרים במחיר ממוצע נמוך יותר ומציע אותם כחיסכון למשתמש!
        """
        code = item_code.strip()
        with self.db._get_connection() as conn:
            cur = conn.cursor()
            cur.execute("SELECT item_name, manufacturer_name FROM products WHERE item_code = ?", (code,))
            prod = cur.fetchone()
            if not prod:
                return []

            name = prod["item_name"]
            # מציאת מחיר ממוצע נוכחי
            cur.execute("SELECT AVG(item_price) FROM prices WHERE item_code = ?", (code,))
            current_avg_row = cur.fetchone()
            current_avg = current_avg_row[0] if current_avg_row and current_avg_row[0] else 0.0

            # חילוץ מילות חיפוש עיקריות מהשם (למשל 'חלב 3%' מתוך 'חלב תנובה 3% 1 ליטר')
            words = [w for w in name.split() if len(w) > 2 and not w.isdigit()]
            if not words:
                return []

            # חיפוש מוצרים עם אותה מילה ראשית
            primary_word = words[0]
            cur.execute("""
            SELECT 
                p.item_code, 
                p.item_name, 
                p.manufacturer_name,
                MIN(pr.item_price) as min_price,
                AVG(pr.item_price) as avg_price
            FROM products p
            JOIN prices pr ON p.item_code = pr.item_code
            WHERE p.item_name LIKE ? AND p.item_code != ?
            GROUP BY p.item_code, p.item_name, p.manufacturer_name
            HAVING avg_price < ?
            ORDER BY avg_price ASC
            LIMIT ?
            """, (f"%{primary_word}%", code, current_avg if current_avg > 0 else 9999, limit))

            alts = []
            for r in cur.fetchall():
                savings = round(current_avg - r["avg_price"], 2) if current_avg > 0 else 0
                alts.append({
                    "item_code": r["item_code"],
                    "item_name": r["item_name"],
                    "manufacturer_name": r["manufacturer_name"] or "",
                    "min_price": round(r["min_price"], 2),
                    "avg_price": round(r["avg_price"], 2),
                    "potential_savings": savings,
                })
            return alts

    def compare_item_rich(self, item_code: str, city: Optional[str] = None, user_coords: Optional[tuple] = None, radius_km: float = 10.0) -> Dict[str, Any]:
        """
        שליפת תוצאה עשירה הכוללת:
        1. פרטי המוצר
        2. מחירי סניפים ורשתות (מהזול ליקר או לפי הקרובים אליך)
        3. מבצעים פעילים
        4. אלטרנטיבות זולות יותר
        """
        import math
        def haversine(lat1, lon1, lat2, lon2):
            R = 6371.0
            dlat = math.radians(lat2 - lat1)
            dlon = math.radians(lon2 - lon1)
            a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
            return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        code = item_code.strip()
        with self.db._get_connection() as conn:
            cur = conn.cursor()
            
            cur.execute("SELECT item_name, manufacturer_name, unit_of_measure FROM products WHERE item_code = ?", (code,))
            prod = cur.fetchone()
            item_name = prod["item_name"] if prod else "מוצר לא ידוע"
            mfg = prod["manufacturer_name"] if prod else ""
            unit = prod["unit_of_measure"] if prod else ""

            query = """
            SELECT 
                p.chain_id,
                p.store_id,
                p.item_price,
                s.chain_name,
                s.sub_chain_name,
                s.store_name,
                s.city,
                s.address,
                s.latitude,
                s.longitude
            FROM prices p
            LEFT JOIN stores s ON p.chain_id = s.chain_id AND p.store_id = s.store_id
            WHERE p.item_code = ?
            """
            params = [code]
            if city and city.strip() and not user_coords:
                query += " AND s.city = ?"
                params.append(city.strip())

            query += " ORDER BY p.item_price ASC"
            cur.execute(query, params)
            rows = cur.fetchall()

            if not rows:
                return {
                    "found": False,
                    "item_code": code,
                    "item_name": item_name,
                    "manufacturer_name": mfg,
                    "unit_of_measure": unit,
                    "prices": [],
                    "best_per_chain": [],
                    "promotions": [],
                    "alternatives": [],
                }

            all_prices = []
            chain_best = {}

            for r in rows:
                chain_name = r["chain_name"] or r["chain_id"]
                price = float(r["item_price"])
                
                dist_km = None
                dist_m = None
                if user_coords:
                    if r["latitude"] is None or r["longitude"] is None or r["latitude"] <= 0 or r["longitude"] <= 0:
                        continue  # אין קואורדינטות פיזיות לסניף זה (או סניף אונליין) - מדלגים בחיפוש מבוסס מרחק
                    d = haversine(user_coords[0], user_coords[1], r["latitude"], r["longitude"])
                    if d > radius_km:
                        continue  # מחוץ לרדיוס המבוקש
                    dist_km = round(d, 2)
                    dist_m = int(d * 1000)

                store_info = {
                    "chain_id": r["chain_id"],
                    "chain_name": chain_name,
                    "sub_chain_name": r["sub_chain_name"] or "",
                    "store_id": r["store_id"],
                    "store_name": r["store_name"] or f"סניף {r['store_id']}",
                    "city": r["city"] or "",
                    "address": r["address"] or "",
                    "price": price,
                    "latitude": r["latitude"],
                    "longitude": r["longitude"],
                    "distance_km": dist_km,
                    "distance_meters": dist_m,
                }
                all_prices.append(store_info)

                if chain_name not in chain_best or price < chain_best[chain_name]["price"]:
                    chain_best[chain_name] = store_info

            if user_coords and not all_prices:
                return {
                    "found": False,
                    "item_code": code,
                    "item_name": item_name,
                    "manufacturer_name": mfg,
                    "unit_of_measure": unit,
                    "not_in_radius": True,
                    "prices": [],
                    "best_per_chain": [],
                    "promotions": [],
                    "alternatives": [],
                }

            prices_vals = [p["price"] for p in all_prices]
            min_price = min(prices_vals)
            max_price = max(prices_vals)
            avg_price = round(sum(prices_vals) / len(prices_vals), 2)
            max_savings = round(max_price - min_price, 2)
            savings_pct = round((max_savings / max_price) * 100, 1) if max_price > 0 else 0

            # מיון: אם הוזנו קואורדינטות, נמיין את הסניפים לפי מרחק עולה!
            if user_coords:
                all_prices.sort(key=lambda x: (x["distance_km"] if x["distance_km"] is not None else 9999, x["price"]))

            # שליפת מבצעים פעילים
            promotions = self.get_product_promotions(code)

            # שליפת מוצרים אלטרנטיביים
            alternatives = self.find_alternatives(code)

            return {
                "found": True,
                "item_code": code,
                "item_name": item_name,
                "manufacturer_name": mfg,
                "unit_of_measure": unit,
                "min_price": min_price,
                "max_price": max_price,
                "avg_price": avg_price,
                "max_savings": max_savings,
                "savings_pct": savings_pct,
                "stores_count": len(all_prices),
                "cheapest_stores": all_prices,
                "best_per_chain": sorted(chain_best.values(), key=lambda x: x["price"]),
                "promotions": promotions,
                "alternatives": alternatives,
            }

    def compare_item(self, item_code: str, city: Optional[str] = None) -> Dict[str, Any]:
        return self.compare_item_rich(item_code, city=city)

    def compare_basket(self, items: List[Dict[str, Any]], city: Optional[str] = None, top: int = 15) -> Dict[str, Any]:
        if not items:
            return {"stores": [], "best_per_chain": [], "items_count": 0}

        item_map = {}
        for it in items:
            code = str(it.get("item_code") or it.get("code") or "").strip()
            qty = float(it.get("quantity") or it.get("qty") or 1)
            if code:
                item_map[code] = qty

        item_codes = list(item_map.keys())
        total_items_in_basket = len(item_codes)

        with self.db._get_connection() as conn:
            cur = conn.cursor()
            placeholders = ",".join("?" for _ in item_codes)
            query = f"""
            SELECT 
                p.chain_id,
                p.store_id,
                p.item_code,
                p.item_price,
                s.chain_name,
                s.store_name,
                s.city,
                s.address
            FROM prices p
            JOIN stores s ON p.chain_id = s.chain_id AND p.store_id = s.store_id
            WHERE p.item_code IN ({placeholders})
            """
            params = list(item_codes)
            if city and city.strip():
                query += " AND s.city = ?"
                params.append(city.strip())

            cur.execute(query, params)
            rows = cur.fetchall()

            store_baskets = {}
            for r in rows:
                key = (r["chain_id"], r["store_id"])
                if key not in store_baskets:
                    store_baskets[key] = {
                        "chain_id": r["chain_id"],
                        "chain_name": r["chain_name"] or r["chain_id"],
                        "store_id": r["store_id"],
                        "store_name": r["store_name"] or f"סניף {r['store_id']}",
                        "city": r["city"] or "",
                        "address": r["address"] or "",
                        "total_price": 0.0,
                        "found_codes": set(),
                        "items_breakdown": [],
                    }
                
                code = r["item_code"]
                price = float(r["item_price"])
                qty = item_map.get(code, 1.0)
                subtotal = round(price * qty, 2)

                store_baskets[key]["total_price"] += subtotal
                store_baskets[key]["found_codes"].add(code)
                store_baskets[key]["items_breakdown"].append({
                    "item_code": code,
                    "unit_price": price,
                    "quantity": qty,
                    "subtotal": subtotal,
                })

            ranked = []
            chain_best = {}

            for b in store_baskets.values():
                b["items_found"] = len(b["found_codes"])
                b["missing_count"] = total_items_in_basket - b["items_found"]
                b["total_price"] = round(b["total_price"], 2)
                del b["found_codes"]
                ranked.append(b)

                c_name = b["chain_name"]
                if c_name not in chain_best:
                    chain_best[c_name] = b
                else:
                    curr_best = chain_best[c_name]
                    if (b["items_found"] > curr_best["items_found"]) or (
                        b["items_found"] == curr_best["items_found"] and b["total_price"] < curr_best["total_price"]
                    ):
                        chain_best[c_name] = b

            ranked.sort(key=lambda x: (-x["items_found"], x["total_price"]))

            return {
                "basket_size": total_items_in_basket,
                "stores_compared": len(ranked),
                "city_filter": city,
                "stores": ranked[:top],
                "best_per_chain": sorted(chain_best.values(), key=lambda x: (-x["items_found"], x["total_price"])),
            }
