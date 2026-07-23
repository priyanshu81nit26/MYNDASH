import 'package:flutter/material.dart';

import '../theme_district.dart';
import '../ui/glass.dart' show ShaderBackground;

/// ============================================================
/// Legal & policy screens — Terms of Service, Privacy Policy.
/// Required for Google Play listing (Data safety + policy links).
/// ============================================================

const String kSupportEmail = 'priyanshukaffota@gmail.com';
const String kEntityName = 'MYNDASH';

/// Soft card colour that reads as a clean sheet in both themes.
Color _cardColor() =>
    ThemeCtl.isDark ? const Color(0xFF15151D) : Colors.white;

Color _cardBorder() => ThemeCtl.isDark
    ? Colors.white.withOpacity(0.06)
    : const Color(0xFF0B1B33).withOpacity(0.06);

class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  const LegalScreen({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.description_rounded,
    this.accent = const Color(0xFF3B82F6),
  });

  @override
  Widget build(BuildContext context) {
    final blocks = body.trim().split(RegExp(r'\n\s*\n'));
    String? updated;
    final sections = <Widget>[];
    for (final raw in blocks) {
      // Strip the "TITLE — MYNDASH" banner and pull out the "Last updated"
      // line wherever they appear (they share the first block).
      final kept = <String>[];
      for (final ln in raw.split('\n')) {
        final t = ln.trim();
        if (t.isEmpty) continue;
        if (t.startsWith('Last updated')) {
          updated = t.replaceFirst('Last updated:', '').trim();
        } else if (t.contains('—') && t.toUpperCase().contains('MYNDASH')) {
          // document banner — shown in the hero instead
        } else {
          kept.add(ln);
        }
      }
      final block = kept.join('\n').trim();
      if (block.isEmpty) continue;
      final lines = block.split('\n');
      final m = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(lines.first.trim());
      if (m != null) {
        sections.add(_PolicySection(
          number: m.group(1)!,
          heading: m.group(2)!.trim(),
          body: lines.skip(1).join('\n').trim(),
          accent: accent,
        ));
      } else {
        sections.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(block,
              style: TextStyle(fontSize: 14, height: 1.6, color: DC.dim)),
        ));
      }
    }

    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            _LegalHeader(title: title, onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                children: [
                  // Hero banner for the document.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent.withOpacity(0.16), accent.withOpacity(0.04)],
                      ),
                      border: Border.all(color: accent.withOpacity(0.20)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 17)),
                            if (updated != null) ...[
                              const SizedBox(height: 3),
                              Text('Updated $updated',
                                  style: TextStyle(fontSize: 11, color: DC.dim)),
                            ],
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ...sections,
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A numbered policy clause rendered as a clean sheet card.
class _PolicySection extends StatelessWidget {
  final String number;
  final String heading;
  final String body;
  final Color accent;
  const _PolicySection({
    required this.number,
    required this.heading,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder()),
        boxShadow: ThemeCtl.isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0B1B33).withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(number,
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(heading,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14, height: 1.25)),
            ),
          ]),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(body,
                style: TextStyle(fontSize: 13.5, height: 1.6, color: DC.dim)),
          ],
        ],
      ),
    );
  }
}

class _LegalHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _LegalHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 10),
      child: Row(children: [
        SizedBox(
          width: 42,
          height: 42,
          child: Material(
            color: _cardColor(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _cardBorder()),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onBack,
              child: const Icon(Icons.arrow_back_rounded, size: 19),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ]),
    );
  }
}

// Accent colours per document — matches the hub cards.
const _cTerms = Color(0xFF3B82F6); // blue
const _cPrivacy = Color(0xFF10B981); // green
const _cRefund = Color(0xFFF59E0B); // amber
const _cShipping = Color(0xFF8B5CF6); // violet
const _cContact = Color(0xFFEC4899); // pink
const _cCommunity = Color(0xFF06B6D4); // cyan
const _cFairPlay = Color(0xFFEF4444); // red

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalScreen(
      title: 'Terms of Service',
      body: kTermsOfService,
      icon: Icons.description_rounded,
      accent: _cTerms);
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalScreen(
      title: 'Privacy Policy',
      body: kPrivacyPolicy,
      icon: Icons.shield_rounded,
      accent: _cPrivacy);
}

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalScreen(
      title: 'Purchases & Refunds',
      body: kRefundPolicy,
      icon: Icons.receipt_long_rounded,
      accent: _cRefund);
}

