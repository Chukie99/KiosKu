from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import get_store_name, is_pin_set, set_pin, set_setting, verify_pin
from ..database import get_db
from ..schemas import PinSetIn, PinVerifyIn

router = APIRouter()


@router.post("/auth/verify-pin")
def verify(data: PinVerifyIn, db: Session = Depends(get_db)):
    if not is_pin_set(db):
        return {"ok": True, "pin_set": False}
    return {"ok": verify_pin(db, data.pin), "pin_set": True}


@router.post("/auth/set-pin")
def set_new_pin(data: PinSetIn, db: Session = Depends(get_db)):
    if len(data.new_pin) < 4:
        raise HTTPException(status_code=422, detail="PIN minimal 4 digit")
    if is_pin_set(db):
        if not data.old_pin or not verify_pin(db, data.old_pin):
            raise HTTPException(status_code=403, detail="PIN lama salah")
    set_pin(db, data.new_pin)
    return {"ok": True}


@router.get("/settings")
def get_settings(db: Session = Depends(get_db)):
    return {
        "store_name": get_store_name(db),
        "pin_set": is_pin_set(db),
        "backup_enabled": True,
        "backup_hour": "00:00",
    }


@router.put("/settings")
def update_settings(payload: dict, db: Session = Depends(get_db)):
    if "store_name" in payload:
        set_setting(db, "store_name", str(payload["store_name"]))
    if "backup_hour" in payload:
        set_setting(db, "backup_hour", str(payload["backup_hour"]))
    return get_settings(db)
