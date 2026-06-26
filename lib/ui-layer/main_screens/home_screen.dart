import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../../main.dart';
import '../../business-layer/services/progress_service.dart';
import 'deck/create_deck_options.dart';
import 'deck/deck_quiz_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN  —  route: /home
// Your Daily Study Hub - personalized command center for quick study actions
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeScaffold();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _HomeScaffold extends StatefulWidget {
  const _HomeScaffold();

  @override
  State<_HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<_HomeScaffold> {
  bool _loading = true;
  String _fullName = '';
  String _username = '';
  ProgressDashboard _dashboard = ProgressDashboard.empty();
  // Live stream — updates automatically whenever _trackDeckStarted() writes to
  // Firestore, even if the quiz screen is open on top of the home screen.
  Stream<List<RecentSession>>? _sessionsStream;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initSessionsStream();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    final dashboard = await ProgressService.loadWeeklyDashboard();

    if (mounted) {
      setState(() {
        _fullName = data['fullName'] as String? ?? '';
        _username = data['username'] as String? ?? '';
        _dashboard = dashboard;
        _loading = false;
      });
    }
  }

  /// Opens a real-time Firestore stream on users/{uid}/recentSessions.
  ///
  /// Shows the 5 most recently played decks, regardless of when they were
  /// last played.  Because it uses .snapshots() the StreamBuilder below
  /// reacts immediately whenever _trackDeckStarted() in QuizScreen writes a
  /// new document — even if the quiz screen is still open on top of this
  /// one.  No route observer or manual refresh needed.
  void _initSessionsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sessionsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recentSessions')
        .orderBy('lastPlayedAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              final ts = d['lastPlayedAt'] as Timestamp?;
              return RecentSession(
                deckId: d['deckId'] as String? ?? doc.id,
                deckTitle: d['deckTitle'] as String? ?? 'Untitled Deck',
                category: d['category'] as String? ?? 'Other',
                lastPlayedAt: ts?.toDate(),
              );
            }).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ───────────────────────────────────────────────
          Positioned(
            top: -60,
            left: -80,
            child: _Blob(
                size: 340,
                color: AppColors.secondaryFixedDim.withOpacity(0.20)),
          ),
          Positioned(
            bottom: 180,
            right: -100,
            child: _Blob(
                size: 300,
                color: AppColors.tertiaryContainer.withOpacity(0.22)),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : _HomeBody(
                    fullName: _fullName,
                    username: _username,
                    dashboard: _dashboard,
                    sessionsStream: _sessionsStream,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.fullName,
    required this.username,
    required this.dashboard,
    required this.sessionsStream,
  });
  final String fullName;
  final String username;
  final ProgressDashboard dashboard;
  final Stream<List<RecentSession>>? sessionsStream;

  String get _firstName {
    if (fullName.trim().isEmpty) return 'there';
    return fullName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Welcome ────────────────────────────────────────────────────
              _WelcomeSection(firstName: _firstName),
              const SizedBox(height: 24),

              // ── Today's Progress ───────────────────────────────────────────
              _TodayProgressCard(dashboard: dashboard),
              const SizedBox(height: 16),

              // ── Create a Deck ──────────────────────────────────────────────
              _SectionHeader(
                title: 'Create a Deck',
                icon: Icons.add_card_rounded,
              ),
              const SizedBox(height: 14),
              const AIImportCard(),
              const SizedBox(height: 12),
              const CreateDeckCard(),
              const SizedBox(height: 28),

              // ── Recent Activity ────────────────────────────────────────────
              _SectionHeader(title: 'Recent Activity'),
              const SizedBox(height: 14),
              // StreamBuilder reacts the instant QuizScreen writes a new
              // recentSessions document — no manual refresh required.
              StreamBuilder<List<RecentSession>>(
                stream: sessionsStream,
                builder: (context, snapshot) {
                  final sessions = snapshot.data ?? [];
                  return _RecentActivityList(recentSessions: sessions);
                },
              ),

              // ── Bottom clearance for nav bar ────────────────────────────────
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WELCOME SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $firstName! 👋',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your personalized study hub awaits',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THIS WEEK'S PROGRESS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TodayProgressCard extends StatelessWidget {
  const _TodayProgressCard({required this.dashboard});
  final ProgressDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryContainer.withOpacity(0.3),
            AppColors.secondaryContainer.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THIS WEEK\'S PROGRESS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (dashboard.hasAttempts)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${(dashboard.overallMastery * 100).round()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.style_rounded,
                  value: '${dashboard.reviewedAnswers}',
                  label: 'Cards',
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.layers_rounded,
                  value: '${dashboard.deckSummaries.length}',
                  label: 'Decks',
                  color: AppColors.secondary,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.quiz_rounded,
                  value: '${dashboard.totalAttempts}',
                  label: 'Sessions',
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS ROW
// ─────────────────────────────────────────────────────────────────────────────

// ignore: unused_element
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_rounded,
            label: 'Create Deck',
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryFixedDim],
            ),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.createDeck),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.explore_rounded,
            label: 'Discover',
            gradient: LinearGradient(
              colors: [
                AppColors.secondary,
                AppColors.secondaryContainer.withOpacity(0.8)
              ],
            ),
            onTap: () =>
                Navigator.of(context).pushReplacementNamed(AppRoutes.discover),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.icon = Icons.history_rounded,
  });
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ACTIVITY LIST
// ─────────────────────────────────────────────────────────────────────────────

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.recentSessions});
  final List<RecentSession> recentSessions;

  @override
  Widget build(BuildContext context) {
    if (recentSessions.isEmpty) {
      return _EmptyActivityCard();
    }

    final shown = recentSessions.take(3).toList();

    return Column(
      children: shown
          .map((session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityCard(session: session),
              ))
          .toList(),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.session});
  final RecentSession session;

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Color _categoryColor(String category) {
    final colors = {
      'Science': AppColors.tertiary,
      'Math': AppColors.primary,
      'Language': AppColors.secondary,
      'History': const Color(0xFFE85D75),
      'Technology': const Color(0xFF9B5DE5),
    };
    return colors[category] ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(session.category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.book_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.deckTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.category} • ${_timeAgo(session.lastPlayedAt)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.quiz,
                arguments: QuizArgs(
                  deckId: session.deckId,
                  deckTitle: session.deckTitle,
                ),
              ),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.play_arrow_rounded, color: color, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete a quiz to see your progress here',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT SESSION MODEL
// Lightweight data class populated from users/{uid}/recentSessions/{deckId}.
// ─────────────────────────────────────────────────────────────────────────────

class RecentSession {
  const RecentSession({
    required this.deckId,
    required this.deckTitle,
    required this.category,
    this.lastPlayedAt,
  });

  final String deckId;
  final String deckTitle;
  final String category;
  final DateTime? lastPlayedAt;
}
