import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  // Firebase Initialize කිරීම
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RentRoot());
}

// =========================
// Rent.lk - Vehicle Rental Application (Firebase Edition)
// =========================

// Professional Premium Color Palette
const Color kPrimary = Color(0xFF1E3A8A); // Deep Premium Blue
const Color kPrimaryDark = Color(0xFF0F172A); // Slate 900
const Color kAccent = Color(0xFF10B981); // Emerald Green
const Color kSurface = Color(0xFFF8FAFC); // Clean Slate 50
const Color kText = Color(0xFF0F172A); // Slate 900 text

const String heroImage = 'https://i.postimg.cc/vmGYFQmM/ll.png';

String money(num value) => 'LKR ${value.toStringAsFixed(0)}';

String dateText(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

int rentalDays(DateTime start, DateTime end) {
  return max(1, end.difference(start).inDays + 1);
}

DateTime _parseDate(dynamic date) {
  if (date == null) return DateTime.now();
  if (date is Timestamp) return date.toDate();
  if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
  return DateTime.now();
}

bool rangesOverlap(
    DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  final a = DateTime(aStart.year, aStart.month, aStart.day);
  final b = DateTime(aEnd.year, aEnd.month, aEnd.day);
  final c = DateTime(bStart.year, bStart.month, bStart.day);
  final d = DateTime(bEnd.year, bEnd.month, bEnd.day);
  return !b.isBefore(c) && !d.isBefore(a);
}

// =========================
// Models (Firebase Ready)
// =========================

enum UserRole { customer, staff, admin, owner }

enum BookingStatus { pending, approved, rejected, completed }

class AppUser {
  final String id;
  String name;
  String email;
  String password;
  UserRole role;
  String phone;
  String nic;
  String? businessName;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.phone,
    required this.nic,
    this.businessName,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String docId) {
    UserRole r = UserRole.customer;
    if (data['role'] == 'admin') r = UserRole.admin;
    if (data['role'] == 'staff') r = UserRole.staff;
    if (data['role'] == 'owner') r = UserRole.owner;

    return AppUser(
      id: docId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      role: r,
      phone: data['phone'] ?? '',
      nic: data['nic'] ?? '',
      businessName: data['businessName'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email.toLowerCase(),
        'password': password,
        'role': role.name,
        'phone': phone,
        'nic': nic,
        'businessName': businessName,
      };
}

class Vehicle {
  final String id;
  String name;
  String type;
  String model;
  String plateNumber;
  String fuelType;
  String transmission;
  String location;
  int seats;
  double pricePerDay;
  bool available;
  String imageUrl;
  String description;
  String? ownerId;
  String? ownerName;

  Vehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.model,
    required this.plateNumber,
    required this.fuelType,
    required this.transmission,
    required this.location,
    required this.seats,
    required this.pricePerDay,
    required this.available,
    required this.imageUrl,
    required this.description,
    this.ownerId,
    this.ownerName,
  });

  factory Vehicle.fromMap(Map<String, dynamic> data, String docId) {
    return Vehicle(
      id: docId,
      name: data['name'] ?? '',
      type: data['type'] ?? 'Car',
      model: data['model'] ?? '',
      plateNumber: data['plateNumber'] ?? '',
      fuelType: data['fuelType'] ?? '',
      transmission: data['transmission'] ?? '',
      location: data['location'] ?? '',
      seats: data['seats'] ?? 4,
      pricePerDay: (data['pricePerDay'] ?? 0).toDouble(),
      available: data['available'] ?? true,
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      ownerId: data['ownerId'],
      ownerName: data['ownerName'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'model': model,
        'plateNumber': plateNumber,
        'fuelType': fuelType,
        'transmission': transmission,
        'location': location,
        'seats': seats,
        'pricePerDay': pricePerDay,
        'available': available,
        'imageUrl': imageUrl,
        'description': description,
        'ownerId': ownerId,
        'ownerName': ownerName,
      };
}

class Booking {
  final String id;
  final String customerId;
  final String vehicleId;
  DateTime startDate;
  DateTime endDate;
  String pickupLocation;
  String returnLocation;
  String driverOption; // 'with_driver' or 'without_driver'
  BookingStatus status;
  double totalAmount;
  double advancePaid;
  String note;
  DateTime createdAt;

  Booking({
    required this.id,
    required this.customerId,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.pickupLocation,
    required this.returnLocation,
    this.driverOption = 'without_driver',
    required this.status,
    required this.totalAmount,
    required this.advancePaid,
    required this.note,
    required this.createdAt,
  });

  factory Booking.fromMap(Map<String, dynamic> data, String docId) {
    BookingStatus s = BookingStatus.pending;
    if (data['status'] == 'approved') s = BookingStatus.approved;
    if (data['status'] == 'rejected') s = BookingStatus.rejected;
    if (data['status'] == 'completed') s = BookingStatus.completed;

    final String dOpt =
        (data['driverOption'] ?? data['driver_option'] ?? 'without_driver')
            .toString();

    return Booking(
      id: docId,
      customerId: data['customerId'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      pickupLocation: data['pickupLocation'] ?? '',
      returnLocation: data['returnLocation'] ?? '',
      driverOption: dOpt == 'with_driver' ? 'with_driver' : 'without_driver',
      status: s,
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      advancePaid: (data['advancePaid'] ?? 0).toDouble(),
      note: data['note'] ?? '',
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'vehicleId': vehicleId,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'pickupLocation': pickupLocation,
        'returnLocation': returnLocation,
        'driverOption': driverOption,
        'status': status.name,
        'totalAmount': totalAmount,
        'advancePaid': advancePaid,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  bool get isWithDriver => driverOption == 'with_driver';
  String get driverOptionLabel =>
      isWithDriver ? 'With Driver' : 'Without Driver';

  double get balance => max(0, totalAmount - advancePaid);
}

class PaymentRecord {
  final String id;
  final String bookingId;
  double amount;
  String method;
  DateTime paidAt;
  String status;

  PaymentRecord({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.paidAt,
    required this.status,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> data, String docId) {
    return PaymentRecord(
      id: docId,
      bookingId: data['bookingId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      method: data['method'] ?? '',
      paidAt: _parseDate(data['paidAt']),
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'amount': amount,
        'method': method,
        'paidAt': Timestamp.fromDate(paidAt),
        'status': status,
      };
}

class AppNotice {
  final String id;
  final String userId;
  String title;
  String message;
  DateTime createdAt;
  bool read;

  AppNotice({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  factory AppNotice.fromMap(Map<String, dynamic> data, String docId) {
    return AppNotice(
      id: docId,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'message': message,
        'createdAt': Timestamp.fromDate(createdAt),
        'read': read,
      };
}

// =========================
// Firebase Store
// =========================

class RentStore extends ChangeNotifier {
  bool booted = false;
  AppUser? currentUser;

  List<AppUser> users = [];
  List<Vehicle> vehicles = [];
  List<Booking> bookings = [];
  List<PaymentRecord> payments = [];
  List<AppNotice> notices = [];

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RentStore() {
    bootstrap();
  }

  Future<void> bootstrap() async {
    // Real-time Firebase Listeners
    _db.collection('vehicles').snapshots().listen((snap) {
      vehicles = snap.docs.map((d) => Vehicle.fromMap(d.data(), d.id)).toList();
      notifyListeners();
    });

    _db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      bookings = snap.docs.map((d) => Booking.fromMap(d.data(), d.id)).toList();
      notifyListeners();
    });

    _db
        .collection('payments')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .listen((snap) {
      payments =
          snap.docs.map((d) => PaymentRecord.fromMap(d.data(), d.id)).toList();
      notifyListeners();
    });

    _db
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      notices =
          snap.docs.map((d) => AppNotice.fromMap(d.data(), d.id)).toList();
      notifyListeners();
    });

    _db.collection('users').snapshots().listen((snap) {
      users = snap.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList();

      // FIXED RACE CONDITION: Always check and safely build core accounts regardless of local speed
      bool hasAdmin =
          users.any((u) => u.email.toLowerCase() == 'admin@rent.lk');
      bool hasStaff =
          users.any((u) => u.email.toLowerCase() == 'staff@rent.lk');
      if (!hasAdmin) {
        _createInitialAccount('System Administrator', 'admin@rent.lk',
            'admin123', UserRole.admin);
      }
      if (!hasStaff) {
        _createInitialAccount('System Staff Workspace', 'staff@rent.lk',
            'staff123', UserRole.staff);
      }

      notifyListeners();
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    booted = true;
    notifyListeners();
  }

  void _createInitialAccount(
      String name, String email, String password, UserRole role) {
    final doc = _db.collection('users').doc();
    doc.set(AppUser(
            id: doc.id,
            name: name,
            email: email,
            password: password,
            role: role,
            phone: '0710001111',
            nic: role.name.toUpperCase())
        .toMap());
  }

  Future<bool> login(String email, String password) async {
    final e = email.trim().toLowerCase();
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: e)
        .where('password', isEqualTo: password)
        .get();

    if (snap.docs.isEmpty) return false;
    currentUser = AppUser.fromMap(snap.docs.first.data(), snap.docs.first.id);
    notifyListeners();
    return true;
  }

  Future<bool> registerCustomer(
      {required String name,
      required String email,
      required String phone,
      required String nic,
      required String password}) async {
    final e = email.trim().toLowerCase();
    final snap =
        await _db.collection('users').where('email', isEqualTo: e).get();

    if (snap.docs.isNotEmpty) return false;

    final doc = _db.collection('users').doc();
    final u = AppUser(
      id: doc.id,
      name: name.trim(),
      email: e,
      password: password,
      role: UserRole.customer,
      phone: phone.trim(),
      nic: nic.trim(),
    );

    await doc.set(u.toMap());
    currentUser = u;
    _notice(u.id, 'Welcome to Rent.lk',
        'Your profile account was successfully created.');
    notifyListeners();
    return true;
  }

  Future<bool> registerVehicleOwner(
      {required String name,
      required String email,
      required String phone,
      required String nic,
      required String password,
      String? businessName}) async {
    final e = email.trim().toLowerCase();
    final snap =
        await _db.collection('users').where('email', isEqualTo: e).get();

    if (snap.docs.isNotEmpty) return false;

    final doc = _db.collection('users').doc();
    final u = AppUser(
      id: doc.id,
      name: name.trim(),
      email: e,
      password: password,
      role: UserRole.owner,
      phone: phone.trim(),
      nic: nic.trim(),
      businessName: businessName?.trim(),
    );

    await doc.set(u.toMap());
    currentUser = u;
    _notice(u.id, 'Welcome to Rent.lk Owner Portal',
        'Your Vehicle Owner account was successfully registered.');
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  AppUser? userById(String id) => users
      .where((u) => u.id == id)
      .cast<AppUser?>()
      .firstWhere((u) => u != null, orElse: () => null);
  Vehicle? vehicleById(String id) => vehicles
      .where((v) => v.id == id)
      .cast<Vehicle?>()
      .firstWhere((v) => v != null, orElse: () => null);
  Booking? bookingById(String id) => bookings
      .where((b) => b.id == id)
      .cast<Booking?>()
      .firstWhere((b) => b != null, orElse: () => null);

  bool isVehicleFree(String vehicleId, DateTime start, DateTime end) {
    final vehicle = vehicleById(vehicleId);
    if (vehicle == null || !vehicle.available) return false;
    return bookings
        .where((b) =>
            b.vehicleId == vehicleId &&
            (b.status == BookingStatus.pending ||
                b.status == BookingStatus.approved))
        .every((b) {
      return !rangesOverlap(b.startDate, b.endDate, start, end);
    });
  }

  List<Vehicle> availableVehiclesFor(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return vehicles.where((v) => v.available).toList();
    }
    return vehicles.where((v) => isVehicleFree(v.id, start, end)).toList();
  }

  Future<String> createBooking({
    required String customerId,
    required String vehicleId,
    required DateTime start,
    required DateTime end,
    required String pickup,
    required String drop,
    required String note,
    required String driverOption,
  }) async {
    final vehicle = vehicleById(vehicleId);
    if (vehicle == null) return 'Vehicle not found';
    if (!isVehicleFree(vehicleId, start, end)) {
      return 'Selected vehicle is not available for this date range';
    }
    final total = rentalDays(start, end) * vehicle.pricePerDay;

    final doc = _db.collection('bookings').doc();
    final booking = Booking(
      id: doc.id,
      customerId: customerId,
      vehicleId: vehicleId,
      startDate: start,
      endDate: end,
      pickupLocation: pickup,
      returnLocation: drop,
      driverOption: driverOption == 'with_driver' ? 'with_driver' : 'without_driver',
      status: BookingStatus.pending,
      totalAmount: total,
      advancePaid: 0,
      note: note,
      createdAt: DateTime.now(),
    );

    await doc.set(booking.toMap());
    _notice(customerId, 'Booking Sent',
        'Booking request sent for ${vehicle.name}.');
    _notifyStaff(
        'New Booking', 'New customer booking request for ${vehicle.name}.');
    return 'success';
  }

  void approveBooking(String bookingId) {
    _db.collection('bookings').doc(bookingId).update({'status': 'approved'});
    final b = bookingById(bookingId);
    if (b != null) {
      _notice(
          b.customerId, 'Booking Approved', 'Your booking has been approved.');
    }
  }

  void rejectBooking(String bookingId) {
    _db.collection('bookings').doc(bookingId).update({'status': 'rejected'});
    final b = bookingById(bookingId);
    if (b != null) {
      _notice(b.customerId, 'Booking Rejected',
          'Your booking request was rejected.');
    }
  }

  Future<void> completeBooking(String bookingId) async {
    final b = bookingById(bookingId);
    if (b == null) return;

    await _db.collection('bookings').doc(bookingId).update({'status': 'completed'});

    // Prevent duplicate completion notifications
    final refTag = '[Ref:${b.id}]';
    final alreadyNotified = notices.any((n) =>
        n.message.contains(refTag) ||
        (n.title.contains('Completed') && n.message.contains(b.id)));
    if (alreadyNotified) return;

    final vehicle = vehicleById(b.vehicleId);
    final customer = userById(b.customerId);
    final vName = vehicle?.name ?? 'Vehicle';
    final vPlate = vehicle?.plateNumber ?? 'N/A';
    final cName = customer?.name ?? 'Customer';
    final dOptText = b.driverOptionLabel;
    final nowText = dateText(DateTime.now());

    final title = 'Booking Completed';
    final message = 'Booking $refTag for $vName ($vPlate) has been completed.\n'
        'Customer: $cName | Option: $dOptText | Date: $nowText | Status: Completed';

    // 1. Notify Admins & Staff
    _notifyStaff(title, message);

    // 2. Notify Vehicle Owner (if vehicle belongs to an owner)
    if (vehicle?.ownerId != null && vehicle!.ownerId!.isNotEmpty) {
      // Send notice specifically to this owner
      _notice(vehicle.ownerId!, title, message);
    }

    // 3. Notify Customer
    _notice(b.customerId, title, message);
  }

  void recordPayment(String bookingId, double amount, String method) {
    final b = bookingById(bookingId);
    if (b == null || amount <= 0) return;

    final pDoc = _db.collection('payments').doc();
    final payment = PaymentRecord(
      id: pDoc.id,
      bookingId: bookingId,
      amount: min(amount, b.balance),
      method: method,
      paidAt: DateTime.now(),
      status: 'Confirmed',
    );

    pDoc.set(payment.toMap());
    _db.collection('bookings').doc(bookingId).update(
        {'advancePaid': min(b.totalAmount, b.advancePaid + payment.amount)});

    _notice(b.customerId, 'Payment Confirmed',
        '${money(payment.amount)} payment recorded.');
  }

  void addVehicle(Vehicle vehicle) {
    final doc = _db.collection('vehicles').doc();
    _db.collection('vehicles').doc(doc.id).set(Vehicle(
          id: doc.id,
          name: vehicle.name,
          type: vehicle.type,
          model: vehicle.model,
          plateNumber: vehicle.plateNumber,
          fuelType: vehicle.fuelType,
          transmission: vehicle.transmission,
          location: vehicle.location,
          seats: vehicle.seats,
          pricePerDay: vehicle.pricePerDay,
          available: vehicle.available,
          imageUrl: vehicle.imageUrl,
          description: vehicle.description,
          ownerId: vehicle.ownerId,
          ownerName: vehicle.ownerName,
        ).toMap());
  }

  List<Vehicle> vehiclesForOwner(String ownerId) {
    return vehicles.where((v) => v.ownerId == ownerId).toList();
  }

  List<Booking> bookingsForOwner(String ownerId) {
    final ownerVehicleIds =
        vehiclesForOwner(ownerId).map((v) => v.id).toSet();
    return bookings.where((b) => ownerVehicleIds.contains(b.vehicleId)).toList();
  }

  List<PaymentRecord> paymentsForOwner(String ownerId) {
    final ownerBookingIds =
        bookingsForOwner(ownerId).map((b) => b.id).toSet();
    return payments.where((p) => ownerBookingIds.contains(p.bookingId)).toList();
  }

  double ownerTotalEarnings(String ownerId) {
    return paymentsForOwner(ownerId).fold(0.0, (sum, p) => sum + p.amount);
  }

  void updateVehicle(Vehicle v) {
    _db.collection('vehicles').doc(v.id).update(v.toMap());
  }

  void toggleVehicle(String id) {
    final v = vehicleById(id);
    if (v != null) {
      _db.collection('vehicles').doc(id).update({'available': !v.available});
    }
  }

  void deleteVehicle(String id) {
    _db.collection('vehicles').doc(id).delete();
  }

  List<Booking> bookingsForCurrentUser() {
    final u = currentUser;
    if (u == null) return [];
    if (u.role == UserRole.customer) {
      return bookings.where((b) => b.customerId == u.id).toList();
    }
    return bookings;
  }

  List<PaymentRecord> paymentsForCurrentUser() {
    final u = currentUser;
    if (u == null) return [];
    if (u.role != UserRole.customer) return payments;
    final myBookingIds =
        bookings.where((b) => b.customerId == u.id).map((b) => b.id).toSet();
    return payments.where((p) => myBookingIds.contains(p.bookingId)).toList();
  }

  List<AppNotice> noticesForCurrentUser() {
    final u = currentUser;
    if (u == null) return [];
    return notices.where((n) => n.userId == u.id).toList();
  }

  void markAllRead() {
    final u = currentUser;
    if (u == null) return;
    for (final n in notices.where((n) => n.userId == u.id && !n.read)) {
      _db.collection('notices').doc(n.id).update({'read': true});
    }
  }

  double get totalIncome => payments.fold(0, (sum, p) => sum + p.amount);
  double get pendingBalance => bookings.fold(0, (sum, b) => sum + b.balance);
  int get pendingBookings =>
      bookings.where((b) => b.status == BookingStatus.pending).length;
  int get activeVehicles => vehicles.where((v) => v.available).length;

  void _notice(String userId, String title, String message) {
    final doc = _db.collection('notices').doc();
    doc.set(AppNotice(
            id: doc.id,
            userId: userId,
            title: title,
            message: message,
            createdAt: DateTime.now(),
            read: false)
        .toMap());
  }

  void _notifyStaff(String title, String message) {
    for (final u in users
        .where((u) => u.role == UserRole.staff || u.role == UserRole.admin)) {
      _notice(u.id, title, message);
    }
  }
}

class RentScope extends InheritedNotifier<RentStore> {
  const RentScope({super.key, required RentStore store, required Widget child})
      : super(notifier: store, child: child);

  static RentStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RentScope>();
    return scope!.notifier!;
  }
}

class RentRoot extends StatefulWidget {
  const RentRoot({super.key});

  @override
  State<RentRoot> createState() => _RentRootState();
}

class _RentRootState extends State<RentRoot> {
  final RentStore store = RentStore();

  @override
  Widget build(BuildContext context) {
    return RentScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Rent.lk',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: kSurface,
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: kText),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 2.0)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        home: const AppGate(),
      ),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    if (!store.booted) return const SplashScreen();

    final user = store.currentUser;
    if (user == null) return const GuestShell();

    if (user.role == UserRole.admin) return const AdminShell();
    if (user.role == UserRole.staff) return const StaffShell();
    if (user.role == UserRole.owner) return const OwnerShell();
    return const CustomerShell();
  }
}

// =========================
// UI Components
// =========================

class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsivePage({super.key, required this.child, this.maxWidth = 1180});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: child,
        ),
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const PremiumCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap, child: card);
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const SectionTitle(
      {super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: kText)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.blueGrey.shade600)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const StatCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: kText)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final BookingStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String text;
    late IconData icon;
    switch (status) {
      case BookingStatus.pending:
        color = const Color(0xFFF59E0B);
        text = 'Pending';
        icon = Icons.pending_actions;
        break;
      case BookingStatus.approved:
        color = kAccent;
        text = 'Approved';
        icon = Icons.verified;
        break;
      case BookingStatus.rejected:
        color = const Color(0xFFEF4444);
        text = 'Rejected';
        icon = Icons.cancel;
        break;
      case BookingStatus.completed:
        color = const Color(0xFF64748B);
        text = 'Completed';
        icon = Icons.task_alt;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w700))
      ]),
    );
  }
}