class ShippingPolicyScreen extends StatelessWidget {
  const ShippingPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalScreen(
      title: 'Rewards & Delivery',
      body: kShippingPolicy,
      icon: Icons.local_shipping_rounded,
      accent: _cShipping);
}

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalScreen(
      title: 'Community Guidelines',
      body: kCommunityGuidelines,
      icon: Icons.groups_rounded,
      accent: _cCommunity);
}

class FairPlayScreen extends StatelessWidget {
  const FairPlayScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalScreen(
      title: 'Fair Play & Anti-Cheat',
      body: kFairPlay,
      icon: Icons.verified_user_rounded,
      accent: _cFairPlay);
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalScreen(
      title: 'Contact Us',
      body: kContactUs,
      icon: Icons.alternate_email_rounded,
      accent: _cContact);
}

/// Hub that lists every legal/policy page, reachable before sign-in.
class PoliciesHubScreen extends StatelessWidget {
  const PoliciesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            _LegalHeader(
                title: 'Legal & Policies',
                onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                children: [
                  const _HubHero(),
                  const SizedBox(height: 18),
                  const _HubSectionLabel('POLICIES'),
                  _PolicyTile(
                    icon: Icons.description_rounded,
                    accent: _cTerms,
                    title: 'Terms of Service',
                    subtitle: 'The rules for using MYNDASH',
                    page: const TermsScreen(),
                  ),
                  _PolicyTile(
                    icon: Icons.shield_rounded,
                    accent: _cPrivacy,
                    title: 'Privacy Policy',
                    subtitle: 'What we collect and your controls',
                    page: const PrivacyScreen(),
                  ),
                  const SizedBox(height: 18),
                  const _HubSectionLabel('PURCHASES'),
                  _PolicyTile(
                    icon: Icons.receipt_long_rounded,
                    accent: _cRefund,
                    title: 'Purchases & Refunds',
                    subtitle: 'Payments, coins and refund status',
                    page: const RefundPolicyScreen(),
                  ),
                  _PolicyTile(
                    icon: Icons.local_shipping_rounded,
                    accent: _cShipping,
                    title: 'Rewards & Delivery',
                    subtitle: 'Store preview and fulfilment',
                    page: const ShippingPolicyScreen(),
                  ),
                  const SizedBox(height: 18),
                  const _HubSectionLabel('COMMUNITY'),
                  _PolicyTile(
                    icon: Icons.groups_rounded,
                    accent: _cCommunity,
                    title: 'Community Guidelines',
                    subtitle: 'How we treat each other here',
                    page: const CommunityGuidelinesScreen(),
                  ),
                  _PolicyTile(
                    icon: Icons.verified_user_rounded,
                    accent: _cFairPlay,
                    title: 'Fair Play & Anti-Cheat',
                    subtitle: 'Keeping every match honest',
                    page: const FairPlayScreen(),
                  ),
                  const SizedBox(height: 18),
                  const _HubSectionLabel('HELP'),
                  _PolicyTile(
                    icon: Icons.alternate_email_rounded,
                    accent: _cContact,
                    title: 'Contact Us',
                    subtitle: 'Reach our support team',
                    page: const ContactScreen(),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B2FD6), Color(0xFF2A1560)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B2FD6).withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.verified_user_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your data, your rights',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              SizedBox(height: 3),
              Text('Transparent policies and easy support.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _HubSectionLabel extends StatelessWidget {
  final String label;
  const _HubSectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(label,
            style: TextStyle(
                color: DC.dim,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900)),
      );
}

class _PolicyTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget page;
  const _PolicyTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardColor(),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorder()),
              boxShadow: ThemeCtl.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF0B1B33).withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(fontSize: 11.5, color: DC.dim)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: DC.dim, size: 22),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

