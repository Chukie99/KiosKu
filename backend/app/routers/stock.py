from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Product, StockLog
from ..schemas import StockAdjustIn

router = APIRouter()


@router.get("/stock/alerts")
def stock_alerts(db: Session = Depends(get_db)):
    items = db.scalars(
        select(Product)
        .where(Product.is_active.is_(True), Product.stock <= Product.stock_alert_threshold)
        .order_by(Product.stock)
    ).all()
    return [
        {
            "id": p.id,
            "name": p.name,
            "sku": p.sku,
            "stock": p.stock,
            "stock_alert_threshold": p.stock_alert_threshold,
            "status": "habis" if p.stock <= 0 else "menipis",
        }
        for p in items
    ]


@router.post("/stock/adjust")
def adjust_stock(data: StockAdjustIn, db: Session = Depends(get_db)):
    p = db.get(Product, data.product_id)
    if p is None:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")
    if not data.reason:
        raise HTTPException(status_code=422, detail="Alasan wajib diisi")
    p.stock = round(p.stock + data.change_qty, 2)
    if p.stock < 0:
        raise HTTPException(status_code=422, detail="Stok tidak boleh negatif")
    db.add(StockLog(product_id=p.id, change_qty=data.change_qty, reason=data.reason))
    db.commit()
    return {"id": p.id, "stock": p.stock}


@router.get("/stock/logs")
def stock_logs(product_id: int | None = None, limit: int = 100, db: Session = Depends(get_db)):
    q = select(StockLog, Product).join(Product, StockLog.product_id == Product.id)
    if product_id:
        q = q.where(StockLog.product_id == product_id)
    rows = db.execute(q.order_by(StockLog.created_at.desc()).limit(limit)).all()
    return [
        {
            "id": log.id,
            "product_id": log.product_id,
            "product_name": product.name,
            "change_qty": log.change_qty,
            "reason": log.reason,
            "reference_id": log.reference_id,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        }
        for log, product in rows
    ]
