from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..dependencies import require_auth
from ..models import Product, Transaction
from ..schemas import SyncPushIn
from .products import product_to_dict
from .transactions import _serialize_tx, create_transaction_core

router = APIRouter()


@router.post("/sync/push")
def sync_push(
    data: SyncPushIn,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    results = []
    for item in data.transactions:
        exists = db.scalar(select(Transaction).where(Transaction.invoice_no == item.invoice_no))
        if exists:
            results.append({"invoice_no": item.invoice_no, "status": "duplicate"})
            continue
        try:
            tx = create_transaction_core(
                db=db,
                items=item.items,
                payment_method=item.payment_method,
                cash_received=item.cash_received,
                discount_amount=item.discount_amount,
                customer_id=item.customer_id,
                payment_split_json=None,
                device_id=item.device_id,
                invoice_no=item.invoice_no,
                created_at=item.created_at,
            )
            if item.payment_method == "tunai":
                tx.change_amount = item.change_amount
            tx.synced = True
            db.commit()
            results.append({"invoice_no": item.invoice_no, "status": "ok", "id": tx.id})
        except HTTPException as e:
            db.rollback()
            results.append({"invoice_no": item.invoice_no, "status": "error", "detail": e.detail})
        except Exception as e:
            db.rollback()
            results.append({"invoice_no": item.invoice_no, "status": "error", "detail": str(e)})
    return {"results": results}


@router.get("/sync/pull")
def sync_pull(
    since: str | None = None,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    products_q = select(Product).options(joinedload(Product.category), joinedload(Product.units))
    if since:
        products_q = products_q.where(Product.updated_at >= since)
    products = db.scalars(products_q).unique().all()

    tx_q = select(Transaction).options(joinedload(Transaction.items))
    if since:
        tx_q = tx_q.where(Transaction.created_at >= since)
    txs = db.scalars(tx_q).unique().all()

    return {
        "products": [product_to_dict(p) for p in products],
        "transactions": [_serialize_tx(t) for t in txs],
        "server_time": datetime.now().isoformat(),
    }
