import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => BusDataProvider()),
      ],
      child: const SmartCampusApp(),
    ),
  );
}

class Bus {
  final String id;
  final String name;
  String routeId;
  String driverId;
  final int capacity;
  bool isActive;
  int passengerCount;
  LatLng? position;
  double speed;
  String nextStop;
  String nextStopTime;
  Bus({
    required this.id,
    required this.name,
    required this.routeId,
    required this.driverId,
    required this.capacity,
    this.isActive = false,
    this.passengerCount = 0,
    this.position,
    this.speed = 0.0,
    this.nextStop = '',
    this.nextStopTime = '',
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'routeId': routeId,
      'driverId': driverId,
      'capacity': capacity,
      'isActive': isActive,
      'passengerCount': passengerCount,
      'position': position != null ? {'lat': position!.latitude, 'lng': position!.longitude} : null,
      'speed': speed,
      'nextStop': nextStop,
      'nextStopTime': nextStopTime,
    };
  }
  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'],
      name: json['name'],
      routeId: json['routeId'],
      driverId: json['driverId'],
      capacity: json['capacity'],
      isActive: json['isActive'] ?? false,
      passengerCount: json['passengerCount'] ?? 0,
      position: json['position'] != null ? LatLng(json['position']['lat'], json['position']['lng']) : null,
      speed: json['speed'] ?? 0.0,
      nextStop: json['nextStop'] ?? '',
      nextStopTime: json['nextStopTime'] ?? '',
    );
  }
}

class Route {
  final String id;
  final String name;
  final String number;
  final List<String> stops;
  final List<LatLng> stopLocations;
  final List<String> stopTimes;
  final Map<String, List<String>> schedule;
  Route({
    required this.id,
    required this.name,
    required this.number,
    required this.stops,
    required this.stopLocations,
    required this.stopTimes,
    required this.schedule,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'number': number,
      'stops': stops,
      'stopLocations': stopLocations.map((loc) => {'lat': loc.latitude, 'lng': loc.longitude}).toList(),
      'stopTimes': stopTimes,
      'schedule': schedule,
    };
  }
  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'],
      name: json['name'],
      number: json['number'],
      stops: List<String>.from(json['stops']),
      stopLocations: (json['stopLocations'] as List).map((loc) => LatLng(loc['lat'], loc['lng'])).toList(),
      stopTimes: List<String>.from(json['stopTimes']),
      schedule: Map<String, List<String>>.from(json['schedule']),
    );
  }
}

class Driver {
  final String id;
  String name;
  String email;
  String busId;
  String password;
  bool isActive;
  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.busId,
    required this.password,
    this.isActive = true,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'busId': busId,
      'password': password,
      'isActive': isActive,
    };
  }
  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      busId: json['busId'],
      password: json['password'],
      isActive: json['isActive'] ?? true,
    );
  }
}

class AuthProvider with ChangeNotifier {
  String _userRole = 'student';
  bool _isLoggedIn = false;
  String _userId = '';
  String _userName = '';
  String get userRole => _userRole;
  bool get isLoggedIn => _isLoggedIn;
  String get userId => _userId;
  String get userName => _userName;

  Future<void> loginAsStudent() async {
    _userRole = 'student';
    _isLoggedIn = true;
    _userId = 'student';
    _userName = 'Student';
    notifyListeners();
  }

  Future<void> loginAsDriver(String driverId, String password, BuildContext context) async {
    final adminProvider = context.read<AdminProvider>();
    final busDataProvider = context.read<BusDataProvider>();
    try {
      final driver = adminProvider.drivers.firstWhere((d) => d.id == driverId && d.password == password && d.isActive);
      _userRole = 'driver';
      _isLoggedIn = true;
      _userId = driverId;
      _userName = driver.name;

      // Sync bus data immediately after login
      busDataProvider.setBuses(adminProvider.buses);

      notifyListeners();
    } catch (e) {
      throw Exception('Invalid driver ID or password');
    }
  }

  Future<void> loginAsAdmin(String username, String password) async {
    if (username == 'admin' && password == 'admin123') {
      _userRole = 'admin';
      _isLoggedIn = true;
      _userId = 'admin';
      _userName = 'Administrator';
      notifyListeners();
    } else {
      throw Exception('Use: admin / admin123');
    }
  }

