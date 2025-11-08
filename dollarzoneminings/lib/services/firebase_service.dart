import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Register user (1 account per device)
  static Future<User?> registerUser({
    required String email,
    required String password,
    required String username,
    required String deviceId,
    String? referralCode,
  }) async {
    try {
      // Check if this device already has an account
      final existingUser = await _firestore
          .collection('users')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (existingUser.docs.isNotEmpty) {
        throw Exception('Account already exists on this device.');
      }

      // Create new user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // Create referral code
      final generatedCode = username.substring(0, 3).toUpperCase() +
          user.uid.substring(0, 4);

      // Save user to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'username': username,
        'referralCode': generatedCode,
        'deviceId': deviceId,
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
        'referredBy': referralCode ?? '',
      });

      // ✅ If they were referred, add to referrer’s list
      if (referralCode != null && referralCode.isNotEmpty) {
        final referrerSnapshot = await _firestore
            .collection('users')
            .where('referralCode', isEqualTo: referralCode)
            .get();

        if (referrerSnapshot.docs.isNotEmpty) {
          final referrerId = referrerSnapshot.docs.first.id;
          await _firestore.collection('referrals').add({
            'referrerId': referrerId,
            'referredUserId': user.uid,
            'active': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      print('❌ Registration error: $e');
      rethrow;
    }
  }

  /// ✅ Login user
  static Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  /// ✅ Logout user
  static Future<void> logoutUser() async {
    await _auth.signOut();
  }

  /// ✅ Open external link (for tasks, Telegram, etc.)
  static Future<void> openLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open $url');
    }
  }

  /// ✅ Update referral active status when wallet hits $1
  static Future<void> updateReferralActive(String userId) async {
    try {
      final referralSnapshot = await _firestore
          .collection('referrals')
          .where('referredUserId', isEqualTo: userId)
          .get();

      if (referralSnapshot.docs.isNotEmpty) {
        final referralDoc = referralSnapshot.docs.first;
        await _firestore
            .collection('referrals')
            .doc(referralDoc.id)
            .update({'active': true});
      }
    } catch (e) {
      print('❌ Error updating referral active: $e');
    }
  }

  /// ✅ Get current user balance
  static Future<double> getUserBalance(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return (userDoc.data()?['balance'] ?? 0.0).toDouble();
    }
    return 0.0;
  }

  /// ✅ Update user balance
  static Future<void> updateUserBalance(String userId, double newBalance) async {
    await _firestore.collection('users').doc(userId).update({
      'balance': newBalance,
    });
  }

  /// ✅ Add earned amount to wallet and mark referral active if needed
  static Future<void> addEarning(String userId, double amount) async {
    double currentBalance = await getUserBalance(userId);
    double newBalance = currentBalance + amount;

    await updateUserBalance(userId, newBalance);

    if (newBalance >= 1.0) {
      await updateReferralActive(userId);
    }
  }

  /// ✅ Get user referral code
  static Future<String?> getReferralCode(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['referralCode'];
  }

  /// ✅ Get referral stats
  static Future<Map<String, int>> getReferralStats(String userId) async {
    final referrals = await _firestore
        .collection('referrals')
        .where('referrerId', isEqualTo: userId)
        .get();

    int total = referrals.docs.length;
    int active =
        referrals.docs.where((doc) => doc['active'] == true).length;
    int pending = total - active;

    return {
      'total': total,
      'active': active,
      'pending': pending,
    };
  }
}