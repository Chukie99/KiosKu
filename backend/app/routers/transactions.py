from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from ..auth import get_store_name
from ..database import get_db
from ..dependencies import require_auth
from ..models import Customer, Debt, Product, StockLog, Transaction, TransactionItem
from ..schemas import CustomerIn, DebtPayIn, ReturnIn, TransactionIn, VoidIn

router = APIRouter()


def _serialize_tx(t: Transaction) -> dict:
    return {
        "id": t.id,
        "invoice_no": t.invoice_no,
        "customer_id": t.customer_id,
        "total_amount": t.total_amount,
        "discount_amount": t.discount_amount,
        "payment_method": t.payment_method,
        "cash_received": t.cash_received,
        "change_amount": t.change_amount,
        "payment_split_json": t.payment_split_json,
        "status": t.status,
        "device_id": t.device_id,
        "synced": bool(t.synced),
        "created_at": t.created_at.isoformat() if t.created_at else None,
        "items": [
            {
                "id": i.id,
                "product_id": i.product_id,
                "product_name_snapshot": i.product_name_snapshot,
                "unit_name": i.unit_name,
                "qty": i.qty,
                "price_per_unit": i.price_per_unit,
                "subtotal": i.subtotal,
            }
            for i in t.items
        ],
    }


def _next_invoice_no(db: Session) -> str:
    date_str = datetime.now().strftime("%Y%m%d")
    last = db.scalar(
        select(Transaction.invoice_no)
        .where(Transaction.invoice_no.like(f"INV-{date_str}-%"))
        .order_by(Transaction.id.desc())
        .limit(1)
    )
    seq = int(last.rsplit("-", 1)[-1]) + 1 if last else 1
    return f"INV-{date_str}-{seq:04d}"


def _apply_stock_change(db: Session, product_id: int, change: float, reason: str, ref_id: int | None = None) -> None:
    p = db.get(Product, product_id)
    if p is None:
        raise HTTPException(status_code=404, detail=f"Produk {product_id} tidak ditemukan")
    p.stock += change
    db.add(StockLog(product_id=product_id, change_qty=change, reason=reason, reference_id=ref_id))


def create_transaction_core(
    db: Session,
    items: list,
    payment_method: str,
    cash_received: float | None,
    discount_amount: float,
    customer_id: int | None,
    payment_split_json: str | None,
    device_id: str | None,
    invoice_no: str | None,
    created_at: datetime | None,
    due_date=None,
    change_amount: float | None = None,
) -> Transaction:
    if not items:
        raise HTTPException(status_code=422, detail="Keranjang kosong")
    tx = Transaction(
        invoice_no=invoice_no or _next_invoice_no(db),
        customer_id=customer_id,
        payment_method=payment_method,
        cash_received=cash_received,
        change_amount=change_amount,
        discount_amount=discount_amount or 0,
        payment_split_json=payment_split_json,
        device_id=device_id,
        status="selesai",
    )
    if created_at:
        tx.created_at = created_at
    total = 0.0
    for item in items:
        p = db.get(Product, item.product_id)
        if p is None or not p.is_active:
            raise HTTPException(status_code=404, detail=f"Produk {item.product_id} tidak ditemukan")
        price = item.price_per_unit if item.price_per_unit and item.price_per_unit > 0 else p.price_sell
        unit = item.unit_name or p.unit_base
        qty = item.qty
        subtotal = round(qty * price, 2)
        total += subtotal
        tx.items.append(
            TransactionItem(
                product_id=p.id,
                product_name_snapshot=p.name,
                unit_name=unit,
                qty=qty,
                price_per_unit=price,
                subtotal=subtotal,
            )
        )
    tx.total_amount = round(total - (discount_amount or 0), 2)
    if tx.total_amount < 0:
        raise HTTPException(status_code=422, detail="Total tidak boleh negatif")
    db.add(tx)
    db.flush()

    for item in tx.items:
        db.flush()
        _apply_stock_change(db, item.product_id, -item.qty, "transaksi", ref_id=tx.id)

    if payment_method == "utang":
        if customer_id is None:
            raise HTTPException(status_code=422, detail="Pilih pelanggan untuk transaksi utang")
        db.add(
            Debt(
                customer_id=customer_id,
                transaction_id=tx.id,
                amount=tx.total_amount,
                amount_paid=0,
                status="belum_lunas",
                due_date=due_date,
            )
        )
    db.commit()
    db.refresh(tx)
    return tx


