import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/game_board/game_board.dart';
import '../services/notification_helper.dart';

class MiningButton extends StatefulWidget {
  final String zoneName; // e.g. 'zone1'
  final String buttonId; // e.g. 'btn1'
  final String admobLink;
  final void Function(double) onEarned;

  const MiningButton({
    super.key,
    required this.zoneName,
    required this.buttonId,
    required this.admobLink,
    required this.onEarned,
  });

  @override
  State<MiningButton> createState() => _MiningButtonState();
}

class _MiningButtonState extends State<MiningButton> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Timer? _countdownTimer;
  int cooldownRemaining = 0;
  bool isCoolingDown = false;
  bool _playingGame = false;
  int localClicks = 0;

  static const int clicksPerCycle = 10;
  static const int cooldownSecondsConst = 4 * 3600; // 4 hours
  static const double coinPerClick = 0.5;

  String get uid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadButtonState();
  }

  Future<void> _loadButtonState() async {
    if (uid.isEmpty) return;
    final docRef = _fire.collection('mining_zone').doc(uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return;
    final zoneData = snapshot.data()?[widget.zoneName] as Map<String, dynamic>?;

    if (zoneData == null) return;
    final buttonsMap = zoneData['buttons'] as Map<String, dynamic>? ?? {};
    final btnMap = buttonsMap[widget.buttonId] as Map<String, dynamic>? ?? {};

    final cooldownEndStr = btnMap['cooldownEnd'] as String? ?? '';

    if (cooldownEndStr.isNotEmpty) {
      final cooldownEnd = DateTime.tryParse(cooldownEndStr);
      if (cooldownEnd != null) {
        final now = DateTime.now();
        if (cooldownEnd.isAfter(now)) {
          setState(() {
            isCoolingDown = true;
            cooldownRemaining = cooldownEnd.difference(now).inSeconds;
          });
          _startCountdown();
        }
      }
    }
  }

  Future<void> _onPressed() async {
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to mine')),
      );
      return;
    }
    if (isCoolingDown || _playingGame) return;

    await _simulateRewardAd(widget.admobLink);
    await _awardCoinAndPersist();
  }

  Future<void> _simulateRewardAd(String link) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulating reward ad...')),
    );
    await Future.delayed(const Duration(seconds: 3));
  }

  Future<void> _awardCoinAndPersist() async {
    localClicks++;
    widget.onEarned(coinPerClick);

    final docRef = _fire.collection('mining_zone').doc(uid);
    await _fire.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      Map<String, dynamic> data = snap.exists ? (snap.data() as Map<String, dynamic>) : {};

      final zoneMap = (data[widget.zoneName] as Map<String, dynamic>?) ?? {};
      double zoneCoins = (zoneMap['coinsEarned'] ?? 0).toDouble();
      int zoneButtonsCompleted = (zoneMap['buttonsCompleted'] ?? 0) as int;
      Map<String, dynamic> buttons = (zoneMap['buttons'] as Map<String, dynamic>?) ?? {};

      final btn = (buttons[widget.buttonId] as Map<String, dynamic>?) ?? {};
      int btnClicks = (btn['clicks'] ?? 0) as int;

      zoneCoins += coinPerClick;
      btnClicks += 1;

      buttons[widget.buttonId] = {
        'clicks': btnClicks,
        'cooldownEnd': btn['cooldownEnd'] ?? '',
      };

      zoneMap['coinsEarned'] = zoneCoins;
      zoneMap['buttonsCompleted'] = zoneButtonsCompleted;
      zoneMap['buttons'] = buttons;

      data[widget.zoneName] = zoneMap;
      tx.set(docRef, data, SetOptions(merge: true));

      // also update wallet
      final walletRef = _fire.collection('wallets').doc(uid);
      final walletSnap = await tx.get(walletRef);
      final currentBalance = (walletSnap.data()?['balance'] ?? 0.0) as double;
      final currentEarnings = (walletSnap.data()?['earnings'] ?? 0.0) as double;

      tx.set(walletRef, {
        'balance': currentBalance + (coinPerClick / 100),
        'earnings': currentEarnings + coinPerClick,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (localClicks >= clicksPerCycle) {
      localClicks = 0;
      await _playTwoGamesThenSetCooldown();
    }
  }

  Future<void> _playTwoGamesThenSetCooldown() async {
    setState(() => _playingGame = true);

    for (int i = 0; i < 2; i++) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CandleCrushGame(onGameComplete: () {}),
        ),
      );
    }

    setState(() => _playingGame = false);

    final cooldownEnd = DateTime.now().add(const Duration(seconds: cooldownSecondsConst)).toIso8601String();
    final docRef = _fire.collection('mining_zone').doc(uid);

    await docRef.set({
      widget.zoneName: {
        'buttons': {
          widget.buttonId: {'cooldownEnd': cooldownEnd, 'clicks': 0}
        },
        'cyclesDoneToday': FieldValue.increment(1),
      }
    }, SetOptions(merge: true));

    final prefs = await SharedPreferences.getInstance();
    prefs.setString('lastMinedTime', DateTime.now().toIso8601String());

    // 🔔 Schedule background/local notification for when cooldown is over
    await NotificationHelper.scheduleCooldownNotification(
      seconds: cooldownSecondsConst,
      title: '⛏ Mining Ready!',
      body: 'Your cooldown is over — start mining again now!',
      payload: 'cooldown_done',
    );

    setState(() {
      isCoolingDown = true;
      cooldownRemaining = cooldownSecondsConst;
    });
    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cooldown started — you’ll be notified when ready!')),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (cooldownRemaining <= 0) {
        timer.cancel();
        setState(() {
          isCoolingDown = false;
          cooldownRemaining = 0;
        });
      } else {
        setState(() => cooldownRemaining--);
      }
    });
  }

  String _formattedTime(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: (isCoolingDown || _playingGame) ? null : _onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isCoolingDown ? Colors.grey : Colors.orange.shade600,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Center(
              child: Text(
                _playingGame
                    ? 'Playing Game...'
                    : isCoolingDown
                        ? 'Cooldown ${_formattedTime(cooldownRemaining)}'
                        : 'Mine (${localClicks}/$clicksPerCycle)',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}