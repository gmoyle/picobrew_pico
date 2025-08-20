#!/bin/bash

# PicoBrew Server Setup Script
# This script automatically sets up and runs the PicoBrew server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    echo $OS
}

# Function to create and activate virtual environment
create_and_use_venv() {
    print_status "Ensuring Python virtual environment (.venv) exists..."
    if [[ ! -d ".venv" ]]; then
        python3 -m venv .venv
        print_success "Created virtual environment at .venv"
    fi
    # shellcheck disable=SC1091
    source .venv/bin/activate
    print_success "Activated virtual environment"
}

# Function to install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies into venv..."

    create_and_use_venv

    # Upgrade pip
    print_status "Upgrading pip..."
    python -m pip install --upgrade pip

    # Install requirements and pytest
    print_status "Installing requirements from requirements.txt and pytest..."
    python -m pip install -r requirements.txt pytest

    print_success "Python dependencies installed successfully!"
}

# Function to setup configuration
setup_config() {
    print_status "Setting up configuration..."
    
    if [[ ! -f "config.yaml" ]]; then
        if [[ -f "config.example.yaml" ]]; then
            cp config.example.yaml config.yaml
            print_success "Created config.yaml from config.example.yaml"
        else
            print_warning "No config.example.yaml found. You may need to create config.yaml manually."
        fi
    else
        print_status "config.yaml already exists"
    fi
    
    # Create required directories
    print_status "Creating required directories..."
    mkdir -p app/recipes/pico/archive
    mkdir -p app/recipes/zseries/archive
    mkdir -p app/recipes/zymatic/archive
    mkdir -p app/sessions/brew/active
    mkdir -p app/sessions/brew/archive
    mkdir -p app/sessions/ferm/active
    mkdir -p app/sessions/ferm/archive
    mkdir -p app/sessions/iSpindel/active
    mkdir -p app/sessions/iSpindel/archive
    mkdir -p app/sessions/still/active
    mkdir -p app/sessions/still/archive
    mkdir -p app/sessions/tilt/active
    mkdir -p app/sessions/tilt/archive
    
    print_success "Directories created successfully!"
}

# Function to check if port is available
check_port() {
    local port=$1
    if command_exists lsof; then
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            return 0  # Port is in use
        else
            return 1  # Port is free
        fi
    elif command_exists netstat; then
        if netstat -tuln | grep ":$port " >/dev/null 2>&1; then
            return 0  # Port is in use
        else
            return 1  # Port is free
        fi
    else
        # Fallback: try to bind to the port
        if python3 -c "import socket; s=socket.socket(); s.bind(('', $port)); s.close()" 2>/dev/null; then
            return 1  # Port is free
        else
            return 0  # Port is in use
        fi
    fi
}

# Function to find available port
find_available_port() {
    local start_port=$1
    local port=$start_port
    
    while check_port $port; do
        port=$((port + 1))
        if [[ $port -gt $((start_port + 100)) ]]; then
            print_error "Could not find an available port between $start_port and $((start_port + 100))"
            exit 1
        fi
    done
    
    echo $port
}

# Function to start server (foreground)
start_server() {
    local port=$1
    local host=$2

    create_and_use_venv

    print_status "Starting PicoBrew server on $host:$port..."

    # Check if we need sudo for the port
    if [[ $port -eq 80 ]] && [[ "$EUID" -ne 0 ]]; then
        print_warning "Port 80 requires root privileges. Using port $port instead."
        port=$(find_available_port 8080)
    fi

    print_status "Server will be available at: http://$host:$port"
    print_status "Press Ctrl+C to stop the server"

    # Start the server
    if python server.py "$host" "$port"; then
        print_success "Server started successfully!"
    else
        print_error "Failed to start server"
        exit 1
    fi
}

# Start server in background, wait for health, then open browser
start_server_bg_and_verify() {
    local port=$1
    local host=$2

    create_and_use_venv

    print_status "Starting PicoBrew server in background on $host:$port..."

    # Check if we need sudo for the port
    if [[ $port -eq 80 ]] && [[ "$EUID" -ne 0 ]]; then
        print_warning "Port 80 requires root privileges. Using port $port instead."
        port=$(find_available_port 8080)
    fi

    # Start background
    nohup python server.py "$host" "$port" > server.out 2>&1 & echo $! > server.pid
    sleep 1

    # Wait for health endpoint
    local health_url="http://$host:$port/health"
    print_status "Waiting for server health at $health_url ..."
    for i in {1..30}; do
        if curl -sSf "$health_url" >/dev/null 2>&1; then
            print_success "Server is healthy!"
            break
        fi
        sleep 1
    done

    # Open browser
    open_browser "$host" "$port"
}

