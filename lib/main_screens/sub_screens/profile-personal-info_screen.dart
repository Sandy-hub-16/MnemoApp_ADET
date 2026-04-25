import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';

// ── Email censor ──────────────────────────────────────────────────────────────
// Reveals first 2 characters, masks the rest of the local part, keeps domain.
// e.g.  alexkindred@study.com  →  al***@study.com
String _censorEmail(String email) {
  final atIndex = email.indexOf('@');
  if (atIndex < 0) return email;
  final local = email.substring(0, atIndex);
  final domain = email.substring(atIndex);
  final visible = local.length >= 2 ? local.substring(0, 2) : local;
  return '$visible***$domain';
}

// ── 7-day lock helper ─────────────────────────────────────────────────────────
bool _isWithin7Days(Timestamp? ts) {
  if (ts == null) return false;
  final diff = DateTime.now().difference(ts.toDate());
  return diff.inDays < 7;
}

/// Returns how many days remain in the 7-day cooldown, e.g. "5 days".
String _daysRemaining(Timestamp? ts) {
  if (ts == null) return '';
  final diff = DateTime.now().difference(ts.toDate());
  final remaining = 7 - diff.inDays;
  return remaining == 1 ? '1 day' : '$remaining days';
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsScaffold();
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 140,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          const SafeArea(
            bottom: false,
            child: _SettingsBody(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS BODY — stateful, owns all controllers + dirty tracking
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _bioCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();

  // ── Original values (for dirty checking) ──────────────────────────────────
  String _origBio = '';
  String _origUsername = '';
  String _origSchool = '';
  String _origCourse = '';
  String _origYearLevel = '';

  // ── State ──────────────────────────────────────────────────────────────────
  String _fullName = '';
  String _email = '';
  String? _photoUrl;
  String? _region; // null = not set yet (one-time)
  String? _birthdate; // null = not set yet (one-time)
  String _yearLevel = '1st Year';

  // ── Lock timestamps ────────────────────────────────────────────────────────
  Timestamp? _createdAt;
  Timestamp? _usernameLastChangedAt; // null → use createdAt for username lock
  Timestamp? _educationLastChangedAt;

  bool _loading = true;
  bool _saving = false;
  bool _isDirty = false;

  // ── Computed locks ─────────────────────────────────────────────────────────
  bool get _usernameIsLocked {
    // Lock against the most recent of: account creation OR last username change
    final ts = _usernameLastChangedAt ?? _createdAt;
    return _isWithin7Days(ts);
  }

  bool get _educationIsLocked => _isWithin7Days(_educationLastChangedAt);
  bool get _regionIsLocked => _region != null && _region!.isNotEmpty;
  bool get _birthdateIsLocked => _birthdate != null && _birthdate!.isNotEmpty;

  static const _regions = [
    'NCR (National Capital Region)',
    'CAR (Cordillera Administrative Region)',
    'Region I — Ilocos Region',
    'Region II — Cagayan Valley',
    'Region III — Central Luzon',
    'Region IV-A — CALABARZON',
    'Region IV-B — MIMAROPA',
    'Region V — Bicol Region',
    'Region VI — Western Visayas',
    'Region VII — Central Visayas',
    'Region VIII — Eastern Visayas',
    'Region IX — Zamboanga Peninsula',
    'Region X — Northern Mindanao',
    'Region XI — Davao Region',
    'Region XII — SOCCSKSARGEN',
    'Region XIII — Caraga',
    'BARMM (Bangsamoro Autonomous Region)',
  ];

  static const _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
  ];

  // ── Dirty tracking ─────────────────────────────────────────────────────────
  void _checkDirty() {
    final dirty = _bioCtrl.text != _origBio ||
        _usernameCtrl.text != _origUsername ||
        _schoolCtrl.text != _origSchool ||
        _courseCtrl.text != _origCourse ||
        _yearLevel != _origYearLevel;
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  @override
  void initState() {
    super.initState();
    _bioCtrl.addListener(_checkDirty);
    _usernameCtrl.addListener(_checkDirty);
    _schoolCtrl.addListener(_checkDirty);
    _courseCtrl.addListener(_checkDirty);
    _loadProfile();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _usernameCtrl.dispose();
    _schoolCtrl.dispose();
    _courseCtrl.dispose();
    super.dispose();
  }

  // ── Load from Firestore ────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      setState(() => _loading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .get();

    final data = doc.data() ?? {};

    if (mounted) {
      setState(() {
        _fullName = data['fullName'] as String? ?? '';
        _email = authUser.email ?? data['email'] as String? ?? '';
        _photoUrl = authUser.photoURL ?? data['photoUrl'] as String?;

        final username = data['username'] as String? ?? '';
        _usernameCtrl.text = username;
        _origUsername = username;

        final bio = data['bio'] as String? ?? '';
        _bioCtrl.text = bio;
        _origBio = bio;

        final school = data['school'] as String? ?? '';
        _schoolCtrl.text = school;
        _origSchool = school;

        final course = data['course'] as String? ?? '';
        _courseCtrl.text = course;
        _origCourse = course;

        final yl = data['yearLevel'] as String? ?? '1st Year';
        _yearLevel = _yearOptions.contains(yl) ? yl : '1st Year';
        _origYearLevel = _yearLevel;

        _region = data['region'] as String?;
        _birthdate = data['birthdate'] as String?;

        _createdAt = data['createdAt'] as Timestamp?;
        _usernameLastChangedAt = data['usernameLastChangedAt'] as Timestamp?;
        _educationLastChangedAt = data['educationLastChangedAt'] as Timestamp?;

        _isDirty = false;
        _loading = false;
      });
    }
  }

  // ── Save to Firestore ──────────────────────────────────────────────────────
  Future<void> _onSaveTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _SaveConfirmDialog(),
    );
    if (confirmed != true) return;
    await _saveChanges();
  }

  Future<void> _saveChanges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final updates = <String, dynamic>{
        'bio': _bioCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Username — only write if editable and changed
      if (!_usernameIsLocked && _usernameCtrl.text.trim() != _origUsername) {
        updates['username'] = _usernameCtrl.text.trim();
        updates['usernameLastChangedAt'] = FieldValue.serverTimestamp();
      }

      // Education — only write if editable and changed
      final eduChanged = _schoolCtrl.text.trim() != _origSchool ||
          _courseCtrl.text.trim() != _origCourse ||
          _yearLevel != _origYearLevel;
      if (!_educationIsLocked && eduChanged) {
        updates['school'] = _schoolCtrl.text.trim();
        updates['course'] = _courseCtrl.text.trim();
        updates['yearLevel'] = _yearLevel;
        updates['educationLastChangedAt'] = FieldValue.serverTimestamp();
      }

      // Region & birthdate — one-time writes (only if not already set)
      if (!_regionIsLocked && _region != null && _region!.isNotEmpty) {
        updates['region'] = _region;
      }
      if (!_birthdateIsLocked && _birthdate != null && _birthdate!.isNotEmpty) {
        updates['birthdate'] = _birthdate;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);

      _showSnack('Changes saved ✓');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showSnack('Could not save changes. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Date picker for birthdate ──────────────────────────────────────────────
  Future<void> _pickBirthdate() async {
    if (_birthdateIsLocked) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 10),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surfaceContainerLowest,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final formatted =
        '${_monthName(picked.month)} ${picked.day}, ${picked.year}';
    setState(() {
      _birthdate = formatted;
      _isDirty = true;
    });
  }

  String _monthName(int m) => const [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][m];

  // ── Snack helper ───────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white)),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar ───────────────────────────────────────────────────────
        _TopBar(
          isDirty: _isDirty,
          saving: _saving,
          onBack: () => Navigator.of(context).pop(),
          onSave: _onSaveTap,
        ),

        // ── Edit indicator stripe ─────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isDirty ? 3 : 0,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryFixedDim],
            ),
          ),
        ),

        if (_loading)
          const Expanded(
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                children: [
                  // ── Avatar ──────────────────────────────────────────────
                  _AvatarSection(
                    photoUrl: _photoUrl,
                    fullName: _fullName,
                  ),
                  const SizedBox(height: 28),

                  // ── Personal Info card ──────────────────────────────────
                  _SectionCard(
                    label: 'Personal Information',
                    children: [
                      // Email — read-only, censored
                      _ReadOnlyTile(
                        label: 'Email Address',
                        value: _censorEmail(_email),
                        icon: Icons.mail_outline_rounded,
                        lockReason: 'Cannot be changed',
                      ),
                      const SizedBox(height: 14),

                      // Full name — read-only
                      _ReadOnlyTile(
                        label: 'Full Name',
                        value: _fullName,
                        icon: Icons.person_outline_rounded,
                        lockReason: 'Set at registration',
                      ),
                      const SizedBox(height: 14),

                      // Username — 7-day lock
                      _EditableOrLockedField(
                        label: 'Username',
                        controller: _usernameCtrl,
                        icon: Icons.alternate_email_rounded,
                        isLocked: _usernameIsLocked,
                        lockSubtitle: _usernameIsLocked
                            ? 'Editable again in '
                                '${_daysRemaining(_usernameLastChangedAt ?? _createdAt)}'
                            : null,
                        hint: 'your_username',
                        prefix: '@',
                      ),
                      const SizedBox(height: 14),

                      // Bio — always editable
                      _FieldLabel('About Me'),
                      const SizedBox(height: 8),
                      _BioTextArea(controller: _bioCtrl),
                      const SizedBox(height: 14),

                      // Birthdate — one-time
                      _OneTimeDateTile(
                        label: 'Date of Birth',
                        value: _birthdate,
                        isLocked: _birthdateIsLocked,
                        placeholder: 'Add Date of Birth',
                        icon: Icons.cake_outlined,
                        onTap: _birthdateIsLocked ? null : _pickBirthdate,
                      ),
                      const SizedBox(height: 14),

                      // Region — one-time dropdown
                      _OneTimeDropdownTile(
                        label: 'Region',
                        value: _region,
                        isLocked: _regionIsLocked,
                        placeholder: 'Add Region',
                        icon: Icons.location_on_outlined,
                        options: _regions,
                        onChanged: _regionIsLocked
                            ? null
                            : (v) => setState(() {
                                  _region = v;
                                  _isDirty = true;
                                }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Educational Background card ─────────────────────────
                  _SectionCard(
                    label: 'Educational Background',
                    trailing: _educationIsLocked
                        ? _LockBadge('Editable in '
                            '${_daysRemaining(_educationLastChangedAt)}')
                        : null,
                    children: [
                      _LockedOrEditableTextField(
                        label: 'School / University',
                        controller: _schoolCtrl,
                        icon: Icons.school_outlined,
                        isLocked: _educationIsLocked,
                        hint: 'e.g. University of the Philippines',
                      ),
                      const SizedBox(height: 14),
                      _LockedOrEditableTextField(
                        label: 'Course / Program',
                        controller: _courseCtrl,
                        icon: Icons.menu_book_outlined,
                        isLocked: _educationIsLocked,
                        hint: 'e.g. BS Computer Science',
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Year Level'),
                      const SizedBox(height: 8),
                      _educationIsLocked
                          ? _ReadOnlyTile(
                              label: '',
                              value: _yearLevel,
                              icon: Icons.stairs_outlined,
                              lockReason: '',
                              compact: true,
                            )
                          : _YearDropdown(
                              value: _yearLevel,
                              options: _yearOptions,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _yearLevel = v);
                                  _checkDirty();
                                }
                              },
                            ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Bottom save button (visible only when dirty) ─────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _isDirty
                        ? _saving
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 3,
                                ),
                              )
                            : _BottomSaveButton(onTap: _onSaveTap)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDirty,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  final bool isDirty;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.80),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.primary, size: 22),
            ),
          ),

          // Title
          Expanded(
            child: Center(
              child: Text(
                'Personal Information',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),

          // Save button — only when dirty
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: isDirty
                ? GestureDetector(
                    key: const ValueKey('save'),
                    onTap: saving ? null : onSave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryFixedDim
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), width: 40),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR SECTION  — display only; photo editing is handled in ProfileScreen.
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.photoUrl, required this.fullName});

  final String? photoUrl;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.25),
            AppColors.primaryContainer.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: CircleAvatar(
        radius: 56,
        backgroundColor: AppColors.surfaceContainerLowest,
        backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
            ? NetworkImage(photoUrl!)
            : null,
        child: (photoUrl == null || photoUrl!.isEmpty)
            ? (fullName.isNotEmpty
                ? Text(
                    fullName[0].toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: AppColors.primary.withOpacity(0.5),
                  ))
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.label,
    required this.children,
    this.trailing,
  });

  final String label;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.outline,
                    letterSpacing: 1.2,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Divider(
              height: 1,
              color: AppColors.outlineVariant.withOpacity(0.3),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.outline,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ-ONLY TILE  (email, full name, locked fields)
// ─────────────────────────────────────────────────────────────────────────────

class _ReadOnlyTile extends StatelessWidget {
  const _ReadOnlyTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.lockReason,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String lockReason;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _FieldLabel(label),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withOpacity(0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.outline.withOpacity(0.6), size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : '—',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.outline,
                  ),
                ),
              ),
              if (lockReason.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.outline.withOpacity(0.35), size: 14),
                  ],
                ),
            ],
          ),
        ),
        if (lockReason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              lockReason,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.outline.withOpacity(0.55)),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITABLE OR LOCKED FIELD  (username — 7-day lock)
