import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'appointment_scheduler.dart';
import 'app_notifications.dart';
import 'app_settings.dart';
import 'constants.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'try_on_webview_screen.dart';

class Main {
  static const String baseUrl = 'https://gonzalesvisionclinic.onrender.com/api';
}

const Map<String, String> jsonHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

const Color primaryBlue = Color(0xFF0F76FF);
const Color surfaceWhite = Color(0xFFFFFFFF);
const Color backgroundGray = Color(0xFFF4F7FB);

String normalizeAppointmentStatus(dynamic rawStatus) {
  final value = rawStatus?.toString().trim();
  if (value == null || value.isEmpty) {
    return 'Pending';
  }

  final normalized = value.toLowerCase();

  if (normalized == 'requested' ||
      normalized == 'pending' ||
      normalized == 'new' ||
      normalized == 'submitted') {
    return 'Pending';
  }

  if (normalized == 'confirmed' ||
      normalized == 'approved' ||
      normalized == 'accepted') {
    return 'Confirmed';
  }

  if (normalized == 'cancelled' ||
      normalized == 'canceled' ||
      normalized == 'rejected' ||
      normalized == 'declined') {
    return 'Cancelled';
  }

  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

String resolveFrameImageUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return '';
  }

  final cleaned = rawUrl.trim();

  if (cleaned.startsWith('http://') ||
      cleaned.startsWith('https://')) {
    return cleaned;
  }

  if (cleaned.startsWith('/')) {
    return '$apiBaseUrl$cleaned';
  }

  return '$apiBaseUrl/${cleaned.replaceFirst(RegExp(r'^/+'), '')}';
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    appSettingsController.load();
    notificationsController.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appSettingsController,
      builder: (BuildContext context, settings, Widget? child) {
        final currentSettings = settings as dynamic;
        return MaterialApp(
          title: 'Gonzales Vision Clinic',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryBlue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: backgroundGray,
            appBarTheme: const AppBarTheme(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: surfaceWhite,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  currentSettings.largeTextOn ? 1.3 : 1.0,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthScreen(),
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  String _selectedGender = 'Male';

  bool _isLogin = true;
  bool _isLoading = false;

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 3650)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDateOfBirth = picked;
      _ageController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final endpoint = _isLogin
        ? '/api/patients/login'
        : '/api/patients/register';

    final uri = Uri.parse('$apiBaseUrl$endpoint');

    // =====================================================
    // LOGIN
    // =====================================================

    if (_isLogin) {
      final payload = {
        'email': _emailController.text.trim().toLowerCase(),
        'password': _passwordController.text,
      };

      final response = await http
          .post(
            uri,
            headers: jsonHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = {};
      }

      debugPrint('LOGIN STATUS: ${response.statusCode}');
      debugPrint('LOGIN RESPONSE: ${response.body}');

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Login successful',
            ),
          ),
        );

        // =================================================
        // YOUR BACKEND RETURNS THE PATIENT DIRECTLY
        // =================================================

        final profileData = <String, dynamic>{};

        profileData['patient_id'] =
            data['patient_id'] ??
            data['user_id'] ??
            data['id'] ??
            '';

        profileData['email'] =
            data['email'] ?? '';

        profileData['first_name'] = '';
        profileData['last_name'] = '';

        profileData['contact_number'] =
            data['contact_number'] ??
            data['contact'] ??
            data['phone'] ??
            '';

        profileData['gender'] =
            data['gender'] ?? 'Male';

        profileData['date_of_birth'] =
            data['date_of_birth'] ??
            data['dob'] ??
            data['birth_date'];

        profileData['age'] =
            data['age'];

        profileData['created_at'] =
            data['created_at'] ??
            data['registered_at'] ??
            data['last_visit'] ??
            '';

        // =================================================
        // SPLIT BACKEND "name" INTO FIRST/LAST NAME
        // =================================================

        if (data['name'] != null) {
          final fullName =
              data['name'].toString().trim();

          if (fullName.isNotEmpty) {
            final parts = fullName.split(' ');

            profileData['first_name'] =
                parts.first;

            profileData['last_name'] =
                parts.length > 1
                    ? parts.sublist(1).join(' ')
                    : '';
          }
        }

        debugPrint(
          'LOGIN PROFILE DATA: $profileData',
        );

        // =================================================
        // OPEN DASHBOARD
        // =================================================

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              profileData: profileData,
            ),
          ),
        );
      } else {
        final msg =
            (data['message'] ?? data['error'])
                ?.toString() ??
            'Login failed';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
          ),
        );
      }
    }

    // =====================================================
    // REGISTRATION
    // =====================================================

    else {
      final calculatedAge =
          _selectedDateOfBirth != null
              ? _calculateAge(
                  _selectedDateOfBirth!,
                )
              : 0;

      final payload = {
        'name':
            '${_firstNameController.text.trim()} '
                    '${_lastNameController.text.trim()}'
                .trim(),

        'age': calculatedAge,

        'gender': _selectedGender,

        'contact':
            _contactController.text.trim(),

        'email':
            _emailController.text
                .trim()
                .toLowerCase(),

        'password':
            _passwordController.text,
      };

      debugPrint(
        'REGISTER REQUEST: $uri',
      );

      debugPrint(
        'REGISTER PAYLOAD: $payload',
      );

      final response = await http
          .post(
            uri,
            headers: jsonHeaders,
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = {};
      }

      debugPrint(
        'REGISTER STATUS: ${response.statusCode}',
      );

      debugPrint(
        'REGISTER RESPONSE: ${response.body}',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Registration successful',
            ),
          ),
        );

        // =================================================
        // CLEAR REGISTRATION FIELDS
        // =================================================

        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _contactController.clear();
        _ageController.clear();

        setState(() {
          _selectedDateOfBirth = null;
          _selectedGender = 'Male';
// sample
          // Return to Login
          _isLogin = true;
        });
      } else {
        final msg =
            (data['message'] ?? data['error'])
                ?.toString() ??
            'Registration failed';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
          ),
        );
      }
    }
  } catch (e) {
    if (!mounted) return;

    debugPrint('AUTH ERROR: $e');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Connection error: $e',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(
        () => _isLoading = false,
      );
    }
  }
}


  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 22,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F76FF), Color(0xFF003BB5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.visibility,
                        size: 36,
                        color: Color(0xFF0F76FF),
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Gonzales Vision Clinic',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Eye Care and Patient Access',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F76FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Text(
                          _isLogin ? 'Login' : 'Register',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter first name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter last name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter email';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter password'
                            : null,
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickDateOfBirth,
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _ageController,
                              decoration: const InputDecoration(
                                labelText: 'Date of birth',
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              validator: (value) => _selectedDateOfBirth == null
                                  ? 'Select date of birth'
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedGender = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact number',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter contact number'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F76FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isLogin ? 'Sign In' : 'Register',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin
                              ? 'Create an account? Register'
                              : 'Already have an account? Login',
                          style: const TextStyle(
                            color: Color(0xFF0F76FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Recover Password or contact support',
                  style: TextStyle(
                    color: Color(0xFF0F76FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FrameModel {
  final int frameId;
  final String name;
  final String? brand;
  final String? material;
  final String? category;
  final String? description;
  final double price;
  final int stockQuantity;
  final String? imageUrl;

  const FrameModel({
    required this.frameId,
    required this.name,
    this.brand,
    this.material,
    this.category,
    this.description,
    required this.price,
    required this.stockQuantity,
    this.imageUrl,
  });

  factory FrameModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final rawStock = json['stock_quantity'] ?? json['stock'];
    final rawName = json['name'] ?? json['frame_name'] ?? '';
    final rawImage = json['image_2d_url'] ?? json['image_url'] ?? json['image'];

    return FrameModel(
      frameId: json['frame_id'] is num
          ? (json['frame_id'] as num).toInt()
          : int.tryParse(json['frame_id']?.toString() ?? '') ?? 0,
      name: rawName.toString(),
      brand: json['brand'] == null ? null : json['brand'].toString(),
      material: json['material'] == null ? null : json['material'].toString(),
      category: json['category'] == null ? null : json['category'].toString(),
      description: json['description'] == null
          ? null
          : json['description'].toString(),
      price: rawPrice is num
          ? rawPrice.toDouble()
          : (rawPrice is String ? double.tryParse(rawPrice) ?? 0.0 : 0.0),
      stockQuantity: rawStock is num
          ? rawStock.toInt()
          : (rawStock is String ? int.tryParse(rawStock) ?? 0 : 0),
      imageUrl: rawImage == null ? null : rawImage.toString(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const DashboardScreen({super.key, required this.profileData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late Map<String, dynamic> _profile;
  bool _loadingAppointments = false;
  bool _loadingFrames = false;
  bool _framesError = false;
  String? _framesErrorMessage;
  List<dynamic> _appointments = [];
  List<FrameModel> _frames = [];

  @override
  void initState() {
    super.initState();
    _profile = widget.profileData;
    // Refresh profile from server to pick up any recent changes (contact, email, etc.)
    _refreshProfile();
    _loadAppointments();
    _loadFrames();
  }

//tryon webview
void _openTryOn(FrameModel frame) {
  final uri = Uri.parse(
    '$tryOnBaseUrl'
    '?frameId=${Uri.encodeComponent(frame.frameId.toString())}'
    '&mobileTryOn=true',
  );

  debugPrint('OPENING TRY-ON FOR FRAME: ${frame.frameId}');
  debugPrint('TRY-ON URL: $uri');

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TryOnWebViewScreen(
        url: uri,
        frameName: frame.name,
      ),
    ),
  );
}

// profile
  Future<void> _refreshProfile() async {
  try {
    final pid = _profile['patient_id'];

    if (pid == null ||
        pid.toString().trim().isEmpty) {
      debugPrint(
        'PROFILE REFRESH: No patient ID available.',
      );
      return;
    }

    // =====================================================
    // EXPRESS PROFILE ENDPOINT
    // GET /api/patients/:id
    // =====================================================

    final uri = Uri.parse(
      '$apiBaseUrl/api/patients/${Uri.encodeComponent(pid.toString())}',
    );

    debugPrint(
      'PROFILE API REQUEST: $uri',
    );

    final response = await http
        .get(
          uri,
          headers: jsonHeaders,
        )
        .timeout(
          const Duration(seconds: 15),
        );

    debugPrint(
      'PROFILE API STATUS: ${response.statusCode}',
    );

    debugPrint(
      'PROFILE API RESPONSE: ${response.body}',
    );

    Map<String, dynamic> data = {};

    try {
      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      data = {};
    }

    if (!mounted) return;

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      // =================================================
      // YOUR EXPRESS ENDPOINT RETURNS THE PATIENT
      // DIRECTLY, NOT INSIDE { success, data }
      // =================================================

      setState(() {
        _profile = {
          ..._profile,
          ...data,

          // Map backend field names to the names
          // already used by the Flutter UI.
          'patient_id':
              data['patient_id'] ??
              _profile['patient_id'],

          'email':
              data['email'] ??
              _profile['email'],

          'contact_number':
              data['contact'] ??
              data['contact_number'] ??
              _profile['contact_number'],

          'gender':
              data['gender'] ??
              _profile['gender'],

          'age':
              data['age'] ??
              _profile['age'],

          'date_of_birth':
              data['date_of_birth'] ??
              data['dob'] ??
              data['birth_date'] ??
              _profile['date_of_birth'],

          'created_at':
              data['created_at'] ??
              _profile['created_at'],

          'last_visit':
              data['last_visit'] ??
              _profile['last_visit'],
        };

        // =================================================
        // SPLIT "name" INTO FIRST/LAST NAME
        // =================================================

        if (data['name'] != null) {
          final fullName =
              data['name'].toString().trim();

          if (fullName.isNotEmpty) {
            final parts =
                fullName.split(' ');

            _profile['first_name'] =
                parts.first;

            _profile['last_name'] =
                parts.length > 1
                    ? parts
                        .sublist(1)
                        .join(' ')
                    : '';
          }
        }
      });

      debugPrint(
        'PROFILE REFRESH SUCCESS: $_profile',
      );
    } else {
      debugPrint(
        'PROFILE REFRESH FAILED: '
        '${data['message'] ?? data['error']}',
      );
    }
  } catch (e) {
    debugPrint(
      'Unable to refresh profile: $e',
    );
  }
}

//load appointments
  Future<void> _loadAppointments() async {
  if (!mounted) return;

  setState(() => _loadingAppointments = true);

  try {
    final patientId = _profile['patient_id']?.toString().trim();

    if (patientId == null || patientId.isEmpty) {
      debugPrint('APPOINTMENTS: No patient ID available.');
      setState(() => _appointments = []);
      return;
    }

    // =====================================================
    // EXPRESS APPOINTMENT ENDPOINT
    // GET /api/appointments/patient/:patient_id
    // =====================================================

    final uri = Uri.parse(
      '$apiBaseUrl/api/appointments/patient/${Uri.encodeComponent(patientId)}',
    );

    debugPrint('APPOINTMENTS API REQUEST: $uri');

    final response = await http
        .get(
          uri,
          headers: jsonHeaders,
        )
        .timeout(const Duration(seconds: 15));

    debugPrint(
      'APPOINTMENTS API STATUS: ${response.statusCode}',
    );

    debugPrint(
      'APPOINTMENTS API RESPONSE: ${response.body}',
    );

    if (!mounted) return;

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      final decoded = jsonDecode(response.body);

      // Your Express endpoint returns the array directly:
      //
      // [
      //   {
      //     "appointment_id": ...,
      //     "patient_id": ...,
      //     "patient_name": ...,
      //     "appointment_date": ...,
      //     "appointment_time": ...,
      //     "purpose_of_visit": ...,
      //     "appointment_status": ...
      //   }
      // ]

      if (decoded is List) {
        setState(() {
          _appointments = decoded;
        });

        debugPrint(
          'APPOINTMENTS LOAD SUCCESS: ${_appointments.length} appointment(s)',
        );
      } else {
        debugPrint(
          'APPOINTMENTS ERROR: Expected List but received ${decoded.runtimeType}',
        );

        setState(() {
          _appointments = [];
        });
      }

      return;
    }

    // =====================================================
    // SERVER ERROR
    // =====================================================

    Map<String, dynamic> data = {};

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {}

    final message =
        (data['message'] ?? data['error'])?.toString() ??
        'Failed to load appointments.';

    debugPrint(
      'APPOINTMENTS API ERROR: $message',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e, st) {
    debugPrint('APPOINTMENTS API EXCEPTION: $e');
    debugPrint('APPOINTMENTS API STACK: $st');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Unable to load appointments: $e',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _loadingAppointments = false);
    }
  }
}

// =====================================================
// LOAD FRAME MODELS
// GET /api/frames
// =====================================================

Future<void> _loadFrames() async {
  if (!mounted) return;

  setState(() {
    _loadingFrames = true;
    _framesError = false;
    _framesErrorMessage = null;
  });

  try {
    final uri = Uri.parse('$apiBaseUrl/api/frames');

    debugPrint('FRAME API REQUEST: $uri');

    final response = await http
        .get(
          uri,
          headers: jsonHeaders,
        )
        .timeout(const Duration(seconds: 20));

    debugPrint(
      'FRAME API STATUS: ${response.statusCode}',
    );

    debugPrint(
      'FRAME API RESPONSE: ${response.body}',
    );

    if (!mounted) return;

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        final frames = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => FrameModel.fromJson(item))
            .toList();

        setState(() {
          _frames = frames;
          _framesError = false;
          _framesErrorMessage = null;
        });

        debugPrint(
          'FRAME LOAD SUCCESS: ${_frames.length} frame(s)',
        );
      } else {
        debugPrint(
          'FRAME API ERROR: Expected List but received ${decoded.runtimeType}',
        );

        setState(() {
          _frames = [];
          _framesError = true;
          _framesErrorMessage =
              'Unexpected frame data received from the server.';
        });
      }

      return;
    }

    Map<String, dynamic> data = {};

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {}

    final message =
        (data['message'] ?? data['error'])?.toString() ??
        'Failed to load frame models.';

    debugPrint(
      'FRAME API ERROR: $message',
    );

    setState(() {
      _framesError = true;
      _framesErrorMessage = message;
    });
  } catch (e, st) {
    debugPrint('FRAME API EXCEPTION: $e');
    debugPrint('FRAME API STACK: $st');

    if (!mounted) return;

    setState(() {
      _framesError = true;
      _framesErrorMessage =
          'Unable to load frame models right now.';
    });
  } finally {
    if (mounted) {
      setState(() => _loadingFrames = false);
    }
  }
}

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildHomeTab() {
    final firstName = (_profile['first_name'] as String?) ?? '';
    final lastName = (_profile['last_name'] as String?) ?? '';
    var userName = '$firstName $lastName'.trim();
    if (userName.isEmpty) {
      userName = (_profile['email'] as String?) ?? 'Patient';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F76FF),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search lenses, frames...',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Material(
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search lenses, frames...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              children: [
                const Icon(
                  Icons.visibility,
                  size: 44,
                  color: Color(0xFF0F76FF),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to Gonzales Vision Clinic, $userName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your complete eye care dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DashboardTile(
                label: 'Appointment Scheduler',
                icon: Icons.calendar_month,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppointmentSchedulerScreen(
                        patientId: _profile['patient_id'],
                        onScheduled: _loadAppointments,
                      ),
                    ),
                  );
                },
              ),
              _DashboardTile(
                label: 'Frame Models',
                icon: Icons.grid_view,
                onTap: () => _onItemTapped(1),
              ),
              _DashboardTile(
                label: 'My Profile',
                icon: Icons.person,
                onTap: () => _onItemTapped(3),
              ),
              _DashboardTile(
                label: 'Appointments',
                icon: Icons.event_available,
                onTap: () => _onItemTapped(2),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryTile(
                value: _appointments.length.toString(),
                label: 'Total booked visits',
              ),
              _SummaryTile(
                value: _appointments
    .where((item) {
      final data = item as Map<String, dynamic>;

      final status =
          data['appointment_status'] ??
          data['status'];

      return status
              .toString()
              .trim()
              .toLowerCase() ==
          'confirmed';
    })
    .length
    .toString(),
                label: 'Upcoming confirmed',
              ),
              const _SummaryTile(value: '12', label: 'Days Since Last Visit'),
            ],
          ),
        ],
      ),
    );
  }

  void _showFrameDetails(FrameModel frame) {
  final imageUrl = resolveFrameImageUrl(frame.imageUrl);
  final inStock = frame.stockQuantity > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 220,
                                color: const Color(0xFFEAF2FF),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              height: 220,
                              width: double.infinity,
                              color: const Color(0xFFEAF2FF),
                              child: const Icon(
                                Icons.remove_red_eye,
                                size: 52,
                                color: Color(0xFF0F76FF),
                              ),
                            ),
                          )
                        : Container(
                            height: 220,
                            width: double.infinity,
                            color: const Color(0xFFEAF2FF),
                            child: const Icon(
                              Icons.remove_red_eye,
                              size: 52,
                              color: Color(0xFF0F76FF),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    frame.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (frame.brand != null && frame.brand!.trim().isNotEmpty)
                    Text(
                      frame.brand!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₱${frame.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F76FF),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: inStock
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          inStock ? 'Available' : 'Out of stock',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: inStock ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _InfoRow(
                    label: 'Stock quantity',
                    value: frame.stockQuantity.toString(),
                  ),
                  if (frame.material != null &&
                      frame.material!.trim().isNotEmpty)
                    _InfoRow(label: 'Material', value: frame.material!),
                  if (frame.category != null &&
                      frame.category!.trim().isNotEmpty)
                    _InfoRow(label: 'Category', value: frame.category!),
                  const SizedBox(height: 12),
                 const Text(
  'Description',
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  ),
),

const SizedBox(height: 6),

Text(
  (frame.description != null &&
          frame.description!.trim().isNotEmpty)
      ? frame.description!
      : 'No description available for this frame.',
  style: const TextStyle(
    fontSize: 14,
    color: Colors.black54,
    height: 1.5,
  ),
),

const SizedBox(height: 24),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () {
      Navigator.of(context).pop();
      _openTryOn(frame);
    },
    icon: const Icon(Icons.view_in_ar),
    label: const Text('Try On'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0F76FF),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFramesTab() {
    if (_loadingFrames && _frames.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_framesError && _frames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _framesErrorMessage ?? 'Unable to load frame models.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadFrames,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_frames.isEmpty) {
      return const Center(child: Text('No frames available.'));
    }

    return RefreshIndicator(
      onRefresh: _loadFrames,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: _frames.length,
        itemBuilder: (context, index) {
          final frame = _frames[index];
          final imageUrl = resolveFrameImageUrl(frame.imageUrl);
          final inStock = frame.stockQuantity > 0;

          return InkWell(
            onTap: () => _showFrameDetails(frame),
            borderRadius: BorderRadius.circular(20),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 120,
                                width: double.infinity,
                                color: const Color(0xFFEAF2FF),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              height: 120,
                              width: double.infinity,
                              color: const Color(0xFFEAF2FF),
                              child: const Icon(
                                Icons.remove_red_eye,
                                size: 34,
                                color: Color(0xFF0F76FF),
                              ),
                            ),
                          )
                        : Container(
                            height: 120,
                            width: double.infinity,
                            color: const Color(0xFFEAF2FF),
                            child: const Icon(
                              Icons.remove_red_eye,
                              size: 34,
                              color: Color(0xFF0F76FF),
                            ),
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            frame.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (frame.brand != null &&
                              frame.brand!.trim().isNotEmpty)
                            Text(
                              frame.brand!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  '₱${frame.price.toStringAsFixed(2)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F76FF),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: inStock
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  inStock ? 'Available' : 'Sold out',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: inStock ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F76FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: const Icon(
                      Icons.event_available,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'My Appointments',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Review your upcoming visits and booking details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AppointmentSchedulerScreen(
                              patientId: _profile['patient_id'],
                              onScheduled: _loadAppointments,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Schedule New Appointment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F76FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_loadingAppointments)
            const Center(child: CircularProgressIndicator())
          else if (_appointments.isEmpty)
            Center(
              child: Text(
                'No appointments found for patient ${_profile['patient_id'] ?? 'unknown'}. Pull down to refresh.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._appointments.map((appointment) {
              final data = appointment as Map<String, dynamic>;

              final purposeOfVisit = (data['purpose_of_visit'] ?? '')
                  .toString();
              final provider = (data['provider'] ?? '').toString().trim();
              final appointmentType = (data['appointment_type'] ?? '')
                  .toString()
                  .trim();
              final parsedProvider = provider.isNotEmpty
                  ? provider
                  : (purposeOfVisit.contains(' - ')
                            ? purposeOfVisit.split(' - ').first
                            : purposeOfVisit)
                        .trim();
              final parsedType = appointmentType.isNotEmpty
                  ? appointmentType
                  : (purposeOfVisit.contains(' - ')
                            ? purposeOfVisit.split(' - ').last
                            : 'General')
                        .trim();
              final status = normalizeAppointmentStatus(
                data['appointment_status'] ?? data['status'],
              );
              final statusKey = status.toLowerCase();
              final statusColor = statusKey == 'confirmed'
                  ? Colors.green
                  : statusKey == 'pending'
                  ? Colors.orange
                  : statusKey == 'cancelled'
                  ? Colors.red
                  : Colors.grey;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${data['appointment_date']} · ${data['appointment_time']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(
                                (statusColor.r * 255.0).round(),
                                (statusColor.g * 255.0).round(),
                                (statusColor.b * 255.0).round(),
                                0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              status.isEmpty ? 'UNKNOWN' : status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Provider: ${parsedProvider.isEmpty ? '-' : parsedProvider}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Type: ${parsedType.isEmpty ? '-' : parsedType}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatProfileDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      return value.toString();
    }

    final datePart =
        '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    final timePart =
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    return '$datePart at $timePart';
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF0F76FF),
                      child: Text(
                        _profile['first_name']?[0] ?? 'O',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_profile['first_name']} ${_profile['last_name']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile['email'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Edit profile button (text)
                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.of(context)
                            .push<Map<String, dynamic>>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditProfileScreen(profile: _profile),
                              ),
                            );
                        if (result != null && mounted) {
                          setState(() {
                            // Merge returned fields into profile
                            _profile = {..._profile, ...result};
                          });
                        }
                      },
                      child: const Text(
                        'Edit profile',
                        style: TextStyle(
                          color: Color(0xFF0F76FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ProfileDetail(
                  label: 'Patient ID',
                  value: _profile['patient_id']?.toString() ?? '-',
                ),
                _ProfileDetail(
                  label: 'Contact',
                  value:
                      ((_profile['contact_number'] ?? '')
                          .toString()
                          .trim()
                          .isEmpty)
                      ? '-'
                      : (_profile['contact_number'] ?? '-').toString(),
                ),
                _ProfileDetail(
                  label: 'Registered',
                  value: _formatProfileDate(_profile['created_at']),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      _buildFramesTab(),
      _buildAppointmentsTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: true,
        title: const Text(
          'Gonzales Vision Clinic',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F76FF),
        actions: [
          IconButton(
            icon: Stack(
              alignment: Alignment.topRight,
              children: [
                const Icon(Icons.notifications),
                if (notificationsController.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(patientId: _profile['patient_id']),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF0F76FF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Frames'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _DashboardTile({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0F76FF), size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F76FF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