# Function to run tests
run_tests() {
    print_status "Running tests to verify installation..."

    create_and_use_venv

    if python -m pytest tests/unit -q; then
        print_success "Unit tests passed!"
    else
        print_warning "Some unit tests failed. This might indicate an issue."
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -p, --port PORT     Specify port to run on (default: auto-detect)"
    echo "  -H, --host HOST     Specify host to bind to (default: 0.0.0.0)"
    echo "  -t, --test          Run tests after setup"
    echo "  -s, --setup-only    Only setup dependencies, don't start server"
    echo "  -v, --verbose       Verbose output"
    echo "  --import-community  Prompt to import PicoBrew community recipes (HTML snapshots)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Auto-setup and start server"
    echo "  $0 -p 8080           # Start on port 8080"
    echo "  $0 -s                # Setup only, don't start server"
    echo "  $0 -t                # Setup, start server, and run tests"
}

# Open default browser to the server URL
open_browser() {
    local host=$1
    local port=$2
    local browse_host=$host
    # Prefer localhost for 0.0.0.0 to avoid blank pages in some browsers
    if [[ "$host" == "0.0.0.0" ]]; then
        browse_host="localhost"
    fi
    local url="http://$browse_host:$port"

    OS=$(detect_os)
    print_status "Attempting to open web browser to $url ..."
    case "$OS" in
        macos)
            command_exists open && open "$url" || print_warning "Could not open browser automatically."
            ;;
        linux)
            command_exists xdg-open && xdg-open "$url" || print_warning "Could not open browser automatically."
            ;;
        windows)
            command_exists start && start "$url" || print_warning "Could not open browser automatically."
            ;;
        *)
            print_warning "Unknown OS; please open $url manually."
            ;;
    esac
}

