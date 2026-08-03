from datetime import datetime, date
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class PinVerifyIn(BaseModel):
    pin: str


class PinSetIn(BaseModel):
    old_pin: str | None = None
    new_pin: str


class CategoryIn(BaseModel):
    name: str


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class ProductUnitIn(BaseModel):
    unit_name: str
    conversion_qty: float
    price_sell: float


class ProductIn(BaseModel):
    name: str
    category_id: int | None = None
    barcode: str | None = None
    sku: str | None = None
    photo_path: str | None = None
    unit_base: str = "pcs"
    price_buy: float = 0
    price_sell: float
    stock: float = 0
    stock_alert_threshold: float = 5
    is_favorite: bool = False
    is_active: bool = True
    units: list[ProductUnitIn] = []


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sku: str | None
    barcode: str | None
    name: str
    category_id: int | None
    category_name: str | None = None
    photo_path: str | None
    unit_base: str
    price_buy: float
    price_sell: float
    stock: float
    stock_alert_threshold: float
    is_favorite: bool
    is_active: bool
    units: list[dict] = []
    created_at: datetime | None = None


class TransactionItemIn(BaseModel):
    product_id: int
    qty: float
    unit_name: str = "pcs"
    price_per_unit: float | None = None


class PaymentSplitIn(BaseModel):
    method: str
    amount: float


class TransactionIn(BaseModel):
    items: list[TransactionItemIn]
    payment_method: Literal["tunai", "qris", "ewallet", "split", "utang"]
    cash_received: float | None = None
    discount_amount: float = 0
    customer_id: int | None = None
    payment_split: list[PaymentSplitIn] | None = None
    device_id: str | None = None
    due_date: date | None = None
    invoice_no: str | None = None
    created_at: datetime | None = None


class VoidIn(BaseModel):
    reason: str = ""


class ReturnItemIn(BaseModel):
    product_id: int
    qty: float
    unit_name: str = "pcs"


class ReturnIn(BaseModel):
    items: list[ReturnItemIn]
    reason: str = ""


class CustomerIn(BaseModel):
    name: str
    phone: str | None = None


class DebtPayIn(BaseModel):
    amount_paid: float


class StockAdjustIn(BaseModel):
    product_id: int
    change_qty: float
    reason: str = "koreksi"


class OfflineItemIn(TransactionItemIn):
    pass


class OfflineTransactionIn(BaseModel):
    invoice_no: str
    items: list[OfflineItemIn]
    payment_method: str
    cash_received: float | None = None
    change_amount: float | None = None
    discount_amount: float = 0
    customer_id: int | None = None
    device_id: str | None = None
    created_at: datetime | None = None


class SyncPushIn(BaseModel):
    transactions: list[OfflineTransactionIn]


class BackupInfo(BaseModel):
    filename: str
    size: int
    created_at: str


class SettingsOut(BaseModel):
    store_name: str
    pin_set: bool
    backup_enabled: bool
    backup_hour: str
