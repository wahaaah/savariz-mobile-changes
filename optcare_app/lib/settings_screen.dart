import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_settings.dart';
import 'constants.dart';

class SettingsScreen extends StatefulWidget {
  final String patientId;

  const SettingsScreen({super.key, required this.patientId});

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
    setState(() {
      _notificationsOn = settings.notificationsOn;
      _emailUpdatesOn = settings.emailUpdatesOn;
      _largeTextOn = settings.largeTextOn;
      _isLoading = false;
    });
  }

  Future<void> _updateNotification(bool value) async {
    await appSettingsController.setNotificationsOn(value);
    setState(() => _notificationsOn = value);
  }

  Future<void> _updateEmailUpdates(bool value) async {
    await appSettingsController.setEmailUpdatesOn(value);
    setState(() => _emailUpdatesOn = value);
  }

  Future<void> _updateLargeText(bool value) async {
    await appSettingsController.setLargeTextOn(value);
    setState(() => _largeTextOn = value);
  }

  Future<void> _savePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password and confirmation do not match.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/change_password.php');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'patient_id': widget.patientId,
              'current_password': _currentPasswordController.text,
              'new_password': _newPasswordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message']?.toString() ?? 'Unable to change password',
          ),
        ),
      );

      if (data['success'] == true) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating password: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF0F76FF),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Account Preferences',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    title: const Text('Notifications'),
                    subtitle: const Text(
                      'Receive alerts for appointment reminders and updates.',
                    ),
                    value: _notificationsOn,
                    activeThumbColor: const Color(0xFF0F76FF),
                    onChanged: _updateNotification,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Email Updates'),
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
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
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
                          backgroundColor: const Color(0xFF0F76FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Save Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'App Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 3,
              child: SwitchListTile(
                title: const Text('Large Text'),
                subtitle: const Text(
                  'Increase typography for better readability.',
                ),
                value: _largeTextOn,
                activeThumbColor: const Color(0xFF0F76FF),
                onChanged: _updateLargeText,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Preferences are saved automatically and will be kept on this device.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
