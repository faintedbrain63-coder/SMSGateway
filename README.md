# SMS Gateway Flutter Application

A comprehensive Flutter application that provides SMS gateway functionality with REST API endpoints for integration with external systems, particularly designed for C# Windows Forms applications.

## Features

- **REST API Server**: Built-in HTTP server with comprehensive endpoints
- **SMS Management**: Send single and bulk SMS messages
- **Database Integration**: SQLite database for message logging and configuration
- **API Key Authentication**: Secure API access with key-based authentication
- **Rate Limiting**: Configurable rate limiting for API endpoints
- **Material 3 UI**: Modern, responsive user interface
- **Background Service**: Continuous operation with background processing
- **Message Retry Logic**: Automatic retry for failed messages
- **Real-time Statistics**: Dashboard with live statistics and monitoring

## Architecture

### Core Services

1. **HTTP Server Service** (`lib/services/http_server_service.dart`)
   - Shelf-based HTTP server
   - REST API endpoints
   - CORS support
   - Authentication middleware
   - Request logging

2. **SMS Service** (`lib/services/sms_service.dart`)
   - Platform channel integration
   - Message queue management
   - Retry logic for failed messages
   - SIM card detection and management

3. **Database Service** (`lib/services/database_service.dart`)
   - SQLite database operations
   - Message logging
   - API key management
   - Configuration storage

4. **Background Service** (`lib/services/background_service.dart`)
   - Continuous server operation
   - Background message processing
   - System integration

### UI Pages

1. **Dashboard** - Server status, statistics, and quick actions
2. **Message Logs** - View and filter SMS message history
3. **Configuration** - Server and SMS settings
4. **API Keys** - Manage authentication keys

## REST API Endpoints

### Base URL
```
http://localhost:8080
```

### Authentication
All endpoints (except health check) require an API key in the header:
```
Authorization: Bearer YOUR_API_KEY
```

### Endpoints

#### Health Check
```http
GET /health
```
Returns server status and basic information.

#### Device Information
```http
GET /device-info
```
Returns device details including SIM card information.

#### Send Single SMS
```http
POST /send-sms
Content-Type: application/json

{
  "recipient": "+1234567890",
  "message": "Your message here",
  "simSlot": 0
}
```

#### Send Bulk SMS
```http
POST /send-bulk
Content-Type: application/json

{
  "recipients": ["+1234567890", "+0987654321"],
  "message": "Your bulk message here",
  "simSlot": 0
}
```

#### Message Status
```http
GET /message/{messageId}/status
```
Returns the status of a specific message.

#### Statistics
```http
GET /statistics
```
Returns SMS statistics and server metrics.

#### Recent Messages
```http
GET /recent-messages?limit=50
```
Returns recent SMS messages with optional limit.

## C# Integration

### Example C# HTTP Client

```csharp
using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

public class SmsGatewayClient
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    private readonly string _apiKey;

    public SmsGatewayClient(string baseUrl, string apiKey)
    {
        _baseUrl = baseUrl;
        _apiKey = apiKey;
        _httpClient = new HttpClient();
        _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {apiKey}");
    }

    public async Task<bool> SendSmsAsync(string recipient, string message, int simSlot = 0)
    {
        try
        {
            var payload = new
            {
                recipient = recipient,
                message = message,
                simSlot = simSlot
            };

            var json = JsonConvert.SerializeObject(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_baseUrl}/send-sms", content);
            return response.IsSuccessStatusCode;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error sending SMS: {ex.Message}");
            return false;
        }
    }

    public async Task<bool> SendBulkSmsAsync(string[] recipients, string message, int simSlot = 0)
    {
        try
        {
            var payload = new
            {
                recipients = recipients,
                message = message,
                simSlot = simSlot
            };

            var json = JsonConvert.SerializeObject(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_baseUrl}/send-bulk", content);
            return response.IsSuccessStatusCode;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error sending bulk SMS: {ex.Message}");
            return false;
        }
    }

    public async Task<string> GetMessageStatusAsync(string messageId)
    {
        try
        {
            var response = await _httpClient.GetAsync($"{_baseUrl}/message/{messageId}/status");
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadAsStringAsync();
            }
            return null;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting message status: {ex.Message}");
            return null;
        }
    }

    public async Task<string> GetStatisticsAsync()
    {
        try
        {
            var response = await _httpClient.GetAsync($"{_baseUrl}/statistics");
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadAsStringAsync();
            }
            return null;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error getting statistics: {ex.Message}");
            return null;
        }
    }

    public void Dispose()
    {
        _httpClient?.Dispose();
    }
}
```

