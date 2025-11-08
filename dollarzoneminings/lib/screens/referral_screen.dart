import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String referralCode = '';
  int pending = 0;
  int active = 0;
  int total = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadReferralData();
  }

  Future<void> loadReferralData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef =
        FirebaseFirestore.instance.collection('referrals').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      referralCode = data['referralCode'] ?? generateReferralCode(user.uid);
      pending = data['pending'] ?? 0;
      active = data['active'] ?? 0;
      total = data['total'] ?? 0;
    } else {
      referralCode = generateReferralCode(user.uid);
      await docRef.set({
        'referralCode': referralCode,
        'pending': 0,
        'active': 0,
        'total': 0,
      });
    }

    // 🔁 Listen for wallets updates to check activation ($1 condition)
    FirebaseFirestore.instance.collection('wallets').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final walletData = doc.data();
        final balance = walletData['balance'] ?? 0.0;
        final referrerId = walletData['referrerId'];

        if (balance >= 1.0 && referrerId == user.uid) {
          activateReferral(user.uid);
        }
      }
    });

    setState(() => _isLoading = false);
  }

  Future<void> activateReferral(String userId) async {
    final refRef = FirebaseFirestore.instance.collection('referrals').doc(userId);
    final doc = await refRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      int pendingCount = data['pending'] ?? 0;
      int activeCount = data['active'] ?? 0;

      if (pendingCount > 0) {
        await refRef.update({
          'pending': pendingCount - 1,
          'active': activeCount + 1,
          'total': (pendingCount - 1) + (activeCount + 1),
        });

        // ✅ Update user's activeReferrals in "users" collection
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'activeReferrals': activeCount + 1,
        });
      }
    }
  }

  String generateReferralCode(String uid) {
    return uid.substring(0, 5).toUpperCase();
  }

  void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied!')),
    );
  }

  Future<void> shareReferral() async {
    final message =
        '🔥 Join me on DollarZoneMining! Use my referral code $referralCode to get started!\n\nDownload the app here: https://t.me/dollarzonemining';
    await Share.share(message);
  }

  Future<void> openTelegramGroup() async {
    const groupUrl = 'https://t.me/dollarzonemining_group';
    if (await canLaunchUrl(Uri.parse(groupUrl))) {
      await launchUrl(Uri.parse(groupUrl));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open Telegram.')),
      );
    }
  }

  Widget buildStatCard(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Referral', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Referral Code',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2))
                                ],
                              ),
                              child: Text(
                                referralCode.isNotEmpty ? referralCode : '...',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () =>
                                copyToClipboard(context, referralCode),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('COPY'),
                          )
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Referral Stats',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      buildStatCard('Pending', '$pending', Colors.orange),
                      buildStatCard('Active', '$active', Colors.green),
                      buildStatCard('Total', '$total', Colors.blue),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: shareReferral,
                              icon: const Icon(Icons.share),
                              label: const Text('Invite Friends'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: openTelegramGroup,
                              icon: const Icon(Icons.telegram),
                              label: const Text('Telegram'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}