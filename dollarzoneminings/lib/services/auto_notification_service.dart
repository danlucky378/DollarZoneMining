import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../helpers/notification_helper.dart';

class AutoNotificationService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _fcm = FirebaseMessaging.instance;

  /// ✅ Listen for important changes in Firestore and send notifications
  void startListening() {
    final user = _auth.currentUser;
    if (user == null) return;

    // 🪙 Listen to wallet updates
    _firestore.collection('wallets').doc(user.uid).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;
      bool cooldownOver = data['cooldownOver'] ?? false;
      bool newReferral = data['newReferral'] ?? false;
      bool withdrawalApproved = data['withdrawalApproved'] ?? false;

      if (cooldownOver) {
        NotificationHelper.showInstantNotification(
          'Mining Ready!',
          'Your 4-hour cooldown is over — start mining again!',
        );
        _firestore
            .collection('wallets')
            .doc(user.uid)
            .update({'cooldownOver': false});
      }

      if (newReferral) {
        NotificationHelper.showInstantNotification(
          'New Referral!',
          'Someone just joined using your referral code!',
        );
        _firestore
            .collection('wallets')
            .doc(user.uid)
            .update({'newReferral': false});
      }

      if (withdrawalApproved) {
        NotificationHelper.showInstantNotification(
          'Withdrawal Approved!',
          'Your pending withdrawal has been successfully approved.',
        );
        _firestore
            .collection('wallets')
            .doc(user.uid)
            .update({'withdrawalApproved': false});
      }
    });
  }
}