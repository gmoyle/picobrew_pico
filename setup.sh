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

# Function to install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    if command_exists pip3; then
        PIP_CMD="pip3"
    elif command_exists pip; then
        PIP_CMD="pip"
    else
        print_error "Neither pip3 nor pip found. Please install Python and pip first."
        exit 1
    fi
    
    # Upgrade pip if needed
    print_status "Upgrading pip..."
    $PIP_CMD install --upgrade pip
    
    # Install requirements
    print_status "Installing requirements from requirements.txt..."
    $PIP_CMD install -r requirements.txt
    
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

# Function to start server
start_server() {
    local port=$1
    local host=$2
    
    print_status "Starting PicoBrew server on $host:$port..."
    
    # Check if we need sudo for the port
    if [[ $port -eq 80 ]] && [[ "$EUID" -ne 0 ]]; then
        print_warning "Port 80 requires root privileges. Using port $port instead."
        port=$(find_available_port 8080)
    fi
    
    print_status "Server will be available at: http://$host:$port"
    print_status "Press Ctrl+C to stop the server"
    
    # Start the server
    if python3 server.py "$host" "$port"; then
        print_success "Server started successfully!"
    else
        print_error "Failed to start server"
        exit 1
    fi
}

# Function to run tests
run_tests() {
    print_status "Running tests to verify our fixes..."
    
    # Check if pytest is available
    if command_exists pytest; then
        print_status "Running unit tests..."
        if python3 -m pytest tests/unit/test_thread_safety.py -v; then
            print_success "Unit tests passed!"
        else
            print_warning "Some unit tests failed. This might indicate an issue."
        fi
    else
        print_warning "pytest not found. Skipping unit tests."
    fi
    
    # Run our manual test script if server is running
    if [[ -f "scripts/test_race_conditions.py" ]]; then
        print_status "Testing race condition fixes..."
        print_status "Note: This requires the server to be running in another terminal"
        print_status "You can run this manually after starting the server:"
        echo "    python3 scripts/test_race_conditions.py http://localhost:$PORT"
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
    echo ""
    echo "Examples:"
    echo "  $0                    # Auto-setup and start server"
    echo "  $0 -p 8080           # Start on port 8080"
    echo "  $0 -s                # Setup only, don't start server"
    echo "  $0 -t                # Setup, start server, and run tests"
}

# Main script
main() {
    # Parse command line arguments
    PORT=""
    HOST="0.0.0.0"
    RUN_TESTS=false
    SETUP_ONLY=false
    VERBOSE=false
    
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
    
    # Start the server
    start_server "$PORT" "$HOST"
}

# Run main function with all arguments
main "$@"
