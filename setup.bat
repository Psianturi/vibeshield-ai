@echo off
echo ========================================
echo   VibeGuard AI - Environment Setup
echo ========================================
echo.

echo [1/3] Setting up Backend...
cd backend
if not exist .env (
    copy .env.example .env
    echo ✓ Created .env file
    echo ⚠️  IMPORTANT: Edit backend\.env and add your API keys!
    echo.
) else (
    echo ✓ .env already exists
    echo.
)

echo [2/3] Installing Backend Dependencies...
call npm install
if %errorlevel% neq 0 (
    echo ❌ Backend installation failed!
    pause
    exit /b 1
)
echo ✓ Backend dependencies installed
echo.

cd ..

echo [3/3] Installing Frontend Dependencies...
cd frontend\vibeguard_app
call flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Frontend installation failed!
    pause
    exit /b 1
)
echo ✓ Frontend dependencies installed
echo.

cd ..\..

echo ========================================
echo   Setup Complete! 🎉
echo ========================================
echo.
echo Next Steps:
echo 1. Edit backend\.env with your API keys
echo 2. Run backend: cd backend ^&^& npm run dev
echo 3. Run frontend: cd frontend\vibeguard_app ^&^& flutter run -d chrome
echo.
echo For detailed instructions, see QUICKSTART.md
echo.
pause
