@echo off
REM PicoBrew Server Setup Script for Windows
REM This script automatically sets up and runs the PicoBrew server

setlocal enabledelayedexpansion

REM Colors for output (Windows 10+ supports ANSI colors)
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM Function to print colored output
:print_status
echo %BLUE%[INFO]%NC% %~1
goto :eof

:print_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:print_warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:print_error
echo %RED%[ERROR]%NC% %~1
goto :eof

REM Function to check if command exists
:command_exists
where %1 >nul 2>&1
if %errorlevel% equ 0 (
    set "exists=true"
) else (
    set "exists=false"
)
goto :eof

REM Function to check if port is available
:check_port
netstat -an | find ":%1 " >nul 2>&1
if %errorlevel% equ 0 (
    set "port_in_use=true"
) else (
    set "port_in_use=false"
)
goto :eof

REM Function to find available port
:find_available_port
set "start_port=%~1"
set "port=!start_port!"

:port_loop
call :check_port !port!
if "!port_in_use!"=="true" (
    set /a port+=1
    if !port! gtr !start_port!100 (
        call :print_error "Could not find an available port between !start_port! and !start_port!100"
        exit /b 1
    )
    goto :port_loop
)
goto :eof

REM Function to install Python dependencies
:install_python_deps
call :print_status "Installing Python dependencies..."

REM Check for pip
call :command_exists pip
if "!exists!"=="false" (
    call :command_exists pip3
    if "!exists!"=="false" (
        call :print_error "Neither pip nor pip3 found. Please install Python and pip first."
        exit /b 1
    ) else (
        set "PIP_CMD=pip3"
    )
) else (
    set "PIP_CMD=pip"
)

REM Upgrade pip if needed
call :print_status "Upgrading pip..."
!PIP_CMD! install --upgrade pip

REM Install requirements
call :print_status "Installing requirements from requirements.txt..."
!PIP_CMD! install -r requirements.txt

call :print_success "Python dependencies installed successfully!"
goto :eof

REM Function to setup configuration
:setup_config
call :print_status "Setting up configuration..."

if not exist "config.yaml" (
    if exist "config.example.yaml" (
        copy "config.example.yaml" "config.yaml" >nul
        call :print_success "Created config.yaml from config.example.yaml"
    ) else (
        call :print_warning "No config.example.yaml found. You may need to create config.yaml manually."
    )
) else (
    call :print_status "config.yaml already exists"
)

REM Create required directories
call :print_status "Creating required directories..."
if not exist "app\recipes\pico\archive" mkdir "app\recipes\pico\archive"
if not exist "app\recipes\zseries\archive" mkdir "app\recipes\zseries\archive"
if not exist "app\recipes\zymatic\archive" mkdir "app\recipes\zymatic\archive"
if not exist "app\sessions\brew\active" mkdir "app\sessions\brew\active"
if not exist "app\sessions\brew\archive" mkdir "app\sessions\brew\archive"
if not exist "app\sessions\ferm\active" mkdir "app\sessions\ferm\active"
if not exist "app\sessions\ferm\archive" mkdir "app\sessions\ferm\archive"
if not exist "app\sessions\iSpindel\active" mkdir "app\sessions\iSpindel\active"
if not exist "app\sessions\iSpindel\archive" mkdir "app\sessions\iSpindel\archive"
if not exist "app\sessions\still\active" mkdir "app\sessions\still\active"
if not exist "app\sessions\still\archive" mkdir "app\sessions\still\archive"
if not exist "app\sessions\tilt\active" mkdir "app\sessions\tilt\active"
if not exist "app\sessions\tilt\archive" mkdir "app\sessions\tilt\archive"

call :print_success "Directories created successfully!"
goto :eof

REM Function to start server
:start_server
set "port=%~1"
set "host=%~2"

call :print_status "Starting PicoBrew server on !host!:!port!..."
call :print_status "Server will be available at: http://!host!:!port!"
call :print_status "Press Ctrl+C to stop the server"

REM Start the server
python server.py "!host!" "!port!"
if %errorlevel% equ 0 (
    call :print_success "Server started successfully!"
) else (
    call :print_error "Failed to start server"
    exit /b 1
)
goto :eof

REM Function to show usage
:show_usage
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo   -h, --help          Show this help message
echo   -p, --port PORT     Specify port to run on (default: auto-detect)
echo   -H, --host HOST     Specify host to bind to (default: 0.0.0.0)
echo   -s, --setup-only    Only setup dependencies, don't start server
echo.
echo Examples:
echo   %~nx0                    # Auto-setup and start server
echo   %~nx0 -p 8080           # Start on port 8080
echo   %~nx0 -s                # Setup only, don't start server
goto :eof

REM Main script
:main
call :print_status "PicoBrew Server Setup Script"
call :print_status "============================="

REM Check Python
call :print_status "Checking Python installation..."
call :command_exists python
if "!exists!"=="false" (
    call :print_error "Python is required but not installed."
    call :print_status "Please install Python 3.6+ and try again."
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%i"
call :print_success "Python !PYTHON_VERSION! found"

REM Check if we're in the right directory
if not exist "server.py" (
    call :print_error "This script must be run from the PicoBrew server directory"
    call :print_error "Make sure you're in the directory containing server.py"
    exit /b 1
)

if not exist "requirements.txt" (
    call :print_error "requirements.txt not found"
    call :print_error "Make sure you're in the directory containing requirements.txt"
    exit /b 1
)

REM Parse command line arguments
set "PORT="
set "HOST=0.0.0.0"
set "SETUP_ONLY=false"

:parse_args
if "%~1"=="" goto :end_parse
if "%~1"=="-h" goto :show_usage
if "%~1"=="--help" goto :show_usage
if "%~1"=="-p" (
    set "PORT=%~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--port" (
    set "PORT=%~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="-H" (
    set "HOST=%~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--host" (
    set "HOST=%~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="-s" (
    set "SETUP_ONLY=true"
    shift
    goto :parse_args
)
if "%~1"=="--setup-only" (
    set "SETUP_ONLY=true"
    shift
    goto :parse_args
)
shift
goto :parse_args

:end_parse

REM Install dependencies
call :install_python_deps

REM Setup configuration
call :setup_config

REM Find available port if not specified
if "!PORT!"=="" (
    call :find_available_port 8080
    set "PORT=!port!"
    call :print_status "Auto-selected port: !PORT!"
)

REM Check if port is available
call :check_port !PORT!
if "!port_in_use!"=="true" (
    call :print_warning "Port !PORT! is already in use"
    call :find_available_port !PORT!
    set "PORT=!port!"
    call :print_status "Using port: !PORT!"
)

if "!SETUP_ONLY!"=="true" (
    call :print_success "Setup completed successfully!"
    call :print_status "To start the server, run: python server.py !HOST! !PORT!"
    exit /b 0
)

REM Start the server
call :start_server "!PORT!" "!HOST!"

exit /b 0
