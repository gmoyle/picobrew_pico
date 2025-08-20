# PicoBrew Server - Easy Setup

Getting the PicoBrew server running is now much easier! We've created automated setup scripts that handle everything for you.

## Quick Start

### On macOS/Linux:
```bash
# Make the script executable (first time only)
chmod +x setup.sh

# Run the setup script
./setup.sh
```

### On Windows:
```cmd
# Run the setup script
setup.bat
```

That's it! The script will:
1. ✅ Check if Python is installed
2. ✅ Install all required dependencies
3. ✅ Create necessary directories
4. ✅ Set up configuration files
5. ✅ Find an available port automatically
6. ✅ Start the server

## What the Setup Scripts Do

### Automatic Dependency Management
- **Python Check**: Verifies Python 3.6+ is installed
- **Dependencies**: Installs all packages from `requirements.txt`
- **Pip Upgrade**: Updates pip to the latest version

### Configuration Setup
- **Config File**: Creates `config.yaml` from `config.example.yaml`
- **Directories**: Creates all required session and recipe directories
- **Permissions**: Ensures proper file structure

### Smart Port Management
- **Port Detection**: Automatically finds available ports
- **Root Handling**: Uses port 80 if available, falls back to 8080+ if not
- **Conflict Resolution**: Avoids port conflicts automatically

## Command Line Options

### Basic Usage
```bash
# Auto-setup and start server
./setup.sh

# Setup only (don't start server)
./setup.sh -s

# Specify a specific port
./setup.sh -p 8080

# Show help
./setup.sh -h
```

### Advanced Options
```bash
# Specify host and port
./setup.sh -H 127.0.0.1 -p 9000

# Setup only with verbose output
./setup.sh -s -v

# Run tests after setup
./setup.sh -t
```

## Troubleshooting

### Common Issues

**"Permission denied" on macOS/Linux:**
```bash
chmod +x setup.sh
```

**"Python not found":**
- Install Python 3.6+ from [python.org](https://python.org)
- Make sure `python3` is in your PATH

**"Port already in use":**
- The script automatically finds an available port
- Or specify a different port: `./setup.sh -p 8081`

**"pip not found":**
- The script checks for both `pip` and `pip3`
- Install pip: `python3 -m ensurepip --upgrade`

### Manual Setup (if scripts fail)

If the automated scripts don't work, you can still set up manually:

```bash
# 1. Install dependencies
pip3 install -r requirements.txt

# 2. Create config
cp config.example.yaml config.yaml

# 3. Create directories
mkdir -p app/{recipes,sessions}/{pico,zseries,zymatic,ferm,still,iSpindel,tilt}/{active,archive}

# 4. Start server
python3 server.py 0.0.0.0 8080
```

## What Happens After Setup

Once the server is running:

1. **Web Interface**: Open `http://localhost:PORT` in your browser
2. **Device Connection**: Your PicoBrew devices can now connect
3. **Real-time Monitoring**: Watch brewing sessions in real-time
4. **Recipe Management**: Create and manage brewing recipes

## Testing Your Setup

After the server is running, test our race condition fixes:

```bash
# In another terminal, run the test script
python3 scripts/test_race_conditions.py

# Or run unit tests
python3 -m pytest tests/unit/test_thread_safety.py -v
```

## Support

If you encounter issues:

1. **Check the logs**: Look for error messages in the terminal
2. **Verify Python**: Ensure Python 3.6+ is installed
3. **Check ports**: Make sure no other services are using the same port
4. **File permissions**: Ensure the script has execute permissions

The setup scripts make getting started much easier, but if you need help, the manual setup steps above should get you running!
