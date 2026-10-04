"""
cli.py
======
ממשק שורת פקודה אינטראקטיבי, מעוצב ועשיר בעברית עבור מנוע 'קופה אופליין'.
בודק אוטומטית בהפעלה את מסד הנתונים והאינטרנט, מזהה עדכונים, ומציג בכל סריקה
פרטים מלאים, טווח מחירים, מבצעים פעילים ואלטרנטיבות חסכוניות.
"""

import sys
import os

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdin.reconfigure(encoding="utf-8")
    except Exception:
        pass

from sync_manager import SyncManager
from offline_kupa_engine import OfflineKupaEngine
from database import KupaDatabase
import json

CONFIG_FILE = os.path.join(os.path.dirname(__file__), "config.json")

def load_config() -> dict:
    defaults = {
        "search_radius_km": 10.0,
        "max_nearby_stores": 20
    }
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                defaults.update(data)
        except Exception:
            pass
    return defaults

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def print_banner():
    print("╔══════════════════════════════════════════════════════════════════════╗")
    print("║            🛒 קופה • מנוע נתונים אופליין (Kupa Offline Engine)       ║")
    print("║          השוואת מחירים, מבצעים ואלטרנטיבות ממאגרי over.org.il        ║")
    print("╚══════════════════════════════════════════════════════════════════════╝")

def startup_check(sync: SyncManager, db: KupaDatabase):
    """
    בדיקת הפעלה אוטומטית:
    1. בודק אם קיים מסד מקומי ומה מצבו.
    2. בודק חיבור לאינטרנט.
    3. אם אין אינטרנט: שגיאה ברורה או המשך אופליין.
    4. אם יש אינטרנט: בדיקת עדכונים באתר והצעת סנכרון מיידי.
    """
    has_local_data = db.has_data()
    stats = db.get_stats()

    print("\n🔍 מריץ בדיקת מערכת ואבחון רשת בהפעלה...")
    is_online, net_msg = sync.check_internet_connection()

    if not is_online:
        print("\n" + "!" * 70)
        print("⚠️  התראת רשת: אין חיבור לאינטרנט או ששרתי over.org.il אינם נגישים!")
        print(f"    פרטים: {net_msg}")
        if has_local_data:
            print("✅  נמצאו נתונים מקומיים במסד! המערכת תפעל ב-100% מצב אופליין (ללא צורך ברשת).")
            print(f"    רשומות זמינות: {stats['products']:,} מוצרים | {stats['prices']:,} מחירים | {stats['promotions']:,} מבצעים.")
        else:
            print("❌  שגיאה קריטית: מסד הנתונים המקומי ריק ואין אינטרנט!")
            print("    נדרש חיבור לרשת בפעם הראשונה כדי להוריד את קבצי המחירים והמבצעים.")
        print("!" * 70 + "\n")
        return

    # מחובר לאינטרנט
    print(f"🌐 חיבור רשת תקין: {net_msg}")

    # אם עדיין אין סניפים במסד - ייבוא ארצי מהיר
    if stats["stores"] == 0:
        sync.sync_all_stores_nationwide()

    # אם המסד ריק ממוצרים ומחירים - הורדה ראשונית אוטומטית של כל הרשתות הזמינות
    if not has_local_data:
        print("\n" + "=" * 70)
        print("📢 הפעלה ראשונה זוהתה! מסד הנתונים המקומי עדיין אינו מכיל מוצרים ומחירים.")
        print("⚡ מוריד ומסנכרן כעת באופן אוטומטי את כל הרשתות בישראל (במקביל, 4 תהליכים)...")
        print("=" * 70)
        chains = sync.list_available_sources()
        if chains:
            sync.sync_chains_parallel(chains, max_workers=4)
        else:
            print("⚠️ לא נמצאו מקורות זמינים להורדה.")
    else:
        # בדיקת גרסאות מעודכנות באתר עבור מסד קיים
        print("📡 בודק האם יש גרסאות מעודכנות יותר באתר 'גרסאות לעם'...")
        upd_res = sync.check_for_updates()
        updates = upd_res.get("updates_available", [])

        if updates:
            print(f"\n🔔 נמצאו {len(updates)} רשתות עם גרסאות מעודכנות באתר:")
            for u in updates[:5]:
                c_name = u["chain_info"].get("name") or u["chain_info"].get("account")
                print(f"   • {c_name}: {u['reason']}")
            if len(updates) > 5:
                print(f"   • ועוד {len(updates)-5} רשתות נוספות...")
            
            ans = input("\nהאם לעדכן את הרשתות הללו כעת? [y/N]: ").strip().lower()
            if ans in ["y", "yes", "כן"]:
                chains_to_sync = [u["chain_info"] for u in updates]
                print(f"⚡ מוריד ומעדכן במקביל {len(chains_to_sync)} רשתות...")
                sync.sync_chains_parallel(chains_to_sync, max_workers=4)
        else:
            print("✨ כל המאגרים המקומיים שלך מעודכנים לגרסאות האחרונות באתר!")

    # בדיקת קואורדינטות (lat/lon) לסניפים - מתבצעת אוטומטית בכל הפעלה עבור סניפים חדשים שנוספו
    from geocoder import ParallelGeocoder
    missing_stores = db.get_stores_without_coords()
    if missing_stores:
        print(f"\n📍 זוהו {len(missing_stores):,} סניפים חדשים ללא מיקום גיאוגרפי.")
        print(f"🌍 מוסיף נקודות ציון גיאוגרפיות (lat/lon) לסניפים אלו באופן אוטומטי...")
        ParallelGeocoder(db, max_workers=20).run_fast_geocoding()