### Usage Example

```csharp
// Initialize the client
var smsClient = new SmsGatewayClient("http://192.168.1.100:8080", "your-api-key-here");

// Send a single SMS
bool success = await smsClient.SendSmsAsync("+1234567890", "Hello from C# app!");

// Send bulk SMS
string[] recipients = { "+1234567890", "+0987654321" };
bool bulkSuccess = await smsClient.SendBulkSmsAsync(recipients, "Bulk message from C# app!");

// Get statistics
string stats = await smsClient.GetStatisticsAsync();
Console.WriteLine(stats);

// Clean up
smsClient.Dispose();
```

## WiFi Network Integration Guide

This section provides comprehensive documentation on how to connect to the SMS Gateway app from other applications on the same WiFi network.

### Network Discovery and Setup

#### Finding the SMS Gateway IP Address

1. **From the SMS Gateway App**:
   - Open the app and go to the Dashboard
   - The server IP address is displayed in the "Server Status" section
   - Example: `Server running on 192.168.1.100:8080`

2. **From Command Line** (on the same network):
   ```bash
   # Scan for devices on your network
   nmap -sn 192.168.1.0/24
   
   # Or use arp to find devices
   arp -a | grep -i android
   ```

3. **Network Configuration**:
   - Ensure both devices are on the same WiFi network
   - The SMS Gateway app binds to `0.0.0.0:8080` (all network interfaces)
   - Default port is `8080` (configurable in app settings)

### Platform-Specific Integration Examples

#### C# Windows Forms Application

```csharp
using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using Newtonsoft.Json;

public partial class SmsGatewayForm : Form
{
    private readonly HttpClient _httpClient;
    private readonly string _gatewayUrl = "http://192.168.1.100:8080"; // Replace with actual IP
    private readonly string _apiKey = "sms-gateway-default-key-2024";

    public SmsGatewayForm()
    {
        InitializeComponent();
        _httpClient = new HttpClient();
        _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {_apiKey}");
        _httpClient.Timeout = TimeSpan.FromSeconds(30);
    }

    private async void btnSendSms_Click(object sender, EventArgs e)
    {
        try
        {
            var payload = new
            {
                recipient = txtRecipient.Text,
                message = txtMessage.Text,
                simSlot = 0
            };

            var json = JsonConvert.SerializeObject(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_gatewayUrl}/send-sms", content);
            
            if (response.IsSuccessStatusCode)
            {
                MessageBox.Show("SMS sent successfully!", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            else
            {
                var error = await response.Content.ReadAsStringAsync();
                MessageBox.Show($"Failed to send SMS: {error}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        catch (HttpRequestException ex)
        {
            MessageBox.Show($"Network error: {ex.Message}\nCheck if SMS Gateway is running and accessible.", "Connection Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private async void btnCheckHealth_Click(object sender, EventArgs e)
    {
        try
        {
            var response = await _httpClient.GetAsync($"{_gatewayUrl}/health");
            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadAsStringAsync();
                MessageBox.Show($"Gateway Status: {result}", "Health Check", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Gateway not accessible: {ex.Message}", "Connection Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }
}
```

#### Django (Python Web Framework)

**settings.py**:
```python
# SMS Gateway Configuration
SMS_GATEWAY_URL = "http://192.168.1.100:8080"
SMS_GATEWAY_API_KEY = "sms-gateway-default-key-2024"
SMS_GATEWAY_TIMEOUT = 30
```

