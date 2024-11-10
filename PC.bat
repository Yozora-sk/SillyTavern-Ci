@echo off
chcp 65001

echo By Night

echo ====================================================
echo 一键部署 SillyTavern
echo ====================================================
echo 请确保网络畅通，且系统架构为X64
echo ====================================================
echo 对于大陆地区用户，请务必使用加速器，开启TUN或虚拟网卡模式，否则可能无法正常工作
echo ====================================================
pause

:CheckNode
echo Checking for Node.js...
where node >nul 2>&1
if errorlevel 1 (
  echo Downloading and installing Node.js...
  powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi' -OutFile 'node-v20.18.0-x64.msi' -ErrorAction Stop" || (echo Node.js download failed! & exit /b 1)
  msiexec /i node-v20.18.0-x64.msi /passive /norestart || (echo Node.js installation failed! & exit /b 1)
  del node-v20.18.0-x64.msi
) else (
  echo Node.js already installed. Skipping...
)

:CheckGit
echo Checking for Git...
where git >nul 2>&1
if errorlevel 1 (
  echo Downloading and installing Git...
  powershell -Command "Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.1/Git-2.42.0-64-bit.exe' -OutFile 'Git-2.42.0-64-bit.exe' -ErrorAction Stop" || (echo Git download failed! & exit /b 1)
  Git-2.42.0-64-bit.exe /VERYSILENT /NORESTART /NOCANCEL /CLOSEAPPLICATIONS || (echo Git installation failed! & exit /b 1)
  del Git-2.42.0-64-bit.exe
) else (
  echo Git already installed. Skipping...
)

set /p STavernPath="请输入 SillyTavern 的安装目录 (例如: D:\SillyTavern，留空则默认为 C:\SillyTavern): "
if "%STavernPath%"=="" (
  set "STavernPath=C:\SillyTavern"
)

echo SillyTavern 将安装到: %STavernPath%

if not exist "%STavernPath%" mkdir "%STavernPath%"

pushd "%STavernPath%"

if exist ".git" (
  echo 更新 SillyTavern 仓库...
  git pull || (echo Git pull failed! Check your network connection and repository. & exit /b 1)
) else (
  echo 克隆 SillyTavern 仓库...
  git clone https://github.com/SillyTavern/SillyTavern.git . || (echo Git clone failed! Check your network connection and repository. & exit /b 1)
)

echo Installing dependencies...
call npm install --no-audit --no-fund --loglevel=error --omit=dev --progress=false || (echo npm install failed! Check your network connection and npm configuration. & exit /b 1)

echo Starting SillyTavern...
set NODE_ENV=production
node server.js %*

popd
