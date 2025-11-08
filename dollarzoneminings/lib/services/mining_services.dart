import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MiningService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Get user ID
  String get userId => _auth.currentUser?.uid ?? '';

  /// Get reference to a specific zone
  DocumentReference<Map<String, dynamic>> getZoneRef(String zoneName) {
    return _firestore.collection('mining_zone').doc(userId);
  }

  /// Fetch data for a given zone
  Future<Map<String, dynamic>?> getZoneData(String zoneName) async {
    final doc = await getZoneRef(zoneName).get();
    if (!doc.exists) return null;
    return doc.data()?[zoneName];
  }

  /// Increment mining progress for one button tap
  Future<void> mine(String zoneName) async {
    final zoneRef = getZoneRef(zoneName);
    final snapshot = await zoneRef.get();

    if (!snapshot.exists) return;
    final data = snapshot.data()?[zoneName];
    if (data == null) return;

    bool locked = data['locked'] ?? false;
    if (locked) throw Exception("Zone is locked");

    int buttonsCompleted = data['buttonsCompleted'] ?? 0;
    int cyclesDoneToday = data['cyclesDoneToday'] ?? 0;
    double coinsEarned = (data['coinsEarned'] ?? 0).toDouble();

    // Each tap = 0.5 coins
    coinsEarned += 0.5;
    buttonsCompleted += 1;

    // After 10 taps, trigger cooldown
    if (buttonsCompleted >= 10) {
      buttonsCompleted = 0;
      cyclesDoneToday += 1;

      // Set 4-hour cooldown from now
      final cooldownEnd = DateTime.now().add(const Duration(hours: 4)).toIso8601String();

      await zoneRef.update({
        '$zoneName.cooldownEnd': cooldownEnd,
        '$zoneName.cyclesDoneToday': cyclesDoneToday,
        '$zoneName.coinsEarned': coinsEarned,
        '$zoneName.buttonsCompleted': buttonsCompleted,
      });
    } else {
      await zoneRef.update({
        '$zoneName.coinsEarned': coinsEarned,
        '$zoneName.buttonsCompleted': buttonsCompleted,
      });
    }
  }

  /// Check if cooldown is active
  Future<bool> isOnCooldown(String zoneName) async {
    final data = await getZoneData(zoneName);
    if (data == null) return false;

    final cooldownEndStr = data['cooldownEnd'] ?? '';
    if (cooldownEndStr.isEmpty) return false;

    final cooldownEnd = DateTime.tryParse(cooldownEndStr);
    if (cooldownEnd == null) return false;

    return DateTime.now().isBefore(cooldownEnd);
  }

  /// Reset zones at 1AM (called daily)
  Future<void> resetDaily() async {
    final zoneRef = getZoneRef("any");
    final doc = await zoneRef.get();
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) return;

    final walletRef = _firestore.collection('wallets').doc(userId);
    final walletDoc = await walletRef.get();

    double walletBalance = walletDoc.data()?['balance'] ?? 0.0;
    double dailyEarnings = 0;

    final updatedZones = <String, dynamic>{};

    data.forEach((zoneName, zoneData) {
      double zoneCoins = (zoneData['coinsEarned'] ?? 0).toDouble();
      dailyEarnings += zoneCoins;

      updatedZones[zoneName] = {
        'coinsEarned': 0,
        'buttonsCompleted': 0,
        'cyclesDoneToday': 0,
        'cooldownEnd': '',
        'locked': zoneData['locked'] ?? false,
      };
    });

    // Update all zones and wallet
    await zoneRef.update(updatedZones);
    await walletRef.update({
      'balance': walletBalance + dailyEarnings / 100, // Convert coins to dollars
      'earnings': FieldValue.increment(dailyEarnings),
      'lastUpdated': DateTime.now(),
    });
  }
}