**services/sms_service.py**:
```python
import requests
import json
from django.conf import settings
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

class SmsGatewayService:
    def __init__(self):
        self.base_url = settings.SMS_GATEWAY_URL
        self.api_key = settings.SMS_GATEWAY_API_KEY
        self.timeout = settings.SMS_GATEWAY_TIMEOUT
        self.headers = {
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        }

    def send_sms(self, recipient, message, sim_slot=0):
        """Send a single SMS message"""
        try:
            payload = {
                'recipient': recipient,
                'message': message,
                'simSlot': sim_slot
            }
            
            response = requests.post(
                f"{self.base_url}/send-sms",
                headers=self.headers,
                json=payload,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                logger.info(f"SMS sent successfully to {recipient}")
                return {'success': True, 'data': response.json()}
            else:
                logger.error(f"Failed to send SMS: {response.text}")
                return {'success': False, 'error': response.text}
                
        except requests.exceptions.ConnectionError:
            logger.error("Cannot connect to SMS Gateway - check network and gateway status")
            return {'success': False, 'error': 'Gateway not accessible'}
        except requests.exceptions.Timeout:
            logger.error("SMS Gateway request timed out")
            return {'success': False, 'error': 'Request timeout'}
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")
            return {'success': False, 'error': str(e)}

    def send_bulk_sms(self, recipients, message, sim_slot=0):
        """Send bulk SMS messages"""
        try:
            payload = {
                'recipients': recipients,
                'message': message,
                'simSlot': sim_slot
            }
            
            response = requests.post(
                f"{self.base_url}/send-bulk",
                headers=self.headers,
                json=payload,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                logger.info(f"Bulk SMS sent to {len(recipients)} recipients")
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': response.text}
                
        except Exception as e:
            logger.error(f"Bulk SMS error: {str(e)}")
            return {'success': False, 'error': str(e)}

    def get_gateway_status(self):
        """Check if SMS Gateway is accessible"""
        try:
            response = requests.get(
                f"{self.base_url}/health",
                timeout=5
            )
            return response.status_code == 200
        except:
            return False

    def get_statistics(self):
        """Get SMS statistics from gateway"""
        try:
            response = requests.get(
                f"{self.base_url}/statistics",
                headers=self.headers,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': response.text}
        except Exception as e:
            return {'success': False, 'error': str(e)}
```

**views.py**:
```python
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .services.sms_service import SmsGatewayService
import json

@csrf_exempt
@require_http_methods(["POST"])
def send_sms_view(request):
    try:
        data = json.loads(request.body)
        recipient = data.get('recipient')
        message = data.get('message')
        
        if not recipient or not message:
            return JsonResponse({'error': 'Recipient and message are required'}, status=400)
        
        sms_service = SmsGatewayService()
        result = sms_service.send_sms(recipient, message)
        
        if result['success']:
            return JsonResponse({'message': 'SMS sent successfully', 'data': result['data']})
        else:
            return JsonResponse({'error': result['error']}, status=500)
            
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

def gateway_status_view(request):
    sms_service = SmsGatewayService()
    is_online = sms_service.get_gateway_status()
    
    return JsonResponse({
        'gateway_online': is_online,
        'gateway_url': sms_service.base_url
    })
```

#### Next.js Application

**lib/smsGateway.js**:
```javascript
class SmsGatewayClient {
  constructor() {
    this.baseUrl = process.env.NEXT_PUBLIC_SMS_GATEWAY_URL || 'http://192.168.1.100:8080';
    this.apiKey = process.env.NEXT_PUBLIC_SMS_GATEWAY_API_KEY || 'sms-gateway-default-key-2024';
    this.timeout = 30000; // 30 seconds
  }

  async makeRequest(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const config = {
      timeout: this.timeout,
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);
      
      const response = await fetch(url, {
        ...config,
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`HTTP ${response.status}: ${errorText}`);
      }
      
      return await response.json();
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error('Request timeout - SMS Gateway not responding');
      }
      if (error.message.includes('fetch')) {
        throw new Error('Cannot connect to SMS Gateway - check network connection');
      }
      throw error;
    }
  }

  async sendSms(recipient, message, simSlot = 0) {
    return await this.makeRequest('/send-sms', {
      method: 'POST',
      body: JSON.stringify({
        recipient,
        message,
        simSlot
      })
    });
  }

  async sendBulkSms(recipients, message, simSlot = 0) {
    return await this.makeRequest('/send-bulk', {
      method: 'POST',
      body: JSON.stringify({
        recipients,
        message,
        simSlot
      })
    });
  }

  async getHealth() {
    return await this.makeRequest('/health');
  }

  async getStatistics() {
    return await this.makeRequest('/statistics');
  }

  async getRecentMessages(limit = 50) {
    return await this.makeRequest(`/recent-messages?limit=${limit}`);
  }

  async getDeviceInfo() {
    return await this.makeRequest('/device-info');
  }
}

export default SmsGatewayClient;
```

