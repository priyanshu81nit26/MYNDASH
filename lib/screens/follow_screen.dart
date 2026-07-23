import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/glass.dart';
import 'friends_search.dart';

/// =====================================================================
/// FOLLOWERS / FOLLOWING / REQUESTS — Instagram-style full page.
/// · ListView.builder everywhere → rows are built lazily, so even a
///   10 000-name list scrolls at 60fps (nothing is materialised until
///   it enters the viewport).
/// · One cloud read on open (syncSocial) — everything else is local.
/// · Search box filters in-memory, no network.
/// =====================================================================
class FollowScreen extends StatefulWidget {
  /// 0 = Followers · 1 = Following · 2 = Requests
  final int initialTab;
  const FollowScreen({super.key, this.initialTab = 0});

  @override
  State<FollowScreen> createState() => _FollowScreenState();
}

class _FollowScreenState extends State<FollowScreen>
    with SingleTickerProviderStateMixin {
  final a = AppData.i;
  final svc = AccountService.instance;
  late final TabController tabs =
      TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  final search = TextEditingController();
  String q = '';
  bool refreshing = true;

  @override
  void initState() {
    super.initState();
    tabs.addListener(() => setState(() {}));
    _refresh();
  }

  Future<void> _refresh() async {
    await svc.syncSocial();
    if (mounted) setState(() => refreshing = false);
  }

  @override
  void dispose() {
    tabs.dispose();
    search.dispose();
    super.dispose();
  }

  List<String> get _current {
    final base = switch (tabs.index) {
      0 => a.followers,
      1 => a.following,
      _ => a.followRequests,
    };
    if (q.isEmpty) return base;
    return base.where((u) => u.contains(q)).toList();
  }

  Future<void> _openProfile(String username) async {
    final id = await svc.findUser(username);
    if (id == null || !mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PublicProfileScreen(uid: id, username: username)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _current;
    return Scaffold(
      backgroundColor: DC.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, size: 18)),
              const SizedBox(width: 12),
              Text('@${a.username.isEmpty ? 'you' : a.username}',
                  style: Theme.of(context).textTheme.titleLarge),
            ]),
          ),
          TabBar(
            controller: tabs,
            indicatorColor: DC.cyan,
            labelColor: DC.cyan,
            unselectedLabelColor: DC.dim,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: '${a.followers.length} Followers'),
              Tab(text: '${a.following.length} Following'),
              Tab(
                  text: a.followRequests.isEmpty
                      ? 'Requests'
                      : 'Requests (${a.followRequests.length})'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Glass(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Icon(Icons.search, size: 18, color: DC.dim),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: search,
                    onChanged: (v) =>
                        setState(() => q = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Search',
                        hintStyle: TextStyle(color: DC.dim)),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: refreshing && list.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: DC.cyan))
                : list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                              switch (tabs.index) {
                                0 =>
                                  'No followers yet — share your wrap-up and let them find you!',
                                1 => 'You\'re not following anyone yet.',
                                _ => 'No pending requests.',
                              },
                              textAlign: TextAlign.center,
                              style: TextStyle(color: DC.dim)),
                        ),
                      )
                    : RefreshIndicator(
                        color: DC.cyan,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: list.length,
                          itemBuilder: (context, i) => _row(list[i]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _row(String u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () => _openProfile(u),
        child: Row(children: [
          CircleAvatar(
              radius: 20,
              backgroundColor: DC.violet.withOpacity(0.35),
              child: Text(u[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@$u', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (a.friends.contains(u))
                Text('friends — you follow each other',
                    style: TextStyle(fontSize: 10, color: DC.lime)),
            ]),
          ),
          ..._actions(u),
        ]),
      ),
    );
  }

  List<Widget> _actions(String u) {
    switch (tabs.index) {
      case 2: // requests → Confirm / Delete
        return [
          _btn('Confirm', DC.cyan, () async {
            final e = await svc.acceptFollowRequest(u);
            if (e != null && mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e)));
            }
            if (mounted) setState(() {});
          }),
          const SizedBox(width: 6),
          _btn('Delete', DC.dim, () async {
            await svc.declineFollowRequest(u);
            if (mounted) setState(() {});
          }),
        ];
      case 1: // following → Unfollow
        return [
          _btn('Unfollow', DC.dim, () async {
            await svc.unfollow(u);
            if (mounted) setState(() {});
          }),
        ];
      default: // followers → Follow back (request) when not yet following
        if (a.following.contains(u)) return const [];
        if (a.sentRequests.contains(u)) {
          return [
            _btn('Requested', DC.dim, () async {
              await svc.cancelFollowRequest(u);
              if (mounted) setState(() {});
            })
          ];
        }
        return [
          _btn('Follow back', DC.magenta, () async {
            final e = await svc.requestFollow(u);
            if (e != null && mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e)));
            }
            if (mounted) setState(() {});
          }),
        ];
    }
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ),
      );
}