  Future<void> logout() async {
    _userRole = 'student';
    _isLoggedIn = false;
    _userId = '';
    _userName = '';
    notifyListeners();
  }
}

class AdminProvider with ChangeNotifier {
  List<Driver> _drivers = [];
  List<Route> _routes = [];
  List<Bus> _buses = [];
  List<Driver> get drivers => _drivers;
  List<Route> get routes => _routes;
  List<Bus> get buses => _buses;

  AdminProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final driversJson = prefs.getStringList('drivers') ?? [];
    _drivers = driversJson.map((json) => Driver.fromJson(jsonDecode(json))).toList();
    final routesJson = prefs.getStringList('routes') ?? [];
    _routes = routesJson.map((json) => Route.fromJson(jsonDecode(json))).toList();
    final busesJson = prefs.getStringList('buses') ?? [];
    _buses = busesJson.map((json) => Bus.fromJson(jsonDecode(json))).toList();

    if (_routes.isEmpty) _initializeSampleData();
    if (_buses.isEmpty) _initializeSampleBuses();
    if (_drivers.isEmpty) _initializeSampleDrivers();

    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('drivers', _drivers.map((driver) => jsonEncode(driver.toJson())).toList());
    prefs.setStringList('routes', _routes.map((route) => jsonEncode(route.toJson())).toList());
    prefs.setStringList('buses', _buses.map((bus) => jsonEncode(bus.toJson())).toList());
  }

  void _initializeSampleData() {
    _routes = [
      Route(
        id: '1',
        name: 'Campus Loop',
        number: 'CL-101',
        stops: ['Main Gate', 'Library', 'Student Center', 'Science Building'],
        stopLocations: [
          const LatLng(37.7749, -122.4194),
          const LatLng(37.7755, -122.4184),
          const LatLng(37.7760, -122.4174),
          const LatLng(37.7765, -122.4164),
        ],
        stopTimes: ['0min', '3min', '6min', '9min'],
        schedule: {
          'Weekdays': ['07:00', '08:00', '12:00', '16:00'],
        },
      ),
    ];
    _saveData();
  }

  void _initializeSampleBuses() {
    _buses = [
      Bus(id: '1', name: 'Campus Bus 01', routeId: '1', driverId: '1', capacity: 40),
      Bus(id: '2', name: 'Campus Bus 02', routeId: '1', driverId: '2', capacity: 35),
    ];
    _saveData();
  }

  void _initializeSampleDrivers() {
    _drivers = [
      Driver(id: '1', name: 'John Smith', email: 'john@campus.edu', busId: '1', password: 'driver001'),
      Driver(id: '2', name: 'Maria Garcia', email: 'maria@campus.edu', busId: '2', password: 'driver002'),
    ];
    _saveData();
  }

  void addDriver(String name, String email, String password) {
    final newDriver = Driver(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      busId: '',
      password: password,
    );
    _drivers.add(newDriver);
    _saveData();
    notifyListeners();
  }

  void assignBusToDriver(String driverId, String busId, BuildContext context) {
    final driverIndex = _drivers.indexWhere((d) => d.id == driverId);
    final busIndex = _buses.indexWhere((b) => b.id == busId);

    if (driverIndex != -1 && busIndex != -1) {
      // Remove driver from current bus if any
      for (var bus in _buses) {
        if (bus.driverId == driverId) {
          bus.driverId = '';
        }
      }

      // Assign new bus to driver
      _drivers[driverIndex].busId = busId;
      _buses[busIndex].driverId = driverId;

      // Sync with BusDataProvider
      final busDataProvider = context.read<BusDataProvider>();
      busDataProvider.setBuses(_buses);

      _saveData();
      notifyListeners();
    }
  }

  void removeBusFromDriver(String driverId) {
    final driverIndex = _drivers.indexWhere((d) => d.id == driverId);
    if (driverIndex != -1) {
      // Remove driver from bus
      for (var bus in _buses) {
        if (bus.driverId == driverId) {
          bus.driverId = '';
        }
      }
      _drivers[driverIndex].busId = '';
      _saveData();
      notifyListeners();
    }
  }

  void updateDriver(String id, String name, String email, String password, bool isActive) {
    final index = _drivers.indexWhere((d) => d.id == id);
    if (index != -1) {
      _drivers[index].name = name;
      _drivers[index].email = email;
      _drivers[index].password = password;
      _drivers[index].isActive = isActive;
      _saveData();
      notifyListeners();
    }
  }

  void deleteDriver(String id) {
    // Remove driver from bus first
    removeBusFromDriver(id);
    _drivers.removeWhere((d) => d.id == id);
    _saveData();
    notifyListeners();
  }

  void addRoute(String name, String number) {
    final newRoute = Route(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      number: number,
      stops: ['Stop 1', 'Stop 2', 'Stop 3'],
      stopLocations: [
        const LatLng(37.7749, -122.4194),
        const LatLng(37.7755, -122.4184),
        const LatLng(37.7760, -122.4174),
      ],
      stopTimes: ['0min', '3min', '6min'],
      schedule: {'Weekdays': ['08:00', '12:00', '16:00']},
    );
    _routes.add(newRoute);
    _saveData();
    notifyListeners();
  }

  void addBus(String name, String routeId, int capacity) {
    final newBus = Bus(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      routeId: routeId,
      driverId: '',
      capacity: capacity,
    );
    _buses.add(newBus);
    _saveData();
    notifyListeners();
  }

  void assignRouteToBus(String busId, String routeId) {
    final busIndex = _buses.indexWhere((b) => b.id == busId);
    if (busIndex != -1) {
      _buses[busIndex].routeId = routeId;
      _saveData();
      notifyListeners();
    }
  }
}

