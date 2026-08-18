<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white" alt="FastAPI"/>
  <img src="https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black" alt="React"/>
  <img src="https://img.shields.io/badge/SQLite-003B57?logo=sqlite&logoColor=white" alt="SQLite"/>
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Android-0078D4?logo=windows&logoColor=white" alt="Platform"/>
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License"/>
</p>

<h1 align="center">
  <br>
  <img src="https://img.shields.io/badge/🏪-KiosKu-A8402E?style=for-the-badge&labelColor=FBF6EC" alt="KiosKu">
  <br>
  <br>
</h1>

<p align="center">
  <b>Aplikasi kasir offline-first untuk warung & toko kelontong Indonesia.</b><br>
  <sub>Satu aplikasi, dua mode — Kasir & Pemilik. Tanpa internet, tanpa cloud, data 100% milik Anda.</sub>
</p>

---

## Mengapa KiosKu?

Kebanyakan software kasir mahal, butuh internet, atau mengharuskan semua barang punya barcode. **KiosKu** dirancang untuk warung dan toko kelontong Indonesia yang:

- **Tidak punya barcode** — beras, cabai, gula curah tetap bisa dijual cepat lewat daftar produk & favorit
- **Ingin hemat** — gratis, open-source, tanpa biaya langganan atau payment gateway
- **Butuh offline** — berjalan sepenuhnya di jaringan WiFi lokal, tanpa internet
- **Mau cetak struk** — langsung ke printer thermal 80mm via USB

## Fitur Utama

| | Fitur | Deskripsi |
|---|---|---|
| 🛒 | **Kasir Cepat** | Scan barcode via scanner USB / ketik manual, pilih produk dari daftar/kategori/favorit |
| 💳 | **Multi Pembayaran** | Tunai, QRIS, E-Wallet, Split, Utang — kembalian hitung otomatis |
| 🧾 | **Cetak Struk** | Printer thermal 80mm via Windows, simpan PDF struk |
| 📦 | **Manajemen Produk** | CRUD produk + foto, kategori, multi-satuan, stok otomatis berkurang |
| 📊 | **Laporan Real-time** | Omzet harian/bulanan, barang terlaris, export Excel/PDF |
| 💰 | **Utang Pelanggan** | Catat bon, jatuh tempo, reminder, bayar sebagian/lunas |
| 🔒 | **PIN Keamanan** | Aplikasi terkunci PIN (bcrypt), PIN default `1234` |
| 🔄 | **Mode Offline** | Transaksi tersimpan lokal saat WiFi putus, auto-sync saat koneksi kembali |
| 💾 | **Backup Otomatis** | Backup harian + restore manual, aman dari data loss |
| 🌐 | **Dashboard Web** | Monitoring dari browser PC — produk, stok, laporan, utang |

## Screenshots

> *Tambahkan screenshot aplikasi Anda di sini*

```
┌─────────────────────────────────────────┐
│  KiosKu — Mode Kasir                    │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ Beras   │ │ Gula    │ │ Minyak  │   │
│  │ Rp12.000│ │ Rp14.500│ │ Rp18.000│   │
│  └─────────┘ └─────────┘ └─────────┘   │
│                                         │
│  🛒 Keranjang          Total: Rp26.500  │
│  ├─ Beras 1x  Rp12.000                 │
│  └─ Gula 1x   Rp14.500                 │
│                                         │
│  [ 💳 Bayar ]                          │
└─────────────────────────────────────────┘
```

## Tech Stack

| Komponen | Technologi | Keterangan |
|----------|-----------|------------|
| **Backend** | Python FastAPI + SQLAlchemy | REST API, autentikasi PIN, logic bisnis |
| **Database** | SQLite | File-based, zero-config, mudah backup |
| **Android/Windows** | Flutter 3.x + Riverpod | Aplikasi kasir & mode pemilik |
| **Dashboard Web** | React 18 + Vite + TypeScript | Dashboard monitoring di browser |
| **Styling** | Tailwind CSS | Desain konsisten, responsive |
| **Icons** | Lucide | Ikon ringan & konsisten di semua platform |
| **Charts** | Recharts (web) / fl_chart (mobile) | Visualisasi laporan |

## Arsitektur

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Android    │    │  PC / Laptop │    │   Browser    │
│  (Flutter)   │    │   (Server)   │    │   (React)    │
│              │    │              │    │              │
│  ┌────────┐  │    │  ┌────────┐  │    │  ┌────────┐  │
│  │ Kasir  │──┼────┼──│ FastAPI│  │    │  │Dashboard│  │
│  │ Mode   │  │WiFi│  │ +SQLite│  │    │  │  Web   │  │
│  └────────┘  │    │  └────────┘  │    │  └────────┘  │
│  ┌────────┐  │    │  ┌────────┐  │    │              │
│  │ Pemilik│──┼────┼──│ Backup │  │    │              │
│  │ Mode   │  │    │  │ Worker │  │    │              │
│  └────────┘  │    │  └────────┘  │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
                         │
                    ┌────┴────┐
                    │ Printer │
                    │ Thermal │
                    └─────────┘
```

**Prinsip desain:**
- **Offline-first** — semua operasi kasir berjalan tanpa internet
- **LAN-only** — komunikasi via WiFi lokal, data tidak keluar dari toko
- **Zero-config** — SQLite tanpa setup, jalankan `start.bat` langsung jalan

## Quick Start

### 1. Jalankan Server (PC/Laptop Toko)

```bash
# Clone repository
git clone https://github.com/username/KiosKu.git
cd KiosKu

# Install dependencies & jalankan
cd backend
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Atau double-click **`start.bat`** untuk install + jalankan sekaligus.

