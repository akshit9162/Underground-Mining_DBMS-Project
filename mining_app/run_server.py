#!/usr/bin/env python
"""Test runner for Mining Management System"""
import os
import sys
import subprocess

# Set working directory
os_path = os.path.dirname(os.path.abspath(__file__))
os.chdir(os_path)

# Add current directory to path
sys.path.insert(0, os_path)

print("=" * 60)
print("  Mining Management System - Starting Server")
print("=" * 60)
print()
print("Working directory:", os.getcwd())
print("Python executable:", sys.executable)
print("Python version:", sys.version)
print()

# Try to import required modules
print("[1/3] Checking dependencies...")
try:
    import flask
    print("  ✓ Flask:", flask.__version__)
except ImportError as e:
    print("  ✗ Flask import failed:", e)
    sys.exit(1)

try:
    import flask_sqlalchemy
    print("  ✓ Flask-SQLAlchemy imported")
except ImportError as e:
    print("  ✗ Flask-SQLAlchemy import failed:", e)
    sys.exit(1)

try:
    import sqlalchemy
    print("  ✓ SQLAlchemy:", sqlalchemy.__version__)
except ImportError as e:
    print("  ✗ SQLAlchemy import failed:", e)
    sys.exit(1)

print()
print("[2/3] Initializing Flask app...")

try:
    from app import app, db
    print("  ✓ App imported successfully")
except Exception as e:
    print("  ✗ Failed to import app:", e)
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
print("[3/3] Starting Flask server...")
print()
print("=" * 60)
print("  The application is ready at http://localhost:5000")
print("=" * 60)
print()
print("Press Ctrl+C to stop the server")
print()

# Run the app
try:
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=True)
except KeyboardInterrupt:
    print("\n\nServer stopped.")
    sys.exit(0)
except Exception as e:
    print("\nError:", e)
    import traceback
    traceback.print_exc()
    sys.exit(1)
