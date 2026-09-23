// Production backend (Render) is the default so a plain
// `flutter build apk --release` always ships pointing to the live API.
// For local XAMPP testing, override with:
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2/optcare_api
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://gonzalesvisionclinic.onrender.com',
);
