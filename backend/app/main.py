import threading
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from .database import Base, engine, get_db
from .routers import auth as auth_router
from .routers import backup as backup_router
from .routers import products as products_router
from .routers import reports as reports_router
from .routers import stock as stock_router
from .routers import sync as sync_router
from .routers import transactions as transactions_router
from .seed import seed_all

WEB_DIST = Path(__file__).resolve().parent.parent.parent / "web_dashboard" / "dist"

BACKUP_THREAD_STARTED = False


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    db = next(get_db())
    try:
        with db.begin():
            db.execute(text("PRAGMA journal_mode=WAL"))
        if seed_all(db):
            print("[KiosKu] Seed data pertama berhasil dibuat (produk, transaksi 30 hari, utang, PIN default: 1234)")
        else:
            print("[KiosKu] Database sudah berisi data, seed dilewati")
    finally:
        db.close()

    global BACKUP_THREAD_STARTED
    if not BACKUP_THREAD_STARTED:
        worker = threading.Thread(target=backup_router.backup_worker, daemon=True)
        worker.start()
        BACKUP_THREAD_STARTED = True
        print("[KiosKu] Backup otomatis aktif (setiap 24 jam, retensi 30 file)")

    yield


app = FastAPI(title="KiosKu API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router, prefix="/auth", tags=["auth"])
app.include_router(auth_router.router, tags=["settings"])
app.include_router(products_router.router, tags=["products"])
app.include_router(transactions_router.router, tags=["transactions"])
app.include_router(reports_router.router, tags=["reports"])
app.include_router(stock_router.router, tags=["stock"])
app.include_router(sync_router.router, tags=["sync"])
app.include_router(backup_router.router, tags=["backup"])


@app.get("/health")
def health():
    return {"status": "ok", "app": "KiosKu", "time": __import__("datetime").datetime.now().isoformat()}


@app.get("/api")
def api_info():
    return {"app": "KiosKu", "docs": "/docs"}


if WEB_DIST.exists():
    app.mount("/dashboard", StaticFiles(directory=str(WEB_DIST), html=True), name="dashboard")

    @app.get("/")
    def root():
        return JSONResponse(
            {
                "app": "KiosKu",
                "message": "Backend berjalan. Buka dashboard di /dashboard dan dokumentasi API di /docs",
                "dashboard": "/dashboard",
                "docs": "/docs",
            }
        )
else:
    print("[KiosKu] web_dashboard/dist belum ada - dashboard web belum disajikan (jalankan npm run build di web_dashboard)")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
