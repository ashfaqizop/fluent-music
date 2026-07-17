import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'AppDatabase opens an in-memory instance with schemaVersion 1',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, 1);
    },
  );
}