class AppLogo extends StatelessWidget {
  final bool light;
  const AppLogo({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
              color: light ? Colors.white : kPrimary,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.directions_car_filled,
              color: light ? kPrimary : Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Text('Rent.lk',
            style: TextStyle(
                color: light ? Colors.white : kText,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyView(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                child: Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFF64748B), height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

// =========================
// Premium Rounded Spinner Splash Screen
// =========================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [kPrimaryDark, kPrimary],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(light: true),
              const SizedBox(height: 32),
              const SizedBox(
                height: 42,
                width: 42,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 4.0,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Central Secured Platform',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool isModal;
  const AuthScreen({super.key, this.isModal = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool registerMode = false;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final nic = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    phone.dispose();
    nic.dispose();
    super.dispose();
  }

  void _submit() async {
    final store = RentScope.of(context);
    if (registerMode) {
      if (name.text.trim().isEmpty ||
          email.text.trim().isEmpty ||
          password.text.length < 4) {
        showSnack(context, 'Please enter a valid name, email, and password.');
        return;
      }
      final ok = await store.registerCustomer(
          name: name.text,
          email: email.text,
          phone: phone.text,
          nic: nic.text,
          password: password.text);
      if (!ok) {
        showSnack(context, 'This email is already registered in the system.');
      } else if (widget.isModal) {
        Navigator.pop(context);
      }
      return;
    }
    final ok = await store.login(email.text, password.text);
    if (!ok) {
      showSnack(context, 'Login failed. Incorrect email or password.');
    } else if (widget.isModal) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.isModal
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(heroImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: kPrimaryDark)),
          ),
          Positioned.fill(
              child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
              kPrimaryDark.withOpacity(0.9),
              kPrimaryDark.withOpacity(0.4)
            ], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
          )),
          SafeArea(
            child: ResponsivePage(
              maxWidth: 1060,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 820;
                  final intro = Padding(
                    padding: EdgeInsets.all(wide ? 12 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppLogo(light: true),
                        SizedBox(height: wide ? 28 : 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24)),
                          child: const Text(
                              'Sri Lanka Vehicle Rental Management',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                        SizedBox(height: wide ? 20 : 12),
                        Text(
                            'Book, manage and track rentals in one clean mobile app.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: wide ? 36 : 22,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: wide ? -1.0 : -0.5)),
                        if (wide) ...[
                          const SizedBox(height: 16),
                          Text(
                              'Customer booking, staff approval, payment tracking, notifications and reports backed by Firebase Cloud.',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 15,
                                  height: 1.6)),
                        ],
                      ],
                    ),
                  );

                  final form = SizedBox(
                    width: wide ? 460 : double.infinity,
                    child: PremiumCard(
                      padding: EdgeInsets.all(wide ? 28 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              registerMode
                                  ? 'Create Account'
                                  : 'Login to Rent.lk',
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: kText)),
                          const SizedBox(height: 8),
                          Text(
                              registerMode
                                  ? 'Enter your details to register'
                                  : 'Sign in to access your account',
                              style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                  fontSize: 14)),
                          const SizedBox(height: 24),
                          if (registerMode) ...[
                            TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: Icon(Icons.person_outline))),
                            const SizedBox(height: 16),
                            TextField(
                                controller: phone,
                                decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    prefixIcon: Icon(Icons.call_outlined))),
                            const SizedBox(height: 16),
                            TextField(
                                controller: nic,
                                decoration: const InputDecoration(
                                    labelText: 'NIC / Passport',
                                    prefixIcon: Icon(Icons.badge_outlined))),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.mail_outline))),
                          const SizedBox(height: 16),
                          TextField(
                              controller: password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline))),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                              onPressed: _submit,
                              icon: Icon(registerMode
                                  ? Icons.person_add_alt
                                  : Icons.login),
                              label: Text(
                                  registerMode ? 'Register Account' : 'Login'),
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56))),
                          const SizedBox(height: 16),
                          TextButton(
                              onPressed: () =>
                                  setState(() => registerMode = !registerMode),
                              child: Text(
                                  registerMode
                                      ? 'Already have an account? Login'
                                      : 'New user? Create account',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          const Divider(height: 24, color: Color(0xFFE2E8F0)),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const VehicleOwnerLoginScreen()),
                              );
                            },
                            icon: const Icon(Icons.car_rental, size: 18),
                            label: const Text('Vehicle Owner Portal',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );

                  return Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Expanded(child: intro),
                                    const SizedBox(width: 48),
                                    form
                                  ])
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    intro,
                                    const SizedBox(height: 16),
                                    form
                                  ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// Role Shells
