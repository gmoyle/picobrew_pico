# Testing Guide for PicoBrew Server Fixes

This guide explains how to test the race condition and information disclosure fixes we've implemented.

## What We Fixed

1. **Race Conditions**: Added thread-safe locks to prevent data corruption when multiple PicoBrew devices connect simultaneously
2. **Information Disclosure**: Sanitized log output to prevent sensitive session data from appearing in logs

## Testing Approaches

### 1. **Unit Tests** (Recommended First)

Run the unit tests to verify our locking mechanism works correctly:

```bash
# Run from the project root directory
cd /path/to/picobrew_pico

# Run the thread safety tests
python3 -m pytest tests/unit/test_thread_safety.py -v

# Run all unit tests
python3 -m pytest tests/unit/ -v
```

**Expected Results:**
- All tests should pass
- No race conditions detected
- Locks are created and reused correctly
- Thread safety is maintained

### 2. **Manual Testing Script** (Quick Verification)

Use our manual testing script to simulate multiple devices:

```bash
# Make the script executable
chmod +x scripts/test_race_conditions.py

# Run the test (make sure server is running first)
python3 scripts/test_race_conditions.py

# Or test against a different server
python3 scripts/test_race_conditions.py http://192.168.1.100:80
```

**Expected Results:**
- All 10 simulated devices should connect successfully
- No connection failures due to race conditions
- Data integrity maintained under concurrent access

### 3. **Functional Tests** (Comprehensive Testing)

Run the full functional test suite:

```bash
# Run the race condition functional tests
python3 tests/functional/test_race_conditions.py

# Run all functional tests
python3 -m pytest tests/functional/ -v
```

**Expected Results:**
- Concurrent connections succeed
- Staggered connections succeed
- Session data integrity maintained
- No data corruption detected

### 4. **Manual Browser Testing** (Real-world Verification)

Test the web interface while devices are connecting:

1. **Start the server:**
   ```bash
   python3 server.py
   ```

2. **Open multiple browser tabs** to the server (e.g., `http://localhost:80`)

3. **Simulate device connections** using curl or the test script

4. **Monitor the web interface** for:
   - Real-time updates working correctly
   - No JavaScript errors in browser console
   - Session data displaying correctly
   - No duplicate or corrupted sessions

## Testing Scenarios

### Scenario 1: Multiple Devices Connect Simultaneously

**Test:** Start 5+ simulated devices at the exact same time
**Expected:** All devices register successfully, no conflicts
**Check:** Server logs, web interface, session files

### Scenario 2: Rapid Session Updates

**Test:** Send log data rapidly from multiple threads to the same device
**Expected:** All log entries are recorded correctly
**Check:** Session JSON files, no data corruption

### Scenario 3: Server Restart with Active Sessions

**Test:** Start devices, then restart the server
**Expected:** Sessions are restored correctly without corruption
**Check:** Session restoration, no duplicate sessions

### Scenario 4: Information Disclosure Prevention

**Test:** Trigger firmware errors for unknown devices
**Expected:** Logs show sanitized UID (e.g., "12345678...") not full UID
**Check:** Server logs, no session data exposure

## Monitoring During Tests

### Server Logs

Watch for these indicators of successful fixes:

```bash
# Monitor server logs in real-time
tail -f /var/log/syslog | grep picobrew

# Or if using Docker
docker logs -f picobrew_pico
```

**Good signs:**
- No "race condition" or "concurrent access" errors
- Clean, sanitized error messages
- Successful session creation messages

**Warning signs:**
- Multiple devices failing to connect
- Session data corruption errors
- Full UIDs or session data in logs

### Web Interface

Monitor the web interface for:
- Real-time updates working smoothly
- No JavaScript errors in browser console
- Session data displaying correctly
- No duplicate sessions appearing

### File System

Check session files for integrity:

```bash
# Look for session files
ls -la app/sessions/brew/active/
ls -la app/sessions/brew/archive/

# Check JSON file integrity
for file in app/sessions/brew/active/*.json; do
    echo "Checking $file..."
    python3 -m json.tool "$file" > /dev/null && echo "✓ Valid JSON" || echo "✗ Invalid JSON"
done
```

## Troubleshooting

### Common Issues

1. **Tests fail with import errors:**
   ```bash
   # Make sure you're in the project root
   cd /path/to/picobrew_pico
   export PYTHONPATH="${PYTHONPATH}:$(pwd)"
   ```

2. **Server not responding:**
   ```bash
   # Check if server is running
   ps aux | grep server.py
   
   # Check port usage
   netstat -tlnp | grep :80
   ```

3. **Permission errors:**
   ```bash
   # Make scripts executable
   chmod +x scripts/*.py
   ```

### Debug Mode

Enable debug logging in the server:

```python
# In server.py, change:
app = create_app(debug=True)
```

### Performance Testing

For stress testing with many devices:

```bash
# Test with more devices
python3 scripts/test_race_conditions.py
# Edit the script to increase num_devices to 50+

# Monitor system resources
htop
iotop
```

## Success Criteria

Your fixes are working correctly if:

✅ **All unit tests pass**  
✅ **10+ devices can connect simultaneously**  
✅ **No session data corruption occurs**  
✅ **Logs show sanitized UIDs (e.g., "12345678...")**  
✅ **Web interface updates smoothly**  
✅ **Session files remain valid JSON**  
✅ **Server handles concurrent access gracefully**  

## Next Steps

After successful testing:

1. **Deploy to production** (if applicable)
2. **Monitor real device connections** for any issues
3. **Consider additional security improvements** (authentication, rate limiting)
4. **Document any new issues** discovered during testing

## Support

If you encounter issues during testing:

1. Check the server logs for error messages
2. Verify the server is running and accessible
3. Ensure all dependencies are installed (`pip install -r requirements.txt`)
4. Check file permissions and paths
5. Review the test output for specific failure details
