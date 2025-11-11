using System;
using System.Net.Http;
using System.Text;
using Newtonsoft.Json;
using System.Threading.Tasks;
using System.Net;

namespace SmsGatewayTest
{
    class Program
    {
        private static readonly string baseUrl = "http://localhost:8080"; // Using localhost with adb port forwarding
        private static readonly string apiKey = "sms-gateway-default-key-2024"; // Default API key
        private static readonly HttpClient client = new HttpClient();

        static async Task Main(string[] args)
        {
            Console.WriteLine("SMS Gateway Connectivity Test");
            Console.WriteLine("============================");
            Console.WriteLine($"Base URL: {baseUrl}");
            Console.WriteLine($"API Key: {apiKey}");
            Console.WriteLine();

            // Set default headers
            client.DefaultRequestHeaders.Add("X-API-Key", apiKey);
            client.Timeout = TimeSpan.FromSeconds(30);

            // Test network connectivity first
            await TestNetworkConnectivity();

            int passedTests = 0;
            int totalTests = 6;

            // Test 1: Health Check
            Console.WriteLine("1. Testing health check endpoint...");
            if (await TestHealthCheck())
                passedTests++;

            // Test 2: Device Info
            Console.WriteLine("\n2. Testing device info endpoint...");
            if (await TestDeviceInfo())
                passedTests++;

            // Test 3: Statistics
            Console.WriteLine("\n3. Testing statistics endpoint...");
            if (await TestStatistics())
                passedTests++;

            // Test 4: Recent Messages
            Console.WriteLine("\n4. Testing recent messages endpoint...");
            if (await TestRecentMessages())
                passedTests++;

            // Test 5: Send SMS
            Console.WriteLine("\n5. Testing send SMS endpoint...");
            if (await TestSendSms())
                passedTests++;

            // Test 6: CORS Support
            Console.WriteLine("\n6. Testing CORS support...");
            if (await TestCors())
                passedTests++;

            // Summary
            Console.WriteLine("\n================================");
            Console.WriteLine("Test Summary:");
            Console.WriteLine($"Passed: {passedTests}/{totalTests}");

            if (passedTests == totalTests)
            {
                Console.WriteLine("🎉 All tests passed! SMS Gateway is working correctly.");
                Environment.Exit(0);
            }
            else
            {
                Console.WriteLine("❌ Some tests failed. Check the server configuration.");
                Environment.Exit(1);
            }
        }

        static async Task TestNetworkConnectivity()
        {
            Console.WriteLine("Testing Network Connectivity...");
            try
            {
                var uri = new Uri(baseUrl);
                using (var tcpClient = new System.Net.Sockets.TcpClient())
                {
                    await tcpClient.ConnectAsync(uri.Host, uri.Port);
                    Console.WriteLine($"✓ TCP connection to {uri.Host}:{uri.Port} successful");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ Network connectivity error: {ex.Message}");
                Console.WriteLine("  Make sure the SMS Gateway app is running on the device");
                Console.WriteLine("  and the device is connected to the same WiFi network");
            }
            Console.WriteLine();
        }

        static async Task<bool> TestHealthCheck()
        {
            try
            {
                var response = await client.GetAsync($"{baseUrl}/health");
                Console.WriteLine($"✓ GET /health: {(int)response.StatusCode}");
                
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"  Response: {content}");
                    return true;
                }
                else
                {
                    Console.WriteLine($"  Error: {response.StatusCode}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ GET /health: Connection failed - {ex.Message}");
                return false;
            }
        }

        static async Task<bool> TestDeviceInfo()
        {
            try
            {
                var response = await client.GetAsync($"{baseUrl}/device-info");
                Console.WriteLine($"✓ GET /device-info: {(int)response.StatusCode}");
                
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"  Response: {content}");
                    return true;
                }
                else
                {
                    Console.WriteLine($"  Error: {response.StatusCode}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ GET /device-info: Connection failed - {ex.Message}");
                return false;
            }
        }

        static async Task<bool> TestStatistics()
        {
            try
            {
                var response = await client.GetAsync($"{baseUrl}/statistics");
                Console.WriteLine($"✓ GET /statistics: {(int)response.StatusCode}");
                
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"  Response: {content}");
                    return true;
                }
                else
                {
                    Console.WriteLine($"  Error: {response.StatusCode}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ GET /statistics: Connection failed - {ex.Message}");
                return false;
            }
        }

        static async Task<bool> TestRecentMessages()
        {
            try
            {
                var response = await client.GetAsync($"{baseUrl}/messages/recent");
                Console.WriteLine($"✓ GET /messages/recent: {(int)response.StatusCode}");
                
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"  Response: {content}");
                    return true;
                }
                else
                {
                    Console.WriteLine($"  Error: {response.StatusCode}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ GET /messages/recent: Connection failed - {ex.Message}");
                return false;
            }
        }

        static async Task<bool> TestSendSms()
        {
            try
            {
                var smsData = new
                {
                    recipient = "+1234567890",
                    message = "Test message from C# connectivity test",
                    priority = "normal"
                };

                var json = JsonConvert.SerializeObject(smsData);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                
                var response = await client.PostAsync($"{baseUrl}/send-sms", content);
                Console.WriteLine($"✓ POST /send-sms: {(int)response.StatusCode}");
                
                if (response.IsSuccessStatusCode)
                {
                    var responseContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"  Response: {responseContent}");
                    return true;
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"  Error: {errorContent}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ POST /send-sms: Connection failed - {ex.Message}");
                return false;
            }
        }

        static async Task<bool> TestCors()
        {
            try
            {
                var request = new HttpRequestMessage(HttpMethod.Options, $"{baseUrl}/send-sms");
                request.Headers.Add("Origin", "http://localhost:3000");
                request.Headers.Add("Access-Control-Request-Method", "POST");
                request.Headers.Add("Access-Control-Request-Headers", "Content-Type, X-API-Key");
                
                var response = await client.SendAsync(request);
                Console.WriteLine($"✓ OPTIONS /send-sms: {(int)response.StatusCode}");
                
                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine("  CORS Headers:");
                    foreach (var header in response.Headers)
                    {
                        Console.WriteLine($"    {header.Key}: {string.Join(", ", header.Value)}");
                    }
                    return true;
                }
                else
                {
                    Console.WriteLine($"  Error: {response.StatusCode}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"✗ OPTIONS /send-sms: Connection failed - {ex.Message}");
                return false;
            }
        }
    }
}