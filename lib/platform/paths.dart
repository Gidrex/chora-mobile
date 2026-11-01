import 'package:path_provider/path_provider.dart';

/// The app's private storage folder, used until the user picks another.
Future<String> defaultStoragePath() async =>
    '${(await getApplicationDocumentsDirectory()).path}/chora';