// ─────────────────────────────────────────────────────────────────────────────

class _EditableOrLockedField extends StatelessWidget {
  const _EditableOrLockedField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isLocked,
    required this.hint,
    this.lockSubtitle,
    this.prefix,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isLocked;
  final String? lockSubtitle;
  final String hint;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        isLocked
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: AppColors.outline.withOpacity(0.6), size: 19),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prefix != null
                            ? '$prefix${controller.text}'
                            : controller.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.outline,
                        ),
                      ),
                    ),
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.outline.withOpacity(0.35), size: 14),
                  ],
                ),
              )
            : _EditableField(
                controller: controller,
                icon: icon,
                hint: hint,
                prefix: prefix,
              ),
        if (lockSubtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 12, color: AppColors.outline.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  lockSubtitle!,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.outline.withOpacity(0.55)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCKED OR EDITABLE TEXT FIELD  (education — 7-day lock)
// ─────────────────────────────────────────────────────────────────────────────

class _LockedOrEditableTextField extends StatelessWidget {
  const _LockedOrEditableTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isLocked,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isLocked;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        isLocked
            ? _ReadOnlyTile(
                label: '',
                value: controller.text,
                icon: icon,
                lockReason: '',
                compact: true,
              )
            : _EditableField(
                controller: controller,
                icon: icon,
                hint: hint,
              ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITABLE FIELD  (shared styled TextField)
// ─────────────────────────────────────────────────────────────────────────────

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.prefix,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: AppColors.outline.withOpacity(0.45)),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 19),
        prefixText: prefix,
        prefixStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide:
              BorderSide(color: AppColors.primary.withOpacity(0.4), width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BIO TEXT AREA
// ─────────────────────────────────────────────────────────────────────────────

class _BioTextArea extends StatelessWidget {
  const _BioTextArea({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      maxLength: 200,
      style:
          GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Tell us about your learning journey…',
        hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: AppColors.outline.withOpacity(0.45)),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.all(18),
        counterStyle: GoogleFonts.plusJakartaSans(
            fontSize: 11, color: AppColors.outline.withOpacity(0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AppColors.primary.withOpacity(0.4), width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONE-TIME DATE TILE  (birthdate — set once, then locked)
// ─────────────────────────────────────────────────────────────────────────────

class _OneTimeDateTile extends StatelessWidget {
  const _OneTimeDateTile({
    required this.label,
    required this.value,
    required this.isLocked,
    required this.placeholder,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String? value;
  final bool isLocked;
  final String placeholder;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isLocked ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isLocked
                  ? AppColors.surfaceContainerLow.withOpacity(0.7)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: !isLocked && !hasValue
                  ? Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: hasValue
                      ? (isLocked
                          ? AppColors.outline.withOpacity(0.6)
                          : AppColors.primary)
                      : AppColors.primary.withOpacity(0.7),
                  size: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue
                          ? (isLocked ? AppColors.outline : AppColors.onSurface)
                          : AppColors.primary.withOpacity(0.7),
                    ),
                  ),
                ),
                if (isLocked)
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.outline.withOpacity(0.35), size: 14)
                else
                  Icon(Icons.edit_calendar_outlined,
                      color: AppColors.primary.withOpacity(0.6), size: 17),
              ],
            ),
          ),
        ),
        if (isLocked) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              'Cannot be changed after being set',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.outline.withOpacity(0.55)),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONE-TIME DROPDOWN TILE  (region — set once, then locked)