// =========================

class RoleShell extends StatefulWidget {
  final List<NavigationDestination> destinations;
  final List<Widget> pages;
  final bool isGuest;

  const RoleShell({
    super.key,
    required this.destinations,
    required this.pages,
    this.isGuest = false,
  });

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final user = store.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AppLogo(),
        ),
        actions: [
          if (widget.isGuest)
            Builder(
              builder: (context) {
                final width = MediaQuery.of(context).size.width;
                final isCompact = width < 600;
                final isVeryCompact = width < 420;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isVeryCompact)
                        IconButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const VehicleOwnerLoginScreen())),
                          icon: const Icon(Icons.car_rental, size: 20),
                          tooltip: 'Owner Portal',
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const VehicleOwnerLoginScreen())),
                          icon: const Icon(Icons.car_rental, size: 16),
                          label: Text(isCompact ? 'Owner' : 'Owner Portal',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 8 : 12),
                          ),
                        ),
                      const SizedBox(width: 6),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AuthScreen(isModal: true))),
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(isCompact ? 'Login' : 'Login / Register',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 10 : 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                );
              },
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                  child: Text(user!.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kPrimary))),
            ),
            IconButton(
                onPressed: () {
                  store.logout();
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                icon: const Icon(Icons.logout),
                tooltip: 'Logout'),
            const SizedBox(width: 8),
          ]
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 920;
          if (wide) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (v) => setState(() => index = v),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  destinations: widget.destinations
                      .map((d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label)))
                      .toList(),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                Expanded(child: widget.pages[index]),
              ],
            );
          }
          return widget.pages[index];
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, c) {
          if (MediaQuery.of(context).size.width > 920) {
            return const SizedBox.shrink();
          }
          return NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (v) => setState(() => index = v),
              elevation: 8,
              backgroundColor: Colors.white,
              destinations: widget.destinations);
        },
      ),
    );
  }
}