def show_stats_box(db: KupaDatabase):
    stats = db.get_stats()
    print("┌────────────────────────────────────────────────────────────────────┐")
    print(f"│ 📊 נתונים אופליין: {stats['products']:,} מוצרים │ {stats['stores']:,} סניפים │ {stats['prices']:,} מחירים │ {stats['promotions']:,} מבצעים │")
    print("└────────────────────────────────────────────────────────────────────┘")

def handle_search(engine: OfflineKupaEngine):
    q = input("\n🔎 הזן שם מוצר או ברקוד לחיפוש: ").strip()
    if not q:
        return
    results = engine.search_products(q, limit=100)
    if not results:
        print(f"❌ לא נמצאו מוצרים עבור '{q}'.")
        return
    
    print(f"\nנמצאו {len(results)} מוצרים:")
    print(f"{'#':<3} | {'ברקוד':<15} | {'שם מוצר':<35} | {'יצרן'}")
    print("-" * 70)
    for idx, r in enumerate(results, 1):
        name = (r['item_name'][:32] + '..') if len(r['item_name']) > 32 else r['item_name']
        print(f"{idx:<3} | {r['item_code']:<15} | {name:<35} | {r['manufacturer_name']}")

def resolve_user_location(user_input: str):
    """מפענח מיקום משתמש (GPS, כתובת או עיר) לקואורדינטות (lat, lon)"""
    from geocoder import ISRAEL_CITIES_COORDS, geocode_single_address
    inp = user_input.strip()
    if not inp:
        return None

    # 1. קואורדינטות ישירות
    if "," in inp or " " in inp:
        parts = [p.strip() for p in inp.replace(",", " ").split() if p.strip()]
        if len(parts) == 2:
            try:
                p1, p2 = float(parts[0]), float(parts[1])
                if 28.0 <= p1 <= 35.0 and 33.0 <= p2 <= 37.0:
                    return (p1, p2)
                elif 28.0 <= p2 <= 35.0 and 33.0 <= p1 <= 37.0:
                    return (p2, p1)
            except ValueError:
                pass

    # 2. בדיקה לפי עיר
    for c_name, c_coords in ISRAEL_CITIES_COORDS.items():
        if inp == c_name:
            return c_coords

    # 3. פענוח גיאוגרפי מלא דרך GovMap
    return geocode_single_address(inp, "")