class BusDataProvider with ChangeNotifier {
  List<Bus> _buses = [];
  bool _isLoading = true;
  final Map<String, StreamSubscription<Position>> _locationSubscriptions = {};
  List<Bus> get buses => _buses;
  bool get isLoading => _isLoading;
  int get activeBusesCount => _buses.where((bus) => bus.isActive).length;

  BusDataProvider() {
    _initializeData();
  }

  void _initializeData() {
    _isLoading = false;
    notifyListeners();
  }

  void setBuses(List<Bus> buses) {
    _buses = List.from(buses);
    notifyListeners();
  }

  Future<void> startLocationSharing(String busId, BuildContext context) async {
    final adminProvider = context.read<AdminProvider>();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Location permissions denied');
    }
    if (permission == LocationPermission.deniedForever) throw Exception('Location permissions permanently denied');

    // Set initial position and route info
    final busIndex = _buses.indexWhere((bus) => bus.id == busId);
    if (busIndex != -1) {
      _buses[busIndex].position = const LatLng(37.7749, -122.4194);
      _updateNextStopInfo(_buses[busIndex], adminProvider);
    }

    final locationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 10),
    ).listen((Position position) {
      updateBusLocation(busId, LatLng(position.latitude, position.longitude), position.speed, adminProvider);
    });

    _locationSubscriptions[busId] = locationStream;
    updateBusStatus(busId, true);
  }

  void stopLocationSharing(String busId) {
    _locationSubscriptions[busId]?.cancel();
    _locationSubscriptions.remove(busId);
    updateBusStatus(busId, false);
  }

  void updateBusLocation(String busId, LatLng newPosition, double speed, AdminProvider adminProvider) {
    final busIndex = _buses.indexWhere((bus) => bus.id == busId);
    if (busIndex != -1) {
      _buses[busIndex].position = newPosition;
      _buses[busIndex].speed = speed;
      _updateNextStopInfo(_buses[busIndex], adminProvider);
      notifyListeners();
    }
  }

  void _updateNextStopInfo(Bus bus, AdminProvider adminProvider) {
    try {
      final route = adminProvider.routes.firstWhere((r) => r.id == bus.routeId);
      if (route.stops.isNotEmpty) {
        if (bus.nextStop.isEmpty) bus.nextStop = route.stops[0];
        bus.nextStopTime = '${Random().nextInt(5) + 1} min';
      }
    } catch (e) {
      bus.nextStop = 'No Route Assigned';
      bus.nextStopTime = 'N/A';
    }
  }

  void updateBusStatus(String busId, bool isActive) {
    final busIndex = _buses.indexWhere((bus) => bus.id == busId);
    if (busIndex != -1) {
      _buses[busIndex].isActive = isActive;
      notifyListeners();
    }
  }

  void updatePassengerCount(String busId, int count) {
    final busIndex = _buses.indexWhere((bus) => bus.id == busId);
    if (busIndex != -1) {
      _buses[busIndex].passengerCount = count;
      notifyListeners();
    }
  }

  Bus? getBusById(String busId) {
    try {
      return _buses.firstWhere((bus) => bus.id == busId);
    } catch (e) {
      return null;
    }
  }

  Bus? getBusByDriverId(String driverId) {
    try {
      return _buses.firstWhere((bus) => bus.driverId == driverId);
    } catch (e) {
      return null;
    }
  }

  List<Bus> getActiveBuses() {
    return _buses.where((bus) => bus.isActive && bus.position != null).toList();
  }

  @override
  void dispose() {
    for (var subscription in _locationSubscriptions.values) {
      subscription.cancel();
    }
    _locationSubscriptions.clear();
    super.dispose();
  }
}

