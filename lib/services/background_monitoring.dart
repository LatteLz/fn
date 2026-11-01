import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import '../models/models.dart';
import 'api_service.dart';
import 'health_service.dart';

const _backgroundTaskName = 'checkStrokeRiskTask';
const _backgroundUniqueName = 'strokeGuardBackgroundCheck';
const _healthPermissionChannel =
    MethodChannel('com.example.strokeguard/health_background');

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    String? uid;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyAnlTjNUS8TXyYbA4CkwctxqkgtcNfvPUs',
          appId: '1:991635367629:android:c0df528b58c83168dd6b84',
          messagingSenderId: '991635367629',
          projectId: 'strokeguard-nhom9',
          storageBucket: 'strokeguard-nhom9.firebasestorage.app',
        ),
      );

      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ??
          await auth.authStateChanges().first.timeout(
                const Duration(seconds: 10),
                onTimeout: () => null,
              );
      if (user == null) {
        debugPrint('[BACKGROUND] No signed-in user; skipping scan.');
        return true;
      }
      uid = user.uid;

      final profileDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!profileDoc.exists) {
        await _saveScanFailure(uid, 'Tài khoản chưa có hồ sơ sức khỏe.');
        return true;
      }
      final profile = UserModel.fromJson(profileDoc.data()!);

      final bio = await HealthService.fetchBackgroundSnapshot();
      if (bio == null) {
        await _saveScanFailure(
          uid,
          'Không có đủ dữ liệu nhịp tim và SpO₂ trong Health Connect.',
        );
        return true;
      }

      final result = await ApiService.predict(user: profile, bio: bio);
      final scannedAt = DateTime.now();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('predictions')
          .add({
        ...result.toFirestore(),
        'timestamp': scannedAt.toIso8601String(),
        'scan_status': 'success',
        'is_background': true,
        'heart_rate': bio.heartRate,
        'spo2': bio.spo2,
        'sleep_hours': bio.sleepHours,
        'stress_score': bio.stressScore,
      });

      if (result.riskLevel == 'CAO') {
        await _showHighRiskNotification(result.ensemble);
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('[BACKGROUND] Scan failed: $error\n$stackTrace');
      if (uid != null) {
        try {
          await _saveScanFailure(uid, 'Không thể hoàn tất lần quét: $error');
          return true;
        } catch (saveError, saveStackTrace) {
          debugPrint(
            '[BACKGROUND] Could not save scan failure: '
            '$saveError\n$saveStackTrace',
          );
        }
      }
      return false;
    }
  });
}

class BackgroundMonitoring {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  static Future<void> startForCurrentUser() async {
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      await Workmanager().registerPeriodicTask(
        _backgroundUniqueName,
        _backgroundTaskName,
        // Android có thể trì hoãn tác vụ; 15 phút là chu kỳ tối thiểu.
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BACKGROUND] Could not start periodic monitoring: '
        '$error\n$stackTrace',
      );
    }
  }

  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_backgroundUniqueName);
  }

  static Future<void> requestNotificationPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<bool> requestBackgroundHealthReadPermission() async {
    return await _healthPermissionChannel
            .invokeMethod<bool>('requestBackgroundReadPermission') ??
        false;
  }
}

Future<void> _saveScanFailure(String uid, String message) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('predictions')
      .add({
    'timestamp': DateTime.now().toIso8601String(),
    'scan_status': 'failed',
    'scan_message': message,
    'is_background': true,
  });
}

Future<void> _showHighRiskNotification(double probability) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'strokeguard_alert_channel',
      'Cảnh báo nguy cơ đột quỵ',
      channelDescription: 'Cảnh báo khi kết quả sàng lọc AI ở mức nguy cơ cao',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFF44336),
    ),
  );

  await _notifications.show(
    0,
    'Cảnh báo: kết quả sàng lọc nguy cơ cao',
    'Kết quả AI: ${(probability * 100).toStringAsFixed(1)}%. '
        'Đây không phải chẩn đoán. Nếu có dấu hiệu đột quỵ đột ngột, '
        'hãy gọi cấp cứu ngay.',
    details,
  );
}
