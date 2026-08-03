import random
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .auth import set_pin, set_setting
from .models import Category, Customer, Product, ProductUnit

random.seed(42)

CATEGORIES = ["Sembako", "Minuman", "Snack", "Rokok", "Perawatan", "Rumah Tangga"]

PRODUCTS = [
    # (name, category, price_buy, price_sell, stock, threshold, barcode, unit, favorite, units)
    ("Beras Premium 5kg", "Sembako", 68000, 72000, 45, 10, "8991002101144", "kg", True, []),
    ("Beras Medium 5kg", "Sembako", 60000, 65000, 30, 10, None, "kg", False, []),
    ("Minyak Goreng 1L", "Sembako", 15500, 17000, 60, 10, "8992748310014", "pcs", True, []),
    ("Gula Pasir 1kg", "Sembako", 15200, 16500, 55, 10, "8992758310014", "kg", False, []),
    ("Telur Ayam 1kg", "Sembako", 23000, 26000, 25, 8, None, "kg", False, []),
    ("Cabai Merah Keriting 1kg", "Sembako", 28000, 32000, 8, 10, None, "kg", False, []),
    ("Bawang Merah 1kg", "Sembako", 24000, 28000, 12, 10, None, "kg", False, []),
    ("Bawang Putih 1kg", "Sembako", 26000, 30000, 10, 8, None, "kg", False, []),
    ("Tepung Terigu Segitiga 1kg", "Sembako", 10200, 11500, 40, 10, "8991002300011", "kg", False, []),
    ("Kecap Manis ABC 550ml", "Sembako", 14200, 16000, 22, 5, "8991002103078", "pcs", False, []),
    ("Indomie Goreng", "Sembako", 3100, 3500, 120, 30, "089686160090", "pcs", True, []),
    ("Indomie Soto", "Sembako", 3100, 3500, 80, 30, None, "pcs", False, []),
    ("Aqua 600ml", "Minuman", 2500, 3000, 90, 30, "8992760100000", "pcs", True, []),
    ("Teh Botol Sosro 350ml", "Minuman", 3900, 4500, 70, 20, "8991002103377", "pcs", False, []),
    ("Kopi Kapal Api 30g", "Minuman", 2100, 2500, 100, 25, None, "pcs", False, []),
    ("Susu Ultra 250ml", "Minuman", 4800, 5500, 50, 15, "8999909008000", "pcs", False, []),
    ("Fanta 1.5L", "Minuman", 11000, 13000, 35, 10, "8992753310014", "pcs", False, []),
    ("Chitato 68g", "Snack", 8200, 9500, 45, 15, "899997080068", "pcs", False, []),
    ("Taro Netto 70g", "Snack", 7800, 9000, 30, 10, None, "pcs", False, []),
    ("Silver Queen 63g", "Snack", 12200, 13500, 25, 10, "8991001103700", "pcs", False, []),
    ("Roti Bimoli 250g", "Snack", 8800, 10000, 20, 8, None, "pcs", False, []),
    (
        "Rokok Sampoerna Mild",
        "Rokok",
        23800,
        24500,
        480,
        100,
        "899990991110",
        "pcs",
        False,
        [
            ("batang", 1, 2500),
            ("bungkus", 24, 24500),
        ],
    ),
    ("Rokok Dji Sam Soe Magnum", "Rokok", 24200, 25000, 360, 80, None, "pcs", False, []),
    ("Sabun Lifebuoy 90g", "Perawatan", 3500, 4000, 60, 15, "8992748310016", "pcs", False, []),
    ("Shampo Lifebuoy 170ml", "Perawatan", 11200, 12500, 35, 10, None, "pcs", False, []),
    ("Pasta Gigi Pepsodent 120g", "Perawatan", 8600, 9500, 40, 10, "8992940012345", "pcs", False, []),
    ("Sabun Rinso 150g", "Rumah Tangga", 5400, 6000, 55, 15, None, "pcs", False, []),
    ("Pembersih Lantai 800ml", "Rumah Tangga", 9200, 10500, 25, 8, None, "pcs", False, []),
]

CUSTOMERS = [
    ("Pak Slamet", "081234567890"),
    ("Bu Sari", "085678901234"),
    ("Mas Budi", "089876543210"),
]

PAYMENT_METHODS = ["tunai", "tunai", "tunai", "tunai", "qris", "qris", "ewallet", "split"]
SPLIT_PAIRS = [("tunai", 0.4), ("qris", 0.6), ("tunai", 0.5), ("ewallet", 0.5)]


