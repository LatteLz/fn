import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';

class HealthService {
  static final Health _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BODY_MASS_INDEX,
  ];

  static Future<bool> requestPermissions() async {
    try {
      await Permission.activityRecognition.request();
      await Permission.sensors.request();

      return await _health.requestAuthorization(
        _types,
        permissions: _types.map((e) => HealthDataAccess.READ).toList(),
      );
    } catch (e, stack) {
      debugPrint("PERMISSION ERROR $e");
      debugPrint(stack.toString());
      return false;
    }
  }

  static Future<BiometricSnapshot> fetchLatestData() async {
    try {
      final snapshot = await _fetchSnapshot(requireVitals: false);
      return snapshot ?? BiometricSnapshot.defaultValues();
    } catch (error, stackTrace) {
      debugPrint('HEALTH FETCH ERROR: $error');
      debugPrint(stackTrace.toString());
      return BiometricSnapshot.defaultValues();
    }
  }

  static Future<BiometricSnapshot?> fetchBackgroundSnapshot() async {
    try {
      return await _fetchSnapshot(requireVitals: true);
    } catch (error, stackTrace) {
      debugPrint('BACKGROUND HEALTH FETCH ERROR: $error');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  static Future<BiometricSnapshot?> _fetchSnapshot({
    required bool requireVitals,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final startToday = DateTime(now.year, now.month, now.day);
    final points = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: now,
      types: _types,
    );
    if (points.isEmpty) return null;

    double? latestNumericValue(HealthDataType type) {
      final matching = points.where((point) => point.type == type).toList()
        ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      if (matching.isEmpty || matching.first.value is! NumericHealthValue) {
        return null;
      }
      return (matching.first.value as NumericHealthValue)
          .numericValue
          .toDouble();
    }

    final heartRateValue = latestNumericValue(HealthDataType.HEART_RATE);
    var spo2Value = latestNumericValue(HealthDataType.BLOOD_OXYGEN);
    if (requireVitals && (heartRateValue == null || spo2Value == null)) {
      return null;
    }
    final heartRate = heartRateValue ?? 72;
    var spo2 = spo2Value ?? 98;
    if (spo2 <= 1) spo2 *= 100;

    final sleepHours = _latestSleepHours(points, now);
    final steps = await _todaySteps(points, startToday, now);
    final calories = _todayActiveCalories(points, startToday, now);
    final bmi = latestNumericValue(HealthDataType.BODY_MASS_INDEX) ?? 22;
    final stress = _estimateStress(
      hr: heartRate,
      spo2: spo2,
      sleepHours: sleepHours,
    );

    return BiometricSnapshot(
      heartRate: heartRate.clamp(30, 220),
      spo2: spo2.clamp(80, 100),
      sleepHours: sleepHours.clamp(0, 24),
      stressScore: stress.clamp(0, 100),
      bmi: bmi.clamp(10, 60),
      steps: steps,
      calories: calories,
      fetchedAt: now,
      isSimulated: heartRateValue == null || spo2Value == null,
    );
  }

  static double _latestSleepHours(List<HealthDataPoint> points, DateTime now) {
    final cutoff = now.subtract(const Duration(days: 2));
    var sleepPoints = points
        .where((point) =>
            point.type == HealthDataType.SLEEP_ASLEEP &&
            point.dateTo.isAfter(cutoff) &&
            point.dateTo.isBefore(now))
        .toList();
    if (sleepPoints.isEmpty) {
      sleepPoints = points
          .where((point) =>
              point.type == HealthDataType.SLEEP_SESSION &&
              point.dateTo.isAfter(cutoff) &&
              point.dateTo.isBefore(now))
          .toList();
    }
    if (sleepPoints.isEmpty) return 0;

    sleepPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final latestEnd = sleepPoints.first.dateTo;
    final sessionStart = latestEnd.subtract(const Duration(hours: 24));
    // Các giai đoạn ngủ có thể chồng lặp, cần gộp khoảng thời gian trước khi cộng.
    final intervals = sleepPoints
        .where((point) =>
            point.dateFrom.isBefore(latestEnd) &&
            point.dateTo.isAfter(sessionStart))
        .map((point) => (
              start: point.dateFrom.isBefore(sessionStart)
                  ? sessionStart
                  : point.dateFrom,
              end: point.dateTo.isAfter(latestEnd) ? latestEnd : point.dateTo,
            ))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    var total = Duration.zero;
    DateTime? intervalStart;
    DateTime? intervalEnd;
    for (final interval in intervals) {
      if (intervalStart == null || intervalEnd == null) {
        intervalStart = interval.start;
        intervalEnd = interval.end;
      } else if (interval.start.isAfter(intervalEnd)) {
        total += intervalEnd.difference(intervalStart);
        intervalStart = interval.start;
        intervalEnd = interval.end;
      } else if (interval.end.isAfter(intervalEnd)) {
        intervalEnd = interval.end;
      }
    }
    if (intervalStart != null && intervalEnd != null) {
      total += intervalEnd.difference(intervalStart);
    }

    final hours = total.inMinutes / 60;
    return hours > 0 && hours < 24 ? hours : 0;
  }

  static Future<int> _todaySteps(
    List<HealthDataPoint> points,
    DateTime startToday,
    DateTime now,
  ) async {
    try {
      final total = await _health.getTotalStepsInInterval(startToday, now);
      if (total != null) return total;
    } catch (error) {
      debugPrint('Could not aggregate Health Connect steps: $error');
    }

    return points
        .where((point) =>
            point.type == HealthDataType.STEPS &&
            point.dateFrom.isBefore(now) &&
            point.dateTo.isAfter(startToday) &&
            point.value is NumericHealthValue)
        .fold<int>(
          0,
          (sum, point) =>
              sum + (point.value as NumericHealthValue).numericValue.toInt(),
        );
  }

  static double _todayActiveCalories(
    List<HealthDataPoint> points,
    DateTime startToday,
    DateTime now,
  ) {
    final calories = points
        .where((point) =>
            point.type == HealthDataType.ACTIVE_ENERGY_BURNED &&
            point.dateFrom.isBefore(now) &&
            point.dateTo.isAfter(startToday) &&
            point.value is NumericHealthValue)
        .fold<double>(
          0,
          (sum, point) =>
              sum + (point.value as NumericHealthValue).numericValue.toDouble(),
        );
    return double.parse(calories.toStringAsFixed(0));
  }

  static double _estimateStress({
    required double hr,
    required double spo2,
    required double sleepHours,
  }) {
    final hrN = ((hr - 60) / 60).clamp(0, 1);
    final spo2N = ((98 - spo2) / 10).clamp(0, 1);
    final sleepN = ((7 - sleepHours) / 7).clamp(0, 1);

    return (0.45 * hrN + 0.35 * spo2N + 0.20 * sleepN) * 100;
  }
}
