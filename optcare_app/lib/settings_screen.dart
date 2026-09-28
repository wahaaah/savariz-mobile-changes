import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_settings.dart';
import 'constants.dart';
import 'terms_and_conditions.dart';

class SettingsScreen extends StatefulWidget {
  final String patientId;

  const SettingsScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsOn = true;
  bool _emailUpdatesOn = true;
  bool _largeTextOn = false;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await appSettingsController.load();

    final settings = appSettingsController.value;

    if (!mounted) return;

    setState(() {
      _notificationsOn = settings.notificationsOn;
      _emailUpdatesOn = settings.emailUpdatesOn;
      _largeTextOn = settings.largeTextOn;
      _isLoading = false;
    });
  }

  Future<void> _updateNotification(bool value) async {
    await appSettingsController.setNotificationsOn(value);

    if (!mounted) return;

    setState(() {
      _notificationsOn = value;
    });
  }

  Future<void> _updateEmailUpdates(bool value) async {
    await appSettingsController.setEmailUpdatesOn(value);

    if (!mounted) return;

    setState(() {
      _emailUpdatesOn = value;
    });
  }

  Future<void> _updateLargeText(bool value) async {
    await appSettingsController.setLargeTextOn(value);

    if (!mounted) return;

    setState(() {
      _largeTextOn = value;
    });
  }

  Future<void> _savePassword() async {
    final currentPassword =
        _currentPasswordController.text.trim();
    final newPassword =
        _newPasswordController.text;
    final confirmPassword =
        _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all password fields.'),
        ),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New password must be at least 6 characters.',
          ),
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New password and confirmation do not match.',
          ),
        ),
      );
      return;
    }

    if (currentPassword == newPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New password must be different from your current password.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(
        '$apiBaseUrl/change_password.php',
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'patient_id': widget.patientId,
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = {};
      }

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Password changed successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error']?.toString() ??
                  data['message']?.toString() ??
                  'Unable to change password.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to connect to the server. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openTermsAndConditions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TermsAndConditionsScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: const Color(0xFF0F76FF),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF0F76FF),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // =========================================================
            // ACCOUNT PREFERENCES
            // =========================================================
            const Text(
              'Account Preferences',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 3,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Notifications',
                    ),
                    subtitle: const Text(
                      'Receive alerts for appointment reminders and updates.',
                    ),
                    value: _notificationsOn,
                    activeThumbColor: const Color(0xFF0F76FF),
                    onChanged: _updateNotification,
                  ),

                  const Divider(height: 1),

                  SwitchListTile(
                    title: const Text(
                      'Email Updates',
                    ),
                    subtitle: const Text(
                      'Receive promo, new lenses, glasses, and update emails.',
                    ),
                    value: _emailUpdatesOn,
                    activeThumbColor: const Color(0xFF0F76FF),
                    onChanged: _updateEmailUpdates,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // =========================================================
            // CHANGE PASSWORD
            // =========================================================
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller:
                          _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller:
                          _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _savePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF0F76FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Save Password',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // =========================================================
            // APP SETTINGS
            // =========================================================
            const Text(
              'App Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 3,
              child: SwitchListTile(
                title: const Text(
                  'Large Text',
                ),
                subtitle: const Text(
                  'Increase typography for better readability.',
                ),
                value: _largeTextOn,
                activeThumbColor:
                    const Color(0xFF0F76FF),
                onChanged: _updateLargeText,
              ),
            ),

            const SizedBox(height: 24),

            // =========================================================
            // LEGAL
            // =========================================================
            const Text(
              'Legal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 3,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F76FF)
                        .withOpacity(0.10),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF0F76FF),
                  ),
                ),
                title: const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'View the clinic terms and conditions',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
                onTap: _openTermsAndConditions,
              ),
            ),

            const SizedBox(height: 24),

            // =========================================================
            // DEVICE PREFERENCES NOTICE
            // =========================================================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Preferences are saved automatically and will be kept on this device.',
                style: TextStyle(
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}