// ─────────────────────────────────────────────────────────────────────────────

class _OneTimeDropdownTile extends StatelessWidget {
  const _OneTimeDropdownTile({
    required this.label,
    required this.value,
    required this.isLocked,
    required this.placeholder,
    required this.icon,
    required this.options,
    this.onChanged,
  });

  final String label;
  final String? value;
  final bool isLocked;
  final String placeholder;
  final IconData icon;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        isLocked
            // Locked — static display
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: AppColors.outline.withOpacity(0.6), size: 19),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.outline,
                        ),
                      ),
                    ),
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.outline.withOpacity(0.35), size: 14),
                  ],
                ),
              )
            // Editable — dropdown
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  border: !hasValue
                      ? Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignInside,
                        )
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: hasValue ? value : null,
                    isExpanded: true,
                    hint: Row(
                      children: [
                        Icon(icon,
                            color: AppColors.primary.withOpacity(0.7),
                            size: 19),
                        const SizedBox(width: 12),
                        Text(
                          placeholder,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.outline, size: 22),
                    dropdownColor: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                    selectedItemBuilder: (_) => options
                        .map(
                          (o) => Row(
                            children: [
                              Icon(icon, color: AppColors.primary, size: 19),
                              const SizedBox(width: 12),
                              Expanded(child: Text(o)),
                            ],
                          ),
                        )
                        .toList(),
                    items: options
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
        if (isLocked) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              'Cannot be changed after being set',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.outline.withOpacity(0.55)),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YEAR LEVEL DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class _YearDropdown extends StatelessWidget {
  const _YearDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.outline, size: 22),
          dropdownColor: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCK BADGE  (shown on card header when section is locked)
// ─────────────────────────────────────────────────────────────────────────────

class _LockBadge extends StatelessWidget {
  const _LockBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 11, color: AppColors.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _SaveConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.save_outlined,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Save Changes?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your profile information will be updated. Some fields may be locked for 7 days after saving.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.6,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: Text(
                          'Discard',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryFixedDim,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Save',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SAVE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSaveButton extends StatelessWidget {
  const _BottomSaveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryFixedDim],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Save Changes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