def handle_rich_compare(engine: OfflineKupaEngine):
    code = input("\n📷 הזן ברקוד מוצר (או סרוק ברקוד): ").strip()
    if not code:
        return
    loc_input = input("סנן לפי מיקום / כתובת / עיר / lat,lon (השאר ריק לכל הארץ): ").strip()
    
    user_coords = None
    city_filter = None
    cfg = load_config()
    radius = float(cfg.get("search_radius_km", 10.0))

    if loc_input:
        user_coords = resolve_user_location(loc_input)
        if user_coords:
            print(f"🎯 נקודת ציון שאותרה: {user_coords[0]:.5f}, {user_coords[1]:.5f} (רדיוס מוגדר: {radius} ק\"מ)")
        else:
            # אם לא נמצאו קואורדינטות, נשתמש כפילטר עיר טקסטואלי
            city_filter = loc_input

    res = engine.compare_item_rich(code, city=city_filter, user_coords=user_coords, radius_km=radius)
    if not res["found"]:
        if res.get("not_in_radius"):
            print(f"\n❌ המוצר '{res['item_name']}' (ברקוד {code}) קיים במסד, אך לא נמצאו סניפים המוכרים אותו ברדיוס של {radius} ק\"מ מ-'{loc_input}'.")
            print("   (תוכל להגדיל את הרדיוס בקובץ config.json או להשאיר ריק לצפייה בכל הארץ).")
            return
        elif city_filter:
            res_all = engine.compare_item_rich(code, city=None)
            if res_all["found"]:
                print(f"\n❌ המוצר '{res_all['item_name']}' (ברקוד {code}) קיים בארץ, אך לא נמצאו מחירים עבורו בעיר '{city_filter}'.")
                return
        print(f"\n❌ ברקוד {code} לא נמצא במסד הנתונים המקומי.")
        return

    print("\n" + "═" * 70)
    print(f"📦 מוצר: {res['item_name']}")
    print(f"🏷️  ברקוד: {res['item_code']} | יצרן: {res['manufacturer_name']} | יחידה: {res['unit_of_measure']}")
    print("─" * 70)
    print(f"💰 מחיר מינימלי: {res['min_price']:.2f} ₪ | מחיר מקסימלי: {res['max_price']:.2f} ₪ | ממוצע: {res['avg_price']:.2f} ₪")
    print(f"🎯 חיסכון אפשרי: עד {res['max_savings']:.2f} ₪ ({res['savings_pct']}%) בין הסניפים!")
    loc_desc = f"קרובים ל-'{loc_input}' ברדיוס {radius} ק\"מ" if user_coords else (f"סינון: {loc_input}" if loc_input else "כל הארץ")
    print(f"📍 נסרקו {res['stores_count']} סניפים ({loc_desc}).")
    print("═" * 70)

    # 1. מבצעים פעילים
    promos = res.get("promotions", [])
    if promos:
        print("\n🎁 מבצעים פעילים שנמצאו על מוצר זה:")
        for p in promos:
            desc = p.get("description", "")
            d_price = f"ב-{p['discounted_price']} ₪" if p.get('discounted_price') else ""
            dates = f"(תוקף: {p.get('start_date')} עד {p.get('end_date')})" if p.get('end_date') else ""
            print(f"   ★ [{p['chain_name']}] {desc} {d_price} {dates}")
    else:
        print("\nℹ️  אין מבצעים מיוחדים פעילים כרגע על מוצר זה.")

    # 2. השוואת מחירים (לפי מרחק עולה אם הוזן מיקום, או הזול ביותר בכל רשת)
    if user_coords:
        print(f"\n📍 הסניפים הקרובים ביותר המוכרים מוצר זה (לפי מרחק):")
        print(f"{'מרחק':<10} | {'מחיר':<9} | {'רשת':<18} | {'סניף ועיר'}")
        print("-" * 70)
        for s in res["cheapest_stores"]:
            if s.get("distance_km") is not None:
                dist_str = f"{s['distance_km']:.1f} ק\"מ" if s['distance_km'] >= 1.0 else f"{s['distance_meters']} מטר"
            else:
                dist_str = "לא ידוע"
            loc = f"{s['store_name']} ({s['address'] or s['city']})"
            raw_c = s.get("chain_name", "")
            sub_c = s.get("sub_chain_name", "")
            if sub_c == "מחסני השוק בשבילך":
                c_name = "מחסני השוק (קואופ)"
            elif sub_c and sub_c != raw_c:
                c_name = f"{raw_c} ({sub_c})"[:18]
            else:
                c_name = raw_c[:18]
            print(f"{dist_str:<10} | {s['price']:<7.2f} ₪ | {c_name:<18} | {loc}")
    else:
        print("\n🏪 המחיר הזול ביותר בכל רשת:")
        print(f"{'רשת':<18} | {'מחיר':<10} | {'סניף ועיר':<35}")
        print("-" * 68)
        for b in res["best_per_chain"]:
            loc = f"{b['store_name']} ({b['city']})" if b['city'] else b['store_name']
            print(f"{b['chain_name']:<18} | {b['price']:<9.2f} ₪ | {loc:<35}")

    print("═" * 70)

