import 'dart:async';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

/// =====================================================================
/// FRIENDS SEARCH — debounced autocomplete over the /usernames index,
/// tapping a result opens the player's public profile.
/// =====================================================================
class FriendsSearchScreen extends StatefulWidget {
  /// When embedded as a home tab: no back button, no autofocus (so switching
  /// to the tab doesn't yank up the keyboard).
  final bool embedded;
  const FriendsSearchScreen({super.key, this.embedded = false});

  @override
  State<FriendsSearchScreen> createState() => _FriendsSearchScreenState();
}

class _FriendsSearchScreenState extends State<FriendsSearchScreen> {
  final c = TextEditingController();
  Timer? _debounce;
  bool searching = false;
  List<MapEntry<String, String>> results = []; // username -> uid
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    q = q.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty) {
      setState(() {
        results = [];
        searching = false;
      });
      return;
    }
    setState(() => searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      _lastQuery = q;
      final r = await AccountService.instance.searchUsernames(q);
      if (!mounted || _lastQuery != q) return;
      setState(() {
        results = r;
        searching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = AccountService.instance.online;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
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
                Text('FIND PLAYERS',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Glass(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Icon(Icons.search, size: 20, color: DC.dim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: c,
                      autofocus: !widget.embedded,
                      onChanged: _onChanged,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: DC.cyan),
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'search @username…',
                          hintStyle: TextStyle(color: DC.dim)),
                    ),
                  ),
                  if (searching)
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: DC.cyan)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            if (!online)
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'You\'re offline — player search needs an internet connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DC.dim, fontSize: 13)),
              ),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (c.text.trim().isNotEmpty &&
                    results.isEmpty &&
                    !searching &&
                    online)
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No players found — check the spelling.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DC.dim)),
                  ),
                for (final e in results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(
                                  uid: e.value, username: e.key))),
                      child: Row(children: [
                        CircleAvatar(
                            backgroundColor: DC.violet.withOpacity(0.35),
                            child: Text(e.key[0].toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('@${e.key}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        if (AppData.i.following.contains(e.key))
                          Text('following',
                              style: TextStyle(fontSize: 11, color: DC.lime)),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, color: DC.dim),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// =====================================================================
/// PUBLIC PROFILE — another player's stats from /profiles/{uid}.
/// =====================================================================
class PublicProfileScreen extends StatefulWidget {
  final String uid;
  final String username;
  const PublicProfileScreen(
      {super.key, required this.uid, required this.username});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? profile;
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    AccountService.instance.fetchProfile(widget.uid).then((p) {
      if (mounted) {
        setState(() {
          profile = p;
          loading = false;
        });
      }
    });
  }

  bool get followingThem => AppData.i.following.contains(widget.username);
  bool get requested => AppData.i.sentRequests.contains(widget.username);

  Future<void> _toggleFollow() async {
    setState(() => busy = true);
    final svc = AccountService.instance;
    if (followingThem) {
      await svc.unfollow(widget.username);
    } else if (requested) {
      await svc.cancelFollowRequest(widget.username);
    } else {
      final e = await svc.requestFollow(widget.username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e ??
                'Request sent — @${widget.username} will see it in their requests.')));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final contest = ((p?['contestRating'] as num?) ?? 1500).toInt();
    // Fields the owner hid come back absent — omit their chips entirely
    // rather than showing a misleading default.
    final showElo = p?['elo'] != null;
    final elo = ((p?['elo'] as num?) ?? 800).toInt();
    final org = (p?['company'] as String?)?.trim().isNotEmpty == true
        ? '${p!['company']}'
        : ((p?['college'] as String?)?.trim().isNotEmpty == true
            ? '${p!['college']}'
            : null);
    final tColor = DC.contestColor(contest);
    final recent = (p?['recent'] as List?) ?? [];
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
              Text('PLAYER', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [tColor, DC.violet]),
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  backgroundColor: DC.bg2,
                  child: Text(widget.username[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('@${widget.username}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: DC.cyan)),
            ),
            if (p?['name'] != null)
              Center(
                child: Text('${p!['name']}',
                    style: TextStyle(fontSize: 13, color: DC.dim)),
              ),
            if ((p?['bio'] as String?)?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text('${p!['bio']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: DC.dim)),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: Glass(
                radius: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.workspace_premium, size: 18, color: tColor),
                  const SizedBox(width: 6),
                  Text(DC.contestTitle(contest).toUpperCase(),
                      style: TextStyle(
                          color: tColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              Center(
                  child: Padding(
                padding: EdgeInsets.all(20),
                child:
                    CircularProgressIndicator(strokeWidth: 3, color: DC.cyan),
              ))
            else if (p == null)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'Could not load this profile — they may not have played online yet, or you\'re offline.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DC.dim, fontSize: 13)),
              )
            else ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatChip(label: 'CONTEST', value: '$contest', color: tColor),
                  if (showElo)
                    StatChip(
                        label: 'DUEL ELO', value: '$elo', color: DC.band(elo)),
                  StatChip(
                      label: 'XP',
                      value: '${((p['xp'] as num?) ?? 0).toInt()}',
                      color: DC.cyan),
                ],
              ),
              if (org != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Glass(
                    radius: 16,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text('🏢 $org',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (recent.isNotEmpty) ...[
                Text('RECENT MATCHES',
                    style: TextStyle(
                        fontSize: 10, letterSpacing: 2, color: DC.dim)),
                const SizedBox(height: 8),
                for (final m in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Glass(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch ('${(m as Map)['result']}') {
                              'W' => DC.lime,
                              'L' => DC.danger,
                              _ => DC.amber,
                            },
                          ),
                          child: Center(
                            child: Text('${m['result']}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('${m['mode']}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700))),
                        Text(
                            '${((m['delta'] as num?) ?? 0) >= 0 ? '+' : ''}${m['delta']} · ${m['date']}',
                            style: TextStyle(fontSize: 11, color: DC.dim)),
                      ]),
                    ),
                  ),
              ],
            ],
            const SizedBox(height: 16),
            NeonButton(
              label: busy
                  ? '…'
                  : followingThem
                      ? 'UNFOLLOW'
                      : requested
                          ? 'REQUESTED ✓ (tap to cancel)'
                          : 'FOLLOW',
              icon: followingThem
                  ? Icons.person_remove
                  : requested
                      ? Icons.hourglass_top
                      : Icons.person_add_alt_1,
              colors: (followingThem || requested)
                  ? const [Color(0xFF44475A), Color(0xFF2B2D3A)]
                  : [DC.violet, DC.cyan],
              onPressed: busy ? null : _toggleFollow,
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}