# Main script
main() {
    # Parse command line arguments
    PORT=""
    HOST="0.0.0.0"
    RUN_TESTS=false
    SETUP_ONLY=false
    VERBOSE=false
    IMPORT_COMMUNITY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            -t|--test)
                RUN_TESTS=true
                shift
                ;;
            -s|--setup-only)
                SETUP_ONLY=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --import-community)
                IMPORT_COMMUNITY=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    print_status "PicoBrew Server Setup Script"
    print_status "============================="
    
    # Detect OS
    OS=$(detect_os)
    print_status "Detected OS: $OS"
    
    # Check Python
    print_status "Checking Python installation..."
    if ! command_exists python3; then
        print_error "Python 3 is required but not installed."
        print_status "Please install Python 3.6+ and try again."
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_success "Python $PYTHON_VERSION found"
    
    # Check if we're in the right directory
    if [[ ! -f "server.py" ]] || [[ ! -f "requirements.txt" ]]; then
        print_error "This script must be run from the PicoBrew server directory"
        print_error "Make sure you're in the directory containing server.py"
        exit 1
    fi
    
    # Install dependencies
    install_python_deps
    
    # Setup configuration
    setup_config
    
    # Find available port if not specified
    if [[ -z "$PORT" ]]; then
        if [[ "$EUID" -eq 0 ]]; then
            PORT=$(find_available_port 80)
        else
            PORT=$(find_available_port 8080)
        fi
        print_status "Auto-selected port: $PORT"
    fi
    
    # Check if port is available
    if check_port "$PORT"; then
        print_warning "Port $PORT is already in use"
        if [[ "$PORT" -eq 80 ]]; then
            print_status "Trying alternative port..."
            PORT=$(find_available_port 8080)
        else
            PORT=$(find_available_port $((PORT + 1)))
        fi
        print_status "Using port: $PORT"
    fi
    
    if [[ "$SETUP_ONLY" == "true" ]]; then
        print_success "Setup completed successfully!"
        print_status "To start the server, run: python3 server.py $HOST $PORT"
        exit 0
    fi
    
    # Run tests if requested
    if [[ "$RUN_TESTS" == "true" ]]; then
        run_tests
    fi

    # Start the server in background, verify health, run smoke, and open browser
    start_server_bg_and_verify "$PORT" "$HOST"

    # Offer to import bundled snapshot recipes if present
    if [[ -d "recipes_snapshot/zseries" ]]; then
        echo -n "Import bundled Z-series recipes snapshot into server library? [y/N]: "
        read -r reply
        if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
            mkdir -p app/recipes/zseries
            cp -n recipes_snapshot/zseries/*.json app/recipes/zseries/ || true
            print_success "Imported Z-series snapshot recipes."
        else
            print_status "Skipping bundled Z-series import."
        fi
    fi

    # Offer to import user's Z-series recipes from PicoBrew (if site reachable)
    if command_exists curl; then
        if curl -sS -k --max-time 5 https://137.117.17.70/ >/dev/null 2>&1; then
            echo -n "Import YOUR Z-series recipes from PicoBrew now? (requires Product ID token) [y/N]: "
            read -r reply
            if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
                echo -n "Enter your Z-series Product ID token: "
                read -r Z_TOKEN
                if [[ -n "$Z_TOKEN" ]]; then
                    create_and_use_venv
                    if python scripts/fetch_zseries_all.py --token "$Z_TOKEN"; then
                        print_success "Imported your Z-series recipes into app/recipes/zseries/"
                    else
                        print_warning "Failed to import Z-series recipes. You can retry later via: python scripts/fetch_zseries_all.py --token YOUR_TOKEN"
                    fi
                else
                    print_warning "No token provided, skipping user recipe import."
                fi
            else
                print_status "Skipping user Z-series recipe import."
            fi
        else
            print_status "PicoBrew vendor site not reachable, skipping user Z-series import."
        fi

        # Offer to import user's Zymatic recipes (requires GUID and Product ID)
        if curl -sS -k --max-time 5 http://137.117.17.70/ [0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m [0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m [0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m[0m; then
            echo -n "Import YOUR Zymatic recipes? (requires GUID and Product ID) [y/N]: "
            read -r reply
            if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
                echo -n "Enter your Zymatic GUID: "
                read -r ZY_GUID
                echo -n "Enter your Zymatic Product ID: "
                read -r ZY_PID
                if [[ -n "$ZY_GUID" ]] && [[ -n "$ZY_PID" ]]; then
                    create_and_use_venv
                    if python scripts/import_zymatic_user.py --guid "$ZY_GUID" --product-id "$ZY_PID"; then
                        print_success "Imported your Zymatic recipes into app/recipes/zymatic/"
                    else
                        print_warning "Failed to import Zymatic recipes. You can retry later via: python scripts/import_zymatic_user.py --guid GUID --product-id PID"
                    fi
                else
                    print_warning "GUID or Product ID missing, skipping Zymatic import."
                fi
            else
                print_status "Skipping user Zymatic recipe import."
            fi
        fi

        # Offer to import a Pico recipe by RFID (requires UID and RFID)
        echo -n "Import a Pico (Pico S/C/Pro) recipe by RFID now? [y/N]: "
        read -r reply
        if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
            echo -n "Enter your Pico device UID (32 chars): "
            read -r PICO_UID
            echo -n "Enter PicoPak RFID (14 chars): "
            read -r PICO_RFID
            if [[ -n "$PICO_UID" ]] && [[ -n "$PICO_RFID" ]]; then
                create_and_use_venv
                if python scripts/import_pico_by_rfid.py --uid "$PICO_UID" --rfid "$PICO_RFID"; then
                    print_success "Imported Pico recipe into app/recipes/pico/"
                else
                    print_warning "Failed to import Pico recipe."
                fi
            else
                print_warning "UID or RFID missing, skipping Pico import."
            fi
        else
            print_status "Skipping Pico recipe import."
        fi
    fi

    # Prompt to import PicoBrew community recipes (HTML snapshots)
    if [[ "$IMPORT_COMMUNITY" == "true" ]]; then
        echo -n "Do you want to fetch the PicoBrew community recipe library locally? [y/N]: "
        read -r reply
        if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
            print_status "Fetching PicoBrew public recipes (this may take a while)..."
            create_and_use_venv
            if python scripts/fetch_public_recipes.py; then
                print_success "Community recipes snapshot saved to app/recipes/public_html"
            else
                print_warning "Failed to fetch community recipes. You can retry later via: python scripts/fetch_public_recipes.py"
            fi
        else
            print_status "Skipping community recipe import."
        fi
    fi

    # Optional smoke test if script exists
    if [[ -f "scripts/smoke.sh" ]]; then
        print_status "Running smoke test script..."
        if bash scripts/smoke.sh "http://$HOST:$PORT" "12345678901234567890123456789012"; then
            print_success "Smoke tests passed!"
        else
            print_warning "Smoke tests encountered issues. Check server.out for details."
        fi
    fi

    print_success "Setup complete. Server running at http://$HOST:$PORT"
}

# Run main function with all arguments
main "$@"