def handle_basket(engine: OfflineKupaEngine):
    print("\n🛒 השוואת סל קניות אופליין (כמו tab=basket באתר):")
    print("הזן ברקודים מופרדים ברווח או פסיק (לדוגמה: 7290000066134 7290004127305):")
    raw = input("ברקודים: ").strip()
    if not raw:
        return
    
    codes = [c.strip() for c in raw.replace(",", " ").split() if c.strip()]
    city = input("סנן לפי עיר (השאר ריק לכל הארץ): ").strip() or None

    items = [{"item_code": c, "quantity": 1} for c in codes]
    res = engine.compare_basket(items, city=city, top=12)

    if not res["stores"]:
        print("❌ לא נמצאו סניפים עם פריטים מהסל המבוקש.")
        return

    print("\n" + "═" * 70)
    print(f"📊 תוצאות השוואת סל קניות ({res['basket_size']} פריטים בסל):")
    print(f"{'רשת':<15} | {'סניף ועיר':<25} | {'פריטים בסל':<12} | {'עלות סל'}")
    print("-" * 68)
    for s in res["stores"]:
        loc = f"{s['store_name']} ({s['city']})" if s['city'] else s['store_name']
        found = f"{s['items_found']}/{res['basket_size']}"
        badge = " 🏆 (הזול ביותר!)" if s == res["stores"][0] else ""
        print(f"{s['chain_name']:<15} | {loc:<25} | {found:<12} | {s['total_price']:<8.2f} ₪{badge}")
def handle_nearby_stores(db: KupaDatabase):
    from geocoder import ISRAEL_CITIES_COORDS, geocode_single_address
    print("\n📍 איתור סניפים קרובים לפי מיקום:")
    print("תוכל להזין:")
    print("  • קואורדינטות ישירות (GPS lat, lon) - לדוגמה: 32.063, 34.762")
    print("  • כתובת מלאה (רחוב ומספר) - לדוגמה: תל אביב קויפמן 2")
    print("  • עיר - לדוגמה: תל אביב, ירושלים, חיפה")
    user_input = input("\nהזן מיקום / כתובת / lat,lon: ").strip()
    if not user_input:
        return

    coords = None

    # 1. בדיקה אם המשתמש הזין קואורדינטות ישירות (lat, lon)
    if "," in user_input or " " in user_input:
        parts = [p.strip() for p in user_input.replace(",", " ").split() if p.strip()]
        if len(parts) == 2:
            try:
                p1, p2 = float(parts[0]), float(parts[1])
                # זיהוי איזה מהם lat ואיזה lon (בישראל lat הוא ~29-34 ו-lon הוא ~34-36)
                if 28.0 <= p1 <= 35.0 and 33.0 <= p2 <= 37.0:
                    coords = (p1, p2)
                elif 28.0 <= p2 <= 35.0 and 33.0 <= p1 <= 37.0:
                    coords = (p2, p1)
            except ValueError:
                pass

    # 2. בדיקה אם הוזנה בדיוק עיר ממילון הערים
    if not coords:
        for c_name, c_coords in ISRAEL_CITIES_COORDS.items():
            if user_input == c_name:
                coords = c_coords
                break

    # 3. אם זו כתובת מלאה (כוללת רחוב / מספר) או עיר שלא נמצאה - נאתר נקודה מדויקת
    if not coords:
        print("🔍 מאתר קואורדינטות מדויקות עבור הכתובת שהזנת...")
        coords = geocode_single_address(user_input, "")

    if not coords:
        print(f"❌ לא הצלחנו לאתר את המיקום עבור '{user_input}'. נסה להזין קואורדינטות lat, lon או כתובת מלאה.")
        return

    lat, lon = coords
    cfg = load_config()
    radius = float(cfg.get("search_radius_km", 10.0))
    limit = int(cfg.get("max_nearby_stores", 20))

    print(f"🎯 נקודת ציון שאותרה: {lat:.5f}, {lon:.5f} (רדיוס מוגדר ב-config: {radius} ק\"מ)")
    stores = db.get_nearby_stores(lat, lon, limit=None, radius_km=radius)
    if not stores:
        print(f"❌ לא נמצאו סניפים ברדיוס של {radius} ק\"מ מנקודה זו. (ניתן להגדיל את הרדיוס בקובץ config.json)")
        return

    print("\n" + "═" * 70)
    print(f"📍 הסניפים הקרובים ביותר ל-'{user_input}' (ברדיוס {radius} ק\"מ, בסדר עולה):")
    print(f"{'מרחק':<10} | {'רשת':<15} | {'סניף':<22} | {'כתובת ועיר'}")
    print("-" * 70)
    for s in stores:
        dist_str = f"{s['distance_km']:.1f} ק\"מ" if s['distance_km'] >= 1.0 else f"{s['distance_meters']} מטר"
        loc = f"{s['address']} ({s['city']})" if s['address'] and s['city'] else (s['address'] or s['city'] or "-")
        raw_chain = s.get('chain_name', '')
        sub_chain = s.get('sub_chain_name', '')

        # אם תת-הרשת היא 'מחסני השוק בשבילך' - זהו פורמט קואופ שופ המקורי
        if sub_chain == "מחסני השוק בשבילך":
            c_name = "מחסני השוק (קואופ)"
        elif sub_chain and sub_chain != raw_chain:
            # למשל: שופרסל אקספרס, קרפור סיטי, רמי לוי בשכונה
            c_name = f"{raw_chain} ({sub_chain})"[:22]
        else:
            c_name = raw_chain[:18] if raw_chain else "-"

        s_name = (s['store_name'][:20]) if s['store_name'] else "-"
        print(f"{dist_str:<10} | {c_name:<22} | {s_name:<22} | {loc}")
    print("═" * 70)

