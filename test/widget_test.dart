import 'package:flutter_test/flutter_test.dart';
import 'package:rent_lk_flutter_application/main.dart';

void main() {
  testWidgets('Rent.lk project test placeholder', (WidgetTester tester) async {
    expect(1, 1);
  });

  group('Booking Driver Option Tests', () {
    test('Booking with_driver option correctly sets properties', () {
      final booking = Booking(
        id: 'test_b1',
        customerId: 'cust_1',
        vehicleId: 'veh_1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 5),
        pickupLocation: 'Colombo',
        returnLocation: 'Kandy',
        driverOption: 'with_driver',
        status: BookingStatus.pending,
        totalAmount: 25000,
        advancePaid: 5000,
        note: 'Need child seat',
        createdAt: DateTime(2026, 7, 29),
      );

      expect(booking.driverOption, equals('with_driver'));
      expect(booking.isWithDriver, isTrue);
      expect(booking.driverOptionLabel, equals('With Driver'));
    });

    test('Booking without_driver option correctly sets properties', () {
      final booking = Booking(
        id: 'test_b2',
        customerId: 'cust_1',
        vehicleId: 'veh_1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 5),
        pickupLocation: 'Colombo',
        returnLocation: 'Colombo',
        driverOption: 'without_driver',
        status: BookingStatus.approved,
        totalAmount: 20000,
        advancePaid: 0,
        note: '',
        createdAt: DateTime(2026, 7, 29),
      );

      expect(booking.driverOption, equals('without_driver'));
      expect(booking.isWithDriver, isFalse);
      expect(booking.driverOptionLabel, equals('Without Driver'));
    });

    test('Backward compatibility: map missing driverOption defaults to without_driver', () {
      final mapData = <String, dynamic>{
        'customerId': 'cust_99',
        'vehicleId': 'veh_99',
        'startDate': '2026-08-01',
        'endDate': '2026-08-05',
        'pickupLocation': 'Galle',
        'returnLocation': 'Galle',
        'status': 'approved',
        'totalAmount': 15000,
        'advancePaid': 0,
        'note': 'Old record without driverOption',
        'createdAt': '2026-07-01',
      };

      final booking = Booking.fromMap(mapData, 'old_b1');

      expect(booking.driverOption, equals('without_driver'));
      expect(booking.isWithDriver, isFalse);
      expect(booking.driverOptionLabel, equals('Without Driver'));
    });
  });
}
