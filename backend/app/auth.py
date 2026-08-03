import bcrypt

from sqlalchemy.orm import Session

from .models import AppSetting

PIN_KEY = "pin_hash"
STORE_NAME_KEY = "store_name"
BACKUP_ENABLED_KEY = "backup_enabled"
BACKUP_HOUR_KEY = "backup_hour"


def hash_pin(pin: str) -> str:
    return bcrypt.hashpw(pin.encode(), bcrypt.gensalt()).decode()


def verify_pin(db: Session, pin: str) -> bool:
    row = db.get(AppSetting, PIN_KEY)
    if row is None or not row.value:
        return True
    try:
        return bcrypt.checkpw(pin.encode(), row.value.encode())
    except ValueError:
        return False


def set_pin(db: Session, new_pin: str) -> None:
    row = db.get(AppSetting, PIN_KEY)
    hashed = hash_pin(new_pin)
    if row is None:
        db.add(AppSetting(key=PIN_KEY, value=hashed))
    else:
        row.value = hashed
    db.commit()


def get_setting(db: Session, key: str, default: str = "") -> str:
    row = db.get(AppSetting, key)
    return row.value if row is not None and row.value is not None else default


def set_setting(db: Session, key: str, value: str) -> None:
    row = db.get(AppSetting, key)
    if row is None:
        db.add(AppSetting(key=key, value=value))
    else:
        row.value = value
    db.commit()


def is_pin_set(db: Session) -> bool:
    row = db.get(AppSetting, PIN_KEY)
    return row is not None and bool(row.value)


def get_store_name(db: Session) -> str:
    name = get_setting(db, STORE_NAME_KEY, "KiosKu")
    return name or "KiosKu"
