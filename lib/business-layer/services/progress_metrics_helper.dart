import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressMetricsHelper {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<Map<String, DeckHybridMetrics>> calculateAllDeckMetrics() async {
    final uid = _uid;
    if (uid == null) return {};

    final result = <String, DeckHybridMetrics>{};

    try {
      final attempts = await _db
          .collection('users')
          .doc(uid)
          .collection('quizAttempts')
          .orderBy('createdAt', descending: true)
          .limit(250)
          .get();

      final deckAttempts = <String, List<double>>{};
      for (final doc in attempts.docs) {
        final data = doc.data();
        final deckId = data['deckId'] as String? ?? '';
        final ownerUid = data['ownerUid'] as String? ?? '';
        if (deckId.isEmpty) continue;

        final key = '${ownerUid}__$deckId';
        final score = _readDouble(data['score']);
        deckAttempts.putIfAbsent(key, () => []).add(score);
      }

      for (final entry in deckAttempts.entries) {
        final scores = entry.value;
        if (scores.isEmpty) continue;

        final recentScores = scores.take(3).toList();
        final currentMastery = recentScores.isEmpty
            ? 0.0
            : recentScores.reduce((a, b) => a + b) / recentScores.length;

        final peakMastery = scores.reduce((a, b) => a > b ? a : b);
        final trend = _calculateTrend(scores);

        result[entry.key] = DeckHybridMetrics(
          currentMastery: currentMastery,
          peakMastery: peakMastery,
          trendDirection: trend.direction,
          trendPercentChange: trend.percentChange,
          recentAttempts: scores.take(5).toList(),
        );
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  static _TrendData _calculateTrend(List<double> scores) {
    if (scores.length < 2) {
      return _TrendData(direction: 'stable', percentChange: 0.0);
    }

    final recent = scores.take(3).toList();
    final previous = scores.skip(3).take(3).toList();

    if (previous.isEmpty) {
      return _TrendData(direction: 'stable', percentChange: 0.0);
    }

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final previousAvg = previous.reduce((a, b) => a + b) / previous.length;

    final percentChange = ((recentAvg - previousAvg) * 100);

    String direction;
    if (percentChange > 2.0) {
      direction = 'up';
    } else if (percentChange < -2.0) {
      direction = 'down';
    } else {
      direction = 'stable';
    }

    return _TrendData(
      direction: direction,
      percentChange: percentChange,
    );
  }

  static double _readDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }
}

class DeckHybridMetrics {
  const DeckHybridMetrics({
    required this.currentMastery,
    required this.peakMastery,
    required this.trendDirection,
    required this.trendPercentChange,
    required this.recentAttempts,
  });

  factory DeckHybridMetrics.empty() {
    return const DeckHybridMetrics(
      currentMastery: 0.0,
      peakMastery: 0.0,
      trendDirection: 'stable',
      trendPercentChange: 0.0,
      recentAttempts: [],
    );
  }

  final double currentMastery;
  final double peakMastery;
  final String trendDirection;
  final double trendPercentChange;
  final List<double> recentAttempts;
}

class _TrendData {
  const _TrendData({
    required this.direction,
    required this.percentChange,
  });

  final String direction;
  final double percentChange;
}
