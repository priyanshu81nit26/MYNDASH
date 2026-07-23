import 'dart:async';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/community_design.dart';

/// ============================================================
/// FIND A SQUAD 🔍 — Clash-style directory.
/// · Debounced prefix autocomplete over the /squad_names index
///   (one indexed range-read per keystroke burst — O(log n)).
/// · Browse feed of top squads by power below the search bar.
/// · Public squads join in one tap; private squads are listed
///   too but ask for their 6-letter code when tapped.
/// ============================================================
class SquadSearchScreen extends StatefulWidget {
  const SquadSearchScreen({super.key});

  @override
  State<SquadSearchScreen> createState() => _SquadSearchScreenState();
}

class _SquadSearchScreenState extends State<SquadSearchScreen> {
  final svc = AccountService.instance;
  final c = TextEditingController();
  Timer? _debounce;
  bool searching = false;
  bool joining = false;
  String _lastQuery = '';
  List<Map<String, dynamic>> results = [];
  List<Map<String, dynamic>>? browse; // null = loading

  @override
  void initState() {
    super.initState();
    svc.listSquads().then((r) {
      if (mounted) setState(() => browse = r ?? []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    c.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    q = q.trim();
    if (q.isEmpty) {
      setState(() {
        results = [];
        searching = false;
      });
      return;
    }
    setState(() => searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      _lastQuery = q;
      final r = await svc.searchSquads(q);
      if (!mounted || _lastQuery != q) return;
      setState(() {
        results = r;
        searching = false;
      });
    });
  }

  Future<void> _tapSquad(Map<String, dynamic> s) async {
    if (joining) return;
    if (AppData.i.squadId.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'You\'re already in a squad — leave it first (one squad at a time).')));
      return;
    }
    final id = '${s['id']}';
    final isPublic = s['public'] == true;
    if (isPublic) {
      setState(() => joining = true);
      final err = await svc.joinPublicSquad(id);
      if (!mounted) return;
      setState(() => joining = false);
      if (err == 'private') {
        _askCode(s); // flipped private since listing
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Welcome to ${s['name']}!')));
      if (err == null) Navigator.pop(context, true);
      return;
    }
    _askCode(s);
  }

  Future<void> _askCode(Map<String, dynamic> s) async {
    final codeC = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CommunityColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.lock_outline_rounded, color: CommunityColors.sky),
        title: Text('${s['name']} is private'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter the squad\'s 6-letter code to join:',
              style: TextStyle(fontSize: 13, color: DC.dim)),
          const SizedBox(height: 10),
          TextField(
              controller: codeC,
              autofocus: true,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4),
              decoration: communityInputDecoration(
                label: 'Six-letter invite code',
                hint: 'ABC123',
                icon: Icons.password_rounded,
              ).copyWith(counterText: '')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, codeC.text.trim()),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => joining = true);
    final err = await svc.joinSquad(code);
    if (!mounted) return;
    setState(() => joining = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Welcome to ${s['name']}!')));
    if (err == null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final showingSearch = c.text.trim().isNotEmpty;
    final list = showingSearch ? results : (browse ?? []);
    final pagePadding = communityPagePadding(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CommunityBackdrop(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                pagePadding.left,
                16,
                pagePadding.right,
                12,
              ),
              child: const CommunityPageHeader(
                title: 'FIND A SQUAD',
                subtitle: 'Search by name or browse the strongest crews.',
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pagePadding.left),
              child: TextField(
                controller: c,
                onChanged: _onChanged,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                decoration: communityInputDecoration(
                  label: 'Search squads',
                  hint: 'Start typing a squad name',
                  icon: Icons.search_rounded,
                  helper:
                      'Public squads join instantly; private squads use a code.',
                ).copyWith(
                  suffixIcon: searching
                      ? Padding(
                          padding: const EdgeInsets.all(15),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: CommunityColors.mint,
                            ),
                          ),
                        )
                      : c.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                c.clear();
                                _onChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pagePadding.left),
              child: CommunitySectionTitle(
                icon: showingSearch
                    ? Icons.manage_search_rounded
                    : Icons.leaderboard_outlined,
                title: showingSearch ? 'SEARCH RESULTS' : 'TOP SQUADS BY POWER',
                trailing: Row(
                  children: [
                    Icon(Icons.public_rounded,
                        size: 14, color: CommunityColors.mint),
                    const SizedBox(width: 3),
                    Text('OPEN', style: TextStyle(color: DC.dim, fontSize: 9)),
                    const SizedBox(width: 8),
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: CommunityColors.sky),
                    const SizedBox(width: 3),
                    Text('CODE', style: TextStyle(color: DC.dim, fontSize: 9)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: browse == null && !showingSearch
                  ? Center(
                      child: CircularProgressIndicator(
                          color: CommunityColors.mint))
                  : list.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group_off_outlined,
                                    color: CommunityColors.sky, size: 36),
                                const SizedBox(height: 10),
                                Text(
                                  showingSearch
                                      ? (searching
                                          ? 'Searching…'
                                          : 'No squads match this name.')
                                      : 'No squads are listed yet.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  showingSearch
                                      ? 'Try a shorter name or create the crew you want.'
                                      : 'Create the first squad and start recruiting.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: DC.dim, fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            pagePadding.left,
                            4,
                            pagePadding.right,
                            24,
                          ),
                          itemCount: list.length,
                          itemBuilder: (context, i) => _row(list[i]),
                        ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final isPublic = s['public'] == true;
    final members = (s['members'] as num?)?.toInt() ?? 0;
    final full = members >= AccountService.squadMaxMembers;
    final accent = isPublic ? CommunityColors.mint : CommunityColors.sky;
    final location = '${s['location'] ?? ''}'.trim();
    final power = (s['power'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: CommunityColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: CommunityColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: full ? null : () => _tapSquad(s),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(color: accent.withValues(alpha: 0.32)),
                  ),
                  child: Icon(
                    isPublic ? Icons.public_rounded : Icons.lock_rounded,
                    size: 25,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${s['name'] ?? 'Unnamed squad'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Icon(
                            isPublic
                                ? Icons.visibility_rounded
                                : Icons.key_rounded,
                            size: 15,
                            color: accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '[${s['tag'] ?? 'SQD'}]  •  $members/${AccountService.squadMaxMembers} members',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (location.isNotEmpty || power != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (location.isNotEmpty) location,
                            if (power != null) '$power XP power',
                          ].join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: (full
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : accent)
                        .withValues(alpha: 0.11),
                    border: Border.all(
                      color: (full
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : accent)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    full
                        ? 'FULL'
                        : isPublic
                            ? 'JOIN'
                            : 'CODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: full
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
