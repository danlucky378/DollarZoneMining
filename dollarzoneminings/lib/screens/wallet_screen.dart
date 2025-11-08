import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../components/balance_card.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get uid => _auth.currentUser?.uid ?? '';

  double coinBalance = 0.0;
  double dollarBalance = 0.0;
  bool walletLocked = true;
  int referrals = 0;
  final _usdtController = TextEditingController();
  final _amountController = TextEditingController();
  String withdrawalStatus = "";

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _checkReferrals();
  }

  Future<void> _loadWallet() async {
    if (uid.isEmpty) return;
    final doc = await _fire.collection('wallets').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        dollarBalance = (data['balance'] ?? 0.0).toDouble();
        coinBalance = (data['earnings'] ?? 0.0).toDouble();
      });
    }
  }

  Future<void> _checkReferrals() async {
    if (uid.isEmpty) return;
    final refDoc = await _fire.collection('referrals').doc(uid).get();
    if (refDoc.exists) {
      referrals = (refDoc.data()?['activeReferrals'] ?? 0);
      if (referrals >= 5) walletLocked = false;
      setState(() {});
    }
  }

  void _withdraw() async {
    if (walletLocked) {
      setState(() {
        withdrawalStatus = "❌ Wallet locked! You need 5 active referrals.";
      });
      return;
    }

    double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0 || amount > dollarBalance) {
      setState(() {
        withdrawalStatus = "⚠ Invalid amount.";
      });
      return;
    }

    await _fire.collection('withdrawals').add({
      'uid': uid,
      'address': _usdtController.text.trim(),
      'amount': amount,
      'status': 'Pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      dollarBalance -= amount;
      withdrawalStatus = "✅ Withdrawal request sent (Pending)";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Wallet"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BalanceCard(title: "Coin Balance", amount: "${coinBalance.toStringAsFixed(0)}"),
                BalanceCard(title: "Dollar Balance", amount: "\$${dollarBalance.toStringAsFixed(2)}"),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: walletLocked
                  ? Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Locked Wallet\nYou need 5 active referrals to unlock withdrawals (You have $referrals).",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      "✅ Wallet Unlocked! You can withdraw every 2 weeks on Thursday.",
                      style: TextStyle(fontSize: 14),
                    ),
            ),
            const SizedBox(height: 24),
            const Text("USDT Address", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _usdtController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: "Enter your USDT address",
              ),
            ),
            const SizedBox(height: 16),
            const Text("Amount", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: "\$ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: "Enter amount",
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _withdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Withdraw",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (withdrawalStatus.isNotEmpty)
              Center(
                child: Text(
                  withdrawalStatus,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}