- **Dashboard:** `http://localhost:8000/dashboard`
- **API Docs:** `http://localhost:8000/docs`
- **Database:** `backend/data/kiosku.db` (SQLite)

### 2. Jalankan Aplikasi (Android/Windows)

```bash
cd android_app
flutter pub get
flutter run -d windows    # atau -d android untuk HP
```

Build release:
```bash
flutter build windows --release
# Output: android_app\build\windows\x64\runner\Release\kiosku.exe
```

### 3. Koneksi Pertama

1. Buka aplikasi → **Pengaturan** → isi **Server URL** dengan IP PC toko
   - Contoh: `http://192.168.1.5:8000`
2. Tekan **Sinkronkan**
3. PIN default: `1234` (ganti di Pengaturan)

## Mode Aplikasi

### Mode Kasir
- Transaksi cepat — scan barcode atau pilih dari daftar
- Hitung kembalian otomatis
- Cetak struk ke printer thermal
- Riwayat transaksi hari ini
- Catat utang pelanggan

### Mode Pemilik (terkunci PIN)
- Dashboard omzet & barang terlaris
- Kelola produk + foto + kategori
- Alert stok menipis & koreksi manual
- Laporan harian/bulanan + export
- Kelola utang pelanggan
- Backup & restore data

## API Endpoints

<details>
<summary>Klik untuk lihat seluruh endpoint</summary>

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| POST | `/auth/verify-pin` | Verifikasi PIN |
| POST | `/auth/set-pin` | Set/ubah PIN |
| POST | `/auth/logout` | Logout (invalidate token) |
| GET | `/products` | Daftar produk (pagination) |
| GET | `/products/search` | Cari produk |
| GET | `/products/barcode/{code}` | Cari by barcode |
| POST | `/products` | Tambah produk |
| PUT | `/products/{id}` | Edit produk |
| DELETE | `/products/{id}` | Soft delete produk |
| POST | `/products/{id}/photo` | Upload foto produk |
| GET | `/categories` | Daftar kategori |
| POST | `/categories` | Tambah kategori |
| POST | `/transactions` | Buat transaksi |
| GET | `/transactions` | Riwayat transaksi |
| POST | `/transactions/{id}/void` | Batalkan transaksi |
| POST | `/transactions/{id}/return` | Proses retur |
| GET | `/reports/daily` | Laporan harian |
| GET | `/reports/monthly` | Laporan bulanan |
| GET | `/reports/top-products` | Barang terlaris |
| GET | `/reports/summary` | Ringkasan |
| GET | `/reports/export` | Export Excel/PDF |
| GET | `/customers` | Daftar pelanggan |
| POST | `/customers` | Tambah pelanggan |
| GET | `/debts` | Daftar utang |
| POST | `/debts/{id}/pay` | Bayar utang |
| GET | `/stock/alerts` | Stok menipis |
| POST | `/stock/adjust` | Koreksi stok |
| POST | `/sync/push` | Push data offline |
| GET | `/sync/pull` | Pull data terbaru |
| POST | `/backup/trigger` | Backup manual |
| GET | `/backup/list` | Daftar backup |
| GET | `/health` | Health check |

</details>

## Struktur Project

```
KiosKu/
├── backend/                # Python FastAPI + SQLite
│   ├── app/
│   │   ├── main.py         # Entry point, middleware, static files
│   │   ├── models.py       # SQLAlchemy models
│   │   ├── database.py     # DB connection & session
│   │   ├── session.py      # In-memory session store
│   │   ├── dependencies.py # Auth dependency (require_auth)
│   │   ├── seed.py         # Seed data (28 produk, transaksi 30 hari)
│   │   └── routers/        # API endpoints
│   │       ├── auth.py
│   │       ├── products.py
│   │       ├── transactions.py
│   │       ├── reports.py
│   │       ├── stock.py
│   │       ├── sync.py
│   │       └── backup.py
│   ├── tests/              # pytest test suite (34 tests)
│   ├── data/               # SQLite DB + backups + photos
│   └── requirements.txt
├── android_app/            # Flutter (Windows + Android)
│   └── lib/
│       ├── main.dart       # Entry point, splash, nav rail
│       ├── theme.dart      # AppColors + AppTheme (Nota Warung)
│       ├── api.dart        # HTTP client + auth interceptor
│       ├── models.dart     # Data models
│       ├── providers.dart  # Riverpod providers
│       ├── components.dart # Reusable widgets
│       ├── offline_db.dart # Local SQLite cache
│       ├── pages/          # Kasir, receipt, payment, history
│       ├── pages/owner/    # Dashboard, products, reports, debts
│       └── widgets/        # EmptyState, StampBadge, StockProgressBar
├── web_dashboard/          # React + Vite + Tailwind
│   ├── src/
│   │   ├── App.tsx         # Router + auth guard
│   │   ├── lib/api.ts      # HTTP client + token mgmt
│   │   ├── pages/          # Login, Dashboard, Products, Reports, etc.
│   │   └── components/     # UI components + layout
│   ├── tailwind.config.js  # Nota Warung design tokens
│   └── index.html
├── start.bat               # One-click server start
├── KiosKu_Blueprint.txt    # Full project specification
└── README.md
```

## Kontribusi

Kontribusi selalu diterima! Jika Anda ingin:

1. Fork repository ini
2. Buat branch baru (`git checkout -b feature/fitur-baru`)
3. Commit perubahan (`git commit -m 'Tambah fitur baru'`)
4. Push ke branch (`git push origin feature/fitur-baru`)
5. Buka Pull Request

## Lisensi

MIT License — silakan gunakan untuk keperluan pribadi maupun komersial.

---

<p align="center">
  <sub>Dibuat dengan ❤️ untuk warung & toko kelontong Indonesia</sub>
</p>