class SmartCampusApp extends StatefulWidget {
  const SmartCampusApp({super.key});
  @override
  State<SmartCampusApp> createState() => _SmartCampusAppState();
}

class _SmartCampusAppState extends State<SmartCampusApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = context.read<AdminProvider>();
      final busDataProvider = context.read<BusDataProvider>();
      busDataProvider.setBuses(adminProvider.buses);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Bus Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final String _selectedRole = 'student'; // Made final since it's not used
  bool _isLoading = false;

  Future<void> _loginAsStudent() async {
    setState(() { _isLoading = true; });
    await context.read<AuthProvider>().loginAsStudent();
    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (authProvider.isLoggedIn) return const MainAppScreen();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(children: [
            const SizedBox(height: 40),
            const Icon(Icons.directions_bus, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('Campus Bus Tracker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 10),
            const Text('Track buses in real-time', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 40),

            if (_isLoading) const CircularProgressIndicator() else Column(children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loginAsStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Continue as Student'),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showDriverLogin(context),
                  child: const Text('Driver Login'),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showAdminLogin(context),
                  child: const Text('Admin Login'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showDriverLogin(BuildContext context) {
    final driverIdController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Driver Login'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: driverIdController, decoration: const InputDecoration(labelText: 'Driver ID')),
          const SizedBox(height: 10),
          TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 10),
          const Text('Sample: ID: 1, Pass: driver001', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (isLoading) const CircularProgressIndicator() else TextButton(
            onPressed: () async {
              setState(() => isLoading = true);
              try {
                await context.read<AuthProvider>().loginAsDriver(driverIdController.text, passwordController.text, context);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
              setState(() => isLoading = false);
            },
            child: const Text('Login'),
          ),
        ],
      )),
    );
  }

  void _showAdminLogin(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Admin Login'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 10),
          const Text('Default: admin / admin123', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (isLoading) const CircularProgressIndicator() else TextButton(
            onPressed: () async {
              setState(() => isLoading = true);
              try {
                await context.read<AuthProvider>().loginAsAdmin(usernameController.text, passwordController.text);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
              setState(() => isLoading = false);
            },
            child: const Text('Login'),
          ),
        ],
      )),
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});
  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;
  final List<Widget> _studentScreens = [const StudentMapScreen(), const StudentScheduleScreen()];
  final List<Widget> _driverScreens = [const DriverMapScreen(), const DriverControlScreen()];
  final List<Widget> _adminScreens = [const AdminDashboardScreen(), const AdminDriversScreen(), const AdminBusesScreen(), const AdminRoutesScreen()];

  List<Widget> _getScreensForRole(String role) {
    switch (role) {
      case 'driver': return _driverScreens;
      case 'admin': return _adminScreens;
      default: return _studentScreens;
    }
  }

  List<BottomNavigationBarItem> _getNavItemsForRole(String role) {
    switch (role) {
      case 'driver': return const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'My Bus'),
      ];
      case 'admin': return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Drivers'),
        BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Buses'),
        BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Routes'),
      ];
      default: return const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Live Map'),
        BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final screens = _getScreensForRole(authProvider.userRole);
    final navItems = _getNavItemsForRole(authProvider.userRole);
    return Scaffold(
      appBar: AppBar(
        title: Text('Campus Bus - ${authProvider.userName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () { context.read<AuthProvider>().logout(); })],
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) { setState(() { _currentIndex = index; }); },
        items: navItems,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class StudentMapScreen extends StatelessWidget {
  const StudentMapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final busDataProvider = context.watch<BusDataProvider>();
    final adminProvider = context.watch<AdminProvider>();

    // Combine data from both providers
    final activeBuses = busDataProvider.getActiveBuses();
    final allBuses = adminProvider.buses;

    // If no active buses in BusDataProvider, check admin provider
    final displayBuses = activeBuses.isNotEmpty ? activeBuses :
    allBuses.where((bus) => bus.isActive).toList();

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.blue[50],
        child: Row(children: [
          const Icon(Icons.directions_bus, color: Colors.blue),
          const SizedBox(width: 8),
          Text('${displayBuses.length} Active Buses', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(child: displayBuses.isEmpty ? const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.directions_bus_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No Buses Running', style: TextStyle(fontSize: 18, color: Colors.grey)),
          Text('Drivers need to start service', style: TextStyle(color: Colors.grey)),
        ]),
      ) : FlutterMap(
        options: MapOptions(
          initialCenter: const LatLng(37.7749, -122.4194), // Fixed: center -> initialCenter
          initialZoom: 15.0, // Fixed: zoom -> initialZoom
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.smartcampus'),
          MarkerLayer(markers: [
            for (final bus in displayBuses)
              Marker(
                point: bus.position!,
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () { _showBusInfo(context, bus); },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white, width: 3)),
                    child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
                  ),
                ),
              ),
          ]),
        ],
      )),
    ]);
  }

  void _showBusInfo(BuildContext context, Bus bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bus.name),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Next Stop: ${bus.nextStop}'),
          Text('Arrival: ${bus.nextStopTime}'),
          Text('Passengers: ${bus.passengerCount}/${bus.capacity}'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class StudentScheduleScreen extends StatelessWidget {
  const StudentScheduleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final busDataProvider = context.watch<BusDataProvider>();
    final activeBuses = busDataProvider.getActiveBuses();
    final allBuses = busDataProvider.buses;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bus Schedule'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Active Buses'),
            Tab(text: 'All Buses'),
          ]),
        ),
        body: TabBarView(children: [
          _buildBusList(activeBuses, true),
          _buildBusList(allBuses, false),
        ]),
      ),
    );
  }

  Widget _buildBusList(List<Bus> buses, bool isActive) {
    if (buses.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(isActive ? Icons.directions_bus_rounded : Icons.directions_bus_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        Text(isActive ? 'No Active Buses' : 'No Buses Available', style: const TextStyle(fontSize: 18, color: Colors.grey)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: buses.length,
      itemBuilder: (context, index) {
        final bus = buses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: bus.isActive ? Colors.green : Colors.grey, child: const Icon(Icons.directions_bus, color: Colors.white)),
            title: Text(bus.name),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Capacity: ${bus.passengerCount}/${bus.capacity}'),
              Text(bus.isActive ? 'Active - ${bus.nextStopTime} to ${bus.nextStop}' : 'Inactive', style: TextStyle(color: bus.isActive ? Colors.green : Colors.grey)),
            ]),
          ),
        );
      },
    );
  }
}

