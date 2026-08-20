# -*- mode: python ; coding: utf-8 -*-
"""
KiosKu PyInstaller Spec File
Build: pyinstaller kiosku.spec
"""

import os
import sys
from pathlib import Path

block_cipher = None

# Paths
SPEC_DIR = os.path.dirname(os.path.abspath(SPECPATH))
WEB_DIST = os.path.join(SPEC_DIR, 'web_dashboard', 'dist')

a = Analysis(
    ['run.py'],
    pathex=[SPEC_DIR],
    binaries=[],
    datas=[
        (WEB_DIST, 'web_dashboard/dist'),
        ('backend', 'backend'),
    ],
    hiddenimports=[
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'sqlalchemy',
        'sqlalchemy.dialects.sqlite',
        'fastapi',
        'pydantic',
        'bcrypt',
        'openpyxl',
        'reportlab',
        'multipart',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'pandas',
        'scipy',
        'PIL',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='KiosKu',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    icon=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='KiosKu',
)
