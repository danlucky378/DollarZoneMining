import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/mining_button.dart';
import '../utils/date_utils.dart';

class Zone2Screen extends StatefulWidget {
  const Zone2Screen({super.key});

  @override
  State<Zone2Screen> createState() => _Zone2ScreenState();
}

class _Zone2ScreenState extends State<Zone2Screen> {
  double totalCoins = 0.0;
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get uid => _auth.currentUser?.uid ?? '';

  // 10 distinct fake ad unit ids / links — replace with real AdMob unit IDs later
  final List<String> fakeAdUnitIds = [
    'ca-app-pub-fake-2001/rewarded_ad_unit_01',
    'ca-app-pub-fake-2002/rewarded_ad_unit_02',
    'ca-app-pub-fake-2003/rewarded_ad_unit_03',
    'ca-app-pub-fake-2004/rewarded_ad_unit_04',
    'ca-app-pub-fake-2005/rewarded_ad_unit_05',
    'ca-app-pub-fake-2006/rewarded_ad_unit_06',
    'ca-app-pub-fake-2007/rewarded_ad_unit_07',
    'ca-app-pub-fake-2008/rewarded_ad_unit_08',
    'ca-app-pub-fake-2009/rewarded_ad_unit_09',
    'ca-app-pub-fake-2010/rewarded_ad_unit_10',
  ];

  @override
  void initState() {
    super.initState();
    _checkDailyReset();
    _loadZoneTotals();
  }

  Future<void> _loadZoneTotals() async {
    if (uid.isEmpty) return;
    final snap = await _fire.collection('mining_zone').doc(uid).get();
    if (!snap.exists) return;
    final z = (snap.data() ?? {})['zone2'] as Map<String, dynamic>?;
    if (z != null) {
      setState(() {
        totalCoins = (z['coinsEarned'] ?? 0).toDouble();
      });
    }
  }

  Future<void> _checkDailyReset() async {
    if (await DateUtilsHelper.shouldReset()) {
      await _moveCoinsToWalletAndResetZone();
      await DateUtilsHelper.markReset();
    }
  }

  Future<void> _moveCoinsToWalletAndResetZone() async {
    if (uid.isEmpty) return;
    final docRef = _fire.collection('mining_zone').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final zoneData = (doc.data() ?? {})['zone2'] as Map<String, dynamic>? ?? {};
    final double zoneCoins = (zoneData['coinsEarned'] ?? 0).toDouble();

    if (zoneCoins <= 0) return;

    // transfer coins to wallet and reset zone coins atomically
    final walletRef = _fire.collection('wallets').doc(uid);

    await _fire.runTransaction((tx) async {
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) {
        tx.set(walletRef, {
          'balance': zoneCoins / 100, // conversion: 100 coins = $1
          'earnings': zoneCoins,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final currentBalance = (walletSnap.data() as Map<String, dynamic>)['balance'] ?? 0.0;
        final currentEarnings = (walletSnap.data() as Map<String, dynamic>)['earnings'] ?? 0.0;
        tx.update(walletRef, {
          'balance': currentBalance + (zoneCoins / 100),
          'earnings': currentEarnings + zoneCoins,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // reset zone2 fields
      tx.update(docRef, {
        'zone2.coinsEarned': 0,
        'zone2.buttonsCompleted': 0,
        'zone2.cyclesDoneToday': 0,
        'zone2.buttons': {},
      });
    });

    setState(() => totalCoins = 0.0);
  }

  Future<void> _onEarned(double coins) async {
    setState(() => totalCoins += coins);

    if (uid.isEmpty) return;

    final docRef = _fire.collection('mining_zone').doc(uid);

    await docRef.set({
      'zone2': {
        'coinsEarned': FieldValue.increment(coins),
      }
    }, SetOptions(merge: true));

    final walletRef = _fire.collection('wallets').doc(uid);
    await _fire.runTransaction((tx) async {
      final w = await tx.get(walletRef);
      if (!w.exists) {
        tx.set(walletRef, {
          'balance': coins / 100,
          'earnings': coins,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final currentBalance = (w.data() ?? {})['balance'] ?? 0.0;
        final currentEarnings = (w.data() ?? {})['earnings'] ?? 0.0;
        tx.update(walletRef, {
          'balance': currentBalance + (coins / 100),
          'earnings': currentEarnings + coins,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FCFF),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        title: const Text("Zone 2 Mining"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Zone 2 - Total Coins: ${totalCoins.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: 10,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final adUnitId = fakeAdUnitIds[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mine ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          MiningButton(
                            zoneName: 'zone2',
                            buttonId: 'btn${index + 1}',
                            admobLink: adUnitId,
                            onEarned: _onEarned,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}