def handle_manual_sync(sync: SyncManager):
    print("\n🔄 מתחיל בדיקת עדכונים וסנכרון מאגרים אוטומטי מלא...")
    upd = sync.check_for_updates()
    if not upd.get("online"):
        print(f"❌ שגיאת רשת: {upd.get('message')}")
        return

    updates = upd.get("updates_available", [])
    if not updates:
        print("✨ כל המאגרים המקומיים שלך מעודכנים ב-100% לגרסאות האחרונות באתר!")
        return

    print(f"📦 זוהו {len(updates)} רשתות הדורשות סנכרון ועדכון (מתוך {upd.get('total_remote')} רשתות).")
    print("🚀 מתחיל בהורדה וסנכרון מקבילי (4 תהליכים בו-זמנית)...")

    chains_to_sync = [u["chain_info"] for u in updates]
    sync.sync_chains_parallel(chains_to_sync, max_workers=4, force=True)

    print("\n🎉 כל המאגרים סונכרנו ועודכנו בהצלחה למצב אופליין מלא!")

def main():
    print_banner()
    db = KupaDatabase()
    sync = SyncManager(db)
    engine = OfflineKupaEngine(db)

    # 1. בדיקת הפעלה אוטומטית (אינטרנט, מסד נתונים, גרסאות חדשות)
    startup_check(sync, db)

    while True:
        show_stats_box(db)
        print("1. 📷 השוואת מחירים, מבצעים ואלטרנטיבות לפי ברקוד מוצר (עשיר)")
        print("2. 🔎 חיפוש מוצר לפי שם")
        print("3. 🛒 השוואת סל קניות שלם (מקביל ל-tab=basket באתר)")
        print("4. 📍 מציאת הסניפים הקרובים אליי (לפי עיר / כתובת / מרחק)")
        print("5. 🔄 בדיקת עדכונים וסנכרון מאגרים מול האתר")
        print("6. 🚪 יציאה")
        
        choice = input("\nבחר פעולה [1-6]: ").strip()
        if choice == "1":
            handle_rich_compare(engine)
        elif choice == "2":
            handle_search(engine)
        elif choice == "3":
            handle_basket(engine)
        elif choice == "4":
            handle_nearby_stores(db)
        elif choice == "5":
            handle_manual_sync(sync)
        elif choice == "6":
            print("\nתודה שהשתמשת ב'קופה אופליין'! להתראות.")
            break
        else:
            print("בחירה שגויה, נסה שוב.")

        input("\nלחץ Enter לחזרה לתפריט הראשי...")

if __name__ == "__main__":
    main()
