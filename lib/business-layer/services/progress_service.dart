import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizCardAnswer {
  const QuizCardAnswer({
    required this.cardId,
    required this.question,
    required this.correct,
  });

  final String cardId;
  final String question;
  final bool correct;

  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'question': question,
      'correct': correct,
    };
  }
}

class QuizAttemptInput {
  const QuizAttemptInput({
    required this.deckId,
    required this.deckTitle,
    required this.ownerUid,
    required this.category,
    required this.correctCount,
    required this.totalCount,
    required this.answers,
  });

  final String deckId;
  final String deckTitle;
  final String ownerUid;
  final String category;
  final int correctCount;
  final int totalCount;
  final List<QuizCardAnswer> answers;
}

class DeckProgressSummary {
  const DeckProgressSummary({
    required this.deckId,
    required this.ownerUid,
    required this.deckTitle,
    required this.category,
    required this.correctTotal,
    required this.answeredTotal,
    required this.attemptCount,
    required this.mastery,
    required this.lastScore,
    this.lastStudiedAt,
  });

  final String deckId;
  final String ownerUid;
  final String deckTitle;
  final String category;
  final int correctTotal;
  final int answeredTotal;
  final int attemptCount;
  final double mastery;
  final double lastScore;
  final DateTime? lastStudiedAt;
}

class CategoryProgressSummary {
  const CategoryProgressSummary({
    required this.label,
    required this.correctTotal,
    required this.answeredTotal,
    required this.attemptCount,
    required this.deckCount,
  });

  final String label;
  final int correctTotal;
  final int answeredTotal;
  final int attemptCount;
  final int deckCount;

  double get mastery => answeredTotal == 0 ? 0.0 : correctTotal / answeredTotal;
}

class WeakSpotSummary {
  const WeakSpotSummary({
    required this.question,
    required this.category,
    required this.deckTitle,
    required this.missCount,
  });

  final String question;
  final String category;
  final String deckTitle;
  final int missCount;
}

class ForgottenCardSummary {
  const ForgottenCardSummary({
    required this.question,
    required this.category,
    required this.deckTitle,
    required this.failureCount,
    required this.lastFailedAt,
  });

  final String question;
  final String category;
  final String deckTitle;
  final int failureCount;
  final DateTime? lastFailedAt;
}

class ProgressDashboard {
  const ProgressDashboard({
    required this.overallMastery,
    required this.correctAnswers,
    required this.reviewedAnswers,
    required this.totalAttempts,
    required this.currentStreakDays,
    required this.personalBestStreakDays,
    required this.categories,
    required this.deckSummaries,
    required this.weakSpots,
    required this.forgottenCards,
  });

  factory ProgressDashboard.empty() {
    return const ProgressDashboard(
      overallMastery: 0.0,
      correctAnswers: 0,
      reviewedAnswers: 0,
      totalAttempts: 0,
      currentStreakDays: 0,
      personalBestStreakDays: 0,
      categories: [],
      deckSummaries: [],
      weakSpots: [],
      forgottenCards: [],
    );
  }

  final double overallMastery;
  final int correctAnswers;
  final int reviewedAnswers;
  final int totalAttempts;
  final int currentStreakDays;
  final int personalBestStreakDays;
  final List<CategoryProgressSummary> categories;
  final List<DeckProgressSummary> deckSummaries;
  final List<WeakSpotSummary> weakSpots;
  final List<ForgottenCardSummary> forgottenCards;

  bool get hasAttempts => totalAttempts > 0;
}

abstract final class ProgressService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> saveQuizAttempt(QuizAttemptInput input) async {
    final uid = _uid;
    
    print('\n📦 [ProgressService] saveQuizAttempt called');
    print('   uid: $uid');
    print('   input.deckId: ${input.deckId}');
    print('   input.ownerUid: ${input.ownerUid}');
    print('   input.category: ${input.category}');
    print('   input.totalCount: ${input.totalCount}');
    
    if (uid == null || input.deckId.trim().isEmpty || input.totalCount <= 0) {
      print('❌ [ProgressService] Validation failed - early return');
      return;
    }

    final ownerUid =
        input.ownerUid.trim().isEmpty ? uid : input.ownerUid.trim();
    final deckId = input.deckId.trim();
    final deckTitle = _cleanLabel(input.deckTitle, 'Untitled Deck');
    final category = _cleanLabel(input.category, 'Other');
    final totalCount = input.totalCount;
    final correctCount = input.correctCount.clamp(0, totalCount).toInt();
    final score = correctCount / totalCount;
    final now = DateTime.now();
    final dayKey = _formatDayKey(now);
    
