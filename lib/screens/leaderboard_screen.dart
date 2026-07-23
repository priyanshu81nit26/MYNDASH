import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/glass.dart';
import 'friends_search.dart';

/// ============================================================
/// LEADERBOARDS HUB — Global 🌍 · Corporate 🏢 · College 🎓 ·
/// Friends 🤝. Each detail page pins YOUR rank up top in a hero
/// card, then pages the field 15 at a time (1-15, 16-30, …).
/// ============================================================
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final boards = <(String, String, String, List<Color>, bool)>[
      ('global', '🌍', 'GLOBAL', [DC.cyan, DC.violet], true),
      (
        'company',
        '🏢',
        a.company.isEmpty ? 'CORPORATE' : a.company.toUpperCase(),
        [DC.amber, DC.magenta],
        a.company.isNotEmpty
      ),
      (
        'college',
        '🎓',
        a.college.isEmpty ? 'COLLEGE' : a.college.toUpperCase(),
        [DC.lime, DC.cyan],
        a.college.isNotEmpty
      ),
      (
        'friends',
        '🤝',
        'FRIENDS',
        [DC.magenta, DC.violet],
        a.following.isNotEmpty || a.friends.isNotEmpty
      ),
    ];
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, size: 18)),
              const SizedBox(width: 12),
              Text('LEADERBOARDS',
                  style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 16),
            for (final (type, emoji, title, colors, unlocked) in boards)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: unlocked
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LeaderboardDetail(type: type)))
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(colors: [
                        colors[0].withOpacity(unlocked ? 0.35 : 0.08),
                        colors[1].withOpacity(unlocked ? 0.15 : 0.04),
                      ]),
                      border: Border.all(
                          color: colors[0].withOpacity(unlocked ? 0.5 : 0.15)),
                    ),
                    child: Row(children: [
                      Text(emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                      fontSize: 15,
                                      color: unlocked ? DC.text : DC.dim)),
                              Text(
                                  switch (type) {
                                    'global' =>
                                      'every mind on MYNDASH · full ranking',
                                    'company' => unlocked
                                        ? 'your workplace rivals'
                                        : 'join a corporate space to unlock',
                                    'college' => unlocked
                                        ? 'your campus rivals'
                                        : 'join a college space to unlock',
                                    _ => unlocked
                                        ? 'people you follow & friends'
                                        : 'follow someone to unlock',
                                  },
                                  style:
                                      TextStyle(fontSize: 11, color: DC.dim)),
                            ]),
                      ),
                      Icon(unlocked ? Icons.chevron_right : Icons.lock,
                          color: DC.dim, size: 20),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// ---------------- detail: hero rank + paged field ----------------
class LeaderboardDetail extends StatefulWidget {
  final String type; // global | company | college | friends
  const LeaderboardDetail({super.key, required this.type});

  @override
  State<LeaderboardDetail> createState() => _LeaderboardDetailState();
}