class DriverMapScreen extends StatelessWidget {
  const DriverMapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final busDataProvider = context.watch<BusDataProvider>();
    final driverBus = busDataProvider.getBusByDriverId(authProvider.userId);

    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: driverBus?.position ?? const LatLng(37.7749, -122.4194), // Fixed: center -> initialCenter
          initialZoom: 16.0, // Fixed: zoom -> initialZoom
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.smartcampus'),
          if (driverBus?.position != null) MarkerLayer(markers: [
            Marker(
              point: driverBus!.position!,
              width: 60,
              height: 60,
              child: Container(
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white, width: 4)),
                child: const Icon(Icons.directions_bus, color: Colors.white, size: 30),
              ),
            ),
          ]),
        ],
      ),
      if (driverBus == null) const Center(child: Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No bus assigned to your account')))),
    ]);
  }
}

class DriverControlScreen extends StatelessWidget {
  const DriverControlScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final busDataProvider = context.watch<BusDataProvider>();
    final adminProvider = context.watch<AdminProvider>();

    // Get bus from both providers to ensure sync
    Bus? driverBus = busDataProvider.getBusByDriverId(authProvider.userId);
    if (driverBus == null) {
      // Fallback to admin provider data
      try {
        driverBus = adminProvider.buses.firstWhere(
                (bus) => bus.driverId == authProvider.userId
        );
      } catch (e) {
        driverBus = null;
      }
    }

