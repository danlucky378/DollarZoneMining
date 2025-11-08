import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get uid => _auth.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF9),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade600,
        title: const Text(
          "DollarZoneMining",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: uid.isEmpty
          ? const Center(
              child: Text(
                "⚠ Please log in to view transactions.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _fire
                  .collection('withdrawals')
                  .where('uid', isEqualTo: uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No transactions yet.",
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final transactions = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final data = transactions[index].data() as Map<String, dynamic>;
                    final double amount = (data['amount'] ?? 0.0).toDouble();
                    final String status = (data['status'] ?? 'Pending').toString();
                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    final DateTime time = ts?.toDate() ?? DateTime.now();

                    Color statusColor;
                    IconData statusIcon;
                    switch (status) {
                      case 'Successful':
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle;
                        break;
                      case 'Failed':
                        statusColor = Colors.redAccent;
                        statusIcon = Icons.cancel;
                        break;
                      default:
                        statusColor = Colors.orangeAccent;
                        statusIcon = Icons.hourglass_bottom;
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: Icon(statusIcon, color: statusColor, size: 32),
                        title: Text(
                          "\$${amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          "USDT Withdrawal\n${time.toLocal().toString().split('.')[0]}",
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}