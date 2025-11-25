#!/bin/bash
# ============================================================================
# Mining Management System - Setup and Run Script (macOS/Linux)
# ============================================================================

echo ""
echo "========================================"
echo "  Mining Management System Setup"
echo "========================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    echo "Please install Python 3.7+ from https://www.python.org/"
    exit 1
fi

python3 --version

echo "[1/4] Python found. Creating virtual environment..."
if [ -d venv ]; then
    echo "Virtual environment already exists. Skipping creation."
else
    python3 -m venv venv
    echo "Virtual environment created successfully."
fi

echo ""
echo "[2/4] Activating virtual environment..."
source venv/bin/activate

echo "Virtual environment activated."
echo ""
echo "[3/4] Installing dependencies..."
pip install -r requirements.txt

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install dependencies"
    exit 1
fi

echo "Dependencies installed successfully."
echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "[4/4] Starting Flask application..."
echo ""
echo "The application will be available at:"
echo "  http://localhost:5000"
echo ""
echo "Once loaded:"
echo "  1. Click 'Initialize Database with Sample Data'"
echo "  2. Explore the dashboards and features"
echo "  3. Press Ctrl+C in terminal to stop the server"
echo ""

python app.py
