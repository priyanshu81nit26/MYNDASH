import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

/// Coin gate for paid entries (contests, arenas, wagers). Returns true if the
/// player can afford [cost] — deduction is the caller's job. If short, it
/// points the player to earning options and the upcoming Store preview.
Future<bool> ensureCoins(BuildContext context, int cost, String purpose) async {
  final a = AppData.i;
  if (a.coins >= cost) return true;
  final short = cost - a.coins;
  final buy = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Need more coins'),
      content: Text(
          'You need $short more coins to $purpose.\n\nCoin purchases are not '
          'available yet. Earn coins through Daily, contests, arenas and games.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Not now')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('View upcoming Store')),
      ],
    ),
  );
  if (buy == true && context.mounted) {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const StoreScreen()));
  }
  return false;
}

/// Full-screen Store (pushed from the Home quick card, now that the navbar
/// slot is the Profile). Wraps [StoreTab] with a background + back button.
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: ShaderBackground(child: const StoreTab(embedded: false)),
      );
}

class StoreTab extends StatefulWidget {
  /// Embedded in the home pager (no back button) vs pushed full-screen.
  final bool embedded;
  const StoreTab({super.key, this.embedded = true});

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  int tab = 0;

  // Preview-only coin packs for the future v2 economy. No currency, checkout,
  // purchase callback, or entitlement is active in this version.
  static const packs = [
    (1000, 'STARTER PREVIEW'),
    (5500, 'BOOST PREVIEW'),
    (12000, 'VAULT PREVIEW'),
    (30000, 'LEGEND PREVIEW'),
  ];

  /// Real-brand prize wall. Redeeming an item worth X coins ALSO needs
  /// earned XP >= 5X — XP can never be bought, so wallets alone can't
  /// shortcut their way to prizes. Play to earn the flex.
  static const merch = [
    ('🧢', 'MYNDASH Pro Cap', 1999),
    ('👕', 'MYNDASH Hoodie', 2999),
    ('🧩', 'GAN Speed Cube', 3499),
    ('⌚', 'Samsung Galaxy Watch', 5999),
    ('🏸', 'Yonex Mavis Racket', 7999),
    ('👟', 'Nike Air Max', 9999),
    ('🏏', 'BAT Cricket Bat', 10000),
    ('🎧', 'boAt Airdopes', 12999),
    ('📚', 'Kindle Paperwhite', 24999),
    ('🔊', 'JBL Flip 6', 30000),
    ('🎧', 'Sony WH-1000XM5', 49999),
    ('🎮', 'PlayStation 5', 99999),
    ('📱', 'iPhone 16', 149999),
  ];

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (!widget.embedded) ...[
              Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, size: 18)),
              const SizedBox(width: 12),
            ],
            Text('STORE', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(width: 8),
            Pill(
                icon: Icons.schedule_rounded,
                label: 'UPCOMING',
                color: DC.amber),
            const Spacer(),
            Pill(icon: Icons.bolt, label: '${a.xp} XP', color: DC.cyan),
            const SizedBox(width: 8),
            Pill(
                icon: Icons.monetization_on,
                label: '${a.coins}',
                color: DC.amber),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final (i, label) in const [
              (0, 'COINS'),
              (1, 'REWARDS'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => tab = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: tab == i
                          ? LinearGradient(colors: [DC.violet, DC.cyan])
                          : null,
                      color: tab == i ? null : DC.fgo(0.06),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight:
                                tab == i ? FontWeight.w900 : FontWeight.w500)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (tab) {
            0 => _coins(context),
            _ => _merch(context),
          },
        ),
      ]),
    );
  }

  Widget _coins(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        radius: 18,
        tint: DC.amber,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.lock_clock, size: 18, color: DC.amber),
            const SizedBox(width: 8),
            const Text('COIN TOP-UPS · COMING IN v2',
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          Text(
            '🪙 Coins remain your competitive fuel for contests, arenas and 1v1 '
            'wagers. This page is a preview only: there is no payment provider or '
            'coin checkout in v1. Earn coins by playing.',
            style: TextStyle(fontSize: 11, color: DC.text, height: 1.4),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // Preview of the packs that unlock in v2 — shown but not purchasable.
      for (final (coins, label) in packs)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Opacity(
            opacity: 0.9,
            child: Glass(
              child: Row(children: [
                const Text('🪙', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$coins coins',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        Text(label,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: DC.dim)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: DC.amber.withOpacity(0.16),
                    border: Border.all(color: DC.amber.withOpacity(0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_clock, size: 13, color: DC.amber),
                    const SizedBox(width: 5),
                    Text('UPCOMING',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                            color: DC.amber)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _merch(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Glass(
        radius: 18,
        tint: DC.violet,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.rocket_launch_rounded, size: 18, color: DC.violet),
            const SizedBox(width: 8),
            const Text('PRIZE WALL · COMING IN v2',
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Real prizes drop in the next update. Keep stacking coins (win duels, '
            'arenas & contests) and earned XP now — they\'ll be ready to spend the '
            'moment the wall opens.',
            style: TextStyle(fontSize: 11, color: DC.text, height: 1.4),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (final (emoji, name, _) in merch)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _upcomingCard(emoji, name),
        ),
    ]);
  }

  /// Teaser card — shows what's coming, but no price and no redeem until v2.
  Widget _upcomingCard(String emoji, String name) {
    return Opacity(
      opacity: 0.9,
      child: Glass(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: DC.violet.withOpacity(0.16),
              border: Border.all(color: DC.violet.withOpacity(0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_clock, size: 13, color: DC.violet),
              const SizedBox(width: 5),
              Text('UPCOMING',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900,
                      color: DC.violet)),
            ]),
          ),
        ]),
      ),
    );
  }
}
