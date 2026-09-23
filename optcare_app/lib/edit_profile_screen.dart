import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

const Map<String, String> _jsonHeaders = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  String _gender = 'Male';
  DateTime? _dob;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstNameController = TextEditingController(text: p['first_name'] ?? '');
    _lastNameController = TextEditingController(text: p['last_name'] ?? '');
    _emailController = TextEditingController(text: p['email'] ?? '');
    _contactController = TextEditingController(text: p['contact_number'] ?? '');
    _gender = (p['gender'] as String?) ?? 'Male';
    final rawDob = p['date_of_birth'] as String?;
    if (rawDob != null && rawDob.isNotEmpty) {
      _dob = DateTime.tryParse(rawDob);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 3650)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$apiBaseUrl/update_patient.php');
      final payload = <String, dynamic>{
        'patient_id': widget.profile['patient_id'],
      };
      payload['first_name'] = _firstNameController.text.trim();
      payload['last_name'] = _lastNameController.text.trim();
      payload['email'] = _emailController.text.trim();
      payload['contact_number'] = _contactController.text.trim();
      payload['gender'] = _gender;
      if (_dob != null) {
        payload['date_of_birth'] = _dob!.toIso8601String().split('T').first;
      }

      final res = await http
          .post(uri, headers: _jsonHeaders, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      final Map<String, dynamic> data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        // Return updated values to caller so UI can update
        Navigator.of(context).pop({
          'first_name': payload['first_name'],
          'last_name': payload['last_name'],
          'email': payload['email'],
          'contact_number': payload['contact_number'],
          'gender': payload['gender'],
          'date_of_birth':
              payload['date_of_birth'] ?? widget.profile['date_of_birth'],
        });
        return;
      }

      final msg =
          (data['message'] ?? data['error'])?.toString() ??
          'Failed to update profile';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Contact number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _gender = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDob,
                    child: IgnorePointer(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Date of birth',
                          hintText: _dob != null
                              ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                              : 'Select',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
