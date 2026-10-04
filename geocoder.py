"""
geocoder.py
===========
מנוע גיאוקודינג מהיר ומקבילי (Multi-Threaded) לאיתור קו רוחב וקו אורך (lat, lon)
עבור כל סניפי רשתות השיווק בישראל.
כולל מילון קואורדינטות מובנה לכל ערי ישראל, ושירות גיאוקודינג מהיר לרמת הרחוב.
"""

import sys
import json
import time
import re
import math
import urllib.request
import urllib.parse
import queue
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Optional, Tuple, Any
from database import KupaDatabase

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# מילון קואורדינטות בסיס מובנה למרכזי כל ערי ישראל (לגיאוקודינג מיידי באפס זמן)
ISRAEL_CITIES_COORDS = {
    "ירושלים": (31.7683, 35.2137),
    "תל אביב -יפו": (32.0853, 34.7818),
    "תל אביב": (32.0853, 34.7818),
    "חיפה": (32.7940, 34.9896),
    "ראשון לציון": (31.9730, 34.7925),
    "פתח תקווה": (32.0840, 34.8878),
    "אשדוד": (31.8044, 34.6553),
    "נתניה": (32.3215, 34.8532),
    "באר שבע": (31.2529, 34.7915),
    "בני ברק": (32.0849, 34.8352),
    "חולון": (32.0158, 34.7874),
    "רמת גן": (32.0684, 34.8248),
    "אשקלון": (31.6688, 34.5743),
    "רחובות": (31.8928, 34.8113),
    "בת ים": (32.0132, 34.7480),
    "בית שמש": (31.7470, 34.9881),
    "כפר סבא": (32.1750, 34.9069),
    "הרצליה": (32.1663, 34.8433),
    "חדרה": (32.4340, 34.9197),
    "מודיעין-מכבים-רעות": (31.8903, 35.0104),
    "מודיעין": (31.8903, 35.0104),
    "נצרת": (32.7019, 35.2979),
    "לוד": (31.9514, 34.8881),
    "רעננה": (32.1848, 34.8713),
    "רמלה": (31.9275, 34.8625),
    "גבעתיים": (32.0722, 34.8089),
    "הוד השרון": (32.1558, 34.8881),
    "נהריה": (33.0059, 35.0941),
    "קריית אתא": (32.8031, 35.1075),
    "קריית גת": (31.6100, 34.7642),
    "קרית גת": (31.6100, 34.7642),
    "קרית חיים": (32.8250, 35.0750),
    "קריית חיים": (32.8250, 35.0750),
    "עפולה": (32.6078, 35.2897),
    "עכו": (32.9278, 35.0818),
    "כרמיאל": (32.9199, 35.2956),
    "אילת": (29.5577, 34.9519),
    "טבריה": (32.7944, 35.5312),
    "קריית מוצקין": (32.8333, 35.0833),
    "קריית ביאליק": (32.8333, 35.0833),
    "קריית ים": (32.8333, 35.0667),
    "ראש העין": (32.0956, 34.9567),
    "נס ציונה": (31.9294, 34.7983),
    "יבנה": (31.8778, 34.7400),
    "דימונה": (31.0694, 35.0333),
    "אור יהודה": (32.0294, 34.8569),
    "טירת כרמל": (32.7600, 34.9700),
    "מעלות-תרשיחא": (33.0167, 35.2667),
    "קריית שמונה": (33.2078, 35.5706),
    "שדרות": (31.5244, 34.5956),
    "נתיבות": (31.4172, 34.5886),
    "אופקים": (31.3125, 34.6197),
    "ערד": (31.2589, 35.2128),
    "ירוחם": (30.9881, 34.9197),
    "חריש": (32.4600, 35.0400),
    "צפת": (32.9658, 35.4983),
    "מגדל העמק": (32.6739, 35.2400),
    "שוהם": (31.9983, 34.9458),
    "יהוד-מונוסון": (32.0333, 34.8833),
    "גבעת שמואל": (32.0778, 34.8472),
    "ביתר עילית": (31.7018, 35.1073),
    "ביתר עלית": (31.7018, 35.1073),
    "מודיעין עילית": (31.9324, 35.0433),
    "מודיעין עלית": (31.9324, 35.0433),
    "אלעד": (32.0500, 34.9521),
    "כפר חב\"ד": (31.9880, 34.8560),
    "רכסים": (32.7480, 35.1020),
    "קריית חיים": (32.8250, 35.0750),
    "קריית ים": (32.8333, 35.0667),
    "גדרה": (31.8122, 34.7786),
    "טלזסטון": (31.8033, 35.1167),
    "קריית יערים": (31.8033, 35.1167),
    "יפיע": (32.6869, 35.2694),
    "סכנין": (32.8681, 35.3047),
    "סחנין": (32.8681, 35.3047),
    "טייבה": (32.2661, 35.0089),
    "באקה": (32.4217, 35.0392),
    "באקה אל גרביה": (32.4217, 35.0392),
    "פרידיס": (32.5975, 34.9542),
    "פוריידיס": (32.5975, 34.9542),
    "איירפורט סיטי": (32.0000, 34.9200),
    "אור ים": (32.4950, 34.9100),
}

