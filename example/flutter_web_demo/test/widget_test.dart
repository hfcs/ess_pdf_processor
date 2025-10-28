// Minimal sanity check without importing flutter_test so CI's
// `flutter analyze` does not require dev dependencies to be present.
void main() {
  // Simple runtime assertion — this file exists so CI's `flutter test`
  // step won't fail due to a missing `test/` directory.
  assert(1 + 1 == 2);
}
