import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class GatingService {
  static const _storage = FlutterSecureStorage();
  static const String _lastAnalysisDateKey = 'last_analysis_date';
  static const String _analysisCountKey = 'analysis_count';

  Future<bool> isOffline() async {
    final result = await Connectivity().checkConnectivity();
    return result == ConnectivityResult.none;
  }

  Future<bool> canAnalyzeFreeUser() async {
    return true; // Always allow free users to analyze
  }

  Future<void> recordAnalysisUsed() async {
    // Commented out to remove daily limit
    // final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    // final lastDate = await _storage.read(key: _lastAnalysisDateKey);
    // if (lastDate == today) {
    //   final countStr = await _storage.read(key: _analysisCountKey);
    //   final count = (int.tryParse(countStr ?? '0') ?? 0) + 1;
    //   await _storage.write(key: _analysisCountKey, value: count.toString());
    // } else {
    //   await _storage.write(key: _lastAnalysisDateKey, value: today);
    //   await _storage.write(key: _analysisCountKey, value: '1');
    // }
  }
}