def _seed_products(db: Session) -> list[Product]:
    cat_map: dict[str, Category] = {}
    for name in CATEGORIES:
        cat = Category(name=name)
        db.add(cat)
        cat_map[name] = cat
    db.flush()

    products: list[Product] = []
    for idx, (name, cat, buy, sell, stock, threshold, barcode, unit, fav, units) in enumerate(PRODUCTS, 1):
        p = Product(
            sku=f"P-{1000 + idx}",
            barcode=barcode,
            name=name,
            category_id=cat_map[cat].id,
            unit_base=unit,
            price_buy=buy,
            price_sell=sell,
            stock=stock,
            stock_alert_threshold=threshold,
            is_favorite=fav,
        )
        for unit_name, conv, price in units:
            p.units.append(ProductUnit(unit_name=unit_name, conversion_qty=conv, price_sell=price))
        db.add(p)
        products.append(p)
    return products


def _seed_transactions(db: Session, products: list[Product], customers: list[Customer]) -> None:
    from .models import Debt, StockLog, Transaction, TransactionItem

    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    invoice_seq = 1

    def make_tx(day_offset: int, hour: int) -> Transaction:
        nonlocal invoice_seq
        ts = today - timedelta(days=day_offset) + timedelta(hours=hour)
        method = random.choice(PAYMENT_METHODS)
        n_items = random.randint(1, 5)
        chosen = random.sample(products, n_items)
        tx = Transaction(
            invoice_no=f"INV-{ts.strftime('%Y%m%d')}-{invoice_seq:04d}",
            payment_method=method,
            status="selesai",
            created_at=ts,
        )
        invoice_seq += 1
        total = 0.0
        for p in chosen:
            unit = None
            if p.units and random.random() < 0.4:
                unit = p.units[0]
            qty = random.choice([1, 1, 1, 2, 2, 3, 5])
            price = unit.price_sell if unit else p.price_sell
            unit_name = unit.unit_name if unit else p.unit_base
            subtotal = round(qty * price, 2)
            total += subtotal
            tx.items.append(
                TransactionItem(
                    product_id=p.id,
                    product_name_snapshot=p.name,
                    unit_name=unit_name,
                    qty=qty,
                    price_per_unit=price,
                    subtotal=subtotal,
                )
            )
        tx.total_amount = round(total, 2)
        if method == "tunai":
            received = (int(total // 1000) + 1) * 1000
            tx.cash_received = received
            tx.change_amount = round(received - total, 2)
        elif method == "split":
            t, r = random.choice(SPLIT_PAIRS)
            first = round(total * r, 2)
            tx.payment_split_json = str(
                [{"method": t, "amount": first}, {"method": "ewallet", "amount": round(total - first, 2)}]
            )
        return tx

    # transaksi tunai/qris normal 30 hari terakhir
    for day in range(30):
        n = random.randint(2, 6)
        for _ in range(n):
            tx = make_tx(day, random.randint(8, 20))
            db.add(tx)
            db.flush()
            for item in tx.items:
                p = db.get(Product, item.product_id)
                p.stock = round(p.stock - item.qty, 2)
                db.add(StockLog(product_id=item.product_id, change_qty=-item.qty, reason="transaksi", reference_id=tx.id))

    # transaksi utang untuk 3 pelanggan
    for i, cust in enumerate(customers):
        for j in range(2):
            ts = today - timedelta(days=random.randint(1, 20)) + timedelta(hours=random.randint(9, 19))
            tx = make_tx(random.randint(1, 20), random.randint(9, 19))
            tx.customer_id = cust.id
            tx.payment_method = "utang"
            tx.cash_received = None
            tx.change_amount = None
            db.add(tx)
            db.flush()
            for item in tx.items:
                p = db.get(Product, item.product_id)
                p.stock = round(p.stock - item.qty, 2)
                db.add(StockLog(product_id=item.product_id, change_qty=-item.qty, reason="transaksi", reference_id=tx.id))
            due = (ts + timedelta(days=random.choice([7, 14, 21]))).date()
            db.add(
                Debt(
                    customer_id=cust.id,
                    transaction_id=tx.id,
                    amount=tx.total_amount,
                    amount_paid=tx.total_amount * random.choice([0, 0, 0.5]) if i == 2 else 0,
                    status="belum_lunas" if i < 2 else "sebagian",
                    due_date=due,
                    created_at=ts,
                )
            )


def seed_all(db: Session) -> bool:
    if db.scalar(select(func.count()).select_from(Product)):
        return False
    customers = []
    for name, phone in CUSTOMERS:
        c = Customer(name=name, phone=phone)
        db.add(c)
        customers.append(c)
    db.flush()
    products = _seed_products(db)
    db.flush()
    _seed_transactions(db, products, customers)
    set_pin(db, "1234")
    set_setting(db, "store_name", "Toko KiosKu")
    set_setting(db, "backup_hour", "00:00")
    return True
