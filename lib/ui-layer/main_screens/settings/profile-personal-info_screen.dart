import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/share_service.dart';
import '../../widgets/app_spinner.dart';

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

// ── 7-day lock helper (username) ─────────────────────────────────────────────
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

// ── 30-day lock helper (per education field) ──────────────────────────────────
// Uses exactly 30 elapsed days, not a calendar-month comparison.
bool _isWithin30Days(Timestamp? ts) {
  if (ts == null) return false;
  final diff = DateTime.now().difference(ts.toDate());
  return diff.inDays < 30;
}

/// Returns how many days remain in the 30-day cooldown, e.g. "25 days".
String _daysRemaining30(Timestamp? ts) {
  if (ts == null) return '';
  final diff = DateTime.now().difference(ts.toDate());
  final remaining = 30 - diff.inDays;
  if (remaining <= 0) return '';
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
                color: AppColors.secondaryContainer.withValues(alpha: 0.18),
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
                color: AppColors.tertiaryContainer.withValues(alpha: 0.15),
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
  String _yearLevel = '1st Year';

  // ── Lock timestamps ────────────────────────────────────────────────────────
  Timestamp? _createdAt;
  Timestamp? _usernameLastChangedAt; // null → use createdAt for username lock
  // Education: one timestamp per field — cooldown is per-field, not per-section
  Timestamp? _schoolLastChangedAt;
  Timestamp? _courseLastChangedAt;
  Timestamp? _yearLevelLastChangedAt;

  bool _loading = true;
  bool _saving = false;
  bool _isDirty = false;
  bool _uploadingPhoto = false;

  // ── Computed locks ─────────────────────────────────────────────────────────
  bool get _usernameIsLocked {
    // Lock against the most recent of: account creation OR last username change
    final ts = _usernameLastChangedAt ?? _createdAt;
    return _isWithin7Days(ts);
  }

  // Education: 30-day cooldown is per-field — changing school doesn't lock course
  bool get _schoolIsLocked => _isWithin30Days(_schoolLastChangedAt);
  bool get _courseIsLocked => _isWithin30Days(_courseLastChangedAt);
  bool get _yearLevelIsLocked => _isWithin30Days(_yearLevelLastChangedAt);

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

        _createdAt = data['createdAt'] as Timestamp?;
        _usernameLastChangedAt = data['usernameLastChangedAt'] as Timestamp?;
        _schoolLastChangedAt = data['schoolLastChangedAt'] as Timestamp?;
        _courseLastChangedAt = data['courseLastChangedAt'] as Timestamp?;
        _yearLevelLastChangedAt = data['yearLevelLastChangedAt'] as Timestamp?;

        _isDirty = false;
        _loading = false;
      });
    }
  }

  // ── Photo upload ───────────────────────────────────────────────────────────

  Future<void> _onAvatarTap() async {
    if (kIsWeb) {
      // On web, skip the bottom sheet entirely and go straight to the
      // file picker — no camera option since desktop browsers don't support
      // the capture attribute reliably.
      await _pickAndUploadPhoto(ImageSource.gallery);
      return;
    }
    // Mobile: show Camera / Gallery choice sheet as normal.
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
    if (source == null) return;
    await _pickAndUploadPhoto(source);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      XFile? picked;

      if (kIsWeb) {
        // Web: always use FilePicker for gallery (ImagePicker.gallery throws on web).
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final pf = result.files.single;
        picked = XFile.fromData(
          pf.bytes ?? Uint8List(0),
          name: pf.name,
          mimeType: 'image/${pf.extension ?? 'jpeg'}',
        );
      } else if (source == ImageSource.camera) {
        // Mobile + camera: native camera via ImagePicker.
        picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 800,
          maxHeight: 800,
        );
      } else {
        // Mobile + gallery: native gallery via ImagePicker.
        picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 800,
          maxHeight: 800,
        );
      }

      // Guard: user cancelled the picker.
      if (picked == null) return;

      // Overlay on — set before any async upload work.
      setState(() => _uploadingPhoto = true);

      final ref =
          FirebaseStorage.instance.ref().child('avatars').child('$uid.jpg');

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
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
        _showSnack('Profile photo updated!');
      }
    } catch (e) {
      debugPrint('Photo upload error: $e');
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        _showSnack(_errorMessage(e), isError: true);
      }
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

    // ── SAVE ORIGINAL VALUES FOR ROLLBACK ──────────────────────────────────
    final origBio = _origBio;
    final origUsername = _origUsername;
    final origSchool = _origSchool;
    final origCourse = _origCourse;
    final origYearLevel = _origYearLevel;

    // ── OPTIMISTICALLY UPDATE LOCAL STATE ──────────────────────────────────
    setState(() {
      _origBio = _bioCtrl.text.trim();
      _origUsername = _usernameCtrl.text.trim();
      _origSchool = _schoolCtrl.text.trim();
      _origCourse = _courseCtrl.text.trim();
      _origYearLevel = _yearLevel;
      _isDirty = false;
      _saving = true;
    });

    // ── SHOW SAVING INDICATOR ──────────────────────────────────────────────
    _showSnack('Saving changes...');

    try {
      final updates = <String, dynamic>{
        'bio': _bioCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Username — only write if editable and changed
      if (!_usernameIsLocked && _usernameCtrl.text.trim() != origUsername) {
        updates['username'] = _usernameCtrl.text.trim();
        updates['usernameLastChangedAt'] = FieldValue.serverTimestamp();
      }

      // Education — per-field 30-day cooldown.
      // Each field is saved independently; editing school does not lock course.
      if (!_schoolIsLocked && _schoolCtrl.text.trim() != origSchool) {
        updates['school'] = _schoolCtrl.text.trim();
        updates['schoolLastChangedAt'] = FieldValue.serverTimestamp();
      }
      if (!_courseIsLocked && _courseCtrl.text.trim() != origCourse) {
        updates['course'] = _courseCtrl.text.trim();
        updates['courseLastChangedAt'] = FieldValue.serverTimestamp();
      }
      if (!_yearLevelIsLocked && _yearLevel != origYearLevel) {
        updates['yearLevel'] = _yearLevel;
        updates['educationLevel'] = _deriveEducationLevel(_yearLevel);
        updates['yearLevelLastChangedAt'] = FieldValue.serverTimestamp();
      }

      // ── SAVE TO FIRESTORE IN BACKGROUND ────────────────────────────────
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);

      // ── FAN-OUT FOLLOWING NOTIFICATIONS (fire-and-forget) ─────────────
      // Notify followers when a username or bio changes. Errors are
      // silently swallowed so a notification hiccup never blocks the save.
      final newUsername = _usernameCtrl.text.trim();
      final newBio = _bioCtrl.text.trim();

      if (!_usernameIsLocked && newUsername != origUsername) {
        ShareService.fanOutUsernameChanged(
          ownerUid: uid,
          newUsername: newUsername,
          oldUsername: origUsername,
        );
      }

      if (newBio != origBio) {
        ShareService.fanOutBioUpdated(
          ownerUid: uid,
          ownerUsername: newUsername.isNotEmpty ? newUsername : origUsername,
        );
      }

      // ── SUCCESS: SHOW SUCCESS MESSAGE ──────────────────────────────────
      if (mounted) {
        _showSnack('Changes saved ✓');
        setState(() => _saving = false);
        // Delay pop to let user see the success message
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      // ── ERROR: REVERT ALL CHANGES ──────────────────────────────────────
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() {
          _bioCtrl.text = origBio;
          _usernameCtrl.text = origUsername;
          _schoolCtrl.text = origSchool;
          _courseCtrl.text = origCourse;
          _yearLevel = origYearLevel;
          _origBio = origBio;
          _origUsername = origUsername;
          _origSchool = origSchool;
          _origCourse = origCourse;
          _origYearLevel = origYearLevel;
          _isDirty = false;
          _saving = false;
        });
        _showSnack('Could not save changes. Changes reverted.', isError: true);
      }
    }
  }

  /// Maps yearLevel to the educationLevel key the Cloud Function expects.
  String _deriveEducationLevel(String yearLevel) {
    switch (yearLevel) {
      case 'Graduate':
        return 'professional';
      case '5th Year':
      case '4th Year':
      case '3rd Year':
      case '2nd Year':
      case '1st Year':
      default:
        return 'college';
    }
  }

  // ── Error message helper ───────────────────────────────────────────────────
  String _errorMessage(Object e) {
    if (e is PlatformException) {
      if (e.code == 'camera_access_denied') {
        return 'Camera access was denied. Please allow camera permission in your browser.';
      }
      // Any other PlatformException from the camera path means the camera
      // itself is unavailable in this browser environment.
      return 'Camera is not available in this browser.';
    }
    if (e is FirebaseException) {
      // Storage plugin uses 'firebase_storage' as its plugin identifier.
      if (e.plugin == 'firebase_storage') {
        return 'Failed to upload photo. Please try again.';
      }
      // Firestore plugin uses 'cloud_firestore'.
      if (e.plugin == 'cloud_firestore') {
        return 'Photo uploaded but profile save failed. Please try again.';
      }
    }
    return 'Failed to update photo. Please try again.';
  }

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
            child: Center(child: AppSpinner()),
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
                    uploadingPhoto: _uploadingPhoto,
                    onTap: _onAvatarTap,
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
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Educational Background card ─────────────────────────
                  _SectionCard(
                    label: 'Educational Background',
                    children: [
                      _LockedOrEditableTextField(
                        label: 'School / University',
                        controller: _schoolCtrl,
                        icon: Icons.school_outlined,
                        isLocked: _schoolIsLocked,
                        hint: 'e.g. University of the Philippines',
                        lockSubtitle: _schoolIsLocked
                            ? 'Editable again in '
                                '${_daysRemaining30(_schoolLastChangedAt)}'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _LockedOrEditableTextField(
                        label: 'Course / Program',
                        controller: _courseCtrl,
                        icon: Icons.menu_book_outlined,
                        isLocked: _courseIsLocked,
                        hint: 'e.g. BS Computer Science',
                        lockSubtitle: _courseIsLocked
                            ? 'Editable again in '
                                '${_daysRemaining30(_courseLastChangedAt)}'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Year Level'),
                      const SizedBox(height: 8),
                      _yearLevelIsLocked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.stairs_outlined,
                                          color: AppColors.outline
                                              .withValues(alpha: 0.6),
                                          size: 19),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _yearLevel,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.lock_outline_rounded,
                                          color: AppColors.outline
                                              .withValues(alpha: 0.35),
                                          size: 14),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18),
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule_rounded,
                                          size: 12,
                                          color: AppColors.outline
                                              .withValues(alpha: 0.5)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Editable again in '
                                        '${_daysRemaining30(_yearLevelLastChangedAt)}',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: AppColors.outline
                                                .withValues(alpha: 0.55)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                            ? const Center(child: AppSpinner())
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
      color: AppColors.background.withValues(alpha: 0.80),
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
                color: AppColors.primaryContainer.withValues(alpha: 0.18),
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
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: AppSpinnerSmall(color: Colors.white),
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
// AVATAR SECTION  — tappable; shows edit pen + upload progress overlay.
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.photoUrl,
    required this.fullName,
    required this.uploadingPhoto,
    required this.onTap,
  });

  final String? photoUrl;
  final String fullName;
  final bool uploadingPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploadingPhoto ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── Gradient ring + avatar ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primaryContainer.withValues(alpha: 0.35),
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
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ))
                  : null,
            ),
          ),

          // ── Upload progress overlay ─────────────────────────────────────
          if (uploadingPhoto)
            Positioned(
              top: 3,
              left: 3,
              right: 3,
              bottom: 3,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: const Center(
                  child: AppSpinner(color: Colors.white),
                ),
              ),
            ),

          // ── Edit pen button (bottom-right) ──────────────────────────────
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: uploadingPhoto ? AppColors.outline : AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceContainerLowest,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
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
        ],
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
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
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
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Divider(
              height: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
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
  });

  final String label;
  final String value;
  final IconData icon;
  final String lockReason;

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
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: AppColors.outline.withValues(alpha: 0.6), size: 19),
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
                        color: AppColors.outline.withValues(alpha: 0.35),
                        size: 14),
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
                  fontSize: 11,
                  color: AppColors.outline.withValues(alpha: 0.55)),
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
                  color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: AppColors.outline.withValues(alpha: 0.6),
                        size: 19),
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
                        color: AppColors.outline.withValues(alpha: 0.35),
                        size: 14),
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
                    size: 12, color: AppColors.outline.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  lockSubtitle!,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.outline.withValues(alpha: 0.55)),
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
// LOCKED OR EDITABLE TEXT FIELD  (education — 30-day per-field lock)
// ─────────────────────────────────────────────────────────────────────────────

