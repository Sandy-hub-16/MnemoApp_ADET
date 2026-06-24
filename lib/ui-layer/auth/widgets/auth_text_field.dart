import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED FORM FIELD — rounded pill/rect input, matching HTML design.
// ─────────────────────────────────────────────────────────────────────────────

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.prefixIcon,
    this.prefixText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.helperText,
    this.errorText,
    this.shape = AuthFieldShape.pill,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? prefixIcon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? helperText;
  final String? errorText;
  final AuthFieldShape shape;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Optional external FocusNode (e.g. for chaining Tab order via
  /// FocusScope.nextFocus or autofocus on a specific field). If omitted,
  /// an internal node is created and disposed automatically.
  final FocusNode? focusNode;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

enum AuthFieldShape { pill, rounded }

class _AuthTextFieldState extends State<AuthTextField> {
  bool _focused = false;
  FocusNode? _internalNode;

  FocusNode get _node => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _focused = _node.hasFocus);
  }

  @override
  void didUpdateWidget(AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalNode)?.removeListener(_handleFocusChange);
      _node.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    (widget.focusNode ?? _internalNode)?.removeListener(_handleFocusChange);
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.shape == AuthFieldShape.pill ? 999.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.label!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _node,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            mouseCursor: SystemMouseCursors.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: AppColors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: AppColors.outlineVariant,
              ),
              filled: true,
              fillColor: _focused
                  ? AppColors.surfaceContainerLowest
                  : AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(
                  // Soft outline so the field is always visible,
                  // but doesn't compete with the focused primary stroke.
                  color: AppColors.outlineVariant.withOpacity(0.55),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.8,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal:
                    widget.prefixIcon != null || widget.prefixText != null
                        ? 0
                        : 22,
                vertical: 18,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: _focused ? AppColors.primary : AppColors.outline,
                    )
                  : widget.prefixText != null
                      ? Padding(
                          padding: const EdgeInsets.only(left: 18, right: 4),
                          child: Text(
                            widget.prefixText!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              color: AppColors.outline,
                            ),
                          ),
                        )
                      : null,
              suffixIcon: widget.suffixIcon != null
                  ? GestureDetector(
                      onTap: widget.onSuffixTap,
                      child: Icon(
                        widget.suffixIcon,
                        size: 20,
                        color: AppColors.outline,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              widget.helperText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}