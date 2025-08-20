import threading
import time
import unittest
from unittest.mock import patch, MagicMock
import sys
import os

# Add the app directory to the path so we can import our modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from app.main.routes_pico_api import get_session_lock, session_locks, session_locks_lock
from app.main.session_parser import session_restore_lock


class TestThreadSafety(unittest.TestCase):
    """Test thread safety of session management functions"""
    
    def setUp(self):
        """Clear session locks before each test"""
        session_locks.clear()
    
    def test_get_session_lock_creates_unique_locks(self):
        """Test that different UIDs get different locks"""
        uid1 = "12345678901234567890123456789012"
        uid2 = "09876543210987654321098765432109"
        
        lock1 = get_session_lock(uid1)
        lock2 = get_session_lock(uid2)
        
        self.assertIsNot(lock1, lock2)
        self.assertIn(uid1, session_locks)
        self.assertIn(uid2, session_locks)
    
    def test_get_session_lock_reuses_existing_locks(self):
        """Test that the same UID always gets the same lock"""
        uid = "12345678901234567890123456789012"
        
        lock1 = get_session_lock(uid)
        lock2 = get_session_lock(uid)
        
        self.assertIs(lock1, lock2)
        self.assertEqual(len(session_locks), 1)
    
    def test_session_locks_are_thread_safe(self):
        """Test that lock creation is thread-safe"""
        uid = "12345678901234567890123456789012"
        results = []
        errors = []
        
        def create_lock():
            try:
                lock = get_session_lock(uid)
                results.append(lock)
            except Exception as e:
                errors.append(e)
        
        # Create multiple threads that try to get the same lock
        threads = []
        for _ in range(10):
            thread = threading.Thread(target=create_lock)
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # Should have no errors and all locks should be the same
        self.assertEqual(len(errors), 0)
        self.assertEqual(len(results), 10)
        self.assertEqual(len(set(results)), 1)  # All locks should be the same object
    
    def test_session_restore_lock_exists(self):
        """Test that the session restore lock exists and is a threading.Lock"""
        self.assertIsInstance(session_restore_lock, threading.Lock)
    
    def test_concurrent_session_operations(self):
        """Test that concurrent operations on different UIDs don't interfere"""
        uid1 = "11111111111111111111111111111111"
        uid2 = "22222222222222222222222222222222"
        
        results = []
        errors = []
        
        def operation1():
            """Simulate session operations for UID1"""
            try:
                lock = get_session_lock(uid1)
                with lock:
                    time.sleep(0.1)  # Simulate some work
                    results.append(f"uid1_completed")
            except Exception as e:
                errors.append(f"uid1_error: {e}")
        
        def operation2():
            """Simulate session operations for UID2"""
            try:
                lock = get_session_lock(uid2)
                with lock:
                    time.sleep(0.1)  # Simulate some work
                    results.append(f"uid2_completed")
            except Exception as e:
                errors.append(f"uid2_error: {e}")
        
        # Run operations concurrently
        thread1 = threading.Thread(target=operation1)
        thread2 = threading.Thread(target=operation2)
        
        start_time = time.time()
        thread1.start()
        thread2.start()
        
        thread1.join()
        thread2.join()
        end_time = time.time()
        
        # Both operations should complete without errors
        self.assertEqual(len(errors), 0)
        self.assertEqual(len(results), 2)
        self.assertIn("uid1_completed", results)
        self.assertIn("uid2_completed", results)
        
        # Operations should run concurrently (total time < sum of individual times)
        self.assertLess(end_time - start_time, 0.15)  # Should be ~0.1s, not 0.2s


class TestInformationDisclosure(unittest.TestCase):
    """Test that sensitive information is not disclosed in logs"""
    
    @patch('app.main.routes_pico_api.current_app.logger.warning')
    def test_firmware_error_log_sanitization(self, mock_logger):
        """Test that firmware error logs don't expose session data"""
        from app.main.routes_pico_api import process_get_firmware
        
        # Mock the active_brew_sessions to simulate a device without machine type
        with patch('app.main.routes_pico_api.active_brew_sessions', {}):
            # Mock the webargs decorator
            with patch('app.main.routes_pico_api.use_args') as mock_use_args:
                mock_use_args.return_value(lambda f: f)
                
                # Call the function directly
                result = process_get_firmware({'uid': '12345678901234567890123456789012'})
                
                # Check that the function returns the expected error response
                self.assertEqual(result, '#F#')
                
                # Verify that the logger was called with sanitized messages
                mock_logger.assert_called()
                log_calls = [call[0][0] for call in mock_logger.call_args_list]
                
                # Should not contain the full UID or session data
                for call in log_calls:
                    self.assertNotIn('12345678901234567890123456789012', call)
                    self.assertNotIn('active_brew_sessions', call)
                
                # Should contain sanitized UID preview
                uid_preview_found = any('12345678...' in call for call in log_calls)
                self.assertTrue(uid_preview_found, "UID preview should be in log messages")


if __name__ == '__main__':
    unittest.main()