const String kTermsOfService = '''
TERMS OF SERVICE — $kEntityName
Last updated: 19 July 2026

1. ACCEPTANCE
By downloading, installing or using the $kEntityName app ("the App"), you agree to these Terms of Service and our Privacy Policy. If you do not agree, do not use the App.

2. ELIGIBILITY
You must be at least 13 years old to create an account. Users under 12 are placed in Kids Mode with restricted features (no store redemptions and no public social features). If you are under 18, you confirm a parent or guardian has reviewed and agreed to these terms on your behalf.

3. YOUR ACCOUNT
You are responsible for your account and everything that happens on it. Keep your credentials safe. Usernames must not impersonate others or contain offensive language. We may reclaim or rename accounts that violate this.

4. VIRTUAL COINS & XP
Coins and XP are virtual items with no real-world monetary value. They cannot be sold, transferred, or exchanged for cash. Coins may be earned through gameplay. XP can only be earned by playing and is never purchasable. We may adjust economy balancing at any time.

5. STORE & REWARDS
The Store is an upcoming preview. Coin purchases, paid top-ups, reward redemptions and fulfilment are not active in this version. Items shown are illustrative and not an offer for sale.

6. PAYMENTS & MEMBERSHIP
The App does not currently accept payments or sell subscriptions. AI Trainer and the current gameplay features are available without a paid membership. If paid features are introduced later, these terms and the in-app disclosures will be updated before checkout is enabled.

7. FAIR PLAY
No cheating, botting, exploiting bugs, multi-accounting to farm rewards, or interfering with other players. Violations may result in score resets, forfeiture of coins/XP/rewards, suspension, or permanent ban.

8. USER CONDUCT
Do not use the App to harass, threaten or abuse others; post unlawful, hateful or sexually explicit content; or attempt to access other users' data. Squad and community names must be appropriate.

9. CONTESTS & ARENAS
Entry fees, prize pots and payout splits are shown before you join. Ratings are calculated automatically and are final. We may void results affected by outages, bugs or cheating.

10. INTELLECTUAL PROPERTY
The App, its puzzles, artwork, branding and code are owned by $kEntityName or its licensors. You get a personal, non-exclusive, non-transferable licence to use the App. You may not copy, modify, or redistribute it.

11. TERMINATION
You can stop using the App and delete your account at any time from Profile → Delete account. We may suspend or terminate accounts that break these terms. On deletion, your virtual items are forfeited.

12. DISCLAIMERS
The App is provided "as is". We do not guarantee uninterrupted or error-free operation. To the maximum extent permitted by law, $kEntityName is not liable for indirect or consequential damages. Our total liability is limited to the amount you paid us in the previous 12 months.

13. CHANGES
We may update these terms. Material changes will be announced in the App. Continuing to use the App after changes means you accept them.

14. CONTACT
Questions: $kSupportEmail
''';

const String kPrivacyPolicy = '''
PRIVACY POLICY — $kEntityName
Last updated: 19 July 2026

This policy explains what data the $kEntityName app collects, why, and your choices. Contact: $kSupportEmail

1. DATA WE COLLECT
• Account data: display name, unique username, email address (if you sign in with Google or email), and an optional profile photo you choose from your device.
• Age band: asked once at onboarding to enable Kids Mode for under-12s. We store the age you enter, not your date of birth.
• Gameplay data: scores, ratings, levels, stars, streaks, match history, activity counts, and answers to practice questions (used to power your personal AI Trainer — stored on your device).
• Social data: usernames you follow, follow requests, squad and community membership.
• Device data: we use standard Firebase services which may collect device identifiers, IP address and crash diagnostics to operate the service.

2. WHAT WE DO NOT COLLECT
No precise location, no contacts, no microphone, no background camera access. The camera/photo permission is used only when you actively pick a profile photo.

3. HOW WE USE DATA
To run the game (matchmaking, leaderboards and contests), sync your progress, prevent cheating and fraud, personalize AI Trainer insights, and improve the App. We do not sell your personal data and we do not show third-party ads.

4. WHERE DATA LIVES
Progress is stored locally on your device and, when you play online, synced to Google Firebase (Authentication and Realtime Database). Firebase's processing is covered by Google's privacy commitments.

5. KIDS
Users under 12 get a restricted Kids Mode: no store redemptions and no public social features. We do not knowingly collect more data from children than needed to run the game. Parents can request deletion at $kSupportEmail.

6. YOUR RIGHTS & CONTROLS
• Profile privacy: you control what your public profile shows (rating, matches, streak, organisations) in Profile settings.
• Access & correction: edit your name, username and photo in the App.
• Deletion: delete your account and associated data anytime from Profile → Delete account, or email $kSupportEmail. Cloud data is removed within 30 days.
• Sign-out: signing out wipes local progress from the device.

7. DATA RETENTION
Account data is kept while your account is active. Deleted accounts are purged from active systems within 30 days; residual backups expire on their normal cycle.

8. SECURITY
Data in transit is encrypted (HTTPS/TLS). Access to production data is restricted. No system is 100% secure — report concerns to $kSupportEmail.

9. CHANGES
We will announce material changes to this policy in the App.
''';

