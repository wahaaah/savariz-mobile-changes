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

  TimeOfDay? _selectedTime;

  final _providerController = TextEditingController();
  final _appointmentTypeController = TextEditingController();

  bool _creatingAppointment = false;
  bool _loadingAvailability = false;

  String? _availabilityError;

  /*
  ============================================================
  CLINIC OPERATING TIME SLOTS
  8:00 AM - 5:30 PM
  Every 30 minutes
  ============================================================
  */
  final List<TimeOfDay> _operatingTimeSlots = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 8, minute: 30),
    const TimeOfDay(hour: 9, minute: 0),
    const TimeOfDay(hour: 9, minute: 30),
    const TimeOfDay(hour: 10, minute: 0),
    const TimeOfDay(hour: 10, minute: 30),
    const TimeOfDay(hour: 11, minute: 0),
    const TimeOfDay(hour: 11, minute: 30),
    const TimeOfDay(hour: 12, minute: 0),
    const TimeOfDay(hour: 12, minute: 30),
    const TimeOfDay(hour: 13, minute: 0),
    const TimeOfDay(hour: 13, minute: 30),
    const TimeOfDay(hour: 14, minute: 0),
    const TimeOfDay(hour: 14, minute: 30),
    const TimeOfDay(hour: 15, minute: 0),
    const TimeOfDay(hour: 15, minute: 30),
    const TimeOfDay(hour: 16, minute: 0),
    const TimeOfDay(hour: 16, minute: 30),
    const TimeOfDay(hour: 17, minute: 0),
    const TimeOfDay(hour: 17, minute: 30),
  ];

  /*
  ============================================================
  BOOKED SLOTS
  Format:
  2026-10-01 12:30
  ============================================================
  */
  final Set<String> _bookedSlots = {};

  /*
  ============================================================
  DATE HELPERS
  ============================================================
  */

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _timeKey(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _toMysqlTime(TimeOfDay time) {
    return '${_timeKey(time)}:00';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /*
  ============================================================
  CHECK IF TIME HAS ALREADY PASSED TODAY
  ============================================================
  */

  bool _isPastTime(TimeOfDay time) {
    if (!_isToday(_selectedDate)) {
      return false;
    }

    final now = TimeOfDay.now();

    if (time.hour < now.hour) {
      return true;
    }

    if (time.hour == now.hour && time.minute <= now.minute) {
      return true;
    }

    return false;
  }

  /*
  ============================================================
  CHECK IF SLOT IS ALREADY BOOKED
  ============================================================
  */

  bool _isSlotBooked(TimeOfDay time) {
    final date = _formatDate(_selectedDate);
    final key = '$date ${_timeKey(time)}';

    return _bookedSlots.contains(key);
  }

  /*
  ============================================================
  LOAD BOOKED APPOINTMENT SLOTS
  ============================================================
  */

  Future<void> _loadBookedSlots() async {
    if (!mounted) return;

    setState(() {
      _loadingAvailability = true;
      _availabilityError = null;
      _bookedSlots.clear();
      _selectedTime = null;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/api/appointments');

      debugPrint(
        'APPOINTMENT AVAILABILITY REQUEST: $uri',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'APPOINTMENT AVAILABILITY STATUS: ${response.statusCode}',
      );

      debugPrint(
        'APPOINTMENT AVAILABILITY RESPONSE: ${response.body}',
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Failed to load appointment availability.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception(
          'Invalid appointment data received from server.',
        );
      }

      final selectedDateString = _formatDate(_selectedDate);

      final booked = <String>{};

      for (final item in decoded) {
        if (item is! Map) continue;

        final status = item['appointment_status']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

        /*
        Cancelled appointments should NOT block the slot.

        Requested, Pending, Confirmed, etc.
        DO block the slot.
        */
        if (status == 'cancelled' ||
            status == 'canceled') {
          continue;
        }

        final rawDate =
            item['appointment_date']?.toString() ?? '';

        final rawTime =
            item['appointment_time']?.toString() ?? '';

        final appointmentDate =
            rawDate.split('T').first;

        final appointmentTime =
            rawTime.length >= 5
                ? rawTime.substring(0, 5)
                : rawTime;

        if (appointmentDate == selectedDateString &&
            appointmentTime.isNotEmpty) {
          booked.add(
            '$appointmentDate $appointmentTime',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _bookedSlots
          ..clear()
          ..addAll(booked);
      });

      debugPrint(
        'BOOKED SLOTS FOR $selectedDateString: $_bookedSlots',
      );
    } catch (e, st) {
      debugPrint(
        'APPOINTMENT AVAILABILITY ERROR: $e',
      );

      debugPrint(
        'APPOINTMENT AVAILABILITY STACK: $st',
      );

      if (!mounted) return;

      setState(() {
        _availabilityError =
            'Unable to load available appointment times.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAvailability = false;
        });
      }
    }
  }

  /*
  ============================================================
  INITIAL LOAD
  ============================================================
  */

  @override
  void initState() {
    super.initState();

    _loadBookedSlots();
  }

  /*
  ============================================================
  CREATE APPOINTMENT
  ============================================================
  */

  Future<void> _createAppointment() async {
    final provider =
        _providerController.text.trim();

    final appointmentType =
        _appointmentTypeController.text.trim();

    /*
    ------------------------------------------------------------
    MAKE SURE TIME WAS SELECTED
    ------------------------------------------------------------
    */

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an available appointment time.',
          ),
        ),
      );
      return;
    }

    /*
    ------------------------------------------------------------
    MAKE SURE TIME HAS NOT PASSED
    ------------------------------------------------------------
    */

    if (_isPastTime(_selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That appointment time has already passed.',
          ),
        ),
      );

      await _loadBookedSlots();

      return;
    }

    /*
    ------------------------------------------------------------
    MAKE SURE SLOT IS NOT ALREADY BOOKED
    ------------------------------------------------------------
    */

    if (_isSlotBooked(_selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That appointment slot is already reserved. '
            'Please choose another time.',
          ),
        ),
      );

      await _loadBookedSlots();

      return;
    }

    /*
    ------------------------------------------------------------
    VALIDATE APPOINTMENT DETAILS
    ------------------------------------------------------------
    */

    if (provider.isEmpty ||
        appointmentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill provider and appointment type.',
          ),
        ),
      );

      return;
    }

    /*
    ------------------------------------------------------------
    VALIDATE PATIENT ID
    ------------------------------------------------------------
    */

    final patientId =
        widget.patientId?.toString().trim();

    if (patientId == null ||
        patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Patient ID is missing. Please log in again.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _creatingAppointment = true;
    });

    try {
      final uri =
          Uri.parse('$apiBaseUrl/api/appointments');

      final appointmentDate =
          _formatDate(_selectedDate);

      final appointmentTime =
          _toMysqlTime(_selectedTime!);

      /*
      Admin scheduler expects the purpose in one field.
      */
      final purposeOfVisit =
          '$appointmentType - $provider';

      debugPrint(
        'APPOINTMENT REQUEST URL: $uri',
      );

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

              /*
              IMPORTANT:
              This puts the appointment into the
              admin Incoming Mobile Bookings queue.
              */
              'appointment_status': 'Requested',
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      debugPrint(
        'APPOINTMENT REQUEST STATUS: '
        '${response.statusCode}',
      );

      debugPrint(
        'APPOINTMENT REQUEST RESPONSE: '
        '${response.body}',
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
            'APPOINTMENT REQUEST: '
            'Invalid JSON response.',
          );
        }
      }

      if (!mounted) return;

      /*
      ----------------------------------------------------------
      SUCCESS
      ----------------------------------------------------------
      */

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

        setState(() {
          _selectedTime = null;
        });

        /*
        Refresh availability so the newly requested
        slot becomes unavailable immediately.
        */
        await _loadBookedSlots();

        await widget.onScheduled();
      }

      /*
      ----------------------------------------------------------
      SLOT ALREADY RESERVED
      ----------------------------------------------------------
      */

      else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error']?.toString() ??
                  'This time slot is already reserved.',
            ),
          ),
        );

        await _loadBookedSlots();
      }

      /*
      ----------------------------------------------------------
      BAD REQUEST
      ----------------------------------------------------------
      */

      else if (response.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error']?.toString() ??
                  'Please provide all required appointment details.',
            ),
          ),
        );
      }

      /*
      ----------------------------------------------------------
      OTHER SERVER ERROR
      ----------------------------------------------------------
      */

      else {
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
      debugPrint(
        'APPOINTMENT REQUEST EXCEPTION: $e',
      );

      debugPrint(
        'APPOINTMENT REQUEST STACK: $st',
      );

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
        setState(() {
          _creatingAppointment = false;
        });
      }
    }
  }

  /*
  ============================================================
  DISPOSE
  ============================================================
  */

  @override
  void dispose() {
    _providerController.dispose();
    _appointmentTypeController.dispose();

    super.dispose();
  }

  /*
  ============================================================
  HEADER
  ============================================================
  */

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F76FF),
            Color(0xFF409CFF),
          ],
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
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_today,
            color: Colors.white,
            size: 32,
          ),

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
            'Selected: '
            '${_selectedDate.day}/'
            '${_selectedDate.month}/'
            '${_selectedDate.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /*
  ============================================================
  CALENDAR
  ============================================================
  */

  Widget _buildCalendarCard() {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
        child: CalendarDatePicker(
          initialDate: _selectedDate,
          firstDate: today,
          lastDate: today.add(
            const Duration(days: 365),
          ),
          currentDate: today,
          onDateChanged: (date) async {
            setState(() {
              _selectedDate = date;
              _selectedTime = null;
            });

            await _loadBookedSlots();
          },
        ),
      ),
    );
  }

  /*
  ============================================================
  TIME SLOT CARD
  ============================================================
  */

  Widget _buildTimeCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Select appointment time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Available clinic hours: '
              '8:00 AM - 5:30 PM',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 16),

            if (_loadingAvailability)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )

            else if (_availabilityError != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Text(
                  _availabilityError!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                  ),
                ),
              )

            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _operatingTimeSlots.map((time) {
                  final booked =
                      _isSlotBooked(time);

                  final past =
                      _isPastTime(time);

                  final disabled =
                      booked || past;

                  final selected =
                      _selectedTime != null &&
                      _selectedTime!.hour ==
                          time.hour &&
                      _selectedTime!.minute ==
                          time.minute;

                  return SizedBox(
                    width: 105,
                    child: OutlinedButton(
                      onPressed: disabled
                          ? null
                          : () {
                              setState(() {
                                _selectedTime =
                                    time;
                              });
                            },
                      style:
                          OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 12,
                        ),

                        backgroundColor:
                            selected
                                ? const Color(
                                    0xFF0F76FF,
                                  )
                                : disabled
                                    ? Colors.grey
                                        .shade100
                                    : Colors.white,

                        foregroundColor:
                            selected
                                ? Colors.white
                                : disabled
                                    ? Colors.grey
                                    : const Color(
                                        0xFF0F76FF,
                                      ),

                        side: BorderSide(
                          color: selected
                              ? const Color(
                                  0xFF0F76FF,
                                )
                              : disabled
                                  ? Colors.grey
                                      .shade300
                                  : const Color(
                                      0xFF0F76FF,
                                    ),
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(12),
                        ),
                      ),

                      child: Column(
                        children: [
                          Text(
                            time.format(context),
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          if (booked)
                            const Text(
                              'Reserved',
                              style:
                                  TextStyle(
                                fontSize: 10,
                              ),
                            )

                          else if (past)
                            const Text(
                              'Passed',
                              style:
                                  TextStyle(
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  /*
  ============================================================
  APPOINTMENT INPUT CARD
  ============================================================
  */

  Widget _buildInputCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Appointment details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _providerController,
              decoration:
                  const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
                prefixIcon:
                    Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller:
                  _appointmentTypeController,
              decoration:
                  const InputDecoration(
                labelText:
                    'Appointment type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.medical_services,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
  ============================================================
  CONFIRM BUTTON
  ============================================================
  */

  Widget _buildActionButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed:
            _creatingAppointment
                ? null
                : _createAppointment,

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFF0F76FF),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
        ),

        child: _creatingAppointment
            ? const CircularProgressIndicator(
                color: Colors.white,
              )
            : const Text(
                'Confirm Appointment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /*
  ============================================================
  BUILD
  ============================================================
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Appointment Scheduler'),
        backgroundColor:
            const Color(0xFF0F76FF),
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

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