**pages/api/send-sms.js**:
```javascript
import SmsGatewayClient from '../../lib/smsGateway';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { recipient, message } = req.body;
    
    if (!recipient || !message) {
      return res.status(400).json({ error: 'Recipient and message are required' });
    }

    const smsClient = new SmsGatewayClient();
    const result = await smsClient.sendSms(recipient, message);
    
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    console.error('SMS sending error:', error);
    res.status(500).json({ 
      error: 'Failed to send SMS', 
      details: error.message 
    });
  }
}
```

**components/SmsForm.jsx**:
```jsx
import { useState } from 'react';

export default function SmsForm() {
  const [recipient, setRecipient] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setStatus('');

    try {
      const response = await fetch('/api/send-sms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ recipient, message }),
      });

      const data = await response.json();

      if (response.ok) {
        setStatus('SMS sent successfully!');
        setRecipient('');
        setMessage('');
      } else {
        setStatus(`Error: ${data.error}`);
      }
    } catch (error) {
      setStatus(`Network error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto mt-8 p-6 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold mb-4">Send SMS</h2>
      
      <form onSubmit={handleSubmit}>
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Recipient Phone Number
          </label>
          <input
            type="tel"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="+1234567890"
            required
          />
        </div>
        
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Message
          </label>
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            rows="4"
            placeholder="Enter your message here..."
            required
          />
        </div>
        
        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-500 text-white py-2 px-4 rounded-md hover:bg-blue-600 disabled:opacity-50"
        >
          {loading ? 'Sending...' : 'Send SMS'}
        </button>
      </form>
      
      {status && (
        <div className={`mt-4 p-3 rounded-md ${
          status.includes('Error') || status.includes('error') 
            ? 'bg-red-100 text-red-700' 
            : 'bg-green-100 text-green-700'
        }`}>
          {status}
        </div>
      )}
    </div>
  );
}
```

#### React.js Application

**services/smsGatewayService.js**:
```javascript
class SmsGatewayService {
  constructor() {
    this.baseUrl = process.env.REACT_APP_SMS_GATEWAY_URL || 'http://192.168.1.100:8080';
    this.apiKey = process.env.REACT_APP_SMS_GATEWAY_API_KEY || 'sms-gateway-default-key-2024';
    this.timeout = 30000;
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    
    const config = {
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);
      
      const response = await fetch(url, {
        ...config,
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        const errorData = await response.text();
        throw new Error(`SMS Gateway Error: ${response.status} - ${errorData}`);
      }
      
      return await response.json();
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error('SMS Gateway timeout - please check connection');
      }
      if (error.message.includes('Failed to fetch')) {
        throw new Error('Cannot reach SMS Gateway - check network and gateway status');
      }
      throw error;
    }
  }

  async sendSms(recipient, message, simSlot = 0) {
    return this.request('/send-sms', {
      method: 'POST',
      body: JSON.stringify({ recipient, message, simSlot })
    });
  }

  async sendBulkSms(recipients, message, simSlot = 0) {
    return this.request('/send-bulk', {
      method: 'POST',
      body: JSON.stringify({ recipients, message, simSlot })
    });
  }

  async getHealth() {
    return this.request('/health');
  }

  async getStatistics() {
    return this.request('/statistics');
  }

  async getDeviceInfo() {
    return this.request('/device-info');
  }

  async getRecentMessages(limit = 50) {
    return this.request(`/recent-messages?limit=${limit}`);
  }
}

export default new SmsGatewayService();
```

**components/SmsManager.jsx**:
```jsx
import React, { useState, useEffect } from 'react';
import smsGatewayService from '../services/smsGatewayService';