class _LeaderboardDetailState extends State<LeaderboardDetail> {
  List<Map<String, dynamic>>? rows; // {username, contestRating, uid?}
  bool loading = true;
  int page = 0;
  static const perPage = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = AccountService.instance;
    final a = AppData.i;
    List<Map<String, dynamic>> out = [];
    switch (widget.type) {
      case 'global':
        out = (await svc.fetchLeaderboard()) ?? [];
        break;
      case 'company':
      case 'college':
        final org = await svc.fetchOrg(
            widget.type, widget.type == 'company' ? a.company : a.college);
        ((org?['members'] as Map?) ?? {}).forEach((k, v) {
          final m = Map<String, dynamic>.from(v as Map);
          m['username'] = '$k';
          out.add(m);
        });
        break;
      case 'friends':
        final names = {...a.following, ...a.friends}.take(30);
        for (final u in names) {
          final id = await svc.findUser(u);
          if (id == null) continue;
          final p = await svc.fetchProfile(id);
          if (p != null) {
            p['username'] = u;
            p['uid'] = id;
            out.add(p);
          }
        }
        // include yourself in the friends race
        out.add({
          'username': a.username,
          'contestRating': a.contestRating,
        });
        break;
    }
    out.sort((x, y) => ((y['contestRating'] as num?) ?? 0)
        .compareTo((x['contestRating'] as num?) ?? 0));
    if (mounted) {
      setState(() {
        rows = out;
        loading = false;
      });
    }
  }

  int get myIndex {
    final me = AppData.i.username;
    return rows?.indexWhere((r) => r['username'] == me) ?? -1;
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final title = switch (widget.type) {
      'global' => '🌍 GLOBAL',
      'company' => '🏢 ${a.company.toUpperCase()}',
      'college' => '🎓 ${a.college.toUpperCase()}',
      _ => '🤝 FRIENDS',
    };
    final total = rows?.length ?? 0;
    final pages = (total / perPage).ceil().clamp(1, 99);
    if (page >= pages) page = pages - 1;
    final visible = (rows ?? []).skip(page * perPage).take(perPage).toList();

    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: DC.cyan,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  Glass(
                      radius: 16,
                      padding: const EdgeInsets.all(8),
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, size: 18)),
                  const SizedBox(width: 12),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 16),
                // ------- YOUR HERO CARD -------
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(colors: [
                      DC.contestColor(a.contestRating).withOpacity(0.45),
                      DC.violet.withOpacity(0.25),
                    ]),
                    border: Border.all(color: DC.contestColor(a.contestRating)),
                    boxShadow: [
                      BoxShadow(
                          color:
                              DC.contestColor(a.contestRating).withOpacity(0.3),
                          blurRadius: 20),
                    ],
                  ),
                  child: Row(children: [
                    Column(children: [
                      Text(myIndex >= 0 ? '#${myIndex + 1}' : '—',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w900)),
                      Text('YOUR RANK',
                          style: TextStyle(
                              fontSize: 8, letterSpacing: 2, color: DC.dim)),
                    ]),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${a.username}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(DC.contestTitle(a.contestRating),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: DC.contestColor(a.contestRating))),
                          ]),
                    ),
                    Text('${a.contestRating}',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: DC.contestColor(a.contestRating))),
                  ]),
                ),
                const SizedBox(height: 18),
                if (loading)
                  Center(
                      child: Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator(color: DC.cyan)))
                else if (rows!.isEmpty)
                  Glass(
                      child: Text('Nobody here yet — bring the competition!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: DC.dim)))
                else ...[
                  Text('TOP ${rows!.length} · page ${page + 1}/$pages',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 2, color: DC.dim)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < visible.length; i++)
                    _row(page * perPage + i, visible[i]),
                  if (pages > 1) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var pi = 0; pi < pages; pi++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => page = pi),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: page == pi
                                        ? LinearGradient(
                                            colors: [DC.violet, DC.cyan])
                                        : null,
                                    color: page == pi
                                        ? null
                                        : Colors.white.withOpacity(0.06),
                                  ),
                                  child: Center(
                                      child: Text(
                                          '${pi * perPage + 1}–${((pi + 1) * perPage).clamp(1, rows!.length)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800))),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(int rank, Map<String, dynamic> r) {
    final username = '${r['username'] ?? '?'}';
    final rating = ((r['contestRating'] as num?) ?? 1500).toInt();
    final me = username == AppData.i.username;
    final uid = r['uid'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        tint: me ? DC.cyan : null,
        border: me ? Border.all(color: DC.cyan, width: 1.4) : null,
        onTap: uid == null && !me
            ? null
            : () async {
                final id =
                    uid ?? await AccountService.instance.findUser(username);
                if (id != null && context.mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(
                              uid: id, username: username)));
                }
              },
        child: Row(children: [
          SizedBox(
            width: 38,
            child: Text(
                switch (rank) {
                  0 => '🥇',
                  1 => '🥈',
                  2 => '🥉',
                  _ => '#${rank + 1}',
                },
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          CircleAvatar(
            radius: 14,
            backgroundColor: DC.contestColor(rating).withOpacity(0.25),
            child: Text(username.isEmpty ? '?' : username[0].toUpperCase(),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@$username${me ? ' (you)' : ''}',
                  style: TextStyle(
                      fontWeight: me ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 13)),
              Text(DC.contestTitle(rating),
                  style:
                      TextStyle(fontSize: 10, color: DC.contestColor(rating))),
            ]),
          ),
          Text('$rating',
              style: TextStyle(
                  color: DC.contestColor(rating), fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}