    if (driverBus == null) {
      return const Center(child: Card(child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No bus assigned to your account')
      )));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.directions_bus, size: 40),
              title: Text(driverBus.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              subtitle: Text('Next Stop: ${driverBus.nextStop}'),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildInfoCard('Capacity', '${driverBus.passengerCount}/${driverBus.capacity}'),
              _buildInfoCard('Next Stop', driverBus.nextStop),
              _buildInfoCard('Arrival', driverBus.nextStopTime),
            ]),
          ]),
        )),
        const SizedBox(height: 20),
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bus Controls', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: driverBus.isActive ? null : () {
                  if (driverBus != null) {
                    busDataProvider.startLocationSharing(driverBus.id, context);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Service'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: driverBus.isActive ? () {
                  if (driverBus != null) {
                    busDataProvider.stopLocationSharing(driverBus.id);
                  }
                } : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Service'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              )),
            ]),
            const SizedBox(height: 20),
            const Text('Passenger Count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: () {
                  if (driverBus != null && driverBus.passengerCount > 0) {
                    busDataProvider.updatePassengerCount(driverBus.id, driverBus.passengerCount - 1);
                  }
                },
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(backgroundColor: Colors.grey[200]),
              ),
              const SizedBox(width: 20),
              Text('${driverBus.passengerCount}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 20),
              IconButton(
                onPressed: () {
                  if (driverBus != null && driverBus.passengerCount < driverBus.capacity) {
                    busDataProvider.updatePassengerCount(driverBus.id, driverBus.passengerCount + 1);
                  }
                },
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: Colors.grey[200]),
              ),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Column(children: [
      Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final busDataProvider = context.watch<BusDataProvider>();
    final adminProvider = context.watch<AdminProvider>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _buildStatCard('Active Buses', busDataProvider.activeBusesCount.toString(), Icons.directions_bus, Colors.blue),
          _buildStatCard('Total Buses', adminProvider.buses.length.toString(), Icons.directions_bus, Colors.green),
          _buildStatCard('Drivers', adminProvider.drivers.length.toString(), Icons.people, Colors.orange),
          _buildStatCard('Routes', adminProvider.routes.length.toString(), Icons.route, Colors.purple),
        ]),
      ]),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ]),
    ));
  }
}

class AdminDriversScreen extends StatelessWidget {
  const AdminDriversScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: adminProvider.drivers.length,
        itemBuilder: (context, index) {
          final driver = adminProvider.drivers[index];
          final assignedBus = adminProvider.buses.firstWhere((b) => b.id == driver.busId, orElse: () => Bus(id: '', name: 'No Bus', routeId: '', driverId: '', capacity: 0));
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: driver.isActive ? Colors.green : Colors.grey, child: const Icon(Icons.person, color: Colors.white)),
              title: Text(driver.name),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bus: ${assignedBus.name}'),
                Text('ID: ${driver.id} • Pass: ${driver.password}'),
              ]),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'assign', child: Text('Assign Bus')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (value) {
                  if (value == 'assign') _showAssignBusDialog(context, driver, adminProvider);
                  if (value == 'edit') _showEditDriverDialog(context, driver, adminProvider);
                  if (value == 'delete') _showDeleteDriverDialog(context, driver.id, adminProvider);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDriverDialog(context, adminProvider),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDriverDialog(BuildContext context, AdminProvider adminProvider) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Driver'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
          TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (nameController.text.isNotEmpty && passwordController.text.isNotEmpty) {
              adminProvider.addDriver(nameController.text, emailController.text, passwordController.text);
              Navigator.pop(context);
            }
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showAssignBusDialog(BuildContext context, Driver driver, AdminProvider adminProvider) {
    String? selectedBusId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Assign Bus to Driver'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Select a bus to assign:'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedBusId,
            items: adminProvider.buses.map((bus) => DropdownMenuItem(value: bus.id, child: Text(bus.name))).toList(),
            onChanged: (value) => setState(() => selectedBusId = value),
            decoration: const InputDecoration(labelText: 'Select Bus'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: selectedBusId == null ? null : () {
              adminProvider.assignBusToDriver(driver.id, selectedBusId!, context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus assigned successfully!')));
            },
            child: const Text('Assign'),
          ),
        ],
      )),
    );
  }

  void _showEditDriverDialog(BuildContext context, Driver driver, AdminProvider adminProvider) {
    final nameController = TextEditingController(text: driver.name);
    final emailController = TextEditingController(text: driver.email);
    final passwordController = TextEditingController(text: driver.password);
    bool isActive = driver.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Edit Driver'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          Row(children: [
            const Text('Active:'),
            const SizedBox(width: 8),
            Switch(value: isActive, onChanged: (value) => setState(() => isActive = value)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            adminProvider.updateDriver(driver.id, nameController.text, emailController.text, passwordController.text, isActive);
            Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      )),
    );
  }

  void _showDeleteDriverDialog(BuildContext context, String driverId, AdminProvider adminProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: const Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            adminProvider.deleteDriver(driverId);
            Navigator.pop(context);
          }, child: const Text('Delete')),
        ],
      ),
    );
  }
}

