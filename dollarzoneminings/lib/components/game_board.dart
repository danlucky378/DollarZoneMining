import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class CandleCrushGame extends StatefulWidget {
  final VoidCallback onGameComplete;
  const CandleCrushGame({super.key, required this.onGameComplete});

  @override
  State<CandleCrushGame> createState() => _CandleCrushGameState();
}

class _CandleCrushGameState extends State<CandleCrushGame> {
  int score = 0;
  int remainingCandles = 0;
  int timeLeft = 60;
  Timer? _timer;
  List<Offset> _candles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _generateCandles();
    _startTimer();
  }

  void _generateCandles() {
    _candles = List.generate(
      5,
      (_) => Offset(
        _random.nextDouble() * 300,
        _random.nextDouble() * 500,
      ),
    );
    remainingCandles = _candles.length;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
        } else {
          timer.cancel();
          widget.onGameComplete();
        }
      });
    });
  }

  void _onTapDown(TapDownDetails details) {
    for (int i = 0; i < _candles.length; i++) {
      final candle = _candles[i];
      final dx = (details.localPosition.dx - candle.dx).abs();
      final dy = (details.localPosition.dy - candle.dy).abs();
      if (dx < 30 && dy < 30) {
        setState(() {
          _candles.removeAt(i);
          score += 10;
          remainingCandles--;
        });

        if (_candles.isEmpty) {
          _generateCandles();
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text('Candle Crush 🕯'),
        backgroundColor: Colors.orange.shade400,
        centerTitle: true,
      ),
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Stack(
          children: [
            ..._candles.map((candle) => Positioned(
                  left: candle.dx,
                  top: candle.dy,
                  child: const Icon(Icons.candlestick_chart,
                      color: Colors.orange, size: 40),
                )),
            Positioned(
              top: 20,
              left: 20,
              child: Text(
                'Time: $timeLeft s',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Text(
                'Score: $score',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            if (timeLeft == 0)
              Center(
                child: ElevatedButton(
                  onPressed: widget.onGameComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('Finish Game'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}