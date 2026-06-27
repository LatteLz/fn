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
    final now = DateTime.now();

    final start = now.subtract(const Duration(days: 7));

    List<HealthDataPoint> pts = [];

    try {
      pts = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _types,
      );

      debugPrint("HEALTH POINTS ${pts.length}");
    } catch (e, stack) {
      debugPrint("FETCH ERROR $e");
      debugPrint(stack.toString());

      return BiometricSnapshot.defaultValues();
    }

    if (pts.isEmpty) {
      return BiometricSnapshot.defaultValues();
    }

    double last(HealthDataType type, double fallback) {
      final list = pts.where((p) => p.type == type).toList();

      if (list.isEmpty) {
        return fallback;
      }

      return (list.last.value as NumericHealthValue).numericValue.toDouble();
    }

    // ================= HEART =================

    final hr = last(
      HealthDataType.HEART_RATE,
      72,
    );

    // ================= SPO2 =================

    double spo2 = last(
      HealthDataType.BLOOD_OXYGEN,
      98,
    );

    if (spo2 <= 1) {
      spo2 *= 100;
    }

    // ================= SLEEP =================

    List<HealthDataPoint> sleepPts = pts.where((p) {
      return p.type == HealthDataType.SLEEP_ASLEEP &&
          p.dateTo.isBefore(now) &&
          p.dateTo.isAfter(
            now.subtract(
              const Duration(days: 2),
            ),
          );
    }).toList();

    // nếu không có asleep lấy session

    if (sleepPts.isEmpty) {
      sleepPts = pts.where((p) {
        return p.type == HealthDataType.SLEEP_SESSION &&
            p.dateTo.isBefore(now) &&
            p.dateTo.isAfter(
              now.subtract(
                const Duration(days: 2),
              ),
            );
      }).toList();
    }

    double sleepHours = 0;

    if (sleepPts.isNotEmpty) {
      sleepPts.sort((a, b) => b.dateTo.compareTo(a.dateTo));

      final s = sleepPts.first;

      final minutes = s.dateTo.difference(s.dateFrom).inMinutes;

      debugPrint("""
====== SLEEP ======

FROM:
${s.dateFrom}

TO:
${s.dateTo}

MIN:
$minutes

===================
""");

      if (minutes > 0 && minutes < 900) {
        sleepHours = double.parse((minutes / 60).toStringAsFixed(1));
      }
    }

    debugPrint("FINAL SLEEP $sleepHours h");

    // ================= STEPS =================

    final startToday = DateTime(
      now.year,
      now.month,
      now.day,
    );

    int steps = 0;

    final stepPts = pts.where((p) {
      return p.type == HealthDataType.STEPS &&
          p.dateFrom.isBefore(now) &&
          p.dateTo.isAfter(startToday);
    }).toList();

    for (final p in stepPts) {
      if (p.value is NumericHealthValue) {
        steps += (p.value as NumericHealthValue).numericValue.toInt();
      }
    }

    // ================= CALORIES =================

    double calories = 0;

    final calPts = pts.where((p) {
      return p.type == HealthDataType.ACTIVE_ENERGY_BURNED &&
          p.dateFrom.isBefore(now) &&
          p.dateTo.isAfter(startToday);
    }).toList();

    for (final p in calPts) {
      if (p.value is NumericHealthValue) {
        final value = (p.value as NumericHealthValue).numericValue.toDouble();

        calories += value;

        debugPrint("CAL RECORD $value");
      }
    }

    final caloriesFinal =
        calories > 0 ? double.parse(calories.toStringAsFixed(0)) : steps * 0.04;

    debugPrint("""
====== TODAY ======

STEP:
$steps

CALORIES:
$calories

CAL FINAL:
$caloriesFinal

===================
""");

    // ================= BMI =================

    final bmi = last(
      HealthDataType.BODY_MASS_INDEX,
      22,
    );

    final stress = _estimateStress(
      hr: hr,
      spo2: spo2,
      sleepHours: sleepHours,
    );

    return BiometricSnapshot(
      heartRate: hr.clamp(30, 220),
      spo2: spo2.clamp(80, 100),
      sleepHours: sleepHours.clamp(0, 24),
      stressScore: stress.clamp(0, 100),
      bmi: bmi.clamp(10, 60),
      steps: steps,
      calories: caloriesFinal,
      fetchedAt: now,
      isSimulated: false,
    );
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