class _LockedOrEditableTextField extends StatelessWidget {
  const _LockedOrEditableTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isLocked,
    required this.hint,
    this.lockSubtitle,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isLocked;
  final String hint;
  final String? lockSubtitle;

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
                  color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: AppColors.outline.withValues(alpha: 0.6),
                        size: 19),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.text.isNotEmpty ? controller.text : '—',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.outline,
                        ),
                      ),
                    ),
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.outline.withValues(alpha: 0.35),
                        size: 14),
                  ],
                ),
              )
            : _EditableField(
                controller: controller,
                icon: icon,
                hint: hint,
              ),
        if (isLocked && lockSubtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 12, color: AppColors.outline.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  lockSubtitle!,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.outline.withValues(alpha: 0.55)),
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
            fontSize: 14, color: AppColors.outline.withValues(alpha: 0.45)),
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
          borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.4), width: 2),
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
            fontSize: 14, color: AppColors.outline.withValues(alpha: 0.45)),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.all(18),
        counterStyle: GoogleFonts.plusJakartaSans(
            fontSize: 11, color: AppColors.outline.withValues(alpha: 0.5)),
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
              color: AppColors.primary.withValues(alpha: 0.4), width: 2),
        ),
      ),
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
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
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
              'Your profile information will be updated. Username locks for 7 days after saving; each education field locks for 30 days independently.',
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
                            color: AppColors.primary.withValues(alpha: 0.25),
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
              color: AppColors.primary.withValues(alpha: 0.25),
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

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE SOURCE BOTTOM SHEET
//
// Lets the user choose between Camera and Gallery for their profile photo.
// Returns an [ImageSource] to the caller via Navigator.pop.
// ─────────────────────────────────────────────────────────────────────────────

class _ImageSourceSheet extends StatelessWidget {
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
              color: AppColors.outline.withValues(alpha: 0.3),
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
          const SizedBox(height: 6),
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
                Expanded(
                  child: _SourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.primary,
                    bgColor: AppColors.primaryContainer.withValues(alpha: 0.25),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppColors.secondary,
                    bgColor:
                        AppColors.secondaryContainer.withValues(alpha: 0.25),
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
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
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
