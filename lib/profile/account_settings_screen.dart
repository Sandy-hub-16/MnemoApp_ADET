import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT SETTINGS SCREEN
// Lets the user edit their profile and educational info.
//
// ✏️  BACKEND NOTE:
// All controllers and state variables are already wired up — just plug in
// your Firestore logic:
//   • In _loadProfile(): read from FirebaseFirestore 'users' collection and
//     populate the controllers + _yearLevel, then setState(() => _loading = false).
//   • In _saveChanges(): write controller values back to Firestore.
//     _saving is already hooked up to show a spinner while the write completes.
//   • In _AvatarSection: pass in the photoURL string from Firebase Auth or
//     Firestore and swap the placeholder icon for a NetworkImage.
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
            top: 80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.28),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _SettingsTopBar(),
                const Expanded(child: _SettingsBody()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _SettingsBottomNav(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR — back button navigates to previous screen
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.75),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Account Settings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          // Spacer to visually balance the back button
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS BODY
// All controllers are ready — backend dev just needs to fill in
// _loadProfile() and _saveChanges().
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  // ── Controllers — backend dev reads/writes these ───────────────────────────
  final _nameCtrl   = TextEditingController();
  final _bioCtrl    = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  String _yearLevel = 'Freshman';
  bool   _saving    = false;

  static const _yearOptions = [
    'Freshman',
    'Sophomore',
    'Junior',
    'Senior',
    'Graduate',
  ];

  @override
  void initState() {
    super.initState();
    // ✏️  BACKEND: Call _loadProfile() here once Firestore is wired up.
    // _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _schoolCtrl.dispose();
    _courseCtrl.dispose();
    super.dispose();
  }

  // ── ✏️  BACKEND: Populate controllers from Firestore ──────────────────────
  // Future<void> _loadProfile() async {
  //   final uid = FirebaseAuth.instance.currentUser?.uid;
  //   if (uid == null) return;
  //   final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  //   final data = doc.data() ?? {};
  //   setState(() {
  //     _nameCtrl.text   = data['fullName']  as String? ?? '';
  //     _bioCtrl.text    = data['bio']       as String? ?? '';
  //     _schoolCtrl.text = data['school']    as String? ?? '';
  //     _courseCtrl.text = data['course']    as String? ?? '';
  //     _yearLevel       = _yearOptions.contains(data['yearLevel'])
  //         ? data['yearLevel'] as String
  //         : 'Freshman';
  //   });
  // }

  // ── ✏️  BACKEND: Write controller values to Firestore ─────────────────────
  // Future<void> _saveChanges() async {
  //   final uid = FirebaseAuth.instance.currentUser?.uid;
  //   if (uid == null) return;
  //   if (_nameCtrl.text.trim().isEmpty) {
  //     _showSnack('Full name cannot be empty.', isError: true);
  //     return;
  //   }
  //   setState(() => _saving = true);
  //   try {
  //     await FirebaseFirestore.instance.collection('users').doc(uid).update({
  //       'fullName':  _nameCtrl.text.trim(),
  //       'bio':       _bioCtrl.text.trim(),
  //       'school':    _schoolCtrl.text.trim(),
  //       'course':    _courseCtrl.text.trim(),
  //       'yearLevel': _yearLevel,
  //       'updatedAt': FieldValue.serverTimestamp(),
  //     });
  //     _showSnack('Changes saved!');
  //     if (mounted) Navigator.of(context).pop();
  //   } catch (e) {
  //     _showSnack('Could not save changes. Try again.', isError: true);
  //   } finally {
  //     if (mounted) setState(() => _saving = false);
  //   }
  // }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade600 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar with edit overlay ──────────────────────────────────────
          // ✏️  BACKEND: Pass photoUrl from FirebaseAuth/Firestore here.
          const _AvatarSection(photoUrl: null),
          const SizedBox(height: 32),

          // ── Basic info card ───────────────────────────────────────────────
          _SettingsCard(
            children: [
              const _FieldLabel('Full Name'),
              const SizedBox(height: 8),
              _SettingsTextField(
                controller: _nameCtrl,
                hint: 'Your full name',
                prefixIcon: Icons.person_outline_rounded,
                shape: _FieldShape.pill,
              ),
              const SizedBox(height: 20),
              const _FieldLabel('About Me'),
              const SizedBox(height: 8),
              _SettingsTextArea(
                controller: _bioCtrl,
                hint: 'Tell us about your learning journey…',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Educational info card ─────────────────────────────────────────
          _SettingsCard(
            children: [
              Text(
                'Educational Info',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('School / University'),
              const SizedBox(height: 8),
              _SettingsTextField(
                controller: _schoolCtrl,
                hint: 'e.g. University of the Philippines',
                prefixIcon: Icons.school_outlined,
                shape: _FieldShape.pill,
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Course / Program'),
              const SizedBox(height: 8),
              _SettingsTextField(
                controller: _courseCtrl,
                hint: 'e.g. BS Computer Science',
                prefixIcon: Icons.book_outlined,
                shape: _FieldShape.pill,
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Year Level'),
              const SizedBox(height: 8),
              _YearDropdown(
                value: _yearLevel,
                options: _yearOptions,
                onChanged: (v) {
                  if (v != null) setState(() => _yearLevel = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Save changes CTA ──────────────────────────────────────────────
          _saving
              ? const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                )
              : _SaveButton(
                  onTap: () {
                    // ✏️  BACKEND: Replace with _saveChanges() once wired up.
                  },
                ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR SECTION
// ✏️  BACKEND: Pass photoUrl from Firebase Auth / Firestore to show the
// user's actual photo instead of the placeholder icon.
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({this.photoUrl});

  /// Pass the user's photo URL (from Firebase Auth or Firestore) here.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
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
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: AppColors.primary.withOpacity(0.5),
                  )
                : null,
          ),
        ),
        Positioned(
          bottom: 2,
          right: -2,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surfaceContainerLowest,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD HELPERS
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
        letterSpacing: 1.1,
      ),
    );
  }
}

enum _FieldShape { pill, rounded }

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.shape = _FieldShape.rounded,
    this.keyboardType = null,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final _FieldShape shape;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final radius = shape == _FieldShape.pill ? 999.0 : 14.0;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.outline.withOpacity(0.5),
        ),
        prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.4),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _SettingsTextArea extends StatelessWidget {
  const _SettingsTextArea({
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.outline.withOpacity(0.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.all(20),
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
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.4),
            width: 2,
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.outline, size: 22),
          dropdownColor: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
          items: options
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(o),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});
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
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV (same style as ProfileScreen, Settings stays on profile tab)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsBottomNav extends StatelessWidget {
  const _SettingsBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavTile(
                icon: Icons.home_outlined,
                label: 'Home',
                active: false,
                onTap: () =>
                    Navigator.of(context).pushReplacementNamed('/home'),
              ),
              _NavTile(
                icon: Icons.layers_outlined,
                label: 'Decks',
                active: false,
                onTap: () =>
                    Navigator.of(context).pushReplacementNamed('/decks'),
              ),
              _NavTile(
                icon: Icons.quiz_outlined,
                label: 'Quiz',
                active: false,
                onTap: () =>
                    Navigator.of(context).pushReplacementNamed('/quiz'),
              ),
              _NavTile(
                icon: Icons.analytics_outlined,
                label: 'Stats',
                active: false,
                onTap: () =>
                    Navigator.of(context).pushReplacementNamed('/stats'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryContainer.withOpacity(0.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24,
                color: active ? AppColors.primary : Colors.grey.shade400),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}