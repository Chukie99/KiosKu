import shutil
import threading
import time
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import BACKUP_DIR, DB_PATH, get_db
from ..models import AppSetting
from ..schemas import BackupInfo

router = APIRouter()

BACKUP_LOCK = threading.Lock()


def run_backup() -> Path | None:
    if not DB_PATH.exists():
        return None
    with BACKUP_LOCK:
        name = f"kiosku_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        dest = BACKUP_DIR / name
        shutil.copy2(DB_PATH, dest)
        keep = 30
        backups = sorted(BACKUP_DIR.glob("kiosku_backup_*.db"), key=lambda p: p.name, reverse=True)
        for old in backups[keep:]:
            old.unlink(missing_ok=True)
        return dest


def backup_worker() -> None:
    while True:
        try:
            run_backup()
        except Exception:
            pass
        time.sleep(24 * 3600)


@router.post("/backup/trigger")
def trigger_backup(db: Session = Depends(get_db)):
    dest = run_backup()
    if dest is None:
        raise HTTPException(status_code=500, detail="Database belum ada")
    return {"ok": True, "filename": dest.name, "size": dest.stat().st_size}


@router.get("/backup/list", response_model=list[BackupInfo])
def list_backups():
    items = []
    for p in sorted(BACKUP_DIR.glob("kiosku_backup_*.db"), reverse=True):
        ts = datetime.fromtimestamp(p.stat().st_mtime).isoformat()
        items.append(BackupInfo(filename=p.name, size=p.stat().st_size, created_at=ts))
    return items


@router.post("/backup/restore")
def restore_backup(filename: str, db: Session = Depends(get_db)):
    src = BACKUP_DIR / Path(filename).name
    if not src.exists():
        raise HTTPException(status_code=404, detail="File backup tidak ditemukan")
    with BACKUP_LOCK:
        backup_current = BACKUP_DIR / f"kiosku_pre_restore_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        shutil.copy2(DB_PATH, backup_current)
        shutil.copy2(src, DB_PATH)
    return {"ok": True, "note": "Server perlu di-restart agar data baru termuat"}
