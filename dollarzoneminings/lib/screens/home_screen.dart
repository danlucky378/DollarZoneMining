import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../zones/zone1_screen.dart';
import '../zones/zone2_screen.dart';
import '../zones/zone3_screen.dart';
import '../zones/zone4_screen.dart';
import '../zones/zone5_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int activeReferrals = 0;
  bool isLoading = true;
  Stream<DocumentSnapshot>? userStream;

  @override
  void initState() {
    super.initState();
    _initUserListener();
  }

  void _initUserListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔥 Real-time listener — auto refresh on data change
    userStream =
        FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    userStream!.listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          activeReferrals = data['activeReferrals'] ?? 0;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    });
  }

  Widget buildZoneButton(
      BuildContext context, String zoneName, Widget zoneScreen, Color color, bool unlocked) {
    return GestureDetector(
      onTap: unlocked
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => zoneScreen),
              );
            }
          : null,
      child: Container(
        height: 90,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: unlocked ? color : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            unlocked ? zoneName : '$zoneName 🔒',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔒 Unlock condition
    bool zone4Unlocked = activeReferrals >= 7;
    bool zone5Unlocked = activeReferrals >= 7;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DollarZone Mining',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Referrals: $activeReferrals',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  if (activeReferrals >= 7)
                    const Icon(Icons.check_circle, color: Colors.green, size: 22),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      buildZoneButton(context, 'Zone 1', const Zone1Screen(),
                          Colors.orange.shade400, true),
                      buildZoneButton(context, 'Zone 2', const Zone2Screen(),
                          Colors.orange.shade500, true),
                      buildZoneButton(context, 'Zone 3', const Zone3Screen(),
                          Colors.orange.shade600, true),
                      buildZoneButton(context, 'Zone 4', const Zone4Screen(),
                          Colors.orange.shade700, zone4Unlocked),
                      buildZoneButton(context, 'Zone 5', const Zone5Screen(),
                          Colors.orange.shade800, zone5Unlocked),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (!zone4Unlocked || !zone5Unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Invite 7 active users to unlock Zone 4 and 5 🔐',
                        style: TextStyle(color: Colors.redAccent, fontSize: 15),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}