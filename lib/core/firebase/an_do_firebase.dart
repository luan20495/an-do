import 'package:an_do/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Shared Firebase accessors for An Đồ.
///
/// Always use the Asia Southeast RTDB URL — google-services auto-init does not
/// include regional databaseURL and defaults to the wrong host.
abstract final class AnDoFirebase {
  static FirebaseDatabase get database => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: DefaultFirebaseOptions.databaseURL,
      );
}
