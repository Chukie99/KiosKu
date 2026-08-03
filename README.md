# KiosKu — Aplikasi Kasir untuk Warung/Toko Kelontong

Aplikasi POS (Point of Sale) lengkap berbasis **LAN lokal** (tanpa internet/cloud): HP Android sebagai kasir (scan barcode pakai kamera), PC/laptop toko sebagai server (data, laporan, dashboard web).

## Struktur Proyek

```
KiosKu/
├── backend/          # Python FastAPI + SQLite (server lokal di PC)
│   └── app/          # main.py, models, routers, seed
├── android_app/      # Flutter (aplikasi kasir di HP Android)
│   └── lib/          # tema, model, API client, halaman
├── web_dashboard/    # React + Vite + Tailwind (dashboard PC)
│   └── dist/         # hasil build, disajikan oleh backend
├── start.bat         # jalanin server + dashboard sekali klik
└── KiosKu_Blueprint.txt
```

## Cara Menjalankan

### 1. Server PC (backend + dashboard web)

**Opsional:** buat virtual environment:
```bat
cd backend
python -m venv venv
venv\Scripts\activate
```

Install & jalankan:
```bat
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
atau tinggal double-click **start.bat**.

- Dashboard web: `http://localhost:8000/dashboard` (dari PC sendiri) atau `http://<IP-PC>:8000/dashboard` (dari HP/PC lain di WiFi yang sama)
- Dokumentasi API: `http://localhost:8000/docs`
- Database: `backend/data/kiosku.db` (SQLite), backup otomatis ke `backend/data/backups/`

**Data pertama kali** (seed otomatis): 28 produk, transaksi 30 hari, 3 pelanggan utang, PIN default `1234`. Hapus `backend/data/kiosku.db` lalu restart untuk seed ulang.

### 2. Aplikasi Android (Flutter)

```bat
cd android_app
flutter pub get
flutter run
```

Setelah install: buka **Pengaturan** di aplikasi → isi **Server URL** dengan alamat IP PC toko, contoh `http://192.168.1.5:8000` → tekan Sinkronkan. PIN default `1234` (bisa diganti di Pengaturan).

Persyaratan: Android 8.0+; HP kasir dan PC harus di jaringan WiFi/ router yang sama. Printer thermal: USB-OTG atau Bluetooth (ESC/POS).

### 3. Dashboard web (jika ingin ubah kode)

```bat
cd web_dashboard
npm install
npm run dev        # development (port 5173)
npm run build      # production -> dist/, disajikan backend di /dashboard
```

## Fitur Utama

- Kasir cepat: scan barcode kamera, pilih produk/kategori/favorit, hitung kembalian otomatis
- Pembayaran: Tunai, QRIS/E-Wallet (cek manual), Split, Utang pelanggan
- Cetak struk thermal USB/Bluetooth, void & retur transaksi (dengan PIN)
- Stok otomatis berkurang + alert menipis, koreksi stok manual
- Laporan harian/bulanan, barang terlaris, export Excel/PDF
- Utang/bon pelanggan + reminder jatuh tempo
- Mode offline: transaksi tersimpan di HP saat WiFi putus, auto-sync saat koneksi kembali
- Backup otomatis harian + restore manual
- PIN keamanan aplikasi (bcrypt di server)

## Teknologi

| Bagian | Stack |
|---|---|
| Backend | Python FastAPI, SQLAlchemy, SQLite |
| Android | Flutter 3.x, Riverpod, mobile_scanner, sqflite, dio, esc_pos |
| Dashboard | React 18, Vite, TypeScript, Tailwind, recharts, lucide |
