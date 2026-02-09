import 'package:flutter_riverpod/flutter_riverpod.dart';

const bool kQcMode =
    bool.fromEnvironment('QC_MODE', defaultValue: false);

final qcEditModeProvider = StateProvider<bool>((ref) => false);
