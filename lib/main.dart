import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/sms_service.dart';
import 'services/config_service.dart';
import 'pages/dashboard_page.dart';
import 'pages/configuration_page.dart';
import 'pages/message_logs_page.dart';
import 'pages/api_keys_page.dart';
import 'pages/about_page.dart';
import 'providers/app_state_provider.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await DatabaseService().initialize();
  
  // Try to initialize SMS service, but don't fail if permissions are not available (e.g., on simulator)
  try {
    await SmsService().initialize();
  } catch (e) {
    debugPrint('SMS Service initialization failed (this is expected on simulator): $e');
  }
  
  // Initialize background service
  await BackgroundService.instance.initialize();
  
  // Check if auto-start is enabled and start server if needed
  final configService = ConfigService();
  final serverConfig = await configService.getServerConfig();
  if (serverConfig['auto_start'] == true) {
    try {
      await BackgroundService.instance.startBackgroundService();
      debugPrint('Auto-started SMS Gateway server');
    } catch (e) {
      debugPrint('Failed to auto-start server: $e');
    }
  }
  
  runApp(const SmsGatewayApp());
}

class SmsGatewayApp extends StatelessWidget {
  const SmsGatewayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: MaterialApp(
        title: 'SMS Gateway',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const MainNavigationPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const DashboardPage(),
    const MessageLogsPage(),
    const ConfigurationPage(),
    const ApiKeysPage(),
    const AboutPage(),
  ];

  final List<NavigationDestination> _destinations = [
    const NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    const NavigationDestination(
      icon: Icon(Icons.message_outlined),
      selectedIcon: Icon(Icons.message),
      label: 'Messages',
    ),
    const NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
    const NavigationDestination(
      icon: Icon(Icons.key_outlined),
      selectedIcon: Icon(Icons.key),
      label: 'API Keys',
    ),
    const NavigationDestination(
      icon: Icon(Icons.info_outline),
      selectedIcon: Icon(Icons.info),
      label: 'About',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
