import shutil
import threading
import time
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import BACKUP_DIR, DB_PATH, get_db
from ..dependencies import require_auth
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
            from ..database import SessionLocal
            from ..models import AppSetting

            db = SessionLocal()
            try:
                hour_str = "00:00"
                row = db.get(AppSetting, "backup_hour")
                if row and row.value:
                    hour_str = row.value
            finally:
                db.close()

            parts = hour_str.split(":")
            target_hour = int(parts[0])
            target_minute = int(parts[1]) if len(parts) > 1 else 0
            target_seconds = target_hour * 3600 + target_minute * 60

            now = datetime.now()
            current_seconds = now.hour * 3600 + now.minute * 60 + now.second
            diff = target_seconds - current_seconds
            if diff <= 0:
                diff += 24 * 3600

            time.sleep(diff)

            try:
                run_backup()
                print(f"[KiosKu] Backup otomatis berhasil ({now.strftime('%Y-%m-%d %H:%M')})")
            except Exception as e:
                print(f"[KiosKu] Backup otomatis gagal: {e}")

        except Exception as e:
            print(f"[KiosKu] Backup worker error: {e}")
            time.sleep(3600)


@router.post("/backup/trigger")
def trigger_backup(
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    dest = run_backup()
    if dest is None:
        raise HTTPException(status_code=500, detail="Database belum ada")
    return {"ok": True, "filename": dest.name, "size": dest.stat().st_size}


@router.get("/backup/list", response_model=list[BackupInfo])
def list_backups(
    _token: str = Depends(require_auth),
):
    items = []
    for p in sorted(BACKUP_DIR.glob("kiosku_backup_*.db"), reverse=True):
        ts = datetime.fromtimestamp(p.stat().st_mtime).isoformat()
        items.append(BackupInfo(filename=p.name, size=p.stat().st_size, created_at=ts))
    return items


@router.post("/backup/restore")
def restore_backup(
    filename: str,
    db: Session = Depends(get_db),
    _token: str = Depends(require_auth),
):
    src = BACKUP_DIR / Path(filename).name
    if not src.exists():
        raise HTTPException(status_code=404, detail="File backup tidak ditemukan")
    with BACKUP_LOCK:
        backup_current = BACKUP_DIR / f"kiosku_pre_restore_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        shutil.copy2(DB_PATH, backup_current)
        shutil.copy2(src, DB_PATH)
    return {"ok": True, "note": "Server perlu di-restart agar data baru termuat"}