    print('   Processed values:');
    print('     ownerUid: $ownerUid');
    print('     deckId: $deckId');
    print('     category: $category');
    print('     score: $score');
    print('     dayKey: $dayKey');

    final userRef = _db.collection('users').doc(uid);
    final attemptRef = userRef.collection('quizAttempts').doc();
    final progressRef =
        userRef.collection('deckProgress').doc('${ownerUid}__$deckId');
    final ownDeckRef = userRef.collection('decks').doc(deckId);
    final missedCards =
        input.answers.where((answer) => !answer.correct).map((answer) {
      return {
        'cardId': answer.cardId,
        'question': answer.question,
        'category': category,
        'deckId': deckId,
        'deckTitle': deckTitle,
      };
    }).toList();
    
    print('   missedCards count: ${missedCards.length}');
    print('   Firestore paths:');
    print('     attemptRef: users/$uid/quizAttempts/${attemptRef.id}');
    print('     progressRef: users/$uid/deckProgress/${ownerUid}__$deckId');
    print('     ownDeckRef: users/$uid/decks/$deckId');

    try {
      print('📤 [ProgressService] Starting Firestore transaction...');
      await _db.runTransaction((transaction) async {
        final progressSnap = await transaction.get(progressRef);
        final existing = progressSnap.data();
        
        // Get previous best score
        final previousBestScore = _readDouble(existing?['bestScore']);
        final previousAttempts = _readInt(existing?['attemptCount']);
        final nextAttempts = previousAttempts + 1;
        
        // Determine if this is the new best score
        final isNewBest = score > previousBestScore;
        final bestScore = isNewBest ? score : previousBestScore;
        final bestCorrectCount = isNewBest ? correctCount : _readInt(existing?['bestCorrectCount']);
        final bestTotalCount = isNewBest ? totalCount : _readInt(existing?['bestTotalCount']);
        final mastery = bestTotalCount == 0 ? 0.0 : bestCorrectCount / bestTotalCount;
        
        print('   Transaction data:');
        print('     previousBestScore: $previousBestScore');
        print('     currentScore: $score');
        print('     isNewBest: $isNewBest');
        print('     bestScore: $bestScore');
        print('     mastery: $mastery');
        print('     attemptCount: $previousAttempts -> $nextAttempts');

        // Save the quiz attempt with session number
        transaction.set(attemptRef, {
          'deckId': deckId,
          'ownerUid': ownerUid,
          'deckTitle': deckTitle,
          'category': category,
          'correctCount': correctCount,
          'totalCount': totalCount,
          'score': score,
          'sessionNumber': nextAttempts,
          'isBestSession': isNewBest,
          'answers': input.answers.map((answer) => answer.toMap()).toList(),
          'missedCards': missedCards,
          'localDayKey': dayKey,
          'clientCreatedAt': Timestamp.fromDate(now),
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('   ✅ Set quizAttempts document');

        // Update deck progress with best score only
        transaction.set(
          progressRef,
          {
            if (!progressSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
            'deckId': deckId,
            'ownerUid': ownerUid,
            'deckTitle': deckTitle,
            'category': category,
            'bestScore': bestScore,
            'bestCorrectCount': bestCorrectCount,
            'bestTotalCount': bestTotalCount,
            'mastery': mastery,
            'attemptCount': nextAttempts,
            'lastScore': score,
            'lastCorrectCount': correctCount,
            'lastTotalCount': totalCount,
            'lastStudiedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        print('   ✅ Set deckProgress document');

        if (ownerUid == uid) {
          transaction.set(
            ownDeckRef,
            {
              'progress': mastery,
              'quizAttemptCount': nextAttempts,
              'bestScore': bestScore,
              'lastQuizScore': score,
              'lastStudiedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          print('   ✅ Set deck document (own deck)');
        } else {
          print('   ⏭️ Skipped deck document update (not owner)');
        }
      });
      print('✅ [ProgressService] Transaction completed successfully!\n');
    } catch (e, st) {
      print('❌ [ProgressService] Transaction failed: $e');
      print('Stack trace: $st\n');
      rethrow;
    }
  }

  static Future<ProgressDashboard> loadDashboard(
      {int attemptLimit = 250}) async {
    final uid = _uid;
    if (uid == null) return ProgressDashboard.empty();

    final userRef = _db.collection('users').doc(uid);
    final results = await Future.wait([
      userRef.collection('deckProgress').get(),
      userRef
          .collection('quizAttempts')
          .orderBy('createdAt', descending: true)
          .limit(attemptLimit)
          .get(),
    ]);

    final deckProgressSnap = results[0];
    final attemptsSnap = results[1];

    var deckSummaries = deckProgressSnap.docs
        .map((doc) => _deckSummaryFromMap(doc.data()))
        .where((summary) => summary.answeredTotal > 0)
        .toList();

    if (deckSummaries.isEmpty && attemptsSnap.docs.isNotEmpty) {
      deckSummaries = _deckSummariesFromAttempts(attemptsSnap.docs);
    }

    deckSummaries.sort((a, b) {
      final aDate = a.lastStudiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.lastStudiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    final correctAnswers =
        deckSummaries.fold<int>(0, (total, item) => total + item.correctTotal);
    final reviewedAnswers =
        deckSummaries.fold<int>(0, (total, item) => total + item.answeredTotal);
    final totalAttempts =
        deckSummaries.fold<int>(0, (total, item) => total + item.attemptCount);
    final overallMastery =
        reviewedAnswers == 0 ? 0.0 : correctAnswers / reviewedAnswers;

    final dayKeys = attemptsSnap.docs
        .map((doc) => _dayKeyFromAttempt(doc.data()))
        .whereType<String>()
        .toSet();

    return ProgressDashboard(
      overallMastery: overallMastery,
      correctAnswers: correctAnswers,
      reviewedAnswers: reviewedAnswers,
      totalAttempts: totalAttempts,
      currentStreakDays: _currentStreak(dayKeys),
      personalBestStreakDays: _personalBestStreak(dayKeys),
      categories: _categorySummaries(deckSummaries),
      deckSummaries: deckSummaries,
      weakSpots: _weakSpotsFromAttempts(attemptsSnap.docs),
      forgottenCards: _forgottenCardsFromAttempts(attemptsSnap.docs),
    );
  }

  static DeckProgressSummary _deckSummaryFromMap(Map<String, dynamic> data) {
    final bestCorrectCount = _readInt(data['bestCorrectCount']);
    final bestTotalCount = _readInt(data['bestTotalCount']);
    final mastery = bestTotalCount == 0
        ? _readDouble(data['mastery'])
        : bestCorrectCount / bestTotalCount;

    return DeckProgressSummary(
      deckId: data['deckId'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      deckTitle: _cleanLabel(data['deckTitle'] as String?, 'Untitled Deck'),
      category: _cleanLabel(data['category'] as String?, 'Other'),
      correctTotal: bestCorrectCount,
      answeredTotal: bestTotalCount,
      attemptCount: _readInt(data['attemptCount']),
      mastery: mastery,
      lastScore: _readDouble(data['lastScore']),
      lastStudiedAt: _readDate(data['lastStudiedAt']),
    );
  }

  static List<DeckProgressSummary> _deckSummariesFromAttempts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final buckets = <String, _DeckProgressBucket>{};

    for (final doc in docs) {
      final data = doc.data();
      final ownerUid = data['ownerUid'] as String? ?? '';
      final deckId = data['deckId'] as String? ?? '';
      if (deckId.isEmpty) continue;

      final key = '${ownerUid}__$deckId';
      final bucket = buckets.putIfAbsent(
        key,
        () => _DeckProgressBucket(
          deckId: deckId,
          ownerUid: ownerUid,
          deckTitle: _cleanLabel(data['deckTitle'] as String?, 'Untitled Deck'),
          category: _cleanLabel(data['category'] as String?, 'Other'),
        ),
      );

      bucket.correctTotal += _readInt(data['correctCount']);
      bucket.answeredTotal += _readInt(data['totalCount']);
      bucket.attemptCount += 1;
      final attemptDate =
          _readDate(data['createdAt']) ?? _readDate(data['clientCreatedAt']);
      if (attemptDate != null &&
          (bucket.lastStudiedAt == null ||
              attemptDate.isAfter(bucket.lastStudiedAt!))) {
        bucket.lastStudiedAt = attemptDate;
        bucket.lastScore = _readDouble(data['score']);
      }
    }

    return buckets.values.map((bucket) => bucket.toSummary()).toList();
  }

  static List<CategoryProgressSummary> _categorySummaries(
    List<DeckProgressSummary> decks,
  ) {
    final buckets = <String, _CategoryProgressBucket>{};

    for (final deck in decks) {
      final bucket = buckets.putIfAbsent(
        deck.category,
        () => _CategoryProgressBucket(label: deck.category),
      );
      bucket.correctTotal += deck.correctTotal;
      bucket.answeredTotal += deck.answeredTotal;
      bucket.attemptCount += deck.attemptCount;
      bucket.deckCount += 1;
    }

    final summaries =
        buckets.values.map((bucket) => bucket.toSummary()).toList();
    summaries.sort((a, b) => b.answeredTotal.compareTo(a.answeredTotal));
    return summaries;
  }

  static List<WeakSpotSummary> _weakSpotsFromAttempts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final buckets = <String, _WeakSpotBucket>{};

    for (final doc in docs) {
      final data = doc.data();
      final deckId = data['deckId'] as String? ?? '';
      final missedCards = data['missedCards'];
      if (missedCards is! List) continue;

      for (final item in missedCards) {
        if (item is! Map) continue;
        final question = _cleanLabel(item['question']?.toString(), 'Untitled');
        final cardId = item['cardId']?.toString() ?? question;
        final key = '${deckId}__$cardId';
        final bucket = buckets.putIfAbsent(
          key,
          () => _WeakSpotBucket(
            question: question,
            category: _cleanLabel(item['category']?.toString(), 'Other'),
            deckTitle:
                _cleanLabel(item['deckTitle']?.toString(), 'Untitled Deck'),
          ),
        );
        bucket.missCount += 1;
      }
    }

    final spots = buckets.values.map((bucket) => bucket.toSummary()).toList();
    spots.sort((a, b) => b.missCount.compareTo(a.missCount));
    return spots.take(5).toList();
  }

  static List<ForgottenCardSummary> _forgottenCardsFromAttempts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // Group attempts by deck
    final deckAttempts = <String, List<Map<String, dynamic>>>{};
    
    for (final doc in docs) {
      final data = doc.data();
      final deckId = data['deckId'] as String? ?? '';
      final ownerUid = data['ownerUid'] as String? ?? '';
      if (deckId.isEmpty) continue;
      
      final key = '${ownerUid}__$deckId';
      deckAttempts.putIfAbsent(key, () => []).add(data);
    }
    
    final forgottenBuckets = <String, _ForgottenCardBucket>{};
    
    // Process each deck's attempts
    for (final attempts in deckAttempts.values) {
      if (attempts.isEmpty) continue;
      
      // Sort by session number (newest first)
      attempts.sort((a, b) {
        final aSession = _readInt(a['sessionNumber']);
        final bSession = _readInt(b['sessionNumber']);
        return bSession.compareTo(aSession);
      });
      
      // Find the best session
      Map<String, dynamic>? bestSession;
      for (final attempt in attempts) {
        if (attempt['isBestSession'] == true) {
          bestSession = attempt;
          break;
        }
      }
      
      if (bestSession == null) continue;
      
      // Get cards that were correct in best session
      final bestAnswers = bestSession['answers'];
      if (bestAnswers is! List) continue;
      
      final correctInBest = <String, Map<String, dynamic>>{};
      for (final answer in bestAnswers) {
        if (answer is! Map) continue;
        if (answer['correct'] == true) {
          final cardId = answer['cardId']?.toString() ?? '';
          if (cardId.isNotEmpty) {
            correctInBest[cardId] = Map<String, dynamic>.from(answer);
          }
        }
      }
      
      // Track failures in subsequent sessions
      final cardFailures = <String, int>{};
      DateTime? lastFailedAt;
      
      for (final attempt in attempts) {
        // Skip the best session itself
        if (attempt == bestSession) continue;
        
        final answers = attempt['answers'];
        if (answers is! List) continue;
        
        for (final answer in answers) {
          if (answer is! Map) continue;
          final cardId = answer['cardId']?.toString() ?? '';
          
          // Check if this card was correct in best session but wrong now
          if (correctInBest.containsKey(cardId) && answer['correct'] == false) {
            cardFailures[cardId] = (cardFailures[cardId] ?? 0) + 1;
            
            // Track most recent failure
            final attemptDate = _readDate(attempt['createdAt']) ?? 
                               _readDate(attempt['clientCreatedAt']);
            if (attemptDate != null) {
              if (lastFailedAt == null || attemptDate.isAfter(lastFailedAt)) {
                lastFailedAt = attemptDate;
              }
            }
          }
        }
      }
      
      // Add cards with 2+ failures to forgotten list
      for (final entry in cardFailures.entries) {
        if (entry.value >= 2) {
          final cardId = entry.key;
          final originalAnswer = correctInBest[cardId];
          if (originalAnswer == null) continue;
          
          final deckId = bestSession['deckId'] as String? ?? '';
          final key = '${deckId}__$cardId';
          
          forgottenBuckets[key] = _ForgottenCardBucket(
            question: _cleanLabel(originalAnswer['question']?.toString(), 'Untitled'),
            category: _cleanLabel(bestSession['category']?.toString(), 'Other'),
            deckTitle: _cleanLabel(bestSession['deckTitle']?.toString(), 'Untitled Deck'),
            failureCount: entry.value,
            lastFailedAt: lastFailedAt,
          );
        }
      }
    }
    
    final forgotten = forgottenBuckets.values.map((b) => b.toSummary()).toList();
    forgotten.sort((a, b) => b.failureCount.compareTo(a.failureCount));
    return forgotten.take(5).toList();
  }

  static String? _dayKeyFromAttempt(Map<String, dynamic> data) {
    final stored = data['localDayKey'];
    if (stored is String && stored.isNotEmpty) return stored;

    final date =
        _readDate(data['createdAt']) ?? _readDate(data['clientCreatedAt']);
    return date == null ? null : _formatDayKey(date);
  }

  static int _currentStreak(Set<String> dayKeys) {
    if (dayKeys.isEmpty) return 0;

    var cursor = _dateOnly(DateTime.now());
    if (!dayKeys.contains(_formatDayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!dayKeys.contains(_formatDayKey(cursor))) return 0;
    }

    var streak = 0;
    while (dayKeys.contains(_formatDayKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int _personalBestStreak(Set<String> dayKeys) {
    if (dayKeys.isEmpty) return 0;

    final days = dayKeys.map(DateTime.parse).map(_dateOnly).toList()..sort();
    var best = 1;
    var current = 1;

    for (var i = 1; i < days.length; i++) {
      final difference = days[i].difference(days[i - 1]).inDays;
      if (difference == 1) {
        current += 1;
      } else if (difference > 1) {
        current = 1;
      }
      if (current > best) best = current;
    }

    return best;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _formatDayKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String _cleanLabel(String? value, String fallback) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? fallback : cleaned;
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static double _readDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class _DeckProgressBucket {
  _DeckProgressBucket({
    required this.deckId,
    required this.ownerUid,
    required this.deckTitle,
    required this.category,
  });

  final String deckId;
  final String ownerUid;
  final String deckTitle;
  final String category;
  int correctTotal = 0;
  int answeredTotal = 0;
  int attemptCount = 0;
  double lastScore = 0.0;
  DateTime? lastStudiedAt;

  DeckProgressSummary toSummary() {
    return DeckProgressSummary(
      deckId: deckId,
      ownerUid: ownerUid,
      deckTitle: deckTitle,
      category: category,
      correctTotal: correctTotal,
      answeredTotal: answeredTotal,
      attemptCount: attemptCount,
      mastery: answeredTotal == 0 ? 0.0 : correctTotal / answeredTotal,
      lastScore: lastScore,
      lastStudiedAt: lastStudiedAt,
    );
  }
}

class _CategoryProgressBucket {
  _CategoryProgressBucket({required this.label});

  final String label;
  int correctTotal = 0;
  int answeredTotal = 0;
  int attemptCount = 0;
  int deckCount = 0;

  CategoryProgressSummary toSummary() {
    return CategoryProgressSummary(
      label: label,
      correctTotal: correctTotal,
      answeredTotal: answeredTotal,
      attemptCount: attemptCount,
      deckCount: deckCount,
    );
  }
}

class _WeakSpotBucket {
  _WeakSpotBucket({
    required this.question,
    required this.category,
    required this.deckTitle,
  });

  final String question;
  final String category;
  final String deckTitle;
  int missCount = 0;

  WeakSpotSummary toSummary() {
    return WeakSpotSummary(
      question: question,
      category: category,
      deckTitle: deckTitle,
      missCount: missCount,
    );
  }
}

class _ForgottenCardBucket {
  _ForgottenCardBucket({
    required this.question,
    required this.category,
    required this.deckTitle,
    required this.failureCount,
    required this.lastFailedAt,
  });

  final String question;
  final String category;
  final String deckTitle;
  final int failureCount;
  final DateTime? lastFailedAt;

  ForgottenCardSummary toSummary() {
    return ForgottenCardSummary(
      question: question,
      category: category,
      deckTitle: deckTitle,
      failureCount: failureCount,
      lastFailedAt: lastFailedAt,
    );
  }
}
