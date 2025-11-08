import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../wallet/wallet_service.dart'; // for updating user wallet balance

class TaskScreen extends StatefulWidget {
  const TaskScreen({Key? key}) : super(key: key);

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool hasEnoughReferrals = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkReferralStatus();
  }

  /// ✅ Check if the user has invited 12 active users
  Future<void> _checkReferralStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final referralsSnapshot = await _firestore
        .collection('referrals')
        .where('referrerId', isEqualTo: uid)
        .where('active', isEqualTo: true)
        .get();

    setState(() {
      hasEnoughReferrals = referralsSnapshot.docs.length >= 12;
      isLoading = false;
    });
  }

  /// ✅ Open task link and mark it as started
  Future<void> _startTask(String taskId, String link, double reward) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userTaskRef = _firestore
        .collection('user_tasks')
        .doc('${uid}_$taskId');

    await userTaskRef.set({
      'userId': uid,
      'taskId': taskId,
      'status': 'pending',
      'reward': reward,
      'startedAt': FieldValue.serverTimestamp(),
      'rewardClaimed': false,
    }, SetOptions(merge: true));

    // open task link
    await FirebaseService.openLink(link);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task started! Come back to verify once done.')),
    );
  }

  /// ✅ Verify and reward user
  Future<void> _verifyTask(String taskId, double reward) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userTaskRef = _firestore
        .collection('user_tasks')
        .doc('${uid}_$taskId');

    final userTaskDoc = await userTaskRef.get();
    if (userTaskDoc.exists &&
        userTaskDoc.data()?['rewardClaimed'] == false) {
      // Mark as completed
      await userTaskRef.update({
        'status': 'completed',
        'verified': true,
        'rewardClaimed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Add to wallet
      await WalletService.addRewardToWallet(uid, reward);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task verified! You earned \$${reward.toStringAsFixed(2)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF9),
      appBar: AppBar(
        title: const Text(
          'DollarZone Tasks',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasEnoughReferrals
              ? StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('tasks')
                      .where('active', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final tasks = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final taskId = task.id;
                        final title = task['title'];
                        final description = task['description'];
                        final link = task['link'];
                        final reward = task['reward']?.toDouble() ?? 0.0;

                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection('user_tasks')
                              .doc('${auth.currentUser?.uid}$taskId')
                              .get(),
                          builder: (context, userTaskSnapshot) {
                            final userTaskData = userTaskSnapshot.data?.data()
                                as Map<String, dynamic>?;

                            final isCompleted =
                                userTaskData?['status'] == 'completed';
                            final isPending =
                                userTaskData?['status'] == 'pending';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F3F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text(description,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black54)),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '\$${reward.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isCompleted
                                              ? Colors.grey
                                              : Colors.blue,
                                        ),
                                        onPressed: isCompleted
                                            ? null
                                            : isPending
                                                ? () => _verifyTask(
                                                    taskId, reward)
                                                : () => _startTask(
                                                    taskId, link, reward),
                                        child: Text(isCompleted
                                            ? 'Completed ✅'
                                            : isPending
                                                ? 'Verify Task'
                                                : 'Start Task'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                )
              : const Center(
                  child: Text(
                    'Invite 12 active users to unlock tasks 🔒',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
    );
  }
}