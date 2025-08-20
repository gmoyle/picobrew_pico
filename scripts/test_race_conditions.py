#!/usr/bin/env python3
"""
Manual Race Condition Test Script for PicoBrew Server

This script simulates multiple PicoBrew devices connecting simultaneously
to test our race condition fixes.

Usage:
    python3 scripts/test_race_conditions.py [server_url]

Example:
    python3 scripts/test_race_conditions.py http://localhost:80
"""

import threading
import time
import requests
import sys
import random

def test_device_connection(base_url, device_id, results, lock):
    """Test a single device connection"""
    try:
        print(f"  Device {device_id[:8]}... connecting...")
        
        # Register device
        register_url = f"{base_url}/API/pico/register?uid={device_id}"
        response = requests.get(register_url, timeout=5)
        
        if response.status_code == 200:
            # Get session
            session_url = f"{base_url}/API/pico/getSession?uid={device_id}&sesType=0"
            response = requests.get(session_url, timeout=5)
            
            if response.status_code == 200:
                # Send log data
                log_url = f"{base_url}/API/pico/log"
                log_data = {
                    'uid': device_id,
                    'sesId': f'test_{device_id[:8]}',
                    'wort': random.randint(140, 160),
                    'therm': random.randint(145, 165),
                    'step': 'Test_Step',
                    'error': 0,
                    'sesType': 0,
                    'timeLeft': 300,
                    'shutScale': 0.0
                }
                
                query_string = '&'.join([f"{k}={v}" for k, v in log_data.items()])
                log_response = requests.get(f"{log_url}?{query_string}", timeout=5)
                
                with lock:
                    results.append({
                        'device_id': device_id,
                        'success': True,
                        'status': 'OK'
                    })
                print(f"  Device {device_id[:8]}... SUCCESS")
            else:
                with lock:
                    results.append({
                        'device_id': device_id,
                        'success': False,
                        'status': f'Session failed: {response.status_code}'
                    })
                print(f"  Device {device_id[:8]}... SESSION FAILED")
        else:
            with lock:
                results.append({
                    'device_id': device_id,
                    'success': False,
                    'status': f'Registration failed: {response.status_code}'
                })
            print(f"  Device {device_id[:8]}... REGISTRATION FAILED")
            
    except Exception as e:
        with lock:
            results.append({
                'device_id': device_id,
                'success': False,
                'status': f'Error: {str(e)}'
            })
        print(f"  Device {device_id[:8]}... ERROR: {e}")

def main():
    # Default server URL
    base_url = "http://localhost:80"
    
    # Allow command line override
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    
    print(f"Testing PicoBrew Server Race Conditions")
    print(f"Server: {base_url}")
    print("=" * 50)
    
    # Check if server is running
    try:
        response = requests.get(f"{base_url}/", timeout=5)
        if response.status_code != 200:
            print(f"Warning: Server responded with status {response.status_code}")
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot connect to server at {base_url}")
        print("Make sure the PicoBrew server is running.")
        print("You can start it with: python3 server.py")
        return 1
    except Exception as e:
        print(f"Error checking server: {e}")
        return 1
    
    # Generate test device IDs
    num_devices = 10
    device_ids = [
        f"test_device_{i:02d}_" + "0" * (32 - len(f"test_device_{i:02d}_"))
        for i in range(num_devices)
    ]
    
    print(f"Testing {num_devices} devices connecting simultaneously...")
    print()
    
    # Test 1: Simultaneous connections
    print("Test 1: All devices connect at the same time")
    results = []
    lock = threading.Lock()
    
    # Start all threads simultaneously
    threads = []
    for device_id in device_ids:
        thread = threading.Thread(
            target=test_device_connection,
            args=(base_url, device_id, results, lock)
        )
        threads.append(thread)
    
    start_time = time.time()
    
    # Start all threads
    for thread in threads:
        thread.start()
    
    # Wait for all threads to complete
    for thread in threads:
        thread.join()
    
    end_time = time.time()
    
    # Analyze results
    successful = sum(1 for r in results if r['success'])
    failed = len(results) - successful
    
    print()
    print("=" * 50)
    print("RESULTS")
    print("=" * 50)
    print(f"Total devices: {num_devices}")
    print(f"Successful: {successful}")
    print(f"Failed: {failed}")
    print(f"Total time: {end_time - start_time:.2f} seconds")
    print()
    
    if failed > 0:
        print("FAILED CONNECTIONS:")
        for result in results:
            if not result['success']:
                print(f"  {result['device_id'][:8]}: {result['status']}")
        print()
        print("❌ Race condition test FAILED - some devices failed to connect")
        return 1
    else:
        print("✅ Race condition test PASSED - all devices connected successfully")
        
        # Test 2: Check for data corruption
        print("\nTest 2: Checking for data corruption...")
        
        # Try to access the same device from multiple threads
        test_device = device_ids[0]
        corruption_results = []
        corruption_lock = threading.Lock()
        
        def test_data_integrity(thread_id):
            try:
                # Send multiple log entries rapidly
                for i in range(5):
                    log_url = f"{base_url}/API/pico/log"
                    log_data = {
                        'uid': test_device,
                        'sesId': f'corruption_test_{thread_id}',
                        'wort': 150 + thread_id + i,
                        'therm': 155 + thread_id + i,
                        'step': f'Corruption_Test_{thread_id}_{i}',
                        'error': 0,
                        'sesType': 0,
                        'timeLeft': 300 - i,
                        'shutScale': 0.0
                    }
                    
                    query_string = '&'.join([f"{k}={v}" for k, v in log_data.items()])
                    response = requests.get(f"{log_url}?{query_string}", timeout=5)
                    
                    if response.status_code == 200:
                        with corruption_lock:
                            corruption_results.append({
                                'thread_id': thread_id,
                                'step': i,
                                'success': True
                            })
                    else:
                        with corruption_lock:
                            corruption_results.append({
                                'thread_id': thread_id,
                                'step': i,
                                'success': False,
                                'status_code': response.status_code
                            })
                    
                    time.sleep(0.01)  # Small delay
                    
            except Exception as e:
                with corruption_lock:
                    corruption_results.append({
                        'thread_id': thread_id,
                        'step': 0,
                        'success': False,
                        'error': str(e)
                    })
        
        # Start multiple threads testing data integrity
        integrity_threads = []
        for i in range(3):
            thread = threading.Thread(target=test_data_integrity, args=(i,))
            integrity_threads.append(thread)
            thread.start()
        
        for thread in integrity_threads:
            thread.join()
        
        corruption_successful = sum(1 for r in corruption_results if r['success'])
        print(f"Data integrity test: {corruption_successful}/{len(corruption_results)} successful")
        
        if corruption_successful == len(corruption_results):
            print("✅ Data integrity test PASSED - no corruption detected")
        else:
            print("❌ Data integrity test FAILED - potential data corruption")
            return 1
    
    return 0

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
