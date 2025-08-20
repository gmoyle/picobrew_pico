import threading
import time
import requests
import json
import sys
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

# Add the app directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

class TestRaceConditions:
    """Test race conditions with multiple simulated PicoBrew devices"""
    
    def __init__(self, base_url="http://localhost:80"):
        self.base_url = base_url
        self.test_results = []
        self.errors = []
    
    def simulate_device_connection(self, device_id, delay=0):
        """Simulate a PicoBrew device connecting and registering"""
        try:
            time.sleep(delay)  # Stagger connections to test race conditions
            
            # Step 1: Register device
            register_url = f"{self.base_url}/API/pico/register?uid={device_id}"
            response = requests.get(register_url, timeout=10)
            
            if response.status_code == 200:
                # Step 2: Try to create a session
                session_url = f"{self.base_url}/API/pico/getSession?uid={device_id}&sesType=0"
                response = requests.get(session_url, timeout=10)
                
                if response.status_code == 200:
                    # Step 3: Send some log data
                    log_url = f"{self.base_url}/API/pico/log"
                    log_data = {
                        'uid': device_id,
                        'sesId': 'test_session_123',
                        'wort': 150,
                        'therm': 155,
                        'step': 'Heating',
                        'error': 0,
                        'sesType': 0,
                        'timeLeft': 300,
                        'shutScale': 0.0
                    }
                    
                    # Convert to query string
                    query_string = '&'.join([f"{k}={v}" for k, v in log_data.items()])
                    log_response = requests.get(f"{log_url}?{query_string}", timeout=10)
                    
                    return {
                        'device_id': device_id,
                        'register_success': True,
                        'session_success': True,
                        'log_success': log_response.status_code == 200,
                        'status_code': log_response.status_code
                    }
                else:
                    return {
                        'device_id': device_id,
                        'register_success': True,
                        'session_success': False,
                        'log_success': False,
                        'status_code': response.status_code
                    }
            else:
                return {
                    'device_id': device_id,
                    'register_success': False,
                    'session_success': False,
                    'log_success': False,
                    'status_code': response.status_code
                }
                
        except Exception as e:
            return {
                'device_id': device_id,
                'register_success': False,
                'session_success': False,
                'log_success': False,
                'error': str(e)
            }
    
    def test_concurrent_device_connections(self, num_devices=5):
        """Test multiple devices connecting simultaneously"""
        print(f"Testing concurrent connections with {num_devices} devices...")
        
        # Generate unique device IDs
        device_ids = [f"test_device_{i:02d}_" + "0" * (32 - len(f"test_device_{i:02d}_")) 
                     for i in range(num_devices)]
        
        # Test 1: All devices connect at exactly the same time
        print("Test 1: Simultaneous connections...")
        with ThreadPoolExecutor(max_workers=num_devices) as executor:
            futures = [executor.submit(self.simulate_device_connection, device_id, 0) 
                      for device_id in device_ids]
            
            results = []
            for future in as_completed(futures):
                result = future.result()
                results.append(result)
                print(f"Device {result['device_id']}: Register={result['register_success']}, "
                      f"Session={result['session_success']}, Log={result['log_success']}")
            
            # All devices should succeed
            successful_registrations = sum(1 for r in results if r['register_success'])
            successful_sessions = sum(1 for r in results if r['session_success'])
            successful_logs = sum(1 for r in results if r['log_success'])
            
            print(f"Results: {successful_registrations}/{num_devices} registrations, "
                  f"{successful_sessions}/{num_devices} sessions, "
                  f"{successful_logs}/{num_devices} logs")
            
            # Test 2: Staggered connections to test lock behavior
            print("\nTest 2: Staggered connections...")
            with ThreadPoolExecutor(max_workers=num_devices) as executor:
                futures = [executor.submit(self.simulate_device_connection, device_id, i * 0.1) 
                          for i, device_id in enumerate(device_ids)]
                
                staggered_results = []
                for future in as_completed(futures):
                    result = future.result()
                    staggered_results.append(result)
                
                staggered_successful = sum(1 for r in staggered_results if r['log_success'])
                print(f"Staggered results: {staggered_successful}/{num_devices} successful logs")
            
            return results, staggered_results
    
    def test_session_data_integrity(self):
        """Test that session data remains consistent under concurrent access"""
        print("\nTest 3: Session data integrity...")
        
        device_id = "integrity_test_device_123456789012"
        
        # Create multiple threads that send log data simultaneously
        def send_log_data(thread_id, count):
            results = []
            for i in range(count):
                try:
                    log_url = f"{self.base_url}/API/pico/log"
                    log_data = {
                        'uid': device_id,
                        'sesId': f'integrity_session_{thread_id}',
                        'wort': 150 + thread_id,
                        'therm': 155 + thread_id,
                        'step': f'Thread_{thread_id}_Step_{i}',
                        'error': 0,
                        'sesType': 0,
                        'timeLeft': 300 - i,
                        'shutScale': 0.0
                    }
                    
                    query_string = '&'.join([f"{k}={v}" for k, v in log_data.items()])
                    response = requests.get(f"{log_url}?{query_string}", timeout=10)
                    
                    results.append({
                        'thread_id': thread_id,
                        'step': i,
                        'success': response.status_code == 200,
                        'status_code': response.status_code
                    })
                    
                    time.sleep(0.01)  # Small delay between requests
                    
                except Exception as e:
                    results.append({
                        'thread_id': thread_id,
                        'step': i,
                        'success': False,
                        'error': str(e)
                    })
            
            return results
        
        # Start multiple threads sending data
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = [
                executor.submit(send_log_data, i, 5) 
                for i in range(3)
            ]
            
            all_results = []
            for future in as_completed(futures):
                thread_results = future.result()
                all_results.extend(thread_results)
        
        # Check results
        successful_logs = sum(1 for r in all_results if r['success'])
        print(f"Session integrity test: {successful_logs}/{len(all_results)} successful log entries")
        
        return all_results
    
    def run_all_tests(self):
        """Run all race condition tests"""
        print("=== PicoBrew Race Condition Tests ===\n")
        
        try:
            # Test concurrent connections
            results, staggered_results = self.test_concurrent_device_connections(5)
            
            # Test session data integrity
            integrity_results = self.test_session_data_integrity()
            
            # Summary
            print("\n=== Test Summary ===")
            print(f"Concurrent connections: {len([r for r in results if r['log_success']])}/{len(results)} successful")
            print(f"Staggered connections: {len([r for r in staggered_results if r['log_success']])}/{len(staggered_results)} successful")
            print(f"Data integrity: {len([r for r in integrity_results if r['success']])}/{len(integrity_results)} successful")
            
            # Check for any failures
            concurrent_failures = [r for r in results if not r['log_success']]
            if concurrent_failures:
                print(f"\nWARNING: {len(concurrent_failures)} concurrent connection failures detected")
                for failure in concurrent_failures:
                    print(f"  Device {failure['device_id']}: {failure.get('error', 'Unknown error')}")
            
            return len(concurrent_failures) == 0
            
        except Exception as e:
            print(f"Test execution failed: {e}")
            return False


if __name__ == "__main__":
    # Check if server is running
    try:
        response = requests.get("http://localhost:80/", timeout=5)
        if response.status_code == 200:
            print("Server is running, starting tests...")
            tester = TestRaceConditions()
            success = tester.run_all_tests()
            exit(0 if success else 1)
        else:
            print(f"Server responded with status {response.status_code}")
            exit(1)
    except requests.exceptions.ConnectionError:
        print("Server is not running. Please start the PicoBrew server first.")
        print("You can start it with: python3 server.py")
        exit(1)
    except Exception as e:
        print(f"Error checking server: {e}")
        exit(1)
