<div align="center">

# 🛒 קופה • Kupa
### The Open-Source Price Intelligence & Smart Basket Platform for Israeli Supermarkets

[![Release](https://img.shields.io/github/v/release/israelxss/kupa?color=10B981&label=Release&logo=github)](https://github.com/israelxss/kupa/releases/latest)
[![Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://github.com/israelxss/kupa/releases/latest)
[![Flutter](https://img.shields.io/badge/Framework-Flutter%203.22+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Open Data](https://img.shields.io/badge/Data-Government%20Price%20Transparency-0052CC)](https://www.over.org.il)

<p align="center">
  <b>לפני שמשלמים בקופה – בודקים ב"קופה"</b><br>
  <i>Empowering Israeli consumers with transparent, real-time grocery prices, automated basket optimization, and tactile drag-and-drop store routing.</i>
</p>

[**Download Latest APK**](https://github.com/israelxss/kupa/releases/latest) • [**Features**](#-core-features) • [**Build Guide**](#-building-from-source) • [**Architecture**](#-technical-stack)

---

</div>

## 📌 Executive Summary

Under Israel's **Food Price Transparency Law (חוק שקיפות המחירים)**, major retail food chains are legally required to publish detailed daily price XML catalogs for every physical and digital branch nationwide. While this raw data is public, it remains heavily fragmented across vendor servers and inaccessible to the everyday shopper standing in front of a supermarket shelf.

**Kupa (קופה)** resolves this by aggregating transparency feeds into a lightning-fast, ad-free mobile engine. With an ultra-responsive barcode scanner, live cross-chain benchmarking, and a dynamic multi-store basket optimizer, Kupa guarantees that consumers never overpay at checkout.

---

## ⚡ Core Features

### 📷 Sub-Second Barcode Scanning
* Point your camera at any retail barcode or shelf tag to instantly query national price databases.
* Displays the nationwide lowest price, highest price, percentage disparity, and the exact local branch offering the discount.

### 🏬 Personalized Store Profile ("My Chains")
* Select the supermarkets you actually shop at (e.g. *Rami Levy, Shufersal, Carrefour, Osher Ad, Yochananof, Victory, Tiv Taam, Hazi Hinam*).
* Filter comparisons and total costs exclusively against your active preferred retailers.
* Includes a **"Select All"** toggle and quick-select presets for major national chains.

### 🔀 Multi-Store Basket Routing & Tactile Drag-and-Drop
* **Automated Clustering:** Instantly segments items into dedicated "Store Windows", assigning each item to the retailer where it is sold cheapest.
* **Tactile Drag-and-Drop:** Drag any product card from one supermarket window and drop it directly into another (e.g., forcing an item from Rami Levy into Carrefour).
* **Price Discrepancy Warnings:** If moved to a more expensive store, Kupa highlights the price variance (`Cheaper at X — save ₪Y`) and provides a **One-Click Restore (↩️ החזר)** action.
* **Smart Single-Store Tab:** Offers a side-by-side total if you prefer to purchase all basket items at a single retailer.

### 💾 Persistent State & Offline-Tolerant UX
* Preserves your custom basket, items, quantities, and chosen stores across app closures via local storage.
* High-resolution official store branding icons with embedded caching.
* Automatic Dark Mode synchronized with Android system appearance.

---

## 🛠 Technical Stack & Dependencies

Kupa is built purely with native-compiled Flutter, adhering to strict zero-bloat principles:

| Library | Version | Purpose |
| :--- | :--- | :--- |
| **[`mobile_scanner`](https://pub.dev/packages/mobile_scanner)** | `^7.4.2` | Native hardware-accelerated camera barcode and QR processing via Google ML Kit / CameraX. |
| **[`provider`](https://pub.dev/packages/provider)** | `^6.1.5` | Reactive state management for shopping basket state and persistent user preferences. |
| **[`http`](https://pub.dev/packages/http)** | `^1.6.0` | Asynchronous REST client interfacing with the transparency price engines. |
| **[`shared_preferences`](https://pub.dev/packages/shared_preferences)** | `^2.5.5` | Key-value disk persistence for shopping baskets and app configuration. |
| **[`intl`](https://pub.dev/packages/intl)** | `^0.20.3` | Localization, numeral normalization, and currency formatting (`₪ ILS`). |
| **[`url_launcher`](https://pub.dev/packages/url_launcher)** | `^6.3.2` | External intent launcher for Open Data repositories and documentation. |
| **[`flutter_svg`](https://pub.dev/packages/flutter_svg)** | `^2.3.0` | Vector rendering for UI icons and high-density store visual badges. |

---

## 🚀 Building from Source

### Prerequisites
1. **Flutter SDK:** Version `3.22.0` or higher ([Installation Guide](https://flutter.dev/docs/get-started/install)).
2. **Java Development Kit (JDK):** OpenJDK 17 (`java -version`).
3. **Android SDK:** Platform API level 34 or 35 with Android Build-Tools.

### Step 1: Clone Repository
```bash
git clone https://github.com/israelxss/kupa.git
cd kupa
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Run on Device
Ensure an Android device or emulator is connected with USB Debugging enabled:
```bash
flutter devices
flutter run
```

### Step 4: Build Standalone APK
```bash
flutter build apk --debug
```
The compiled package will be output to `build/app/outputs/flutter-apk/app-debug.apk`.



---

## 📜 License & Open Source

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for full details.  
Built and maintained by [**israelxss**](https://github.com/israelxss).  
Dedicated to full price transparency and public empowerment in Israel 🇮🇱.