const SmsManager = () => {
  const [recipient, setRecipient] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');
  const [gatewayHealth, setGatewayHealth] = useState(null);
  const [statistics, setStatistics] = useState(null);

  useEffect(() => {
    checkGatewayHealth();
    loadStatistics();
  }, []);

  const checkGatewayHealth = async () => {
    try {
      const health = await smsGatewayService.getHealth();
      setGatewayHealth(health);
    } catch (error) {
      setGatewayHealth({ error: error.message });
    }
  };

  const loadStatistics = async () => {
    try {
      const stats = await smsGatewayService.getStatistics();
      setStatistics(stats);
    } catch (error) {
      console.error('Failed to load statistics:', error);
    }
  };

  const handleSendSms = async (e) => {
    e.preventDefault();
    setLoading(true);
    setStatus('');

    try {
      const result = await smsGatewayService.sendSms(recipient, message);
      setStatus('SMS sent successfully!');
      setRecipient('');
      setMessage('');
      loadStatistics(); // Refresh stats
    } catch (error) {
      setStatus(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-3xl font-bold mb-6">SMS Gateway Manager</h1>
      
      {/* Gateway Status */}
      <div className="mb-6 p-4 rounded-lg bg-gray-100">
        <h2 className="text-xl font-semibold mb-2">Gateway Status</h2>
        {gatewayHealth ? (
          gatewayHealth.error ? (
            <div className="text-red-600">❌ {gatewayHealth.error}</div>
          ) : (
            <div className="text-green-600">✅ Gateway Online</div>
          )
        ) : (
          <div>Checking...</div>
        )}
      </div>

      {/* Statistics */}
      {statistics && (
        <div className="mb-6 p-4 rounded-lg bg-blue-50">
          <h2 className="text-xl font-semibold mb-2">Statistics</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>Total: {statistics.totalMessages}</div>
            <div>Sent: {statistics.sentMessages}</div>
            <div>Failed: {statistics.failedMessages}</div>
            <div>Pending: {statistics.pendingMessages}</div>
          </div>
        </div>
      )}

      {/* SMS Form */}
      <div className="max-w-md mx-auto bg-white p-6 rounded-lg shadow-md">
        <h2 className="text-2xl font-bold mb-4">Send SMS</h2>
        
        <form onSubmit={handleSendSms}>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Recipient
            </label>
            <input
              type="tel"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="+1234567890"
              required
            />
          </div>
          
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Message
            </label>
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              rows="4"
              placeholder="Enter your message..."
              required
            />
          </div>
          
          <button
            type="submit"
            disabled={loading || gatewayHealth?.error}
            className="w-full bg-blue-500 text-white py-2 px-4 rounded-md hover:bg-blue-600 disabled:opacity-50"
          >
            {loading ? 'Sending...' : 'Send SMS'}
          </button>
        </form>
        
        {status && (
          <div className={`mt-4 p-3 rounded-md ${
            status.includes('Error') 
              ? 'bg-red-100 text-red-700' 
              : 'bg-green-100 text-green-700'
          }`}>
            {status}
          </div>
        )}
      </div>
    </div>
  );
};

export default SmsManager;
```

#### Node.js Application

**package.json dependencies**:
```json
{
  "dependencies": {
    "axios": "^1.6.0",
    "express": "^4.18.0",
    "cors": "^2.8.5"
  }
}
```

**services/smsGatewayClient.js**:
```javascript
const axios = require('axios');

class SmsGatewayClient {
  constructor(options = {}) {
    this.baseUrl = options.baseUrl || process.env.SMS_GATEWAY_URL || 'http://192.168.1.100:8080';
    this.apiKey = options.apiKey || process.env.SMS_GATEWAY_API_KEY || 'sms-gateway-default-key-2024';
    this.timeout = options.timeout || 30000;
    
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: this.timeout,
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      }
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      response => response,
      error => {
        if (error.code === 'ECONNREFUSED') {
          throw new Error('SMS Gateway not accessible - check network connection and gateway status');
        }
        if (error.code === 'ENOTFOUND') {
          throw new Error('SMS Gateway host not found - check IP address');
        }
        if (error.code === 'ETIMEDOUT') {
          throw new Error('SMS Gateway request timeout');
        }
        throw error;
      }
    );
  }

  async sendSms(recipient, message, simSlot = 0) {
    try {
      const response = await this.client.post('/send-sms', {
        recipient,
        message,
        simSlot
      });
      return { success: true, data: response.data };
    } catch (error) {
      console.error('SMS sending failed:', error.message);
      return { success: false, error: error.message };
    }
  }

  async sendBulkSms(recipients, message, simSlot = 0) {
    try {
      const response = await this.client.post('/send-bulk', {
        recipients,
        message,
        simSlot
      });
      return { success: true, data: response.data };
    } catch (error) {
      console.error('Bulk SMS sending failed:', error.message);
      return { success: false, error: error.message };
    }
  }

  async getHealth() {
    try {
      const response = await this.client.get('/health');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getStatistics() {
    try {
      const response = await this.client.get('/statistics');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getDeviceInfo() {
    try {
      const response = await this.client.get('/device-info');
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getRecentMessages(limit = 50) {
    try {
      const response = await this.client.get(`/recent-messages?limit=${limit}`);
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getMessageStatus(messageId) {
    try {
      const response = await this.client.get(`/message/${messageId}/status`);
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
}

module.exports = SmsGatewayClient;
```

**app.js** (Express server example):
```javascript
const express = require('express');
const cors = require('cors');
const SmsGatewayClient = require('./services/smsGatewayClient');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize SMS Gateway Client
const smsClient = new SmsGatewayClient({
  baseUrl: 'http://192.168.1.100:8080', // Replace with actual IP
  apiKey: 'sms-gateway-default-key-2024'
});

// Routes
app.post('/api/send-sms', async (req, res) => {
  try {
    const { recipient, message } = req.body;
    
    if (!recipient || !message) {
      return res.status(400).json({ 
        error: 'Recipient and message are required' 
      });
    }

    const result = await smsClient.sendSms(recipient, message);
    
    if (result.success) {
      res.json({ message: 'SMS sent successfully', data: result.data });
    } else {
      res.status(500).json({ error: result.error });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/send-bulk-sms', async (req, res) => {
  try {
    const { recipients, message } = req.body;
    
    if (!recipients || !Array.isArray(recipients) || !message) {
      return res.status(400).json({ 
        error: 'Recipients array and message are required' 
      });
    }

    const result = await smsClient.sendBulkSms(recipients, message);
    
    if (result.success) {
      res.json({ message: 'Bulk SMS sent successfully', data: result.data });
    } else {
      res.status(500).json({ error: result.error });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/gateway-status', async (req, res) => {
  const health = await smsClient.getHealth();
  const stats = await smsClient.getStatistics();
  
  res.json({
    health: health.success ? health.data : { error: health.error },
    statistics: stats.success ? stats.data : { error: stats.error }
  });
});

app.get('/api/recent-messages', async (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  const result = await smsClient.getRecentMessages(limit);
  
  if (result.success) {
    res.json(result.data);
  } else {
    res.status(500).json({ error: result.error });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Start server
app.listen(port, () => {
  console.log(`SMS Gateway API server running on port ${port}`);
  
  // Test gateway connection on startup
  smsClient.getHealth().then(result => {
    if (result.success) {
      console.log('✅ SMS Gateway connection successful');
    } else {
      console.log('❌ SMS Gateway connection failed:', result.error);
    }
  });
});
```

### Network Configuration and Troubleshooting

#### Common Network Issues and Solutions

1. **Gateway Not Accessible**:
   ```bash
   # Test connectivity
   ping 192.168.1.100
   
   # Test port accessibility
   telnet 192.168.1.100 8080
   # or
   nc -zv 192.168.1.100 8080
   ```

2. **Firewall Issues**:
   - Ensure Android device allows incoming connections on port 8080
   - Check router firewall settings
   - Verify WiFi network allows device-to-device communication

3. **IP Address Changes**:
   - Use static IP assignment in router settings
   - Implement dynamic IP discovery in your applications
   - Consider using mDNS/Bonjour for service discovery

#### Environment Variables Setup

Create a `.env` file in your project root:

```env
# SMS Gateway Configuration
SMS_GATEWAY_URL=http://192.168.1.100:8080
SMS_GATEWAY_API_KEY=sms-gateway-default-key-2024
SMS_GATEWAY_TIMEOUT=30000

# For Next.js (prefix with NEXT_PUBLIC_)
NEXT_PUBLIC_SMS_GATEWAY_URL=http://192.168.1.100:8080
NEXT_PUBLIC_SMS_GATEWAY_API_KEY=sms-gateway-default-key-2024

# For React.js (prefix with REACT_APP_)
REACT_APP_SMS_GATEWAY_URL=http://192.168.1.100:8080
REACT_APP_SMS_GATEWAY_API_KEY=sms-gateway-default-key-2024
```

#### Testing Connection

Use this simple test script to verify connectivity:

```bash
#!/bin/bash
# test-gateway.sh

GATEWAY_IP="192.168.1.100"
GATEWAY_PORT="8080"
API_KEY="sms-gateway-default-key-2024"

echo "Testing SMS Gateway connectivity..."

# Test basic connectivity
if ping -c 1 $GATEWAY_IP > /dev/null 2>&1; then
    echo "✅ Device is reachable"
else
    echo "❌ Device not reachable"
    exit 1
fi

# Test port accessibility
if nc -z $GATEWAY_IP $GATEWAY_PORT; then
    echo "✅ Port $GATEWAY_PORT is open"
else
    echo "❌ Port $GATEWAY_PORT is not accessible"
    exit 1
fi

# Test API endpoint
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $API_KEY" \
    http://$GATEWAY_IP:$GATEWAY_PORT/health)

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ SMS Gateway API is responding"
else
    echo "❌ SMS Gateway API not responding (HTTP $HTTP_STATUS)"
fi

echo "Connection test completed."
```

## Installation and Setup

### Prerequisites
- Flutter SDK (3.0 or higher)
- Android SDK
- Android device with SMS capabilities

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd MobileSMSGateway
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Android permissions**
   The app requires the following permissions (already configured in AndroidManifest.xml):
   - SEND_SMS
   - READ_SMS
   - RECEIVE_SMS
   - READ_PHONE_STATE
   - INTERNET
   - ACCESS_NETWORK_STATE
   - FOREGROUND_SERVICE

4. **Build and install**
   ```bash
   flutter build apk --release
   flutter install
   ```

### Configuration

1. **Server Settings**
   - Default port: 8080
   - Default host: 0.0.0.0 (all interfaces)
   - Auto-start server: Enabled

2. **API Keys**
   - Default API key is created automatically
   - Manage keys through the API Keys page
   - Keys can have expiration dates and rate limits

3. **SMS Settings**
   - Retry attempts: 3
   - Retry delay: 30 seconds
   - SIM slot selection available

## Security Considerations

1. **API Key Management**
   - Use strong, unique API keys
   - Regularly rotate keys
   - Set appropriate expiration dates

2. **Network Security**
   - Use HTTPS in production
   - Implement proper firewall rules
   - Consider VPN for remote access

3. **Rate Limiting**
   - Configure appropriate rate limits
   - Monitor for abuse
   - Implement IP-based restrictions if needed

## Troubleshooting

### Common Issues

1. **Server won't start**
   - Check if port is already in use
   - Verify network permissions
   - Check firewall settings

2. **SMS not sending**
   - Verify SIM card is active
   - Check SMS permissions
   - Ensure sufficient balance/plan

3. **API authentication fails**
   - Verify API key format
   - Check key expiration
   - Ensure proper Authorization header

### Logs and Debugging

- Check application logs in the Message Logs page
- Monitor server status on Dashboard
- Use `flutter logs` for detailed debugging

## Performance Optimization

1. **Database Maintenance**
   - Regular cleanup of old logs
   - Index optimization
   - Backup strategies

2. **Memory Management**
   - Message queue limits
   - Background service optimization
   - Resource cleanup

3. **Network Optimization**
   - Connection pooling
   - Request batching
   - Timeout configurations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support and questions:
- Check the troubleshooting section
- Review application logs
- Contact development team

## Version History

- **v1.0.0** - Initial release with full SMS gateway functionality
- Complete REST API implementation
- Material 3 UI design
- Background service support
- C# integration ready