class GuestShell extends StatelessWidget {
  const GuestShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      isGuest: true,
      destinations: [
        NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Vehicles'),
      ],
      pages: [
        CustomerHomePage(),
        CustomerVehiclePage(),
      ],
    );
  }
}

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      destinations: [
        NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Vehicles'),
        NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bookings'),
        NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payments'),
        NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts'),
      ],
      pages: [
        CustomerHomePage(),
        CustomerVehiclePage(),
        BookingHistoryPage(),
        CustomerPaymentsPage(),
        NotificationsPage()
      ],
    );
  }
}

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      destinations: [
        NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard'),
        NavigationDestination(
            icon: Icon(Icons.car_rental_outlined),
            selectedIcon: Icon(Icons.car_rental),
            label: 'Vehicles'),
        NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Bookings'),
        NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payments'),
        NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports'),
      ],
      pages: [
        AdminDashboardPage(),
        VehicleManagementPage(),
        BookingManagementPage(),
        PaymentManagementPage(),
        ReportsPage()
      ],
    );
  }
}

class StaffShell extends StatelessWidget {
  const StaffShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      destinations: [
        NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Today'),
        NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Bookings'),
        NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payments'),
        NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts'),
      ],
      pages: [
        StaffTodayPage(),
        BookingManagementPage(),
        PaymentManagementPage(),
        NotificationsPage()
      ],
    );
  }
}

// =========================
// Customer & Guest Pages
// =========================

class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final user = store.currentUser;
    final myBookings =
        user == null ? <Booking>[] : store.bookingsForCurrentUser();

    return ResponsivePage(
      child: ListView(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 280),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                    image: NetworkImage(heroImage), fit: BoxFit.cover)),
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(colors: [
                    kPrimaryDark.withOpacity(0.85),
                    kPrimaryDark.withOpacity(0.15)
                  ], begin: Alignment.bottomLeft, end: Alignment.topRight)),
              padding: const EdgeInsets.all(32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Hello ${user?.name.split(' ').first ?? 'Traveler'}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Find a vehicle for your next Sri Lanka trip.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            letterSpacing: -0.5,
                            fontWeight: FontWeight.w900,
                            height: 1.1)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 10, runSpacing: 10, children: const [
                      _HeroPill(
                          icon: Icons.verified_user_outlined,
                          text: 'Secure booking'),
                      _HeroPill(
                          icon: Icons.event_available_outlined,
                          text: 'Real-time availability'),
                      _HeroPill(
                          icon: Icons.payments_outlined,
                          text: 'Payment tracking'),
                    ]),
                  ]),
            ),
          ),
          const SizedBox(height: 24),

          // BUG FIX: Switched from rigid GridView to dynamic Wrap to allow StatCard natural height expansion.
          LayoutBuilder(builder: (context, c) {
            final cards = user != null
                ? [
                    StatCard(
                        icon: Icons.receipt_long,
                        label: 'My Bookings',
                        value: myBookings.length.toString(),
                        color: kPrimary),
                    StatCard(
                        icon: Icons.pending_actions,
                        label: 'Pending',
                        value: myBookings
                            .where((b) => b.status == BookingStatus.pending)
                            .length
                            .toString(),
                        color: const Color(0xFFF59E0B)),
                    StatCard(
                        icon: Icons.account_balance_wallet,
                        label: 'Balance',
                        value:
                            money(myBookings.fold(0, (s, b) => s + b.balance)),
                        color: const Color(0xFFEF4444)),
                  ]
                : [
                    StatCard(
                        icon: Icons.directions_car,
                        label: 'Available Vehicles',
                        value: store.activeVehicles.toString(),
                        color: kPrimary),
                    const StatCard(
                        icon: Icons.location_on,
                        label: 'Pickup Locations',
                        value: 'Island-wide',
                        color: kAccent),
                    const StatCard(
                        icon: Icons.support_agent,
                        label: 'Customer Support',
                        value: '24/7',
                        color: Color(0xFFF59E0B)),
                  ];

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((e) => SizedBox(
                        width: c.maxWidth > 760
                            ? (c.maxWidth - 32) / 3
                            : double.infinity,
                        child: e,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 16),
          const SectionTitle(
              title: 'Available Vehicles',
              subtitle:
                  'Vehicles suited for Sri Lankan routes and local rental requirements.'),
          VehicleGrid(
              vehicles:
                  store.vehicles.where((v) => v.available).take(4).toList(),
              customerMode: true),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))
      ]),
    );
  }
}

class CustomerVehiclePage extends StatefulWidget {
  const CustomerVehiclePage({super.key});

  @override
  State<CustomerVehiclePage> createState() => _CustomerVehiclePageState();
}

class _CustomerVehiclePageState extends State<CustomerVehiclePage> {
  String category = 'All';
  String search = '';
  DateTimeRange? range;

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    var list = store.availableVehiclesFor(range?.start, range?.end);
    if (category != 'All') {
      list = list.where((v) => v.type == category).toList();
    }
    if (search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      list = list
          .where((v) =>
              v.name.toLowerCase().contains(q) ||
              v.location.toLowerCase().contains(q) ||
              v.type.toLowerCase().contains(q))
          .toList();
    }
    return ResponsivePage(
      child: ListView(
        children: [
          SectionTitle(
            title: 'Browse Vehicles',
            subtitle: 'Search by date range, category, and location.',
            trailing: FilledButton.tonalIcon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: range);
                if (picked != null) setState(() => range = picked);
              },
              icon: const Icon(Icons.date_range),
              label: const Text('Dates'),
            ),
          ),
          PremiumCard(
            child: Column(
              children: [
                TextField(
                    onChanged: (v) => setState(() => search = v),
                    decoration: const InputDecoration(
                        labelText: 'Search by vehicle, type or city',
                        prefixIcon: Icon(Icons.search))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: Text(
                          range == null
                              ? 'No date filter selected'
                              : '${dateText(range!.start)} to ${dateText(range!.end)}',
                          style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w700))),
                  if (range != null)
                    TextButton(
                        onPressed: () => setState(() => range = null),
                        child: const Text('Clear Filter',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ['All', 'Car', 'Van', 'Tuk Tuk', 'Motorcycle']
                        .map((c) => ChoiceChip(
                            label: Text(c),
                            selected: category == c,
                            showCheckmark: false,
                            selectedColor: kPrimary.withOpacity(0.15),
                            labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: category == c ? kPrimary : kText),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            onSelected: (_) => setState(() => category = c)))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (list.isEmpty)
            const EmptyView(
                icon: Icons.search_off,
                title: 'No vehicles found',
                message: 'No vehicles available for the selected filters.')
          else
            VehicleGrid(vehicles: list, customerMode: true),
        ],
      ),
    );
  }
}

class VehicleGrid extends StatelessWidget {
  final List<Vehicle> vehicles;
  final bool customerMode;
  const VehicleGrid(
      {super.key, required this.vehicles, required this.customerMode});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final count = c.maxWidth > 980
          ? 3
          : c.maxWidth > 640
              ? 2
              : 1;

      // BUG FIX: Intelligently computing childAspectRatio based on dynamic cell width
      // ensuring card heights are consistently anchored at 280px rather than rigid constraints.
      final cellWidth = (c.maxWidth - (16 * (count - 1))) / count;
      final safeHeight = 280.0;
      final ratio = cellWidth / safeHeight;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            childAspectRatio: ratio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16),
        itemCount: vehicles.length,
        itemBuilder: (context, i) =>
            VehicleCard(vehicle: vehicles[i], customerMode: customerMode),
      );
    });
  }
}

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final bool customerMode;
  const VehicleCard(
      {super.key, required this.vehicle, required this.customerMode});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);

    void handleTap() {
      if (store.currentUser == null) {
        showSnack(context, 'Please log in to book a vehicle.');
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AuthScreen(isModal: true)));
      } else {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VehicleDetailPage(vehicleId: vehicle.id)));
      }
    }

    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: customerMode ? handleTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 120, // Strict design standard height budget
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(vehicle.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE9EEF6),
                          child: const Icon(Icons.directions_car,
                              size: 40, color: kPrimary))),
                  Positioned.fill(
                      child: Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ])))),
                  Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 2)
                              ],
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(vehicle.type,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w900)))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(vehicle.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: kText))),
                    Icon(
                        vehicle.available
                            ? Icons.check_circle
                            : Icons.remove_circle,
                        color: vehicle.available
                            ? kAccent
                            : const Color(0xFFEF4444),
                        size: 16)
                  ]),
                  const SizedBox(height: 4),
                  Text('${vehicle.location} • ${vehicle.fuelType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade600,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: Text('${money(vehicle.pricePerDay)}/d',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                color: kPrimary,
                                fontWeight: FontWeight.w900))),
                    if (customerMode)
                      SizedBox(
                        height: 32,
                        child: FilledButton(
                            onPressed: handleTap,
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                textStyle: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            child: const Text('Book')),
                      ),
                  ]),
                ]),
          ),
        ],
      ),
    );
  }
}

class VehicleDetailPage extends StatefulWidget {
  final String vehicleId;
  const VehicleDetailPage({super.key, required this.vehicleId});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  DateTimeRange? range;
  String driverOption = 'without_driver';
  final pickup = TextEditingController(text: 'Colombo City Office');
  final drop = TextEditingController(text: 'Colombo City Office');
  final note = TextEditingController();

