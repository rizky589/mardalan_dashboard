#!/usr/bin/env python3
"""
Runner dashboard mardalan.
Jalankan dari folder web_dashboard atau dari root project.
"""

from pathlib import Path
import os
import sys


def run_dashboard():
    base_dir = Path(__file__).resolve().parent
    os.chdir(base_dir)

    if str(base_dir) not in sys.path:
        sys.path.insert(0, str(base_dir))

    from app import app

    print("mardalan Dashboard")
    print("Monitoring Aktivitas dan Rute Petugas Lapangan")
    print("URL: http://127.0.0.1:8081")
    print("=" * 50)

    app.run(host="127.0.0.1", port=8081, debug=False, use_reloader=False)


if __name__ == "__main__":
    run_dashboard()
