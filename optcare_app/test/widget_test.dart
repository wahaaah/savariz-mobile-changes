import 'package:flutter_test/flutter_test.dart';

import 'package:optcare_app/main.dart';

void main() {
  test('appointment status normalization keeps the expected app labels', () {
    expect(normalizeAppointmentStatus('Requested'), 'Pending');
    expect(normalizeAppointmentStatus('pending'), 'Pending');
    expect(normalizeAppointmentStatus('Confirmed'), 'Confirmed');
    expect(normalizeAppointmentStatus('cancelled'), 'Cancelled');
    expect(normalizeAppointmentStatus('Canceled'), 'Cancelled');
  });

  test('frame model accepts PHP frame payload keys and aliases', () {
    final frame = FrameModel.fromJson({
      'frame_id': 7,
      'frame_name': 'Aster Classic',
      'category': 'Mens',
      'description': 'Lightweight everyday frame.',
      'price': '2499.00',
      'stock': '12',
      'image_url': '/uploads/frames/aster.png',
    });

    expect(frame.frameId, 7);
    expect(frame.name, 'Aster Classic');
    expect(frame.price, 2499.0);
    expect(frame.stockQuantity, 12);
    expect(frame.imageUrl, '/uploads/frames/aster.png');
  });

  test('uploaded frame paths resolve to the Node backend upload host', () {
    expect(
      resolveFrameImageUrl('/uploads/frames/aster.png'),
      'http://10.0.2.2:5000/uploads/frames/aster.png',
    );
    expect(
      resolveFrameImageUrl('uploads/frames/aster.png'),
      'http://10.0.2.2:5000/uploads/frames/aster.png',
    );
    expect(
      resolveFrameImageUrl('http://localhost:5000/uploads/frames/aster.png'),
      'http://10.0.2.2:5000/uploads/frames/aster.png',
    );
    expect(
      resolveFrameImageUrl(
        'http://192.168.100.23/uploads/1789920969230-406953798.png',
      ),
      'http://10.0.2.2:5000/uploads/1789920969230-406953798.png',
    );
  });
}
