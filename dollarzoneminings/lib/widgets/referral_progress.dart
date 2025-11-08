// lib/widgets/referral_progress.dart
import 'package:flutter/material.dart';

class ReferralProgress extends StatelessWidget {
  final int active;
  final int pending;
  final int total;

  const ReferralProgress({
    super.key,
    required this.active,
    required this.pending,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? active / total : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Referral Progress",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              color: Colors.orange,
              backgroundColor: Colors.orange.withOpacity(0.2),
              minHeight: 8,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Active: $active",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text("Pending: $pending",
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                Text("Total: $total",
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}