const String kRefundPolicy = '''
PURCHASES & REFUNDS STATUS — $kEntityName
Last updated: 19 July 2026

1. NO ACTIVE CHECKOUT
The App does not currently accept payments, sell subscriptions, or sell coin packs. No payment provider is integrated in this version.

2. NO CURRENT PURCHASE TO CANCEL
Because checkout is disabled, there is no current recurring membership or in-app purchase to cancel.

3. VIRTUAL ITEMS
Coins and XP are earned through gameplay, carry no real-world monetary value, and are not sold for cash.

4. FUTURE PAYMENTS
If payments are introduced in a later version, the price, provider, fulfilment, cancellation and refund terms will be shown before any purchase.

5. SUPPORT
$kSupportEmail
''';

const String kShippingPolicy = '''
REWARDS & DELIVERY STATUS — $kEntityName
Last updated: 19 July 2026

1. STORE PREVIEW
The in-app Store currently previews possible future coin packs and rewards. Purchases, redemptions, orders, shipping and digital delivery are not active.

2. NO FULFILMENT PROMISE
Items shown in the preview are illustrative and are not presently available to order or redeem.

3. FUTURE AVAILABILITY
Availability, eligibility, fulfilment and delivery terms will be published in the App before the Store is activated.

4. SUPPORT
$kSupportEmail
''';

const String kContactUs = '''
CONTACT US — $kEntityName
Last updated: 19 July 2026

We'd love to hear from you.

Email: $kSupportEmail
Typical response time: within 2 business days.

For app support, account deletion, privacy requests, or Store-preview questions, email the address above and include your registered username so we can help you faster.
''';

const String kCommunityGuidelines = '''
COMMUNITY GUIDELINES — $kEntityName
Last updated: 19 July 2026

1. PLAY WITH RESPECT
$kEntityName is a competitive space for sharp minds. Treat every opponent, squad-mate, and community member with respect. Harassment, hate speech, threats, or discrimination of any kind are not tolerated.

2. KEEP IT CLEAN
Usernames, squad names, org names, and any text you enter must be free of offensive, sexual, or hateful content. We may rename or remove anything that breaches this.

3. NO IMPERSONATION
Do not pretend to be another player, a $kEntityName staff member, or an official account. One person, one identity.

4. PROTECT MINORS
The under-12 Kids zone is a safe, ad-free, payment-free space. Nothing that targets or endangers children is ever acceptable.

5. REPORT, DON'T RETALIATE
If someone breaks these rules, report them to $kSupportEmail instead of responding in kind.

6. ENFORCEMENT
Breaking these guidelines can lead to warnings, feature restrictions, or a permanent ban — at our discretion, to keep the community healthy.
''';

const String kFairPlay = '''
FAIR PLAY & ANTI-CHEAT — $kEntityName
Last updated: 19 July 2026

1. YOUR SKILL, YOUR SCORE
Every rating, streak, and win must come from you actually playing. Ratings and leaderboards only mean something when they're earned.

2. NO CHEATING TOOLS
Bots, scripts, auto-solvers, memory editors, modified clients, and any software that plays for you or alters the game are strictly forbidden.

3. NO COLLUSION OR RESULT-FIXING
Deliberately losing, arranging outcomes, or teaming up to manipulate duels, arenas, contests, or wagers is prohibited.

4. ONE ACCOUNT PER PERSON
Do not create multiple accounts to farm rewards, dodge ratings, or fill your own arenas. Smurfing and multi-accounting can wipe your progress.

5. ECONOMY INTEGRITY
Coins and XP are earned through fair play. Exploiting bugs to duplicate currency, farm bots for rewards, or bypass earning limits is a violation — abuse may be reversed.

6. CONSEQUENCES
Confirmed cheating can cost you your rating, coins, rewards, or account. We investigate reports and act to keep competition fair for everyone.

7. REPORT CHEATERS
Seen something off? Email $kSupportEmail with the username and details.
''';
