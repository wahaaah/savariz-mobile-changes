import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';

class AppointmentSchedulerScreen extends StatefulWidget {
  final dynamic patientId;
  final Future<void> Function() onScheduled;

  const AppointmentSchedulerScreen({
    super.key,
    required this.patientId,
    required this.onScheduled,
  });

  @override
  State<AppointmentSchedulerScreen> createState() =>
      _AppointmentSchedulerScreenState();
}

class _AppointmentSchedulerScreenState
    extends State<AppointmentSchedulerScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final _providerController = TextEditingController();
  final _appointmentTypeController = TextEditingController();
  bool _creatingAppointment = false;

  Future<void> _pickTime() async {
    final selection = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (selection != null && mounted) {
      setState(() => _selectedTime = selection);
    }
  }

  String _toMysqlTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

// create appointment 
  Future<void> _createAppointment() async {
  final provider = _providerController.text.trim();
  final appointmentType = _appointmentTypeController.text.trim();

  if (provider.isEmpty || appointmentType.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill provider and appointment type'),
      ),
    );
    return;
  }

  final patientId = widget.patientId?.toString().trim();

  if (patientId == null || patientId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient ID is missing. Please log in again.'),
      ),
    );
    return;
  }

  setState(() => _creatingAppointment = true);

  try {
    final uri = Uri.parse('$apiBaseUrl/api/appointments');

    final appointmentDate =
        _selectedDate.toIso8601String().split('T').first;

    final appointmentTime = _toMysqlTime(_selectedTime);

    // The admin scheduler expects the purpose in one field.
    final purposeOfVisit =
        '$appointmentType - $provider';

    debugPrint('APPOINTMENT REQUEST URL: $uri');

    debugPrint(
      'APPOINTMENT REQUEST DATA: '
      'patient_id=$patientId, '
      'date=$appointmentDate, '
      'time=$appointmentTime, '
      'purpose=$purposeOfVisit',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'patient_id': patientId,
            'appointment_date': appointmentDate,
            'appointment_time': appointmentTime,
            'purpose_of_visit': purposeOfVisit,

            // IMPORTANT:
            // This keeps it in the Incoming Mobile Bookings queue.
            'appointment_status': 'Requested',
          }),
        )
        .timeout(const Duration(seconds: 15));

    debugPrint(
      'APPOINTMENT REQUEST STATUS: ${response.statusCode}',
    );

    debugPrint(
      'APPOINTMENT REQUEST RESPONSE: ${response.body}',
    );

    final body = response.body.trim();

    Map<String, dynamic> data = {};

    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        debugPrint(
          'APPOINTMENT REQUEST: Invalid JSON response.',
        );
      }
    }

    if (!mounted) return;

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appointment request sent successfully!',
          ),
        ),
      );

      _providerController.clear();
      _appointmentTypeController.clear();

      await widget.onScheduled();
    } else if (response.statusCode == 409) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['error']?.toString() ??
                'This time slot is already reserved.',
          ),
        ),
      );
    } else if (response.statusCode == 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['error']?.toString() ??
                'Please provide all required appointment details.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['error']?.toString() ??
                data['message']?.toString() ??
                'Could not send appointment request.',
          ),
        ),
      );
    }
  } catch (e, st) {
    debugPrint('APPOINTMENT REQUEST EXCEPTION: $e');
    debugPrint('APPOINTMENT REQUEST STACK: $st');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Unable to send appointment request: $e',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _creatingAppointment = false);
    }
  }
}

  @override
  void dispose() {
    _providerController.dispose();
    _appointmentTypeController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F76FF), Color(0xFF409CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          const Text(
            'Pick a date on the calendar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selected: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: CalendarDatePicker(
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          currentDate: DateTime.now(),
          onDateChanged: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select appointment time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Choose'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F76FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Appointment details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _providerController,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _appointmentTypeController,
              decoration: const InputDecoration(
                labelText: 'Appointment type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _creatingAppointment ? null : _createAppointment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F76FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _creatingAppointment
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Confirm Appointment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Scheduler'),
        backgroundColor: const Color(0xFF0F76FF),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildCalendarCard(),
              const SizedBox(height: 16),
              _buildTimeCard(),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 24),
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }
}