  @override
  void dispose() {
    pickup.dispose();
    drop.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final vehicle = store.vehicleById(widget.vehicleId)!;
    final days = range == null ? 0 : rentalDays(range!.start, range!.end);
    final total = days * vehicle.pricePerDay;
    return Scaffold(
      appBar: AppBar(
          title: Text(vehicle.name,
              style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ResponsivePage(
        maxWidth: 980,
        child: ListView(
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(vehicle.imageUrl,
                    height: 320,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: 320,
                        color: Colors.white,
                        child: const Icon(Icons.directions_car, size: 72)))),
            const SizedBox(height: 24),
            PremiumCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(vehicle.name,
                              style: const TextStyle(
                                  fontSize: 26,
                                  letterSpacing: -0.5,
                                  fontWeight: FontWeight.w900))),
                      StatusBadge(available: vehicle.available)
                    ]),
                    const SizedBox(height: 12),
                    Text(vehicle.description,
                        style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontSize: 15,
                            height: 1.5)),
                    const SizedBox(height: 20),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      InfoChip(
                          icon: Icons.event_seat_outlined,
                          label: '${vehicle.seats} seats'),
                      InfoChip(
                          icon: Icons.local_gas_station_outlined,
                          label: vehicle.fuelType),
                      InfoChip(
                          icon: Icons.settings_outlined,
                          label: vehicle.transmission),
                      InfoChip(
                          icon: Icons.location_on_outlined,
                          label: vehicle.location),
                      InfoChip(
                          icon: Icons.pin_outlined, label: vehicle.plateNumber),
                    ]),
                  ]),
            ),
            const SizedBox(height: 24),
            PremiumCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Booking Details',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    const Text('Driver Requirement Option',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'without_driver',
                          label: Text('Without Driver',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          icon: Icon(Icons.directions_car),
                        ),
                        ButtonSegment<String>(
                          value: 'with_driver',
                          label: Text('With Driver',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          icon: Icon(Icons.person_pin),
                        ),
                      ],
                      selected: {driverOption},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          driverOption = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: range);
                        if (picked != null) setState(() => range = picked);
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(range == null
                          ? 'Select rental period'
                          : '${dateText(range!.start)} to ${dateText(range!.end)}'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                        controller: pickup,
                        decoration: const InputDecoration(
                            labelText: 'Pickup Location',
                            prefixIcon: Icon(Icons.place_outlined))),
                    const SizedBox(height: 16),
                    TextField(
                        controller: drop,
                        decoration: const InputDecoration(
                            labelText: 'Return Location',
                            prefixIcon: Icon(Icons.flag_outlined))),
                    const SizedBox(height: 16),
                    TextField(
                        controller: note,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Special Note',
                            prefixIcon: Icon(Icons.notes_outlined))),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                days == 0
                                    ? 'Select dates to calculate total'
                                    : '$days days × ${money(vehicle.pricePerDay)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        Text(money(total),
                            style: const TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 20))
                      ]),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        if (range == null) {
                          showSnack(
                              context, 'Please select a rental date range.');
                          return;
                        }
                        if (store.currentUser == null) {
                          showSnack(context,
                              'Please log in to send a booking request.');
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const AuthScreen(isModal: true)));
                          return;
                        }
                        final result = await store.createBooking(
                            customerId: store.currentUser!.id,
                            vehicleId: vehicle.id,
                            start: range!.start,
                            end: range!.end,
                            pickup: pickup.text,
                            drop: drop.text,
                            note: note.text,
                            driverOption: driverOption);
                        if (result == 'success') {
                          showSnack(
                              context, 'Booking request sent successfully.');
                          Navigator.of(context).pop();
                        } else {
                          showSnack(context, result);
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Send Booking Request',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56)),
                    ),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final bool available;
  const StatusBadge({super.key, required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color:
              (available ? kAccent : const Color(0xFFEF4444)).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(available ? 'Available' : 'Unavailable',
          style: TextStyle(
              color: available ? kAccent : const Color(0xFFEF4444),
              fontWeight: FontWeight.w800,
              fontSize: 12)),
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: kPrimary),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))
      ]),
    );
  }
}

class BookingHistoryPage extends StatelessWidget {
  const BookingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final list = store.bookingsForCurrentUser();
    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
              title: 'Booking History',
              subtitle:
                  'Your booking confirmations, pending requests, and completed rentals.'),
          if (list.isEmpty)
            const EmptyView(
                icon: Icons.receipt_long_outlined,
                title: 'No bookings',
                message: 'Select a vehicle and send a booking request.')
          else
            ...list.map((b) => BookingCard(booking: b, managementMode: false)),
        ],
      ),
    );
  }
}

class CustomerPaymentsPage extends StatelessWidget {
  const CustomerPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final list = store.paymentsForCurrentUser();
    final myBookings = store.bookingsForCurrentUser();
    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
              title: 'Payment Tracking',
              subtitle:
                  'Track advance payments, confirmed payments, and pending balances.'),

          // BUG FIX: Switched from rigid GridView to dynamic Wrap to allow StatCard natural height expansion.
          LayoutBuilder(builder: (context, c) {
            final cards = [
              StatCard(
                  icon: Icons.payments,
                  label: 'Paid',
                  value: money(list.fold(0, (s, p) => s + p.amount)),
                  color: kAccent),
              StatCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Pending',
                  value: money(myBookings.fold(0, (s, b) => s + b.balance)),
                  color: const Color(0xFFF59E0B)),
            ];

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((e) => SizedBox(
                        width: c.maxWidth > 700
                            ? (c.maxWidth - 16) / 2
                            : double.infinity,
                        child: e,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 24),
          ...list.map((p) => PaymentCard(payment: p)),
          if (list.isEmpty)
            const EmptyView(
                icon: Icons.payments_outlined,
                title: 'No payments yet',
                message:
                    'Payment records will be shown here after the booking is approved.'),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final list = store.noticesForCurrentUser();
    return ResponsivePage(
      child: ListView(
        children: [
          SectionTitle(
              title: 'Notifications',
              subtitle: 'Alerts for bookings, payments, and return reminders.',
              trailing: FilledButton.tonalIcon(
                  onPressed: store.markAllRead,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Mark read',
                      style: TextStyle(fontWeight: FontWeight.bold)))),
          if (list.isEmpty)
            const EmptyView(
                icon: Icons.notifications_none,
                title: 'No alerts',
                message: 'System notifications will appear here.')
          else
            ...list.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                  color: (n.read ? Colors.blueGrey : kPrimary)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(
                                  n.read
                                      ? Icons.notifications_none
                                      : Icons.notifications_active,
                                  color: n.read ? Colors.blueGrey : kPrimary)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Text(n.title,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(n.message,
                                    style: TextStyle(
                                        color: Colors.blueGrey.shade700,
                                        height: 1.4)),
                                const SizedBox(height: 8),
                                Text(dateText(n.createdAt),
                                    style: TextStyle(
                                        color: Colors.blueGrey.shade400,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold))
                              ])),
                        ]),
                  ),
                )),
        ],
      ),
    );
  }
}

// =========================
// Admin / Staff Pages
// =========================

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
              title: 'Business Dashboard',
              subtitle:
                  'Summary of bookings, revenue, vehicles, and pending balances.'),
          LayoutBuilder(builder: (context, c) {
            final cards = [
              StatCard(
                  icon: Icons.directions_car,
                  label: 'Active Vehicles',
                  value: store.activeVehicles.toString(),
                  color: kPrimary),
              StatCard(
                  icon: Icons.pending_actions,
                  label: 'Pending Bookings',
                  value: store.pendingBookings.toString(),
                  color: const Color(0xFFF59E0B)),
              StatCard(
                  icon: Icons.payments,
                  label: 'Income',
                  value: money(store.totalIncome),
                  color: kAccent),
              StatCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Pending Balance',
                  value: money(store.pendingBalance),
                  color: const Color(0xFFEF4444)),
            ];

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((e) => SizedBox(
                        width: c.maxWidth > 1000
                            ? (c.maxWidth - 48) / 4
                            : c.maxWidth > 680
                                ? (c.maxWidth - 16) / 2
                                : double.infinity,
                        child: e,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 24),
          PremiumCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Booking Status Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              SimpleBar(
                  label: 'Pending',
                  value: store.bookings
                      .where((b) => b.status == BookingStatus.pending)
                      .length
                      .toDouble(),
                  maxValue: max(1, store.bookings.length).toDouble(),
                  color: const Color(0xFFF59E0B)),
              SimpleBar(
                  label: 'Approved',
                  value: store.bookings
                      .where((b) => b.status == BookingStatus.approved)
                      .length
                      .toDouble(),
                  maxValue: max(1, store.bookings.length).toDouble(),
                  color: kAccent),
              SimpleBar(
                  label: 'Completed',
                  value: store.bookings
                      .where((b) => b.status == BookingStatus.completed)
                      .length
                      .toDouble(),
                  maxValue: max(1, store.bookings.length).toDouble(),
                  color: kPrimary),
              SimpleBar(
                  label: 'Rejected',
                  value: store.bookings
                      .where((b) => b.status == BookingStatus.rejected)
                      .length
                      .toDouble(),
                  maxValue: max(1, store.bookings.length).toDouble(),
                  color: const Color(0xFFEF4444)),
            ]),
          ),
          const SizedBox(height: 24),
          const SectionTitle(
              title: 'Recent Bookings', subtitle: 'Latest booking activity'),
          ...store.bookings
              .take(4)
              .map((b) => BookingCard(booking: b, managementMode: true)),
        ],
      ),
    );
  }
}

class StaffTodayPage extends StatelessWidget {
  const StaffTodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final pending =
        store.bookings.where((b) => b.status == BookingStatus.pending).toList();
    final approved = store.bookings
        .where((b) => b.status == BookingStatus.approved)
        .toList();
    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
              title: 'Staff Today',
              subtitle:
                  'Approve bookings, record payments, and update returns.'),
          LayoutBuilder(builder: (context, c) {
            final cards = [
              StatCard(
                  icon: Icons.pending_actions,
                  label: 'Pending Approval',
                  value: pending.length.toString(),
                  color: const Color(0xFFF59E0B)),
              StatCard(
                  icon: Icons.car_rental,
                  label: 'Active Rentals',
                  value: approved.length.toString(),
                  color: kAccent),
              StatCard(
                  icon: Icons.payments,
                  label: 'Total Income',
                  value: money(store.totalIncome),
                  color: kPrimary),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((e) => SizedBox(
                        width: c.maxWidth > 760
                            ? (c.maxWidth - 32) / 3
                            : double.infinity,
                        child: e,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 16),
          const SectionTitle(
              title: 'Pending Booking Requests',
              subtitle: 'Customer requests awaiting staff approval.'),
          if (pending.isEmpty)
            const EmptyView(
                icon: Icons.task_alt,
                title: 'No pending requests',
                message: 'There are no pending booking requests.')
          else
            ...pending
                .map((b) => BookingCard(booking: b, managementMode: true)),
        ],
      ),
    );
  }
}

class VehicleManagementPage extends StatelessWidget {
  const VehicleManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    return Scaffold(
      body: ResponsivePage(
        child: ListView(
          children: [
            SectionTitle(
              title: 'Vehicle Management',
              subtitle:
                  'Add, update, toggle availability, and delete fleet details.',
              trailing: FilledButton.icon(
                  onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const VehicleFormDialog()),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Vehicle',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ),
            if (store.vehicles.isEmpty)
              const EmptyView(
                  icon: Icons.directions_car,
                  title: 'No Vehicles Found',
                  message:
                      'Click on the Add Vehicle button above to create a vehicle profile.')
            else
              ...store.vehicles.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(builder: (context, box) {
                        final useWide = box.maxWidth > 540;
                        final imgBlock = ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(v.imageUrl,
                                height: 86,
                                width: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    height: 86,
                                    width: 100,
                                    color: const Color(0xFFE9EEF6),
                                    child: const Icon(Icons.directions_car))));

                        final txtBlock = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(v.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      color: kText)),
                              const SizedBox(height: 4),
                              Text(
                                  '${v.type} • ${v.location} • ${money(v.pricePerDay)}/day',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.blueGrey.shade600,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              StatusBadge(available: v.available)
                            ]);

                        final btnBlock = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                                onPressed: () => store.toggleVehicle(v.id),
                                icon: Icon(v.available
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                tooltip: 'Toggle availability'),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                                onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) =>
                                        VehicleFormDialog(vehicle: v)),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit'),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                                onPressed: () => store.deleteVehicle(v.id),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete',
                                style: IconButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444))),
                          ],
                        );

                        if (useWide) {
                          return Row(children: [
                            imgBlock,
                            const SizedBox(width: 16),
                            Expanded(child: txtBlock),
                            const SizedBox(width: 16),
                            btnBlock
                          ]);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              imgBlock,
                              const SizedBox(width: 16),
                              Expanded(child: txtBlock)
                            ]),
                            const SizedBox(height: 12),
                            Align(
                                alignment: Alignment.centerRight,
                                child: btnBlock)
                          ],
                        );
                      }),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class BookingManagementPage extends StatelessWidget {
  const BookingManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
              title: 'Booking Management',
              subtitle:
                  'Approve, reject, update returns, and view booking records.'),
          if (store.bookings.isEmpty)
            const EmptyView(
                icon: Icons.assignment_outlined,
                title: 'No bookings',
                message: 'Customer bookings can be managed here.')
          else
            ...store.bookings
                .map((b) => BookingCard(booking: b, managementMode: true)),
        ],
      ),
    );
  }
}

class PaymentManagementPage extends StatelessWidget {
  const PaymentManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final payableBookings = store.bookings
        .where((b) => b.status == BookingStatus.approved && b.balance > 0)
        .toList();
    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
              title: 'Payment Management',
              subtitle: 'Record advance, balance, and full payments.'),
          if (payableBookings.isNotEmpty) ...[
            const Text('Bookings with Pending Balance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ...payableBookings.map((b) => BookingCard(
                booking: b, managementMode: true, paymentOnly: true)),
            const SizedBox(height: 24),
          ],
          const Text('Payment Records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          if (store.payments.isEmpty)
            const EmptyView(
                icon: Icons.payments_outlined,
                title: 'No payments',
                message: 'Payment records will be listed here.')
          else
            ...store.payments.map((p) => PaymentCard(payment: p)),
        ],
      ),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final maxRevenue = max(
        1,
        store.vehicles.map((v) {
          final ids = store.bookings
              .where((b) => b.vehicleId == v.id)
              .map((b) => b.id)
              .toSet();
          return store.payments
              .where((p) => ids.contains(p.bookingId))
              .fold<double>(0, (s, p) => s + p.amount);
        }).fold<double>(0, (a, b) => max(a, b).toDouble()));
    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
              title: 'Reports',
              subtitle:
                  'Reports on revenue, booking status, vehicle usage, and decision support.'),
          LayoutBuilder(builder: (context, c) {
            final cards = [
              StatCard(
                  icon: Icons.summarize_outlined,
                  label: 'Bookings',
                  value: store.bookings.length.toString(),
                  color: kPrimary),
              StatCard(
                  icon: Icons.payments,
                  label: 'Revenue',
                  value: money(store.totalIncome),
                  color: kAccent),
              StatCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Outstanding',
                  value: money(store.pendingBalance),
                  color: const Color(0xFFF59E0B)),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((e) => SizedBox(
                        width: c.maxWidth > 760
                            ? (c.maxWidth - 32) / 3
                            : double.infinity,
                        child: e,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 24),
          PremiumCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Revenue by Vehicle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              ...store.vehicles.map((v) {
                final ids = store.bookings
                    .where((b) => b.vehicleId == v.id)
                    .map((b) => b.id)
                    .toSet();
                final revenue = store.payments
                    .where((p) => ids.contains(p.bookingId))
                    .fold<double>(0, (s, p) => s + p.amount);
                return SimpleBar(
                    label: v.name,
                    value: revenue,
                    color: kPrimary,
                    suffix: money(revenue),
                    maxValue: maxRevenue.toDouble());
              }),
            ]),
          ),
          const SizedBox(height: 24),
          PremiumCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Vehicle Utilization',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              ...store.vehicles.map((v) {
                final count = store.bookings
                    .where((b) => b.vehicleId == v.id)
                    .length
                    .toDouble();
                return SimpleBar(
                    label: v.name,
                    value: count,
                    maxValue: max(1, store.bookings.length).toDouble(),
                    color: kAccent,
                    suffix: count.toInt().toString());
              }),
            ]),
          ),
        ],
      ),
    );
  }
}

class SimpleBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String? suffix;
  const SimpleBar(
      {super.key,
      required this.label,
      required this.value,
      required this.maxValue,
      required this.color,
      this.suffix});

  @override
  Widget build(BuildContext context) {
    final width = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800))),
          Text(suffix ?? value.toInt().toString(),
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w800))
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(
            builder: (context, c) => Stack(children: [
                  Container(
                      height: 12,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8))),
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      height: 12,
                      width: c.maxWidth * width,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8))),
                ])),
      ]),
    );
  }
}

// =========================
// Shared Cards and Dialogs
// =========================

class BookingCard extends StatelessWidget {
  final Booking booking;
  final bool managementMode;
  final bool paymentOnly;
  const BookingCard(
      {super.key,
      required this.booking,
      required this.managementMode,
      this.paymentOnly = false});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final vehicle = store.vehicleById(booking.vehicleId);
    final customer = store.userById(booking.customerId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PremiumCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14)),
                child:
                    const Icon(Icons.receipt_long, color: kPrimary, size: 26)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(vehicle?.name ?? 'Vehicle removed',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(
                      '${dateText(booking.startDate)} to ${dateText(booking.endDate)} • ${rentalDays(booking.startDate, booking.endDate)} days',
                      style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  if (managementMode && customer != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            'Customer: ${customer.name} • ${customer.phone}',
                            style: TextStyle(
                                color: Colors.blueGrey.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w900))),
                ])),
            StatusChip(status: booking.status),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoChip(icon: Icons.place_outlined, label: booking.pickupLocation),
            InfoChip(icon: Icons.flag_outlined, label: booking.returnLocation),
            InfoChip(
                icon: booking.isWithDriver
                    ? Icons.person_pin
                    : Icons.directions_car,
                label: booking.driverOptionLabel),
            InfoChip(
                icon: Icons.payments_outlined,
                label: 'Total ${money(booking.totalAmount)}'),
            InfoChip(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Balance ${money(booking.balance)}'),
          ]),
          if (booking.note.isNotEmpty)
            Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEF3C7))),
                child: Text('Note: ${booking.note}',
                    style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 13,
                        fontWeight: FontWeight.bold))),
          if (managementMode) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              if (!paymentOnly && booking.status == BookingStatus.pending)
                FilledButton.icon(
                    onPressed: () => store.approveBooking(booking.id),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              if (!paymentOnly && booking.status == BookingStatus.pending)
                OutlinedButton.icon(
                    onPressed: () => store.rejectBooking(booking.id),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              if (booking.status == BookingStatus.approved &&
                  booking.balance > 0)
                FilledButton.icon(
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => PaymentDialog(bookingId: booking.id)),
                    icon: const Icon(Icons.payments),
                    label: const Text('Record Payment',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              if (!paymentOnly && booking.status == BookingStatus.approved)
                OutlinedButton.icon(
                    onPressed: () => store.completeBooking(booking.id),
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('Mark Returned',
                        style: TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ],
        ]),
      ),
    );
  }
}

class PaymentCard extends StatelessWidget {
  final PaymentRecord payment;
  const PaymentCard({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final b = store.bookingById(payment.bookingId);
    final vehicle = b == null ? null : store.vehicleById(b.vehicleId);
    final customer = b == null ? null : store.userById(b.customerId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PremiumCard(
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.payments, color: kAccent, size: 26)),
              SizedBox(
                  width: 320,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(money(payment.amount),
                            style: const TextStyle(
                                fontSize: 20,
                                letterSpacing: -0.5,
                                fontWeight: FontWeight.w900,
                                color: kText)),
                        const SizedBox(height: 6),
                        Text(
                            '${vehicle?.name ?? 'Booking'} • ${payment.method}',
                            style: TextStyle(
                                color: Colors.blueGrey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (customer != null)
                          Text('Customer: ${customer.name}',
                              style: TextStyle(
                                  color: Colors.blueGrey.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                      ])),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(payment.status,
                      style: const TextStyle(
                          color: kAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11)),
                ),
                const SizedBox(height: 8),
                Text(dateText(payment.paidAt),
                    style: TextStyle(
                        color: Colors.blueGrey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))
              ]),
            ]),
      ),
    );
  }
}

class PaymentDialog extends StatefulWidget {
  final String bookingId;
  const PaymentDialog({super.key, required this.bookingId});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final amount = TextEditingController();
  String method = 'Cash';

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final booking = store.bookingById(widget.bookingId)!;
    return AlertDialog(
      title: const Text('Record Payment',
          style: TextStyle(fontWeight: FontWeight.w900)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8)),
          child: Text('Pending balance: ${money(booking.balance)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: Color(0xFF991B1B))),
        ),
        const SizedBox(height: 16),
        TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.payments_outlined))),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
            value: method,
            items: ['Cash', 'Card', 'Bank Transfer', 'Online Transfer']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => method = v ?? method),
            decoration: const InputDecoration(labelText: 'Payment Method')),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.bold))),
        FilledButton(
            onPressed: () {
              final v = double.tryParse(amount.text) ?? 0;
              if (v <= 0) return;
              store.recordPayment(widget.bookingId, v, method);
              Navigator.pop(context);
            },
            child: const Text('Save Payment',
                style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class VehicleFormDialog extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormDialog({super.key, this.vehicle});

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  late TextEditingController name;
  late TextEditingController model;
  late TextEditingController plate;
  late TextEditingController location;
  late TextEditingController price;
  late TextEditingController seats;
  late TextEditingController image;
  late TextEditingController description;
  String type = 'Car';
  String fuel = 'Petrol';
  String transmission = 'Automatic';
  bool available = true;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    name = TextEditingController(text: v?.name ?? '');
    model = TextEditingController(text: v?.model ?? '');
    plate = TextEditingController(text: v?.plateNumber ?? '');
    location = TextEditingController(text: v?.location ?? 'Colombo');
    price = TextEditingController(
        text: v?.pricePerDay.toStringAsFixed(0) ?? '10000');
    seats = TextEditingController(text: v?.seats.toString() ?? '5');
    image = TextEditingController(
        text: v?.imageUrl ?? 'https://i.postimg.cc/vmGYFQmM/ll.png');
    description = TextEditingController(
        text: v?.description ??
            'A suitable rental vehicle for traveling in Sri Lanka.');
    type = v?.type ?? type;
    fuel = v?.fuelType ?? fuel;
    transmission = v?.transmission ?? transmission;
    available = v?.available ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    model.dispose();
    plate.dispose();
    location.dispose();
    price.dispose();
    seats.dispose();
    image.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.vehicle != null;
    return AlertDialog(
      title: Text(editing ? 'Update Vehicle' : 'Add Vehicle',
          style: const TextStyle(fontWeight: FontWeight.w900)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Vehicle Name')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                      isExpanded: true, // BUG FIX: Prevents horizontal overflow
                      value: type,
                      items: ['Car', 'Van', 'Tuk Tuk', 'Motorcycle']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => type = v ?? type),
                      decoration: const InputDecoration(labelText: 'Type'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: model,
                      decoration: const InputDecoration(labelText: 'Model'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: plate,
                      decoration:
                          const InputDecoration(labelText: 'Plate Number'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: location,
                      decoration:
                          const InputDecoration(labelText: 'Location'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                      isExpanded: true, // BUG FIX: Prevents horizontal overflow
                      value: fuel,
                      items: ['Petrol', 'Diesel', 'Hybrid', 'Electric']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => fuel = v ?? fuel),
                      decoration: const InputDecoration(labelText: 'Fuel'))),
              const SizedBox(width: 12),
              Expanded(
                  child: DropdownButtonFormField<String>(
                      isExpanded: true, // BUG FIX: Prevents horizontal overflow
                      value: transmission,
                      items: ['Automatic', 'Manual']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => transmission = v ?? transmission),
                      decoration:
                          const InputDecoration(labelText: 'Transmission'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: seats,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Seats'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Price / Day'))),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: image,
                decoration: const InputDecoration(labelText: 'Image URL')),
            const SizedBox(height: 12),
            TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 8),
            SwitchListTile(
                value: available,
                activeColor: kPrimary,
                onChanged: (v) => setState(() => available = v),
                title: const Text('Available',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.bold))),
        FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              final store = RentScope.of(context);
              final currentUser = store.currentUser;
              final String? ownerId = widget.vehicle?.ownerId ??
                  (currentUser?.role == UserRole.owner ? currentUser?.id : null);
              final String? ownerName = widget.vehicle?.ownerName ??
                  (currentUser?.role == UserRole.owner ? currentUser?.name : null);

              final v = Vehicle(
                id: widget.vehicle?.id ?? '',
                name: name.text.trim(),
                type: type,
                model: model.text.trim(),
                plateNumber: plate.text.trim(),
                fuelType: fuel,
                transmission: transmission,
                location: location.text.trim(),
                seats: int.tryParse(seats.text) ?? 5,
                pricePerDay: double.tryParse(price.text) ?? 10000,
                available: available,
                imageUrl: image.text.trim(),
                description: description.text.trim(),
                ownerId: ownerId,
                ownerName: ownerName,
              );
              if (editing) {
                store.updateVehicle(v);
              } else {
                store.addVehicle(v);
              }
              Navigator.pop(context);
            },
            child: Text(editing ? 'Update' : 'Add',
                style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}

// =========================
// Vehicle Owner Module
// =========================

class VehicleOwnerRegisterScreen extends StatefulWidget {
  const VehicleOwnerRegisterScreen({super.key});

  @override
  State<VehicleOwnerRegisterScreen> createState() =>
      _VehicleOwnerRegisterScreenState();
}

