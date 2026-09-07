# Rent.lk - Vehicle Rental Management Application

මෙය **Vehicle Rental Application (Rent.lk)** proposal එකට අනුව Flutter භාවිතා කරලා සකස් කළ modern, professional, premium mobile application project එකකි.

## ඇතුළත් කර ඇති ප්‍රධාන features

- Customer registration සහ login
- Admin / Staff / Customer role-based access
- Vehicle list, search, category filter, date availability checking
- Online booking request
- Booking approve / reject / return complete
- Payment tracking සහ payment records
- Customer booking history සහ payment history
- Notifications / alerts
- Admin dashboard summary
- Vehicle management: add, update, availability toggle, delete
- Basic reports: revenue, booking status, vehicle usage
- Mobile responsive layout lock
- Hero section එකට Sri Lanka road background image
- Modern Material Icons භාවිතා කර ඇත. Emojis භාවිතා කර නැත.
- Code comments සිංහලෙන් දාලා ඇත.

## Demo Login Details

### Admin
Email: `admin@rent.lk`  
Password: `admin123`

### Staff
Email: `staff@rent.lk`  
Password: `staff123`

### Customer
Email: `user@rent.lk`  
Password: `user123`

## Run කරන විදිහ

### Step 1: Flutter install කරන්න
Flutter SDK install කරලා `flutter doctor` command එක run කරලා Android Studio / VS Code setup එක හරිද බලන්න.

```bash
flutter doctor
```

### Step 2: ZIP extract කරන්න
මේ ZIP file එක extract කරලා folder එක VS Code එකෙන් open කරන්න.

### Step 3: Platform files generate කරන්න
මෙම source project එක Flutter app source එකක් ලෙස සකස් කරලා තියෙන නිසා Android/iOS/Web platform folders auto generate කරගන්න පුළුවන්.

```bash
flutter create . --platforms=android,ios,web
```

### Step 4: Packages get කරන්න
```bash
flutter pub get
```

### Step 5: Run කරන්න
Android emulator හෝ real Android device එක connect කරලා:

```bash
flutter run
```

Chrome web test එකක් සඳහා:

```bash
flutter run -d chrome
```

## Project Structure

```text
rent_lk_flutter_application/
  lib/main.dart                  Main Flutter application code
  pubspec.yaml                   Flutter project settings
  backend/mysql_schema.sql       MySQL database structure for real backend
  backend/firebase_notes.txt     Firebase connection notes
  docs/project_notes_si.md       Student friendly notes
  assets/attributions/           Image attribution details
```

## Backend ගැන සටහන

මෙම app එක **working demo** එකක් ලෙස in-memory data store එකක් භාවිතා කරලා run වෙනවා. ඒ නිසා app එක install කරලා features test කරන්න Firebase/MySQL එකක් අවශ්‍ය නැහැ. Real production backend එකකට connect කරන්න `RentStore` class එක API service එකකට replace කරන්න පුළුවන්. MySQL database schema එක `backend/mysql_schema.sql` තුළ දාලා ඇත.

## Important

- Real project submission එකට Firebase project එකක් හෝ PHP/MySQL backend එකක් connect කරන්න පුළුවන්.
- App එකේ vehicle images network URLs ලෙස භාවිතා කරලා තියෙනවා.
- Offline mode එකේ images load නොවුණොත් app එක fallback icon පෙන්වයි.