def clean_city_name(raw_city: str) -> str:
    if not raw_city or raw_city == "0":
        return ""
    c = raw_city.replace("-", " ").strip()
    return c

def geocode_single_address(address: str, city: str, store_name: str = "") -> Optional[Tuple[float, float]]:
    """
    מבצע פנייה מהירה לשירות Geocoding (GovMap, Nominatim, Photon)
    ומחזיר (lat, lon) ברמת הרחוב/סניף.
    תומך בחילוץ חכם של כתובת ועיר גם כאשר הרשת רשמה אותם בתוך שם הסניף!
    """
    clean_addr = address.strip() if address else ""
    clean_c = city.strip() if city and city != "0" else ""
    clean_sname = store_name.strip() if store_name else ""

    # טיפול בחנויות אינטרנט / משלוחים
    all_text = f"{clean_addr} {clean_c} {clean_sname}".lower()
    
    # בדיקת אזור לחנויות אונליין של שוק העיר (כגון 'אונליין - רמות', 'אונליין - אשקלון צפוני')
    if "shukcity" in all_text or "אונליין" in clean_sname:
        for c_name, c_coords in sorted(ISRAEL_CITIES_COORDS.items(), key=lambda x: len(x[0]), reverse=True):
            if c_name in clean_sname:
                return c_coords
        if "רמות" in clean_sname:
            return ISRAEL_CITIES_COORDS.get("ירושלים")

    if "קרית חיים" in clean_sname or "קריית חיים" in clean_sname:
        return ISRAEL_CITIES_COORDS.get("קרית חיים")
    if "הדרים" in clean_sname:
        return ISRAEL_CITIES_COORDS.get("רחובות")

    # חנויות וירטואליות ארציות (ללא סניף פיזי): מסומנות ב-(0.0, 0.0) כדי שלא יישארו כ-None
    if any(k in all_text for k in ["victoryonline", "shop.hazi-hinam", "mishnatyosef", "אתר משנת יוסף"]) or (clean_sname == "אינטרנט" and not clean_c):
        return (0.0, 0.0)

    if not clean_addr and not clean_c and not clean_sname:
        return None

    def query_service(q_text: str) -> Optional[Tuple[float, float]]:
        import math
        # 1. ניסיון ראשי: GovMap (מאגר המפות הרשמי של מדינת ישראל)
        try:
            gov_url = "https://www.govmap.gov.il/api/search-service/autocomplete"
            gov_headers = {
                "Origin": "https://www.govmap.gov.il",
                "Referer": "https://www.govmap.gov.il/",
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
            }
            gov_payload = json.dumps({"searchText": q_text.replace(" ישראל", "").strip()}).encode("utf-8")
            gov_req = urllib.request.Request(gov_url, data=gov_payload, headers=gov_headers)
            with urllib.request.urlopen(gov_req, timeout=3) as resp:
                gov_data = json.loads(resp.read().decode("utf-8"))
                results = gov_data.get("results", [])
                if results and "shape" in results[0]:
                    shape = results[0]["shape"]
                    if "POINT(" in shape:
                        clean_shape = shape.replace("POINT(", "").replace(")", "").strip()
                        parts = clean_shape.split()
                        x, y = float(parts[0]), float(parts[1])
                        lon = (x / 20037508.34) * 180
                        lat_merc = (y / 20037508.34) * 180
                        lat = 180 / math.pi * (2 * math.atan(math.exp(lat_merc * math.pi / 180)) - math.pi / 2)
                        if 28.5 <= lat <= 34.5 and 33.5 <= lon <= 36.8:
                            return (lat, lon)
        except Exception:
            pass

        # 2. ניסיון משני: Nominatim (OpenStreetMap)
        try:
            url_nom = f"https://nominatim.openstreetmap.org/search?q={urllib.parse.quote(q_text)}&format=json&limit=1"
            req_nom = urllib.request.Request(url_nom, headers={"User-Agent": "KupaOfflineEngine/2.0 (offline_prices_israel)"})
            with urllib.request.urlopen(req_nom, timeout=4) as resp:
                nom_data = json.loads(resp.read().decode("utf-8"))
                if nom_data and len(nom_data) > 0:
                    lat, lon = float(nom_data[0]["lat"]), float(nom_data[0]["lon"])
                    if 29.0 <= lat <= 34.0 and 34.0 <= lon <= 36.5:
                        return lat, lon
        except Exception:
            pass

        # 3. ניסיון שלישי: Photon
        try:
            url_ph = f"https://photon.komoot.io/api/?q={urllib.parse.quote(q_text)}&limit=1"
            req_ph = urllib.request.Request(url_ph, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
            with urllib.request.urlopen(req_ph, timeout=4) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                features = data.get("features", [])
                if features:
                    coords = features[0]["geometry"]["coordinates"]
                    lat, lon = float(coords[1]), float(coords[0])
                    if 29.0 <= lat <= 34.0 and 34.0 <= lon <= 36.5:
                        return lat, lon
        except Exception:
            pass
        return None

    # יצירת מועמדי חיפוש מדויקים
    # בדיקת סניפי אונליין / אתרי אינטרנט שאין להם מיקום פיזי
    online_indicators = ["אונליין", "אינטרנט", "אתר משנת יוסף", "משלוחים", "פיקאפ"]
    is_online = any(ind in sname.lower() or ind in addr.lower() for ind in online_indicators) or "http" in addr.lower() or ".co." in addr.lower() or ".org" in addr.lower()

    # חילוץ עיר מתוך סניפי אונליין אזוריים (למשל: 'אונליין - רמות', 'אונליין - אשקלון צפוני', 'אונליין - כפר סבא')
    if is_online:
        for c_name, c_coords in sorted(ISRAEL_CITIES_COORDS.items(), key=lambda x: len(x[0]), reverse=True):
            if c_name in sname:
                return c_coords
        if "רמות" in sname:
            return ISRAEL_CITIES_COORDS.get("ירושלים")

    # סניפים ומחסנים ספציפיים
    if "קרית חיים" in sname or "קריית חיים" in sname:
        return ISRAEL_CITIES_COORDS.get("קרית חיים")
    if "הדרים" in sname:
        # יוחננוף הדרים פיקאפ (רחובות - פארק המדע / הדרים)
        return ISRAEL_CITIES_COORDS.get("רחובות")

    if is_online and not clean_c and not clean_addr:
        # סניף אינטרנט ארצי ללא כתובת פיזית (כמו ויקטורי אונליין, חצי חינם משלוחים, אתר משנת יוסף)
        # מסמנים ב-0, 0 כדי שלא ייסרק מחדש כל פעם בלופים
        return (0.0, 0.0)

    candidates = []

    # אם הרשת רשמה את כל הכתובת בתוך שם הסניף (למשל סיטי מרקט: "סיטי מרקט אגמים בע\"מ , עמק האלה 47 אשקלון")
    if clean_sname:
        parts = [p.strip() for p in clean_sname.split(",") if p.strip()]
        if len(parts) > 1:
            for p in parts[1:]:
                candidates.append(f"{p} ישראל")
                candidates.append(p)

    if clean_addr and clean_c:
        candidates.append(f"{clean_addr} {clean_c} ישראל")
    elif clean_addr:
        candidates.append(f"{clean_addr} ישראל")

    # חילוץ רחוב ומספר במידה וקיים בשם הסניף
    if clean_sname and not clean_addr:
        # הסרת קידומות נפוצות
        cleaned_sn = re.sub(r'^(סיטי מרקט|סופר ספיר|מ. יוחננוף|נטו חיסכון|זכיין|המכולת)\s*', '', clean_sname)
        cleaned_sn = re.sub(r'[\*\(\)]', '', cleaned_sn).strip()
        if cleaned_sn:
            candidates.append(f"{cleaned_sn} ישראל")

    # ניקוי תארים נפוצים ("הרבי מ...", "הרב...", "שדרות...")
    clean_base = clean_addr or clean_sname
    cleaned_simplified = clean_base.replace("הרבי מ", "").replace("הרב ", "").replace("רחוב ", "").strip()
    if cleaned_simplified != clean_base:
        if clean_c:
            candidates.append(f"{cleaned_simplified} {clean_c} ישראל")
        else:
            candidates.append(f"{cleaned_simplified} ישראל")

    # הסרת מספר בית
    without_num = re.sub(r'\d+', '', clean_base).strip()
    if without_num and without_num != clean_base:
        if clean_c:
            candidates.append(f"{without_num} {clean_c} ישראל")
        else:
            candidates.append(f"{without_num} ישראל")

    # הרצת כל מועמדי החיפוש ב-GovMap/OSM
    for cand in candidates:
        if len(cand.strip()) < 3:
            continue
        res = query_service(cand)
        if res:
            return res

    # בדיקה האם שם עיר מופיע בתוך הכתובת, בשדה העיר, או בשם הסניף
    full_text = f"{clean_addr} {clean_c} {clean_sname}".replace("-", " ").strip()
    for city_key, coords in sorted(ISRAEL_CITIES_COORDS.items(), key=lambda x: len(x[0]), reverse=True):
        if city_key in full_text:
            return coords

    # חיפוש עיר בלבד בשרת המפות אם קיימת
    if clean_c:
        city_res = query_service(f"{clean_c} ישראל")
        if city_res:
            return city_res

    return None

class ParallelGeocoder:
    def __init__(self, db: Optional[KupaDatabase] = None, max_workers: int = 12):
        self.db = db or KupaDatabase()
        self.max_workers = max_workers

    def run_fast_geocoding(self, progress_callback=None) -> int:
        """
        סורק במקביל בגישת תור רציף (FIFO Queue):
        - כל Worker שמסיים משימה מושך מיד את הבאה בתור (ללא המתנה ל-batch).
        - סניף שנכשל/חווה שגיאת רשת נכנס לתור ניסיון חוזר (Retry Queue) לסוף.
        - שמירה רציפה ל-SQLite.
        """
        pending = self.db.get_stores_without_coords()
        total = len(pending)
        if total == 0:
            print("✅ כל הסניפים במסד כבר כוללים קואורדינטות (lat/lon)!")
            return 0

        print(f"🌍 מתחיל גיאוקודינג מהיר בגישת תור רציף (FIFO) עבור {total:,} סניפים ({self.max_workers} תהליכים)...")
        start_time = time.time()

        work_queue = queue.Queue()
        retry_queue = queue.Queue()
        for s in pending:
            work_queue.put((s, 1)) # (store, attempt_number)

        updates_lock = threading.Lock()
        updates_batch = []
        updated_count = 0
        completed_count = 0
        failed_stores = []

        def worker():
            nonlocal updated_count, completed_count
            while True:
                try:
                    store, attempt = work_queue.get_nowait()
                except queue.Empty:
                    break

                addr = store.get("address", "")
                city = store.get("city", "")
                sname = store.get("store_name", "")
                coords = None

                try:
                    coords = geocode_single_address(addr, city, store_name=sname)
                except Exception:
                    coords = None

                if coords:
                    with updates_lock:
                        updates_batch.append((coords[0], coords[1], store["chain_id"], store["store_id"]))
                        updated_count += 1
                        completed_count += 1
                        # כתיבה ל-DB במנות של 25 תוך כדי זרימת התור
                        if len(updates_batch) >= 25:
                            self.db.batch_update_store_coords(updates_batch)
                            updates_batch.clear()
                else:
                    # אם נכשל בניסיון ראשון - נשמור לסיבוב שני בסיום
                    if attempt == 1:
                        retry_queue.put((store, 2))
                    else:
                        with updates_lock:
                            completed_count += 1
                            failed_stores.append(store)

                with updates_lock:
                    if progress_callback:
                        progress_callback(completed_count, total)
                    else:
                        pct = int((completed_count / total) * 100) if total else 0
                        bar_len = 25
                        filled = int(bar_len * completed_count / total) if total else 0
                        bar = "█" * filled + "░" * (bar_len - filled)
                        sys.stdout.write(f"\r  [{bar}] {pct}% ({completed_count:,}/{total:,} סניפים עובדו)")
                        sys.stdout.flush()

                work_queue.task_done()

        # סבב 1: ריצת כל התור הראשי ב-20 תהליכים רציפים
        threads = []
        for _ in range(self.max_workers):
            t = threading.Thread(target=worker, daemon=True)
            t.start()
            threads.append(t)

        for t in threads:
            t.join()

        # סבב 2: ניסיון חוזר לסניפים שנכשלו
        if not retry_queue.empty():
            retry_count = retry_queue.qsize()
            sys.stdout.write(f"\n🔄 מריץ ניסיון חוזר (Retry Loop) עבור {retry_count} סניפים שנכשלו בסבב הראשון...\n")
            sys.stdout.flush()
            
            while not retry_queue.empty():
                work_queue.put(retry_queue.get())

            threads = []
            for _ in range(min(self.max_workers, 8)):
                t = threading.Thread(target=worker, daemon=True)
                t.start()
                threads.append(t)

            for t in threads:
                t.join()

        # שמירת שארית אחרונה
        with updates_lock:
            if updates_batch:
                self.db.batch_update_store_coords(updates_batch)
                updates_batch.clear()

        sys.stdout.write("\n")
        sys.stdout.flush()

        elapsed = round(time.time() - start_time, 2)
        success_rate = (updated_count / total * 100) if total else 0
        
        print("\n" + "═" * 70)
        print("📊 דוח סיכום גיאוקודינג וסריקת מיקומי סניפים:")
        print(f"   • סה\"כ סניפים שנסרקו: {total:,}")
        print(f"   • עודכנו בהצלחה: {updated_count:,} ({success_rate:.1f}%)")
        print(f"   • זמן כולל: {elapsed} שניות")

        if failed_stores:
            print(f"\n⚠️ לא אותרו נקודות ציון עבור {len(failed_stores):,} סניפים (עקב כתובת חסרה או לא מוכרת):")
            print(f"   {'רשת':<15} | {'סניף':<22} | {'עיר וכתובת שדווחו ברשת'}")
            print("   " + "-" * 65)
            for fs in failed_stores[:10]:
                chain = fs.get("chain_name") or fs.get("chain_id") or ""
                sname = fs.get("store_name") or ""
                addr_str = f"{fs.get('address', '')} ({fs.get('city', '')})".strip()
                print(f"   {chain:<15} | {sname:<22} | {addr_str}")
            if len(failed_stores) > 10:
                print(f"   ...ועוד {len(failed_stores) - 10} סניפים נוספים ללא כתובת תקינה.")
        else:
            print("✨ כל הסניפים אופסו ואותרו ב-100% הצלחה!")
        print("═" * 70 + "\n")

        return updated_count
