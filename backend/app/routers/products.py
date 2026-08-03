import re
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import Category, Product, ProductUnit
from ..schemas import CategoryIn, CategoryOut, ProductIn, ProductOut

router = APIRouter()


def product_to_dict(p: Product) -> dict:
    return {
        "id": p.id,
        "sku": p.sku,
        "barcode": p.barcode,
        "name": p.name,
        "category_id": p.category_id,
        "category_name": p.category.name if p.category else None,
        "photo_path": p.photo_path,
        "unit_base": p.unit_base,
        "price_buy": p.price_buy,
        "price_sell": p.price_sell,
        "stock": p.stock,
        "stock_alert_threshold": p.stock_alert_threshold,
        "is_favorite": bool(p.is_favorite),
        "is_active": bool(p.is_active),
        "units": [
            {
                "id": u.id,
                "unit_name": u.unit_name,
                "conversion_qty": u.conversion_qty,
                "price_sell": u.price_sell,
            }
            for u in p.units
        ],
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }


def generate_sku(db: Session) -> str:
    for _ in range(20):
        candidate = "P-" + uuid.uuid4().hex[:8].upper()
        if db.scalar(select(Product).where(Product.sku == candidate)) is None:
            return candidate
    raise HTTPException(status_code=500, detail="Gagal generate kode produk")


def apply_units(db: Session, product: Product, units: list) -> None:
    product.units.clear()
    for u in units:
        product.units.append(
            ProductUnit(
                unit_name=u.unit_name,
                conversion_qty=u.conversion_qty,
                price_sell=u.price_sell,
            )
        )


@router.get("/products")
def list_products(
    page: int = 1,
    page_size: int = 50,
    category_id: int | None = None,
    favorite: bool | None = None,
    include_inactive: bool = False,
    db: Session = Depends(get_db),
):
    q = select(Product).options(joinedload(Product.category), joinedload(Product.units))
    count_q = select(Product.id)
    if category_id is not None:
        q = q.where(Product.category_id == category_id)
        count_q = count_q.where(Product.category_id == category_id)
    if favorite is not None:
        q = q.where(Product.is_favorite == favorite)
        count_q = count_q.where(Product.is_favorite == favorite)
    if not include_inactive:
        q = q.where(Product.is_active.is_(True))
        count_q = count_q.where(Product.is_active.is_(True))
    total = db.scalar(select(func.count()).select_from(count_q.subquery())) or 0
    page = max(page, 1)
    q = q.order_by(Product.name).offset((page - 1) * page_size).limit(page_size)
    items = db.scalars(q).unique().all()
    return {"items": [product_to_dict(p) for p in items], "page": page, "page_size": page_size, "total": total}


@router.get("/products/search")
def search_products(q: str = "", db: Session = Depends(get_db)):
    items = db.scalars(
        select(Product)
        .options(joinedload(Product.category), joinedload(Product.units))
        .where(
            Product.is_active.is_(True),
            Product.name.ilike(f"%{q}%"),
        )
        .order_by(Product.name)
        .limit(100)
    ).unique().all()
    return [product_to_dict(p) for p in items]


@router.get("/products/barcode/{code}")
def get_by_barcode(code: str, db: Session = Depends(get_db)):
    p = db.scalar(
        select(Product)
        .options(joinedload(Product.category), joinedload(Product.units))
        .where(Product.barcode == code)
    )
    if p is None:
        raise HTTPException(status_code=404, detail="Barcode tidak ditemukan")
    return product_to_dict(p)


@router.get("/products/{product_id}")
def get_product(product_id: int, db: Session = Depends(get_db)):
    p = db.get(Product, product_id)
    if p is None:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")
    return product_to_dict(p)


@router.post("/products", response_model=ProductOut, status_code=201)
def create_product(data: ProductIn, db: Session = Depends(get_db)):
    if data.price_sell <= 0:
        raise HTTPException(status_code=422, detail="Harga jual tidak boleh 0")
    if data.barcode and db.scalar(select(Product).where(Product.barcode == data.barcode)):
        raise HTTPException(status_code=409, detail="Barcode sudah terdaftar")
    sku = data.sku or generate_sku(db)
    if db.scalar(select(Product).where(Product.sku == sku)):
        raise HTTPException(status_code=409, detail="SKU sudah terdaftar")
    product = Product(**data.model_dump(exclude={"units", "sku"}), sku=sku)
    if data.units:
        apply_units(db, product, data.units)
    db.add(product)
    db.commit()
    db.refresh(product)
    return product_to_dict(product)


@router.put("/products/{product_id}", response_model=ProductOut)
def update_product(product_id: int, data: ProductIn, db: Session = Depends(get_db)):
    p = db.get(Product, product_id)
    if p is None:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")
    if data.price_sell <= 0:
        raise HTTPException(status_code=422, detail="Harga jual tidak boleh 0")
    payload = data.model_dump(exclude={"units"})
    if payload.get("barcode") and payload["barcode"] != p.barcode:
        dup = db.scalar(select(Product).where(Product.barcode == payload["barcode"], Product.id != product_id))
        if dup:
            raise HTTPException(status_code=409, detail="Barcode sudah terdaftar")
    for k, v in payload.items():
        setattr(p, k, v)
    if data.units is not None:
        apply_units(db, p, data.units)
    db.commit()
    db.refresh(p)
    return product_to_dict(p)


@router.delete("/products/{product_id}")
def deactivate_product(product_id: int, db: Session = Depends(get_db)):
    p = db.get(Product, product_id)
    if p is None:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")
    p.is_active = False
    db.commit()
    return {"ok": True}


@router.get("/categories", response_model=list[CategoryOut])
def list_categories(db: Session = Depends(get_db)):
    return db.scalars(select(Category).order_by(Category.name)).all()


@router.post("/categories", response_model=CategoryOut, status_code=201)
def create_category(data: CategoryIn, db: Session = Depends(get_db)):
    if not data.name.strip():
        raise HTTPException(status_code=422, detail="Nama kategori wajib diisi")
    if db.scalar(select(Category).where(Category.name == data.name.strip())):
        raise HTTPException(status_code=409, detail="Kategori sudah ada")
    cat = Category(name=data.name.strip())
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat
