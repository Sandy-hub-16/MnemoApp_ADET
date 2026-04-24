import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../landing_page/app_theme.dart';
import '../auth/services/auth_google_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileScaffold();
  }
}

class _ProfileScaffold extends StatefulWidget {
  const _ProfileScaffold();

  @override
  State<_ProfileScaffold> createState() => _ProfileScaffoldState();
}

class _ProfileScaffoldState extends State<_ProfileScaffold> {
  final _bodyKey = GlobalKey<_ProfileBodyState>();

  Future<void> _goToSettings() async {
    await Navigator.of(context).pushNamed('/account-settings');
    _bodyKey.currentState?._loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          Positioned(
            top: 80,
            right: -80,
            child: _Blob(
              size: 320,
              color: AppColors.primaryContainer.withOpacity(0.35),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -100,
            child: _Blob(
              size: 280,
              color: AppColors.secondaryContainer.withOpacity(0.28),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _ProfileTopBar(onSettingsTap: _goToSettings),
                Expanded(
                  child: _ProfileBody(key: _bodyKey),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNavBar(activeIndex: 3),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.onSettingsTap});
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.75),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavIconButton(icon: Icons.menu_rounded, onTap: () {}),
          Text(
            'Buddy Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.2,
            ),
          ),
          _NavIconButton(icon: Icons.settings_outlined, onTap: onSettingsTap),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE BODY
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({super.key});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool _loading = true;
  bool _uploadingPhoto = false;
  String _fullName = '';
  String _username = '';
  String _bio = '';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser!;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    if (mounted) {
      setState(() {
        _fullName = data['fullName'] as String? ?? '';
        _username = data['username'] as String? ?? '';
        _bio = data['bio'] as String? ?? '';
        _photoUrl = authUser.photoURL ?? data['photoUrl'] as String?;
        _loading = false;
      });
    }
  }

  // ── Photo picker & uploader ──────────────────────────────────────────────

  /// Shows a bottom sheet so the user can choose Camera or Gallery.
  Future<void> _onAvatarTap() async {
    final source = await _showImageSourceSheet();
    if (source == null) return;
    await _pickAndUploadPhoto(source);
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImageSourceSheet(),
    );
  }

  /// Picks an image, uploads it to Firebase Storage, then updates both
  /// Firebase Auth profile and the Firestore 'users' document.
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return; // user cancelled

      setState(() => _uploadingPhoto = true);

      final ref =
          FirebaseStorage.instance.ref().child('avatars').child('$uid.jpg');

      // ── Web: read as bytes (dart:io File doesn't exist on web) ──────
      // ── Mobile: use File for efficient streaming upload ──────────────
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        await ref.putFile(
          File(picked.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseAuth.instance.currentUser!.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
          _uploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile photo updated!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Photo upload error: $e'); // ← helps debug future errors
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update photo. Please try again.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProfileHeader(
            fullName: _fullName,
            username: _username,
            bio: _bio,
            photoUrl: _photoUrl,
            uploadingPhoto: _uploadingPhoto,
            onAvatarTap: _onAvatarTap, // ← NEW callback
          ),
          const SizedBox(height: 32),
          _SectionLabel(left: 'Deck Statistics', right: 'LIFETIME IMPACT'),
          const SizedBox(height: 12),
          const _StatsGrid(),
          const SizedBox(height: 32),
          _ActionList(
            onSettingsTap: () async {
              await Navigator.of(context).pushNamed('/account-settings');
              _loadProfile();
            },
          ),
          const SizedBox(height: 20),
          const _LogOutButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE SOURCE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Update Profile Photo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a source for your new photo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Camera option
                Expanded(
                  child: _SourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.primary,
                    bgColor: AppColors.primaryContainer.withOpacity(0.25),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                // Gallery option
                Expanded(
                  child: _SourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppColors.secondary,
                    bgColor: AppColors.secondaryContainer.withOpacity(0.25),
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Cancel
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.outline,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HEADER  (updated: tappable avatar, upload spinner, default avatar)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullName,
    required this.username,
    required this.bio,
    required this.onAvatarTap,
    this.photoUrl,
    this.uploadingPhoto = false,
  });

  final String fullName;
  final String username;
  final String bio;
  final String? photoUrl;
  final bool uploadingPhoto;
  final VoidCallback onAvatarTap; // ← NEW

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Avatar stack ─────────────────────────────────────────────
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient ring
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
                child: _AvatarContent(
                  photoUrl: photoUrl,
                  fullName: fullName,
                  uploading: uploadingPhoto,
                ),
              ),

              // Upload progress overlay
              if (uploadingPhoto)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),

              // Edit button (bottom-right)
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: onAvatarTap,
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
                    child: Icon(
                      uploadingPhoto
                          ? Icons.hourglass_top_rounded
                          : Icons.edit_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          fullName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),

        // Username
        Text(
          '@$username',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),

        // Bio
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR CONTENT  — photo → initial letter → default icon (priority order)
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.photoUrl,
    required this.fullName,
    this.uploading = false,
  });

  final String? photoUrl;
  final String fullName;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          // ── Shown while the image is downloading ──────────────────
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 112,
              height: 112,
              color: AppColors.primaryContainer.withOpacity(0.2),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          // ── Fallback on 429, network error, bad URL, etc. ─────────
          errorBuilder: (context, error, stackTrace) =>
              _FallbackAvatar(fullName: fullName),
        ),
      );
    }

    return _FallbackAvatar(fullName: fullName);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK AVATAR  — initial letter  OR  default person icon
// Used when: no photo URL set, network error, or 429 rate-limit hit.
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.fullName});
  final String fullName;

  @override
  Widget build(BuildContext context) {
    if (fullName.isNotEmpty) {
      return Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primaryContainer,
              AppColors.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            fullName[0].toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    // No name — plain person icon, no badge
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryContainer.withOpacity(0.3),
      ),
      child: Icon(
        Icons.person_rounded,
        size: 60,
        color: AppColors.primary.withOpacity(0.5),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// STATS GRID
// ─────────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '12',
            label: 'Built',
            accentColor: AppColors.primaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '45',
            label: 'Saved',
            accentColor: AppColors.secondaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '3',
            label: 'Drafts',
            accentColor: AppColors.tertiaryContainer,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.accentColor,
  });

  final String value;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.outline,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ActionList extends StatelessWidget {
  const _ActionList({required this.onSettingsTap});
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.person_outline_rounded,
            iconBg: AppColors.primaryContainer.withOpacity(0.3),
            iconColor: AppColors.primary,
            label: 'Account Settings',
            onTap: onSettingsTap,
          ),
          _ActionTile(
            icon: Icons.notifications_active_outlined,
            iconBg: AppColors.secondaryContainer.withOpacity(0.3),
            iconColor: AppColors.secondary,
            label: 'Notification Preferences',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.quiz_outlined,
            iconBg: AppColors.tertiaryContainer.withOpacity(0.3),
            iconColor: AppColors.tertiary,
            label: 'Help & Support',
            onTap: () {},
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.outline, size: 22),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: AppColors.outlineVariant.withOpacity(0.3),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOG OUT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: AppColors.errorContainer.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Text(
                'Log Out',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
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
// BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.activeIndex});
  final int activeIndex;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home', route: '/home'),
    _NavItem(icon: Icons.layers_outlined, label: 'Decks', route: '/decks'),
    _NavItem(icon: Icons.quiz_outlined, label: 'Quiz', route: '/quiz'),
    _NavItem(icon: Icons.analytics_outlined, label: 'Stats', route: '/stats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
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
            children: _items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final active = i == activeIndex;

              return GestureDetector(
                onTap: () {
                  if (!active) {
                    Navigator.of(context).pushReplacementNamed(item.route);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withOpacity(0.45)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? _filledIcon(item.icon) : item.icon,
                        size: 24,
                        color:
                            active ? AppColors.primary : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              active ? AppColors.primary : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static final Map<IconData, IconData> _filledIconMap = {
    Icons.home_outlined: Icons.home_rounded,
    Icons.layers_outlined: Icons.layers_rounded,
    Icons.quiz_outlined: Icons.quiz_rounded,
    Icons.analytics_outlined: Icons.analytics_rounded,
  };

  IconData _filledIcon(IconData outline) => _filledIconMap[outline] ?? outline;
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
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

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.left, required this.right});
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          left,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          right,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.outline,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
