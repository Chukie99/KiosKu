"""
KiosKu - Single Exe Entry Point
Jalankan file ini untuk memulai KiosKu tanpa perlu install Python.
"""
import os
import sys
import webbrowser
import threading
import time
from pathlib import Path


def get_base_path():
    """Get base path for PyInstaller or normal execution."""
    if getattr(sys, 'frozen', False):
        return Path(sys._MEIPASS)
    return Path(__file__).parent


def get_data_path():
    """Get data path for storing database and backups."""
    if getattr(sys, 'frozen', False):
        return Path(os.path.dirname(sys.executable)) / "data"
    return Path(__file__).parent / "backend" / "data"


def main():
    import uvicorn
    from backend.app.main import app
    from backend.app import database

    base_path = get_base_path()
    data_path = get_data_path()
    data_path.mkdir(parents=True, exist_ok=True)

    # Update database path to be next to exe
    database.DATA_DIR = data_path
    database.DB_PATH = data_path / "kiosku.db"
    database.BACKUP_DIR = data_path / "backups"
    database.BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    # Re-create engine with new path
    from sqlalchemy import create_engine
    from sqlalchemy.pool import NullPool
    database.engine = create_engine(
        f"sqlite:///{database.DB_PATH}",
        connect_args={"check_same_thread": False},
        poolclass=NullPool,
    )
    database.SessionLocal.configure(bind=database.engine)

    host = "127.0.0.1"
    port = 8000
    url = f"http://{host}:{port}"

    print("=" * 50)
    print("  KiosKu - Kasir Warung")
    print("=" * 50)
    print(f"  Server:  {url}")
    print(f"  Dashboard: {url}/dashboard")
    print(f"  API Docs:  {url}/docs")
    print(f"  Data:    {data_path}")
    print("=" * 50)
    print("  Tekan Ctrl+C untuk berhenti")
    print("=" * 50)

    # Open browser after 1.5 seconds
    def open_browser():
        time.sleep(1.5)
        webbrowser.open(f"{url}/dashboard")

    threading.Thread(target=open_browser, daemon=True).start()

    # Run server
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info",
    )


if __name__ == "__main__":
    main()
