import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum CardVariant { wideWithImage, narrowAccentTertiary, narrowAccentSecondary, wideWithSkeleton }

class FeatureItem {
  const FeatureItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.variant,
    this.imageUrl,
  });

  final String title;
  final String description;
  final IconData icon;
  final CardVariant variant;
  final String? imageUrl;
}

class StudentAvatar {
  const StudentAvatar({required this.name, required this.url});
  final String name;
  final String url;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENT — edit this when copy or cards change.
// ─────────────────────────────────────────────────────────────────────────────

const heroHeadlinePrefix = 'Master your subjects, one ';
const heroHeadlineHighlight = 'breakthrough';
const heroHeadlineSuffix = ' at a time.';

const heroBody =
    'Turn passive reading into a dynamic challenge-response cycle. '
    'MnemoApp helps you build a personal knowledge base through '
    'active participation, not just review.';

const featuresHeading = 'Built for active learning';
const featuresSubheading =
    'Stop forgetting what you read. MnemoApp facilitates the '
    'participation needed to truly own your knowledge.';

const socialProofLabel = 'Join 15,000+ students';
const socialProofSub = 'mastering their subjects today';

const List<StudentAvatar> socialProofAvatars = [
  StudentAvatar(
    name: 'Student A',
    url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDoA5H5ruUbAHq4nIAuI3dBn24BDFR9PNaXAHqk1jk-37yTsOL-zGpwQorZCf2xgk-D-rc6B07aGcjLJn2S3zKNTbLxKSLOQwaDFBrTvRFWDWI2xh0qN3XIrKjAsjh3W1XBs9ThCkxz9-DkWh_b6OyAciD-Mqs0r78q4szFcojjEN397Ibt6-cWSyytkwC5wDxXpkV0PFWdEzmtliy3q0Lb8YAWEbQZ4W11Vr_-r0vSqBZFY2oMVqt-5rWQQnaNik0Lhy6nWQ8qqRtA',
  ),
  StudentAvatar(
    name: 'Student B',
    url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAe72-TiU_qvbzWyTxXQVI6IE559y67GBCg77o6CFnBK2tE-uAWMSQCuSQwzgAQGie86dz1gwiGGoAOGlTM21mGHDXIOIplbLrkzjVdFGJADaQWqjnwcnlc4gkYjI47ItYJKinHENVa_TZgr6BNioAc1x9B1nNVwZ2-8IzqDeS4eBF8J5Eoz6kONwWgPhY6QgDEAqZfJXiUOfm1LM7N3aF7eJ6nQ4jeBs3EGev5m28GBS5i7K7RttIsvy3oILYekuikMWJE43Ko_4ma',
  ),
  StudentAvatar(
    name: 'Student C',
    url: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAtOahW-q09XnUHi05qOyG3uu1NaQ53aMXIe19gzATlRoiJDZImmTAl-SR84BVpvkiE2E5hxzIFMvtV0KJoNFmppYEXG5nVZErrvqCxPh0wr34NGgyxKXRUNql0eyCmKPa62rGPU6XjVpIqvDfv0WSTafurXfDzXMjkS17wL0q0nXb7Gc8VtKIWIKX4PEPBQE2zw7WvriycFmwDoaSKYtX9qZgjAMHyGbDX74U5bSR8o6WSCW98XsThfs3DLQFZRHvmX5n4DD9mKg3c',
  ),
];

const String heroImageUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCzSvAjjMgL1PUzOMwUwDs3NyVVXftGmjPU_TUyIn1IQ5OJqlUC66gUOYCqD8tInHM914jupiogqhe0uQnwc5PV1ZLuSo7tITT4gSbIHPHY_5IulSpRzOnSE5t32v6kquMfjLrN025S7icGNFrFXNUwMujgYshKwIq2SL4M7xRseusKqvKZo2juYjYShPYaA2wcWgpEkiiPfhYp97NUJj7rpDY1WjzO2bQF8zYQAZbdMF1dQRzbdJdUQyfKcvwy9lZZFr3ywGI6amjW';

const String featureImageUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDbQ3BQm7sgco8llIDn65V9L9RUaH9fgSX0zYL4IzaKijjERMWESJ00nO-jp2zKh3jmmcNrux-o1POy4WVhnYM4JkVBHRNG91K0w9LADym-FyLtcqfR48dLIcErbFemLShkisNfupmMRh6dlYSDezAAR2GEfD_2fuWp3WKhF6KTs7h8kxzYX1hd84K8azXXc0F7iEGyskrmNYtnfPuOl3YgtIbuV390SMRtH12s4rzmwhJyj1lmnCGLyoKiR4BKAftTdkn1MpgALVkG';

const List<FeatureItem> features = [
  FeatureItem(
    title: 'Your Personal Knowledge Base',
    description:
        'MnemoApp organizes every challenge, note, and breakthrough into a '
        'structured second brain. Build a lifelong asset as you study.',
    icon: Icons.inventory_2_rounded,
    variant: CardVariant.wideWithImage,
    imageUrl: featureImageUrl,
  ),
  FeatureItem(
    title: 'Challenge-Response Cycle',
    description:
        'Engagement is key. We replace passive review with active prompts '
        'that force your brain to retrieve and apply information in real-time.',
    icon: Icons.psychology_alt_outlined,
    variant: CardVariant.narrowAccentTertiary,
  ),
  FeatureItem(
    title: 'Active Participation',
    description:
        'Passivity is the enemy of learning. Our interface keeps you '
        'interacting with your material through smart sketching, typing, and speaking.',
    icon: Icons.edit_note_rounded,
    variant: CardVariant.narrowAccentSecondary,
  ),
  FeatureItem(
    title: 'Synthesis Summaries',
    description:
        "Don't just read summaries—participate in them. Our AI-assisted synthesis "
        'helps you connect dots between complex topics across your entire collection.',
    icon: Icons.schema_outlined,
    variant: CardVariant.wideWithSkeleton,
  ),
];

const List<String> footerLinks = ['Support', 'Privacy', 'Terms', 'Community'];
