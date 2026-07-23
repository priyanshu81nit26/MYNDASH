import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/art.dart';
import '../ui/community_design.dart';
import '../ui/glass.dart';
import 'friends_search.dart';
import 'squad_mania.dart';
import 'squad_search.dart';

/// ============================================================
/// SQUADS — Clash-style clans, max 10 minds.
/// Public squads join in one tap; private ones need the code.
/// One squad at a time; leave anytime. SQUAD MANIA — the monthly
/// inter-squad war — lives at the top with a live countdown.
/// ============================================================
class SquadsScreen extends StatefulWidget {
  const SquadsScreen({super.key});

  @override
  State<SquadsScreen> createState() => _SquadsScreenState();
}

class _SquadsScreenState extends State<SquadsScreen> {
  final svc = AccountService.instance;
  Map<String, dynamic>? squad;
  bool loading = true;
  bool unreachable = false; // squad fetch hit a network error (not deletion)
  Timer? ticker; // keeps the Mania countdown alive

  @override
  void initState() {
    super.initState();
    _load();
    ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  /// The Squad Mania banner: stage + live timer. Hidden until v2.
  // ignore: unused_element
  Widget _maniaBanner() {
    final (st, _, nextAt) = maniaStageFor(DateTime.now());
    final left = nextAt.difference(DateTime.now());
    return GestureDetector(
      onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SquadManiaScreen()))
          .then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: [
            DC.amber.withValues(alpha: 0.26),
            DC.magenta.withValues(alpha: 0.15),
          ]),
          border: Border.all(color: DC.amber.withValues(alpha: 0.55)),
        ),
        child: Row(children: [
          const MyndArt(theme: 'mania', size: 58),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SQUAD MANIA',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: DC.amber)),
              Text(maniaStageLabel(st),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
              Text(
                  st == ManiaStage.results
                      ? 'next war in ${fmtLeftLong(left)} · every 1st of the month'
                      : 'next stage in ${fmtLeftLong(left)} · 10-coin entry per squad',
                  style: TextStyle(fontSize: 10, color: DC.dim)),
            ]),
          ),
          Icon(Icons.chevron_right, color: DC.amber),
        ]),
      ),
    );
  }

  /// Opens a member's public profile. Older member entries saved before
  /// uid tracking was added fall back to a username lookup.
  Future<void> _openProfile(String username, String? uid) async {
    final id = uid ?? await svc.findUser(username);
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load @$username\'s profile.')));
      }
      return;
    }
    if (!mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PublicProfileScreen(uid: id, username: username)));
  }

  Future<void> _load() async {
    if (AppData.i.squadId.isEmpty) {
      setState(() {
        loading = false;
        squad = null;
        unreachable = false;
      });
      return;
    }
    setState(() {
      loading = true;
      unreachable = false;
    });
    Map<String, dynamic>? s;
    try {
      s = await svc.fetchSquad();
    } catch (_) {
      // Genuine network/permission error — keep the membership and let
      // the user retry, don't wipe their squad over a transient blip.
      if (mounted) {
        setState(() {
          squad = null;
          unreachable = true;
          loading = false;
        });
      }
      return;
    }
    // Read succeeded but the squad is gone → it was deleted. Clear the
    // stale local membership so the user can create/join a fresh one.
    if (s == null) {
      await svc.clearSquadLocal();
      if (mounted) {
        setState(() {
          squad = null;
          loading = false;
        });
      }
      return;
    }
    // Self-heal the admin flag from the squad's `leader` field.
    final amLeader = s['leader'] == AppData.i.username;
    if (amLeader != AppData.i.isSquadLeader) {
      AppData.i.isSquadLeader = amLeader;
      await AppData.i.save();
    }
    if (mounted) {
      setState(() {
        squad = s;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CommunityBackdrop(
        child: SafeArea(
          child: ListView(padding: communityPagePadding(context), children: [
            CommunityPageHeader(
              title: 'SQUADS',
              subtitle: AppData.i.squadName.isEmpty
                  ? 'Find your crew and combine your power.'
                  : 'Your crew, shared XP and member ranking.',
              trailing: AppData.i.squadId.isEmpty
                  ? null
                  : CommunityIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh squad',
                      onTap: loading ? null : _load,
                    ),
            ),
            const SizedBox(height: 16),
            // Squad Mania ships in v2 — hidden for now.
            // _maniaBanner(),
            if (loading)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: CircularProgressIndicator(
                          color: CommunityColors.mint)))
            else if (AppData.i.squadId.isEmpty)
              ..._noSquad()
            else
              ..._mySquad(),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  // ---------------- no squad yet ----------------

  List<Widget> _noSquad() => [
        CommunityHeroCard(
          icon: Icons.groups_3_rounded,
          eyebrow: 'YOUR CREW',
          title: 'Stronger together.',
          subtitle: 'Create a squad or join an existing crew. Up to '
              '${AccountService.squadMaxMembers} minds combine earned XP into '
              'Squad Power—progress comes from playing, not shortcuts.',
          metrics: [
            const CommunityMetric(
              icon: Icons.people_alt_outlined,
              value: '${AccountService.squadMaxMembers}',
              label: 'member limit',
            ),
            CommunityMetric(
              icon: Icons.bolt_outlined,
              value: 'SHARED',
              label: 'squad power',
              color: CommunityColors.sky,
            ),
          ],
        ),
        const SizedBox(height: 14),
        NeonButton(
            label: 'FIND A SQUAD',
            icon: Icons.search_rounded,
            colors: CommunityColors.actionGradient,
            onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SquadSearchScreen()))
                .then((_) => _load())),
        const SizedBox(height: 10),
        NeonButton(
            label: 'CREATE A SQUAD',
            icon: Icons.add_rounded,
            colors: CommunityColors.actionGradient,
            onPressed: _create),
        const SizedBox(height: 10),
        GhostButton(
          label: 'JOIN WITH CODE',
          icon: Icons.key_rounded,
          onPressed: _join,
        ),
      ];

  Future<void> _create() async {
    final name = TextEditingController();
    final location = TextEditingController();
    var isPublic = true;
    String? dialogError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: CommunityColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Icon(Icons.groups_3_outlined, color: CommunityColors.mint),
          title: const Text('Create your squad'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              decoration: communityInputDecoration(
                label: 'Squad name',
                hint: 'Choose a unique name',
                icon: Icons.badge_outlined,
              ).copyWith(counterText: '', errorText: dialogError),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: location,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              decoration: communityInputDecoration(
                label: 'Location · optional',
                hint: 'e.g. Mumbai, India',
                icon: Icons.location_on_outlined,
              ).copyWith(counterText: ''),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              activeThumbColor: CommunityColors.sky,
              secondary: Icon(
                isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                color: CommunityColors.sky,
              ),
              title: Text(
                isPublic ? 'Public squad' : 'Private squad',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                  isPublic
                      ? 'Anyone can find your squad in search and join in one tap.'
                      : 'Still listed in search, but joining needs the 6-letter code you share.',
                  style: TextStyle(fontSize: 11, color: DC.dim)),
              value: !isPublic,
              onChanged: (v) => setD(() => isPublic = !v),
            ),
            const SizedBox(height: 4),
            Text(
                'You become the squad admin — only you can enter the squad into events.',
                style: TextStyle(fontSize: 11, color: DC.dim, height: 1.4)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () {
                if (name.text.trim().length < 3) {
                  setD(() => dialogError = 'Use at least 3 characters.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final (err, code) = await svc.createSquad(name.text.trim(),
        isPublic: isPublic, location: location.text.trim());
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (code != null) {
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: CommunityColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Icon(Icons.verified_rounded, color: CommunityColors.mint),
          title: const Text('Squad created'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Share this private invite code with your crew.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DC.dim, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient:
                      LinearGradient(colors: CommunityColors.actionGradient),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(c).showSnackBar(
                        const SnackBar(content: Text('Invite code copied.')));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(code,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(c), child: const Text('Done')),
          ],
        ),
      );
    }
    _load();
  }

  Future<void> _join() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CommunityColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.key_rounded, color: CommunityColors.sky),
        title: const Text('Join with invite code'),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
            decoration: communityInputDecoration(
              label: 'Six-letter squad code',
              hint: 'ABC123',
              icon: Icons.password_rounded,
            ).copyWith(counterText: '')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    final err = await svc.joinSquad(code);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    _load();
  }

  // ---------------- my squad ----------------

  List<Widget> _mySquad() {
    final s = squad;
    if (s == null) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CommunityColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: CommunityColors.border),
          ),
          child: Column(children: [
            Icon(Icons.cloud_off_outlined,
                color: CommunityColors.sky, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Squad temporarily unavailable',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 5),
            Text(
              unreachable
                  ? 'Your membership is safe. Check your connection and retry.'
                  : 'The squad could not be loaded. Try refreshing the page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 14),
            NeonButton(
              label: 'RETRY',
              icon: Icons.refresh_rounded,
              height: 46,
              colors: CommunityColors.actionGradient,
              onPressed: _load,
            ),
            const SizedBox(height: 8),
            GhostButton(
              label: 'RESET LOCAL MEMBERSHIP',
              icon: Icons.logout_rounded,
              height: 46,
              onPressed: () => _confirmLeave(clearLocalOnly: true),
            ),
          ]),
        ),
      ];
    }
    final members = <MapEntry<String, Map<String, dynamic>>>[];
    ((s['members'] as Map?) ?? {}).forEach((k, v) {
      members.add(MapEntry('$k', Map<String, dynamic>.from(v as Map)));
    });
    members.sort((a, b) =>
        ((b.value['xp'] as num?) ?? 0).compareTo((a.value['xp'] as num?) ?? 0));
    final power = members.fold<int>(
        0, (sum, m) => sum + ((m.value['xp'] as num?)?.toInt() ?? 0));
    // Squad level climbs with combined earned XP (pure grind).
    final level = 1 + power ~/ 1000;
    final trophies = (s['trophies'] as num?)?.toInt() ?? 0;
    final location = '${s['location'] ?? ''}'.trim();
    final leaderName = '${s['leader'] ?? ''}';
    final isPublic = s['public'] == true;
    final motto = '${s['motto'] ?? ''}'.trim();
    return [
      CommunityHeroCard(
        icon: Icons.groups_3_rounded,
        eyebrow:
            '${isPublic ? 'PUBLIC' : 'PRIVATE'} SQUAD${AppData.i.isSquadLeader ? ' · YOU ARE ADMIN' : ''}',
        title: '${s['name']}',
        subtitle: motto.isNotEmpty
            ? motto
            : 'Every member’s earned XP contributes to one shared power score.',
        metrics: [
          CommunityMetric(
            icon: Icons.military_tech_outlined,
            value: '$level',
            label: 'level',
          ),
          CommunityMetric(
            icon: Icons.people_alt_outlined,
            value: '${members.length}/${AccountService.squadMaxMembers}',
            label: 'members',
            color: CommunityColors.sky,
          ),
          CommunityMetric(
            icon: Icons.emoji_events_outlined,
            value: '$trophies',
            label: 'trophies',
          ),
          CommunityMetric(
            icon: Icons.bolt_outlined,
            value: '$power XP',
            label: 'squad power',
            color: CommunityColors.sky,
          ),
          if (location.isNotEmpty)
            CommunityMetric(
              icon: Icons.location_on_outlined,
              value: location,
              label: 'location',
            ),
        ],
      ),
      const SizedBox(height: 12),
      _inviteCodeCard('${s['code'] ?? ''}', isPublic),
      const SizedBox(height: 16),
      CommunitySectionTitle(
        icon: Icons.leaderboard_rounded,
        title: 'MEMBER LEADERBOARD',
        trailing: Text(
          '${members.length} members',
          style: TextStyle(color: DC.dim, fontSize: 10.5),
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < members.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _squadMemberRow(
            index: i,
            entry: members[i],
            leaderName: leaderName,
          ),
        ),
      const SizedBox(height: 10),
      GhostButton(
          label: 'LEAVE SQUAD',
          icon: Icons.logout_rounded,
          onPressed: _confirmLeave),
    ];
  }

  Widget _inviteCodeCard(String code, bool isPublic) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CommunityColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CommunityColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: CommunityColors.skySoft,
            ),
            child: Icon(
              isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
              color: CommunityColors.sky,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPublic ? 'Public joining is open' : 'Private invite code',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  code.isEmpty ? 'No invite code available' : code,
                  style: TextStyle(
                    color: CommunityColors.mint,
                    fontWeight: FontWeight.w900,
                    letterSpacing: code.isEmpty ? 0 : 3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Copy squad invite code',
              onPressed: code.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied.')),
                      );
                    },
              icon: const Icon(Icons.copy_rounded),
              style: IconButton.styleFrom(
                backgroundColor: CommunityColors.mintSoft,
                foregroundColor: CommunityColors.mint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _squadMemberRow({
    required int index,
    required MapEntry<String, Map<String, dynamic>> entry,
    required String leaderName,
  }) {
    final isLeader = entry.key == leaderName;
    final mine = entry.key == AppData.i.username;
    final xp = (entry.value['xp'] as num?)?.toInt() ?? 0;
    final elo = (entry.value['elo'] as num?)?.toInt() ?? 800;
    final contest = (entry.value['contestRating'] as num?)?.toInt() ?? 1500;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: mine ? CommunityColors.mintSoft : CommunityColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mine ? CommunityColors.mint : CommunityColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openProfile(entry.key, entry.value['uid'] as String?),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (isLeader ? CommunityColors.mint : CommunityColors.sky)
                            .withValues(alpha: 0.12),
                  ),
                  child: isLeader
                      ? Icon(Icons.shield_outlined,
                          color: CommunityColors.mint, size: 20)
                      : Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: CommunityColors.sky,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${entry.key}${mine ? ' · YOU' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${isLeader ? 'ADMIN · ' : ''}Elo $elo · Contest $contest',
                        style: TextStyle(color: DC.dim, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$xp XP',
                  style: TextStyle(
                    color: CommunityColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeave({bool clearLocalOnly = false}) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CommunityColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.logout_rounded, color: DC.danger),
        title: Text(clearLocalOnly ? 'Reset membership?' : 'Leave squad?'),
        content: Text(
          clearLocalOnly
              ? 'Use this only if the squad no longer exists or cannot be '
                  'reached. It clears the saved membership on this device.'
              : 'You will leave the squad and stop contributing to its shared '
                  'power. You can join another squad afterward.',
          style: TextStyle(color: DC.dim, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DC.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(clearLocalOnly ? 'Reset' : 'Leave'),
          ),
        ],
      ),
    );
    if (leave != true) return;
    if (clearLocalOnly) {
      await svc.clearSquadLocal();
    } else {
      await svc.leaveSquad();
    }
    await _load();
  }
}
