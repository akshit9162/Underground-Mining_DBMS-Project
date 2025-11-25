@echo off
REM ============================================================================
REM Mining Management System - Setup and Run Script (Windows)
REM ============================================================================

echo.
echo ========================================
echo  Mining Management System Setup
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ from https://www.python.org/
    pause
    exit /b 1
)

echo [1/4] Python found. Creating virtual environment...
if exist venv (
    echo Virtual environment already exists. Skipping creation.
) else (
    python -m venv venv
    echo Virtual environment created successfully.
)

echo.
echo [2/4] Activating virtual environment...
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)

echo Virtual environment activated.
echo.
echo [3/4] Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo Dependencies installed successfully.
echo.
echo ========================================
echo  Setup Complete!
echo ========================================
echo.
echo [4/4] Starting Flask application...
echo.
echo The application will be available at:
echo   http://localhost:5000
echo.
echo Once loaded:
echo   1. Click "Initialize Database with Sample Data"
echo   2. Explore the dashboards and features
echo   3. Press Ctrl+C in terminal to stop the server
echo.
python app.py

pause
