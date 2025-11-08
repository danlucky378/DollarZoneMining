// lib/services/referral_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralService {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser?.uid ?? '';

  /// Generate a referral code from UID
  String generateReferralCode() {
    if (uid.isEmpty) return '';
    return uid.substring(0, 6).toUpperCase();
  }

  /// Fetch current user's referral data
  Future<Map<String, dynamic>> getReferralData() async {
    if (uid.isEmpty) return {};
    final snap = await _fire.collection('referral').doc(uid).get();
    return snap.data() ?? {};
  }

  /// Add a referred user under the inviter
  Future<void> addReferral(String inviterCode) async {
    if (uid.isEmpty || inviterCode.isEmpty) return;
    final refCollection = _fire.collection('referral');

    final query = await refCollection.where('referralCode', isEqualTo: inviterCode).limit(1).get();
    if (query.docs.isEmpty) return;

    final inviterId = query.docs.first.id;

    // Update inviter's referral counts
    await _fire.runTransaction((tx) async {
      final inviterRef = refCollection.doc(inviterId);
      final snap = await tx.get(inviterRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      final pending = (data['pending'] ?? 0) + 1;

      tx.update(inviterRef, {'pending': pending});
    });
  }

  /// Mark a referral as active (when a referred user performs task)
  Future<void> activateReferral(String inviterId) async {
    final ref = _fire.collection('referral').doc(inviterId);
    await _fire.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final active = (data['active'] ?? 0) + 1;
      final pending = (data['pending'] ?? 1) - 1;
      tx.update(ref, {'active': active, 'pending': pending});
    });
  }
}