#!/usr/bin/env python3
"""
Test script to verify SMS Gateway fixes:
1. Long message support (multipart SMS)
2. Statistics tracking functionality
"""

import requests
import json
import time
from datetime import datetime

class SMSGatewayTester:
    def __init__(self, base_url="http://localhost:8080", api_key="default-api-key"):
        self.base_url = base_url
        self.headers = {
            'Content-Type': 'application/json',
            'X-API-Key': api_key
        }
        
    def test_connection(self):
        """Test if the SMS Gateway is running"""
        try:
            response = requests.get(f"{self.base_url}/health", headers=self.headers, timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def send_sms(self, recipient, message):
        """Send SMS message"""
        data = {
            'recipient': recipient,
            'message': message
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/send",
                headers=self.headers,
                json=data,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                return {'success': True, 'data': result}
            else:
                return {'success': False, 'error': response.text}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_statistics(self):
        """Get SMS statistics"""
        try:
            response = requests.get(
                f"{self.base_url}/statistics",
                headers=self.headers,
                timeout=5
            )
            
            if response.status_code == 200:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': response.text}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_message_status(self, message_id):
        """Get message status"""
        try:
            response = requests.get(
                f"{self.base_url}/message/{message_id}",
                headers=self.headers,
                timeout=5
            )
            
            if response.status_code == 200:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': response.text}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def test_long_message_support(self):
        """Test long message support (multipart SMS)"""
        print("\n=== Testing Long Message Support ===")
        
        # Test messages of different lengths
        test_messages = [
            {
                'name': 'Short Message (< 160 chars)',
                'message': 'This is a short test message to verify basic SMS functionality works correctly.',
                'recipient': '+1234567890'
            },
            {
                'name': 'Medium Message (160-320 chars)',
                'message': 'This is a longer test message that exceeds the standard 160 character SMS limit. It should be automatically split into multiple parts by the SMS Gateway using multipart SMS functionality. This tests the PDU format support.',
                'recipient': '+1234567890'
            },
            {
                'name': 'Long Message (> 320 chars)',
                'message': 'This is a very long test message that significantly exceeds the standard SMS character limits. It should demonstrate the SMS Gateway\'s ability to handle extended text messages by automatically splitting them into multiple SMS parts using the Android SmsManager\'s divideMessage and sendMultipartTextMessage functionality. This comprehensive test ensures that users can send messages of any reasonable length without worrying about character limits, making the SMS Gateway much more versatile and user-friendly for various applications and use cases.',
                'recipient': '+1234567890'
            }
        ]
        
        results = []
        for test in test_messages:
            print(f"\nTesting: {test['name']}")
            print(f"Message length: {len(test['message'])} characters")
            print(f"Message preview: {test['message'][:100]}...")
            
            result = self.send_sms(test['recipient'], test['message'])
            results.append({
                'test': test['name'],
                'length': len(test['message']),
                'success': result['success'],
                'result': result
            })
            
            if result['success']:
                print(f"✅ SUCCESS: {result['data'].get('message', 'SMS sent')}")
                if 'messageId' in result['data']:
                    # Check message status
                    time.sleep(1)
                    status = self.get_message_status(result['data']['messageId'])
                    if status['success']:
                        print(f"   Message Status: {status['data'].get('status', 'unknown')}")
            else:
                print(f"❌ FAILED: {result['error']}")
            
            time.sleep(2)  # Wait between tests
        
        return results
    
    def test_statistics_tracking(self):
        """Test statistics tracking functionality"""
        print("\n=== Testing Statistics Tracking ===")
        
        # Get initial statistics
        print("Getting initial statistics...")
        initial_stats = self.get_statistics()
        if not initial_stats['success']:
            print(f"❌ Failed to get initial statistics: {initial_stats['error']}")
            return False
        
        print("Initial Statistics:")
        stats_data = initial_stats['data'].get('statistics', {})
        for key, value in stats_data.items():
            print(f"  {key}: {value}")
        
        # Send a test message to update statistics
        print("\nSending test message to update statistics...")
        test_result = self.send_sms('+1234567890', 'Statistics test message')
        
        if not test_result['success']:
            print(f"❌ Failed to send test message: {test_result['error']}")
            return False
        
        # Wait a moment for statistics to update
        time.sleep(3)
        
        # Get updated statistics
        print("Getting updated statistics...")
        updated_stats = self.get_statistics()
        if not updated_stats['success']:
            print(f"❌ Failed to get updated statistics: {updated_stats['error']}")
            return False
        
        print("Updated Statistics:")
        updated_data = updated_stats['data'].get('statistics', {})
        for key, value in updated_data.items():
            print(f"  {key}: {value}")
        
        # Check if statistics were updated
        print("\nStatistics Comparison:")
        changes_detected = False
        for key in ['total', 'todayCount', 'totalSent']:
            if key in stats_data and key in updated_data:
                initial_val = stats_data[key]
                updated_val = updated_data[key]
                if updated_val > initial_val:
                    print(f"✅ {key}: {initial_val} → {updated_val} (increased)")
                    changes_detected = True
                else:
                    print(f"⚠️  {key}: {initial_val} → {updated_val} (no change)")
            else:
                print(f"❓ {key}: missing in statistics")
        
        # Check success rate calculation
        if 'successRate' in updated_data:
            success_rate = updated_data['successRate']
            print(f"✅ Success Rate: {success_rate}%")
        else:
            print("❌ Success Rate: missing")
        
        return changes_detected
    
    def run_all_tests(self):
        """Run all tests"""
        print("SMS Gateway Fix Verification Test")
        print("=" * 50)
        print(f"Testing against: {self.base_url}")
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Test connection
        print("\n=== Testing Connection ===")
        if self.test_connection():
            print("✅ SMS Gateway is running and accessible")
        else:
            print("❌ SMS Gateway is not accessible")
            print("Please ensure the SMS Gateway is running on the specified URL")
            return False
        
        # Test long message support
        long_message_results = self.test_long_message_support()
        
        # Test statistics tracking
        statistics_working = self.test_statistics_tracking()
        
        # Summary
        print("\n" + "=" * 50)
        print("TEST SUMMARY")
        print("=" * 50)
        
        print("\n📱 Long Message Support:")
        for result in long_message_results:
            status = "✅ PASS" if result['success'] else "❌ FAIL"
            print(f"  {status} {result['test']} ({result['length']} chars)")
        
        print(f"\n📊 Statistics Tracking:")
        status = "✅ PASS" if statistics_working else "❌ FAIL"
        print(f"  {status} Statistics are updating correctly")
        
        # Overall result
        all_long_messages_pass = all(r['success'] for r in long_message_results)
        overall_success = all_long_messages_pass and statistics_working
        
        print(f"\n🎯 Overall Result:")
        if overall_success:
            print("✅ ALL TESTS PASSED - SMS Gateway fixes are working correctly!")
        else:
            print("❌ SOME TESTS FAILED - Please check the issues above")
        
        return overall_success

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Test SMS Gateway fixes')
    parser.add_argument('--url', default='http://localhost:8080', help='SMS Gateway URL')
    parser.add_argument('--api-key', default='default-api-key', help='API Key')
    
    args = parser.parse_args()
    
    tester = SMSGatewayTester(args.url, args.api_key)
    success = tester.run_all_tests()
    
    exit(0 if success else 1)

if __name__ == '__main__':
    main()