class _VehicleOwnerRegisterScreenState
    extends State<VehicleOwnerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final nicController = TextEditingController();
  final businessController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    nicController.dispose();
    businessController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      showSnack(context, 'Passwords do not match.');
      return;
    }

    setState(() => loading = true);
    final store = RentScope.of(context);
    final ok = await store.registerVehicleOwner(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      phone: phoneController.text.trim(),
      nic: nicController.text.trim(),
      password: passwordController.text,
      businessName: businessController.text.trim().isEmpty
          ? null
          : businessController.text.trim(),
    );
    setState(() => loading = false);

    if (!ok) {
      showSnack(context, 'This email is already registered in the system.');
    } else {
      showSnack(
          context, 'Registration successful! Welcome to Vehicle Owner Portal.');
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(heroImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: kPrimaryDark)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimaryDark.withValues(alpha: 0.92),
                    kPrimaryDark.withValues(alpha: 0.5)
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: ResponsivePage(
              maxWidth: 960,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wideCard = c.maxWidth > 520;
                  return Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: PremiumCard(
                          padding: EdgeInsets.all(wideCard ? 28 : 18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: kPrimary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.car_rental,
                                          color: kPrimary, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Vehicle Owner Registration',
                                              style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.5,
                                                  color: kText)),
                                          SizedBox(height: 2),
                                          Text(
                                            'Register your vehicle fleet on Rent.lk',
                                            style: TextStyle(
                                                color: Colors.blueGrey,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name *',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Full Name is required'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address *',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Email Address is required';
                                    }
                                    if (!v.contains('@') || !v.contains('.')) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, fieldBox) {
                                    final sideBySide = fieldBox.maxWidth > 460;
                                    if (sideBySide) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: phoneController,
                                              keyboardType: TextInputType.phone,
                                              decoration: const InputDecoration(
                                                labelText: 'Phone Number *',
                                                prefixIcon:
                                                    Icon(Icons.call_outlined),
                                              ),
                                              validator: (v) => v == null ||
                                                      v.trim().isEmpty
                                                  ? 'Phone number required'
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: nicController,
                                              decoration: const InputDecoration(
                                                labelText: 'NIC / Passport *',
                                                prefixIcon:
                                                    Icon(Icons.badge_outlined),
                                              ),
                                              validator: (v) => v == null ||
                                                      v.trim().isEmpty
                                                  ? 'NIC/Passport required'
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Column(
                                      children: [
                                        TextFormField(
                                          controller: phoneController,
                                          keyboardType: TextInputType.phone,
                                          decoration: const InputDecoration(
                                            labelText: 'Phone Number *',
                                            prefixIcon:
                                                Icon(Icons.call_outlined),
                                          ),
                                          validator: (v) => v == null ||
                                                  v.trim().isEmpty
                                              ? 'Phone number is required'
                                              : null,
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: nicController,
                                          decoration: const InputDecoration(
                                            labelText: 'NIC / Passport *',
                                            prefixIcon:
                                                Icon(Icons.badge_outlined),
                                          ),
                                          validator: (v) => v == null ||
                                                  v.trim().isEmpty
                                              ? 'NIC/Passport is required'
                                              : null,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: businessController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Business / Company Name (Optional)',
                                    prefixIcon: Icon(Icons.storefront_outlined),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password *',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() =>
                                          obscurePassword = !obscurePassword),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: confirmPasswordController,
                                  obscureText: obscureConfirmPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password *',
                                    prefixIcon:
                                        const Icon(Icons.lock_clock_outlined),
                                    suffixIcon: IconButton(
                                      icon: Icon(obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() =>
                                          obscureConfirmPassword =
                                              !obscureConfirmPassword),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: loading ? null : _submitRegister,
                                  icon: loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.app_registration),
                                  label: Text(
                                      loading
                                          ? 'Processing...'
                                          : 'Register as Owner',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(54)),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const VehicleOwnerLoginScreen()),
                                      );
                                    },
                                    child: const Text(
                                      'Already registered as a Vehicle Owner? Login here',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleOwnerLoginScreen extends StatefulWidget {
  const VehicleOwnerLoginScreen({super.key});

  @override
  State<VehicleOwnerLoginScreen> createState() =>
      _VehicleOwnerLoginScreenState();
}

class _VehicleOwnerLoginScreenState extends State<VehicleOwnerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    final store = RentScope.of(context);
    final ok = await store.login(
      emailController.text.trim(),
      passwordController.text,
    );
    setState(() => loading = false);

    if (!ok) {
      showSnack(context, 'Login failed. Incorrect email or password.');
    } else {
      final user = store.currentUser;
      if (user != null && user.role != UserRole.owner) {
        showSnack(context,
            'LoggedIn account is a ${user.role.name.toUpperCase()}. Redirecting to dashboard...');
      } else {
        showSnack(context, 'Welcome back, ${user?.name}!');
      }
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(heroImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: kPrimaryDark)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimaryDark.withValues(alpha: 0.92),
                    kPrimaryDark.withValues(alpha: 0.5)
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: ResponsivePage(
              maxWidth: 520,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wideCard = c.maxWidth > 400;
                  return Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: PremiumCard(
                          padding: EdgeInsets.all(wideCard ? 28 : 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: kPrimary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.key,
                                          color: kPrimary, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Vehicle Owner Login',
                                              style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.5,
                                                  color: kText)),
                                          SizedBox(height: 2),
                                          Text(
                                              'Sign in to manage your vehicles',
                                              style: TextStyle(
                                                  color: Colors.blueGrey,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Please enter your email'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() =>
                                          obscurePassword = !obscurePassword),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Please enter your password'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: loading ? null : _submitLogin,
                                  icon: loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.login),
                                  label: Text(
                                      loading
                                          ? 'Signing in...'
                                          : 'Owner Login',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(54)),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const VehicleOwnerRegisterScreen()),
                                      );
                                    },
                                    child: const Text(
                                      'New Vehicle Owner? Register here',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car),
          label: 'My Vehicles',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Bookings',
        ),
        NavigationDestination(
          icon: Icon(Icons.monetization_on_outlined),
          selectedIcon: Icon(Icons.monetization_on),
          label: 'Earnings',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
      ],
      pages: [
        OwnerDashboardPage(),
        OwnerVehiclesPage(),
        OwnerBookingsPage(),
        OwnerEarningsPage(),
        NotificationsPage(),
      ],
    );
  }
}

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final user = store.currentUser;
    if (user == null) return const SizedBox.shrink();

    final myVehicles = store.vehiclesForOwner(user.id);
    final myBookings = store.bookingsForOwner(user.id);
    final totalEarnings = store.ownerTotalEarnings(user.id);
    final activeCount = myVehicles.where((v) => v.available).length;

    return ResponsivePage(
      child: ListView(
        children: [
          SectionTitle(
            title: 'Owner Portal Dashboard',
            subtitle:
                'Welcome, ${user.name}${user.businessName != null ? " (${user.businessName})" : ""}',
            trailing: FilledButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const VehicleFormDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          LayoutBuilder(builder: (context, c) {
            final cards = [
              StatCard(
                icon: Icons.directions_car,
                label: 'My Listed Vehicles',
                value: myVehicles.length.toString(),
                color: kPrimary,
              ),
              StatCard(
                icon: Icons.check_circle_outline,
                label: 'Active Vehicles',
                value: activeCount.toString(),
                color: kAccent,
              ),
              StatCard(
                icon: Icons.receipt_long,
                label: 'Total Bookings',
                value: myBookings.length.toString(),
                color: const Color(0xFFF59E0B),
              ),
              StatCard(
                icon: Icons.account_balance_wallet,
                label: 'Total Revenue',
                value: money(totalEarnings),
                color: const Color(0xFF10B981),
              ),
            ];

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((e) => SizedBox(
                        width: c.maxWidth > 800
                            ? (c.maxWidth - 48) / 4
                            : c.maxWidth > 500
                                ? (c.maxWidth - 16) / 2
                                : double.infinity,
                        child: e,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Recent Rental Bookings',
            subtitle: 'Customer requests for your registered vehicles.',
          ),
          if (myBookings.isEmpty)
            const EmptyView(
              icon: Icons.car_rental_outlined,
              title: 'No vehicle bookings yet',
              message:
                  'When customers request your vehicles, their bookings will appear here.',
            )
          else
            ...myBookings.take(5).map((b) => BookingCard(
                  booking: b,
                  managementMode: false,
                )),
        ],
      ),
    );
  }
}

class OwnerVehiclesPage extends StatelessWidget {
  const OwnerVehiclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final user = store.currentUser;
    final list = user == null ? <Vehicle>[] : store.vehiclesForOwner(user.id);

    return ResponsivePage(
      child: ListView(
        children: [
          SectionTitle(
            title: 'My Vehicles',
            subtitle: 'Manage your vehicle listings and availability status.',
            trailing: FilledButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const VehicleFormDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (list.isEmpty)
            const EmptyView(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles added yet',
              message:
                  'Click "Add Vehicle" to register your first car, van, or motorcycle for rental.',
            )
          else
            VehicleGrid(vehicles: list, customerMode: false),
        ],
      ),
    );
  }
}

class OwnerBookingsPage extends StatelessWidget {
  const OwnerBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final user = store.currentUser;
    final list = user == null ? <Booking>[] : store.bookingsForOwner(user.id);

    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
            title: 'Vehicle Bookings',
            subtitle:
                'All booking requests received for vehicles owned by you.',
          ),
          if (list.isEmpty)
            const EmptyView(
              icon: Icons.assignment_outlined,
              title: 'No bookings found',
              message: 'Bookings for your vehicles will be listed here.',
            )
          else
            ...list.map((b) => BookingCard(booking: b, managementMode: false)),
        ],
      ),
    );
  }
}

class OwnerEarningsPage extends StatelessWidget {
  const OwnerEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = RentScope.of(context);
    final user = store.currentUser;
    final list = user == null ? <PaymentRecord>[] : store.paymentsForOwner(user.id);
    final total = user == null ? 0.0 : store.ownerTotalEarnings(user.id);

    return ResponsivePage(
      child: ListView(
        children: [
          const SectionTitle(
            title: 'Earnings & Payments',
            subtitle: 'Financial overview of income earned from your rentals.',
          ),
          PremiumCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: kAccent, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Net Revenue',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey)),
                      const SizedBox(height: 4),
                      Text(money(total),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: kText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (list.isEmpty)
            const EmptyView(
              icon: Icons.payments_outlined,
              title: 'No payment records',
              message:
                  'Confirmed customer payments for your vehicles will be tracked here.',
            )
          else
            ...list.map((p) => PaymentCard(payment: p)),
        ],
      ),
    );
  }
}