class AdminBusesScreen extends StatelessWidget {
  const AdminBusesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: adminProvider.buses.length,
        itemBuilder: (context, index) {
          final bus = adminProvider.buses[index];
          String routeName = 'No Route';
          try {
            final route = adminProvider.routes.firstWhere((r) => r.id == bus.routeId);
            routeName = route.name;
          } catch (e) {}

          String driverName = 'No Driver';
          try {
            final driver = adminProvider.drivers.firstWhere((d) => d.id == bus.driverId);
            driverName = driver.name;
          } catch (e) {}

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: bus.isActive ? Colors.green : Colors.grey, child: const Icon(Icons.directions_bus, color: Colors.white)),
              title: Text(bus.name),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Route: $routeName'),
                Text('Driver: $driverName'),
                Text('Capacity: ${bus.capacity} • ${bus.isActive ? 'Active' : 'Inactive'}'),
              ]),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'assign_route', child: Text('Assign Route')),
                ],
                onSelected: (value) {
                  if (value == 'assign_route') _showAssignRouteDialog(context, bus, adminProvider);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBusDialog(context, adminProvider),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddBusDialog(BuildContext context, AdminProvider adminProvider) {
    final nameController = TextEditingController();
    final capacityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bus'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Bus Name')),
          TextField(controller: capacityController, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (nameController.text.isNotEmpty && capacityController.text.isNotEmpty) {
              adminProvider.addBus(nameController.text, '1', int.parse(capacityController.text));
              Navigator.pop(context);
            }
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showAssignRouteDialog(BuildContext context, Bus bus, AdminProvider adminProvider) {
    String? selectedRouteId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Assign Route to Bus'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Select a route to assign:'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedRouteId,
            items: adminProvider.routes.map((route) => DropdownMenuItem(value: route.id, child: Text(route.name))).toList(),
            onChanged: (value) => setState(() => selectedRouteId = value),
            decoration: const InputDecoration(labelText: 'Select Route'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: selectedRouteId == null ? null : () {
              adminProvider.assignRouteToBus(bus.id, selectedRouteId!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route assigned successfully!')));
            },
            child: const Text('Assign'),
          ),
        ],
      )),
    );
  }
}

class AdminRoutesScreen extends StatelessWidget {
  const AdminRoutesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: adminProvider.routes.length,
        itemBuilder: (context, index) {
          final route = adminProvider.routes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.route, size: 40, color: Colors.purple),
              title: Text('${route.number} - ${route.name}'),
              subtitle: Text('${route.stops.length} stops'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRouteDialog(context, adminProvider),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRouteDialog(BuildContext context, AdminProvider adminProvider) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Route'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Route Name')),
          TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Route Number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (nameController.text.isNotEmpty && numberController.text.isNotEmpty) {
              adminProvider.addRoute(nameController.text, numberController.text);
              Navigator.pop(context);
            }
          }, child: const Text('Add')),
        ],
      ),
    );
  }
}