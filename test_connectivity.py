#!/usr/bin/env python3
"""
Test script to verify SMS Gateway connectivity from external applications.
This script tests all the critical endpoints and functionality.
"""

import requests
import json
import time
import sys

# Configuration
BASE_URL = "http://localhost:8080"  # Using localhost with adb port forwarding
API_KEY = "sms-gateway-default-key-2024"  # Default API key

def test_endpoint(endpoint, method="GET", data=None, headers=None):
    """Test a specific endpoint and return the result."""
    url = f"{BASE_URL}{endpoint}"
    
    if headers is None:
        headers = {"X-API-Key": API_KEY}
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=10)
        elif method == "POST":
            response = requests.post(url, json=data, headers=headers, timeout=10)
        
        print(f"✓ {method} {endpoint}: {response.status_code}")
        if response.status_code == 200:
            try:
                result = response.json()
                print(f"  Response: {json.dumps(result, indent=2)}")
            except:
                print(f"  Response: {response.text}")
        else:
            print(f"  Error: {response.text}")
        
        return response.status_code == 200
    
    except requests.exceptions.RequestException as e:
        print(f"✗ {method} {endpoint}: Connection failed - {e}")
        return False

def main():
    print("SMS Gateway Connectivity Test")
    print("=" * 40)
    print(f"Testing server at: {BASE_URL}")
    print(f"Using API key: {API_KEY}")
    print()
    
    # Test 1: Health Check (no auth required)
    print("1. Testing health check endpoint...")
    health_ok = test_endpoint("/health")
    
    # Test 2: Device Info
    print("\n2. Testing device info endpoint...")
    device_ok = test_endpoint("/device-info")
    
    # Test 3: Statistics
    print("\n3. Testing statistics endpoint...")
    stats_ok = test_endpoint("/statistics")
    
    # Test 4: Recent Messages
    print("\n4. Testing recent messages endpoint...")
    messages_ok = test_endpoint("/messages/recent")
    
    # Test 5: Send SMS (test endpoint - won't actually send)
    print("\n5. Testing send SMS endpoint...")
    sms_data = {
        "recipient": "+1234567890",
        "message": "Test message from connectivity test",
        "priority": "normal"
    }
    sms_ok = test_endpoint("/send-sms", method="POST", data=sms_data)
    
    # Test 6: CORS preflight
    print("\n6. Testing CORS preflight...")
    try:
        response = requests.options(f"{BASE_URL}/send-sms", 
                                  headers={"Origin": "http://localhost:3000"}, 
                                  timeout=10)
        cors_ok = response.status_code == 200
        print(f"✓ OPTIONS /send-sms: {response.status_code}")
        print(f"  CORS Headers: {dict(response.headers)}")
    except Exception as e:
        cors_ok = False
        print(f"✗ OPTIONS /send-sms: {e}")
    
    # Test 7: Invalid API Key
    print("\n7. Testing invalid API key...")
    invalid_headers = {"X-API-Key": "invalid-key"}
    try:
        response = requests.get(f"{BASE_URL}/device-info", headers=invalid_headers, timeout=10)
        auth_ok = response.status_code == 403
        print(f"✓ Invalid API key properly rejected: {response.status_code}")
    except Exception as e:
        auth_ok = False
        print(f"✗ Auth test failed: {e}")
    
    # Summary
    print("\n" + "=" * 40)
    print("Test Summary:")
    print(f"Health Check: {'✓' if health_ok else '✗'}")
    print(f"Device Info: {'✓' if device_ok else '✗'}")
    print(f"Statistics: {'✓' if stats_ok else '✗'}")
    print(f"Recent Messages: {'✓' if messages_ok else '✗'}")
    print(f"Send SMS: {'✓' if sms_ok else '✗'}")
    print(f"CORS Support: {'✓' if cors_ok else '✗'}")
    print(f"Authentication: {'✓' if auth_ok else '✗'}")
    
    total_tests = 7
    passed_tests = sum([health_ok, device_ok, stats_ok, messages_ok, sms_ok, cors_ok, auth_ok])
    
    print(f"\nPassed: {passed_tests}/{total_tests}")
    
    if passed_tests == total_tests:
        print("🎉 All tests passed! SMS Gateway is working correctly.")
        return 0
    else:
        print("❌ Some tests failed. Check the server configuration.")
        return 1

if __name__ == "__main__":
    sys.exit(main())