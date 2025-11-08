import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CooldownTimer extends StatefulWidget {
  final DateTime lastMinedTime;
  final Duration cooldownDuration;
  final VoidCallback onCooldownComplete;

  const CooldownTimer({
    Key? key,
    required this.lastMinedTime,
    this.cooldownDuration = const Duration(hours: 4),
    required this.onCooldownComplete,
  }) : super(key: key);

  @override
  State<CooldownTimer> createState() => _CooldownTimerState();
}

class _CooldownTimerState extends State<CooldownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadCooldownTime();
  }

  Future<void> _loadCooldownTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getString('lastMinedTime');

    DateTime lastTime;
    if (savedTime != null) {
      lastTime = DateTime.parse(savedTime);
    } else {
      lastTime = widget.lastMinedTime;
      prefs.setString('lastMinedTime', lastTime.toIso8601String());
    }

    _updateRemaining(lastTime);
    _startTimer();
  }

  void _updateRemaining(DateTime lastTime) {
    final now = DateTime.now();
    final diff = widget.cooldownDuration - now.difference(lastTime);

    if (diff.isNegative) {
      _remaining = Duration.zero;
    } else {
      _remaining = diff;
    }
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), () {
      if (_remaining.inSeconds <= 0) {
        _timer?.cancel();
        widget.onCooldownComplete();

        // 🔔 Trigger notification
        NotificationHelper.notifyCooldownDone();
      } else {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    return Text(
      _remaining.inSeconds > 0
          ? '⏳ Next mining in ${hours}h ${minutes}m ${seconds}s'
          : '✅ Ready to Mine!',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }
}