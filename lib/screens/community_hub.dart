import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import '../ui/community_design.dart';
import 'community_screen.dart';
import 'squads_screen.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  @override
  void initState() {
    super.initState();
    AppData.i.addListener(_refresh);
  }

  @override
  void dispose() {
    AppData.i.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = AppData.i;
    final connected = [
      data.squadName,
      data.college,
      data.company,
    ].where((value) => value.isNotEmpty).length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CommunityBackdrop(
        child: SafeArea(
          child: ListView(
            padding: communityPagePadding(context),
            children: [
              const CommunityPageHeader(
                title: 'COMMUNITY',
                subtitle: 'Squad up, represent your campus or join your team.',
              ),
              const SizedBox(height: 20),
              CommunityHeroCard(
                icon: Icons.diversity_3_rounded,
                eyebrow: 'YOUR MYNDASH NETWORK',
                title: 'Build your circle.\nRaise your rank.',
                subtitle:
                    'Three verified spaces, one competitive identity. Find '
                    'your people, enter private arenas and climb together.',
                metrics: [
                  CommunityMetric(
                    icon: Icons.link_rounded,
                    value: '$connected/3',
                    label: 'spaces connected',
                  ),
                  CommunityMetric(
                    icon: Icons.shield_outlined,
                    value: 'VERIFIED',
                    label: 'organization access',
                    color: CommunityColors.sky,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const CommunitySectionTitle(
                icon: Icons.explore_outlined,
                title: 'CHOOSE YOUR SPACE',
              ),
              const SizedBox(height: 10),
              _spaceCards(context, data),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CommunityColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: CommunityColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: CommunityColors.mintSoft,
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: CommunityColors.mint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verified spaces, safer competition',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'College and Corporate require a one-time email '
                            'code on the real domain. Free-mail addresses '
                            'cannot claim an organization.',
                            style: TextStyle(
                              color: DC.dim,
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spaceCards(BuildContext context, AppData data) {
    final cards = <Widget>[
      CommunityCard(
        icon: Icons.groups_3_outlined,
        title: data.squadName.isEmpty ? 'Squad' : data.squadName,
        subtitle: data.squadName.isEmpty
            ? 'Create or join a crew of up to 10 minds and combine your XP.'
            : 'Your crew, shared power and member leaderboard.',
        status: data.squadName.isEmpty ? 'CREATE / JOIN' : 'ACTIVE',
        primary: true,
        onTap: () => _open(const SquadsScreen()),
      ),
      CommunityCard(
        icon: Icons.school_outlined,
        title: data.college.isEmpty ? 'College' : data.college,
        subtitle: data.college.isEmpty
            ? 'Verify your campus email and represent your college.'
            : 'Campus ranking, members and college-only arenas.',
        status: data.college.isEmpty ? 'VERIFY' : 'CONNECTED',
        onTap: () => _open(const CommunityScreen(type: 'college')),
      ),
      CommunityCard(
        icon: Icons.business_outlined,
        title: data.company.isEmpty ? 'Corporate' : data.company,
        subtitle: data.company.isEmpty
            ? 'Verify your work email and compete with colleagues.'
            : 'Workplace ranking, members and organization arenas.',
        status: data.company.isEmpty ? 'VERIFY' : 'CONNECTED',
        primary: true,
        onTap: () => _open(const CommunityScreen(type: 'company')),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}
