import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationHelper {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'dollarzone_channel',
    'DollarZone Notifications',
    description: 'Mining, wallet, referral, and admin updates.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // =====================================================
  // INITIALIZE NOTIFICATIONS + REGISTER FCM TOKEN
  // =====================================================
  static Future<void> initializeNotifications() async {
    // Timezone for scheduling
    tz.initializeTimeZones();

    // Local notification setup
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("🔔 Notification clicked: ${response.payload}");
      },
    );

    // Create Android channel
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Request permission for FCM
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Get FCM token
    final token = await _fcm.getToken();
    debugPrint("✅ FCM Token: $token");

    // Save token to Firestore
    await _saveTokenToFirestore(token);

    // Listen for new tokens (in case it refreshes)
    _fcm.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(newToken);
    });

    // Handle FCM foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showLocalNotification(
          title: message.notification!.title ?? 'DollarZoneMining',
          body: message.notification!.body ?? 'You have a new update!',
          payload: message.data['target'],
        );
      }
    });

    // Handle background/terminated notifications
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // =====================================================
  // BACKGROUND HANDLER
  // =====================================================
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    await showLocalNotification(
      title: message.notification?.title ?? 'DollarZoneMining',
      body: message.notification?.body ?? 'You have a new update!',
      payload: message.data['target'],
    );
  }

  // =====================================================
  // SHOW LOCAL NOTIFICATION
  // =====================================================
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'dollarzone_channel',
      'DollarZone Notifications',
      channelDescription: 'Mining cooldowns, referrals, wallet updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // =====================================================
  // CUSTOM AUTOMATED NOTIFICATIONS
  // =====================================================
  static Future<void> scheduleCooldownNotification({
    required int seconds,
    String title = '⛏ Mining Ready!',
    String body = 'Your mining cooldown is complete. Tap to mine again!',
  }) async {
    await _local.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dollarzone_channel',
          'DollarZone Notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'mining',
    );
  }

  static Future<void> notifyTransactionApproved(String amount) async {
    await showLocalNotification(
      title: '💸 Transaction Approved!',
      body: 'Your withdrawal of \$${amount} has been approved.',
      payload: 'wallet',
    );
  }

  static Future<void> notifyNewReferral(String username) async {
    await showLocalNotification(
      title: '👥 New Referral!',
      body: '$username just joined using your code!',
      payload: 'referral',
    );
  }

  // =====================================================
  // SAVE TOKEN TO FIRESTORE
  // =====================================================
  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userRef.set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}