@router.post("/transactions", status_code=201)
def create_transaction(
    data: TransactionIn,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    split_json = None
    if data.payment_method == "split" and data.payment_split:
        split_json = str([s.model_dump() for s in data.payment_split])
    tx = create_transaction_core(
        db=db,
        items=data.items,
        payment_method=data.payment_method,
        cash_received=data.cash_received,
        discount_amount=data.discount_amount,
        customer_id=data.customer_id,
        payment_split_json=split_json,
        device_id=data.device_id,
        invoice_no=data.invoice_no,
        created_at=data.created_at,
        due_date=data.due_date,
    )
    if data.payment_method == "tunai":
        tx.cash_received = data.cash_received
        tx.change_amount = round((data.cash_received or 0) - tx.total_amount, 2)
    db.commit()
    db.refresh(tx)
    return _serialize_tx(tx)


@router.get("/transactions")
def list_transactions(
    date_from: str | None = None,
    date_to: str | None = None,
    status: str | None = None,
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    q = select(Transaction).options(joinedload(Transaction.items))
    if date_from:
        q = q.where(Transaction.created_at >= f"{date_from} 00:00:00")
    if date_to:
        q = q.where(Transaction.created_at <= f"{date_to} 23:59:59")
    if status:
        q = q.where(Transaction.status == status)
    total = db.scalar(select(func.count()).select_from(q.subquery()))
    q = q.order_by(Transaction.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    return {"items": [_serialize_tx(t) for t in db.scalars(q).unique().all()], "total": total or 0}


@router.get("/transactions/{tx_id}")
def get_transaction(
    tx_id: int,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    t = db.scalar(select(Transaction).where(Transaction.id == tx_id).options(joinedload(Transaction.items)))
    if t is None:
        raise HTTPException(status_code=404, detail="Transaksi tidak ditemukan")
    return _serialize_tx(t)


@router.post("/transactions/{tx_id}/void")
def void_transaction(
    tx_id: int,
    data: VoidIn,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    t = db.scalar(select(Transaction).where(Transaction.id == tx_id).options(joinedload(Transaction.items)))
    if t is None:
        raise HTTPException(status_code=404, detail="Transaksi tidak ditemukan")
    if t.status != "selesai":
        raise HTTPException(status_code=409, detail="Transaksi sudah di-void/retur")
    t.status = "void"
    for item in t.items:
        _apply_stock_change(db, item.product_id, item.qty, "void", ref_id=t.id)
    for debt in db.scalars(select(Debt).where(Debt.transaction_id == t.id)):
        debt.status = "lunas" if debt.amount_paid >= debt.amount else debt.status
    db.commit()
    return _serialize_tx(t)


@router.post("/transactions/{tx_id}/return")
def return_transaction(
    tx_id: int,
    data: ReturnIn,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    t = db.scalar(select(Transaction).where(Transaction.id == tx_id).options(joinedload(Transaction.items)))
    if t is None:
        raise HTTPException(status_code=404, detail="Transaksi tidak ditemukan")
    if t.status != "selesai":
        raise HTTPException(status_code=409, detail="Hanya transaksi selesai yang bisa di-retur")
    for item in data.items:
        existing = next((x for x in t.items if x.product_id == item.product_id), None)
        if existing is None or item.qty > existing.qty:
            raise HTTPException(status_code=422, detail="Jumlah retur melebihi qty transaksi")
        existing.qty -= item.qty
        existing.subtotal = round(existing.qty * existing.price_per_unit, 2)
        if existing.qty == 0:
            t.items.remove(existing)
        _apply_stock_change(db, item.product_id, item.qty, "retur", ref_id=t.id)
    t.status = "retur" if not t.items else t.status
    db.commit()
    return _serialize_tx(t)


@router.get("/customers")
def list_customers(
    q: str | None = None,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    query = select(Customer).order_by(Customer.name)
    if q:
        query = query.where(Customer.name.ilike(f"%{q}%"))
    return db.scalars(query).all()


@router.post("/customers", status_code=201)
def create_customer(
    data: CustomerIn,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    if not data.name.strip():
        raise HTTPException(status_code=422, detail="Nama pelanggan wajib diisi")
    c = Customer(name=data.name.strip(), phone=data.phone)
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


@router.get("/debts")
def list_debts(
    status: str | None = None,
    customer_id: int | None = None,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    q = select(Debt, Customer).join(Customer, Debt.customer_id == Customer.id)
    if status:
        q = q.where(Debt.status == status)
    if customer_id:
        q = q.where(Debt.customer_id == customer_id)
    rows = db.execute(q.order_by(Debt.created_at.desc())).all()
    result = {}
    for debt, customer in rows:
        if customer.id not in result:
            result[customer.id] = {
                "customer_id": customer.id,
                "customer_name": customer.name,
                "phone": customer.phone,
                "debts": [],
                "total_debt": 0.0,
                "total_paid": 0.0,
                "due_date_min": None,
            }
        entry = {
            "id": debt.id,
            "transaction_id": debt.transaction_id,
            "amount": debt.amount,
            "amount_paid": debt.amount_paid,
            "remaining": round(debt.amount - debt.amount_paid, 2),
            "status": debt.status,
            "due_date": debt.due_date.isoformat() if debt.due_date else None,
            "created_at": debt.created_at.isoformat() if debt.created_at else None,
        }
        result[customer.id]["debts"].append(entry)
        result[customer.id]["total_debt"] = round(result[customer.id]["total_debt"] + debt.amount, 2)
        result[customer.id]["total_paid"] = round(result[customer.id]["total_paid"] + debt.amount_paid, 2)
        due_iso = debt.due_date.isoformat() if debt.due_date else None
        if due_iso and (result[customer.id]["due_date_min"] is None or due_iso < result[customer.id]["due_date_min"]):
            result[customer.id]["due_date_min"] = due_iso
    return list(result.values())


@router.post("/debts/{debt_id}/pay")
def pay_debt(
    debt_id: int,
    data: DebtPayIn,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    debt = db.get(Debt, debt_id)
    if debt is None:
        raise HTTPException(status_code=404, detail="Utang tidak ditemukan")
    if data.amount_paid <= 0:
        raise HTTPException(status_code=422, detail="Nominal harus lebih dari 0")
    debt.amount_paid = round(debt.amount_paid + data.amount_paid, 2)
    debt.status = "lunas" if debt.amount_paid >= debt.amount else "sebagian"
    db.commit()
    return {
        "id": debt.id,
        "amount": debt.amount,
        "amount_paid": debt.amount_paid,
        "remaining": round(debt.amount - debt.amount_paid, 2),
        "status": debt.status,
    }
