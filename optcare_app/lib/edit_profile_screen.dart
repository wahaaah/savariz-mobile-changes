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

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  late TextEditingController _ageController;

  String _gender = 'Male';
  DateTime? _dob;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    final p = widget.profile;

    // =====================================================
    // LOAD EXISTING PROFILE DATA
    // =====================================================

    _firstNameController = TextEditingController(
      text: p['first_name']?.toString() ?? '',
    );

    _lastNameController = TextEditingController(
      text: p['last_name']?.toString() ?? '',
    );

    _emailController = TextEditingController(
      text: p['email']?.toString() ?? '',
    );

    _contactController = TextEditingController(
      text: p['contact_number']?.toString() ??
          p['contact']?.toString() ??
          '',
    );

    _addressController = TextEditingController(
      text: p['address']?.toString() ?? '',
    );

    _ageController = TextEditingController(
      text: p['age']?.toString() ?? '',
    );

    // =====================================================
    // GENDER
    // =====================================================

    final savedGender = p['gender']?.toString();

    if (savedGender != null &&
        ['Male', 'Female', 'Other'].contains(savedGender)) {
      _gender = savedGender;
    }

    // =====================================================
    // DATE OF BIRTH
    // =====================================================

    final rawDob = p['date_of_birth']?.toString();

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
    _addressController.dispose();
    _ageController.dispose();

    super.dispose();
  }

  // =====================================================
  // PICK DATE OF BIRTH
  // =====================================================

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ??
          DateTime.now().subtract(
            const Duration(days: 3650),
          ),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dob = picked;

      // Automatically calculate age from date of birth.
      final today = DateTime.now();

      int age = today.year - picked.year;

      if (today.month < picked.month ||
          (today.month == picked.month &&
              today.day < picked.day)) {
        age--;
      }

      _ageController.text = age.toString();
    });
  }

  // =====================================================
  // FORMAT DATE OF BIRTH
  // =====================================================

  String _formatDob() {
    if (_dob == null) {
      return 'Select date of birth';
    }

    return '${_dob!.day.toString().padLeft(2, '0')}/'
        '${_dob!.month.toString().padLeft(2, '0')}/'
        '${_dob!.year}';
  }

  // =====================================================
  // SAVE PROFILE
  // =====================================================

  Future<void> _save() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // ===================================================
      // PATIENT ID
      // ===================================================

      final patientId =
          widget.profile['patient_id']?.toString().trim();

      if (patientId == null || patientId.isEmpty) {
        throw Exception('Patient ID is missing.');
      }

      // ===================================================
      // GET VALUES
      // ===================================================

      final firstName =
          _firstNameController.text.trim();

      final lastName =
          _lastNameController.text.trim();

      final email =
          _emailController.text.trim();

      final contact =
          _contactController.text.trim();

      final address =
          _addressController.text.trim();

      final ageText =
          _ageController.text.trim();

      // ===================================================
      // VALIDATION
      // ===================================================

      if (firstName.isEmpty) {
        throw Exception('First name cannot be empty.');
      }

      if (lastName.isEmpty) {
        throw Exception('Last name cannot be empty.');
      }

      if (ageText.isEmpty) {
        throw Exception('Age cannot be empty.');
      }

      final age = int.tryParse(ageText);

      if (age == null || age < 0 || age > 150) {
        throw Exception('Please enter a valid age.');
      }

      // ===================================================
      // FULL NAME
      // ===================================================

      final fullName =
          '$firstName $lastName'.trim();

      // ===================================================
      // DATE OF BIRTH
      // ===================================================

      String? dateOfBirth;

      if (_dob != null) {
        dateOfBirth =
            '${_dob!.year.toString().padLeft(4, '0')}-'
            '${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';
      }

      // ===================================================
      // REQUEST PAYLOAD
      // ===================================================

      final payload = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'name': fullName,
        'email': email,
        'contact_number': contact,
        'gender': _gender,
        'age': age,
        'address': address,
        'date_of_birth': dateOfBirth,
      };

      debugPrint(
        'UPDATE PROFILE PAYLOAD: ${jsonEncode(payload)}',
      );

      // ===================================================
      // API URL
      // ===================================================

      final uri = Uri.parse(
        '$apiBaseUrl/api/patients/$patientId',
      );

      // ===================================================
      // SEND UPDATE
      // ===================================================

      final res = await http
          .put(
            uri,
            headers: _jsonHeaders,
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      debugPrint(
        'UPDATE PROFILE STATUS: ${res.statusCode}',
      );

      debugPrint(
        'UPDATE PROFILE RESPONSE: ${res.body}',
      );

      // ===================================================
      // DECODE RESPONSE
      // ===================================================

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(res.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = {};
      }

      // ===================================================
      // SUCCESS
      // ===================================================

      if (res.statusCode == 200 &&
          data['success'] == true) {
        if (!mounted) {
          return;
        }

        // Your backend returns the updated patient
        // inside the "patient" object.
        final updatedPatient =
            data['patient'] is Map
                ? Map<String, dynamic>.from(
                    data['patient'],
                  )
                : <String, dynamic>{};

        Navigator.of(context).pop({
          'patient_id':
              updatedPatient['patient_id'] ??
                  patientId,

          'first_name': firstName,

          'last_name': lastName,

          'name':
              updatedPatient['name'] ??
                  fullName,

          'email':
              updatedPatient['email'] ??
                  email,

          'contact_number':
              updatedPatient['contact'] ??
                  contact,

          'contact':
              updatedPatient['contact'] ??
                  contact,

          'gender':
              updatedPatient['gender'] ??
                  _gender,

          'age':
              updatedPatient['age'] ??
                  age,

          'address':
              updatedPatient['address'] ??
                  address,

          'date_of_birth':
              updatedPatient['date_of_birth'] ??
                  dateOfBirth,
        });

        return;
      }

      // ===================================================
      // API ERROR
      // ===================================================

      final message =
          (data['message'] ??
                  data['error'])
              ?.toString() ??
          'Failed to update profile.';

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      // ===================================================
      // ERROR
      // ===================================================

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // =================================================
            // FIRST NAME
            // =================================================

            TextField(
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'First name',
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // LAST NAME
            // =================================================

            TextField(
              controller: _lastNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Last name',
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // EMAIL
            // =================================================

            TextField(
              controller: _emailController,
              keyboardType:
                  TextInputType.emailAddress,
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // CONTACT NUMBER
            // =================================================

            TextField(
              controller: _contactController,
              keyboardType:
                  TextInputType.phone,
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Contact number',
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // ADDRESS
            // =================================================

            TextField(
              controller: _addressController,
              keyboardType:
                  TextInputType.streetAddress,
              textInputAction:
                  TextInputAction.newline,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText:
                    'Enter your complete address',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // AGE
            // =================================================

            TextField(
              controller: _ageController,
              keyboardType:
                  TextInputType.number,
              textInputAction:
                  TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Age',
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // GENDER
            // =================================================

            DropdownButtonFormField<String>(
              value: _gender,
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
                DropdownMenuItem(
                  value: 'Other',
                  child: Text('Other'),
                ),
              ],

              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _gender = value;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            // =================================================
            // DATE OF BIRTH
            // =================================================

            InkWell(
              onTap: _pickDob,
              borderRadius:
                  BorderRadius.circular(4),

              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText: 'Date of birth',
                  suffixIcon: Icon(
                    Icons.calendar_today,
                  ),
                ),

                child: Text(
                  _formatDob(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // =================================================
            // SAVE BUTTON
            // =================================================

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _loading ? null : _save,

                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child:
                            CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}