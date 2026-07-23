import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../core/state.dart';
import '../services/account_service.dart';
import '../services/firebase_service.dart';
import '../theme_district.dart';
import '../ui/calendar_view.dart';
import '../ui/dna.dart';
import '../ui/default_avatar.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'follow_screen.dart';
import 'friends_search.dart';
import 'squads_screen.dart';
import 'lobby_screen.dart';
import 'onboarding.dart';
import 'welcome_screen.dart';
import 'practice_screen.dart';
import 'wrap_screen.dart';

class ProfileScreen extends StatefulWidget {
  /// When shown as a navbar tab there's no route to pop, so hide the back arrow.
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final a = AppData.i;
  final svc = AccountService.instance;

  @override
  void initState() {
    super.initState();
    svc.syncSocial().then((_) {
      if (mounted) setState(() {});
    });
  }

  // ---------------- avatar ----------------
  Future<void> _setPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: DC.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Text('SET PROFILE PHOTO',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
          ListTile(
            leading: Icon(Icons.photo_camera, color: DC.cyan),
            title: const Text('Take a photo'),
            subtitle: Text('camera permission will be requested',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: DC.magenta),
            title: const Text('Choose from gallery'),
            subtitle: Text('photos permission will be requested',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
    if (source == null) return;
    try {
      // image_picker triggers the OS permission dialogs automatically
      final img = await ImagePicker()
          .pickImage(source: source, maxWidth: 600, imageQuality: 85);
      if (img == null) return;
      // Read raw bytes (not the file path) — works on web too, where
      // there's no dart:io File to read a picked image back from.
      final bytes = await img.readAsBytes();
      if (bytes.length > 400 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('That photo is too large — try a smaller one.')));
        }
        return;
      }
      a.avatarB64 = base64Encode(bytes);
      await a.save();
      // Persist to the cloud so the photo survives sign-out / new device.
      await AccountService.instance.saveAvatar(bytes);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not access ${source.name}: '
                'permission denied or unavailable.')));
      }
    }
  }

  // ---------------- username change ----------------
  void _changeUsername() {
    if (!a.canChangeUsername) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'You can change your username again in ${a.daysUntilUsernameChange} days.')));
      return;
    }
    final c = TextEditingController(text: a.username);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Change username'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, autofocus: true),
          const SizedBox(height: 8),
          Text('6–20 chars · unique · changeable once every 15 days',
              style: TextStyle(fontSize: 11, color: DC.dim)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final e = await svc.claimUsername(c.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (e != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e)));
              }
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------- edit profile ----------------
  void _editProfile() {
    final nameC = TextEditingController(text: a.name);
    final bioC = TextEditingController(text: a.bio);
    final emailC = TextEditingController(text: a.contactEmail);
    final phoneC = TextEditingController(text: a.contactPhone);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DC.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('EDIT PROFILE',
                  style: TextStyle(
                      fontSize: 11, letterSpacing: 2, color: DC.dim)),
              const SizedBox(height: 16),
              TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(
                controller: bioC,
                maxLength: 140,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'A line about you — visible on your profile'),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pop(c);
                  _changeUsername();
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                      '@${a.username.isEmpty ? 'choose_handle' : a.username}  ·  change',
                      style:
                          TextStyle(color: DC.cyan, fontWeight: FontWeight.w700)),
                ),
              ),
              TextField(
                controller: emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Contact email — not your sign-in email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final email = emailC.text.trim();
                    if (email.isNotEmpty && !email.contains('@')) {
                      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                          content: Text(
                              'That email looks off — check it and try again.')));
                      return;
                    }
                    final name = nameC.text.trim();
                    if (name.isNotEmpty) a.name = name;
                    a.bio = bioC.text.trim();
                    a.contactEmail = email;
                    a.contactPhone = phoneC.text.trim();
                    await a.save();
                    await svc.updatePublicProfile();
                    if (c.mounted) Navigator.pop(c);
                    if (mounted) setState(() {});
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- social ----------------
  void _openFollow(int tab) {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => FollowScreen(initialTab: tab)))
        .then((_) => setState(() {}));
  }

  void _showList(String title, List<String> users) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      backgroundColor: DC.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
          const SizedBox(height: 6),
          if (users.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nobody here yet.', style: TextStyle(color: DC.dim)),
            ),
          for (final u in users)
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: DC.violet.withOpacity(0.3),
                  child: Text(u[0].toUpperCase())),
              title: Text('@$u'),
              onTap: () async {
                Navigator.pop(c);
                await _openProfile(u);
              },
              trailing: a.friends.contains(u)
                  ? TextButton(
                      onPressed: () {
                        Navigator.pop(c);
                        _challenge(u);
                      },
                      child: Text('⚔ Challenge',
                          style: TextStyle(color: DC.magenta)),
                    )
                  : (title == 'Following'
                      ? TextButton(
                          onPressed: () async {
                            await svc.unfollow(u);
                            if (mounted) setState(() {});
                            if (c.mounted) Navigator.pop(c);
                          },
                          child:
                              Text('Unfollow', style: TextStyle(color: DC.dim)),
                        )
                      : null),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<void> _openProfile(String username) async {
    final id = await svc.findUser(username);
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

  /// Mutual friends can be challenged to a Reflex Duel 1v1.
  Future<void> _challenge(String friend) async {
    if (AppState.instance.online) {
      try {
        final code = await FirebaseService.instance
            .createRoom(a.username.isEmpty ? a.name : a.username);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Room $code created — share it with @$friend!')));
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => LobbyScreen(code: code)));
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Online challenges need Firebase — practicing vs bot instead.')));
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PracticeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final title = DC.contestTitle(a.contestRating);
    final tColor = DC.contestColor(a.contestRating);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              if (!widget.embedded) ...[
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
              ],
              Text('PROFILE', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: _editProfile,
                  child: const Icon(Icons.edit_outlined, size: 18)),
            ]),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _setPhoto,
                child: Stack(children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [tColor, DC.violet]),
                      boxShadow: [
                        BoxShadow(
                            color: tColor.withOpacity(0.4), blurRadius: 24)
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ProfileAvatar(
                        avatarB64: a.avatarB64, name: a.name, size: 104),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: DC.cyan),
                      child: const Icon(Icons.photo_camera,
                          size: 14, color: Colors.black),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _changeUsername,
                child: Text(
                  '@${a.username.isEmpty ? 'choose_handle' : a.username} ✎',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DC.cyan),
                ),
              ),
            ),
            if (a.bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(a.bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: DC.dim)),
                ),
              ),
            const SizedBox(height: 6),
            Center(
              child: Glass(
                radius: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.workspace_premium, size: 18, color: tColor),
                  const SizedBox(width: 6),
                  Text(title.toUpperCase(),
                      style: TextStyle(
                          color: tColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                ]),
              ),
            ),
            if (a.squadName.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SquadsScreen()))
                        .then((_) => setState(() {})),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          DC.lime.withOpacity(0.25),
                          DC.cyan.withOpacity(0.2)
                        ]),
                        border: Border.all(color: DC.lime.withOpacity(0.5)),
                      ),
                      child: Text('👥 ${a.squadName}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: DC.lime)),
                    ),
                  ),
                ),
              ),
            if (!a.canChangeUsername)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      'username changeable in ${a.daysUntilUsernameChange} days',
                      style: TextStyle(fontSize: 11, color: DC.dim)),
                ),
              ),
            const SizedBox(height: 20),
            // social counts — tap opens the full scrollable page
            Glass(
              radius: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _social('Friends', a.friends.length,
                      () => _showList('Friends', a.friends)),
                  _social(
                      'Followers', a.followers.length, () => _openFollow(0)),
                  _social(
                      'Following', a.following.length, () => _openFollow(1)),
                ],
              ),
            ),
            if (a.followRequests.isNotEmpty) ...[
              const SizedBox(height: 10),
              Glass(
                tint: DC.magenta,
                onTap: () => _openFollow(2),
                child: Row(children: [
                  Icon(Icons.person_add_alt_1, color: DC.magenta, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        '${a.followRequests.length} follow request${a.followRequests.length == 1 ? '' : 's'} waiting',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  Icon(Icons.chevron_right, color: DC.dim),
                ]),
              ),
            ],
            // MYNDASH Wrapped — visible from day 1; an animated neon tile
            // that features each fresh weekly drop.
            if (AppData.i.wrappedUnlocked) ...[
              const SizedBox(height: 10),
              const WrappedEntryTile(),
            ],
            const SizedBox(height: 10),
            GhostButton(
                label: 'FIND PLAYERS',
                icon: Icons.person_search,
                height: 46,
                onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FriendsSearchScreen()))
                    .then((_) => setState(() {}))),
            const SizedBox(height: 20),
            // living radar of six traits, computed from real play
            const MindDnaCard(),
            const SizedBox(height: 16),
            // last-12-weeks activity heatmap
            const ActivityHeatmap(),
            const SizedBox(height: 16),
            // month calendar: contests, drops, reminders, matches
            const ProfileCalendar(),
            const SizedBox(height: 16),
            // stats
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                StatChip(
                    label: 'CONTEST',
                    value: '${a.contestRating}',
                    color: tColor),
                StatChip(
                    label: 'DUEL ELO',
                    value: '${a.elo}',
                    color: DC.band(a.elo)),
                StatChip(label: 'XP', value: '${a.xp}', color: DC.cyan),
                StatChip(label: 'COINS', value: '${a.coins}', color: DC.amber),
                StatChip(
                    label: 'STREAK', value: '${a.streak}🔥', color: DC.amber),
                StatChip(
                    label: 'SOLVE',
                    value: '${a.overallRating}',
                    color: DC.band(a.overallRating)),
              ],
            ),
            const SizedBox(height: 16),
            // match history — last 15 games + form
            Glass(
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('GAMES',
                        style: TextStyle(
                            fontSize: 10, letterSpacing: 2, color: DC.dim)),
                    const Spacer(),
                    Text('form  ',
                        style: TextStyle(fontSize: 9, color: DC.dim)),
                    const FormStrip(),
                  ]),
                  const SizedBox(height: 10),
                  if (a.matches.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          'No games yet — hit 1v1 or the Arena to start your record.',
                          style: TextStyle(fontSize: 12, color: DC.dim)),
                    ),
                  for (final m in a.matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch ('${m['result']}') {
                              'W' => DC.lime,
                              'L' => DC.danger,
                              _ => DC.amber,
                            },
                          ),
                          child: Center(
                            child: Text('${m['result']}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${m['mode']}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                Text('vs ${m['opponent']}',
                                    style:
                                        TextStyle(fontSize: 10, color: DC.dim)),
                              ]),
                        ),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '${((m['delta'] as num?) ?? 0).toInt() >= 0 ? '+' : ''}${((m['delta'] as num?) ?? 0).toInt()}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: ((m['delta'] as num?) ?? 0) >= 0
                                          ? DC.lime
                                          : DC.danger)),
                              Text('${m['date']}',
                                  style: TextStyle(fontSize: 9, color: DC.dim)),
                            ]),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Glass(
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PUBLIC PROFILE · what others can see',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 2, color: DC.dim)),
                  const SizedBox(height: 4),
                  for (final (key, label) in const [
                    ('elo', 'Duel rating (Elo)'),
                    ('matches', 'Recent match results'),
                    ('streak', 'Daily streak'),
                    ('orgs', 'College / company'),
                  ])
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: DC.cyan,
                      title: Text(label, style: const TextStyle(fontSize: 13)),
                      value: a.publicPrefs[key] != false,
                      onChanged: (v) {
                        setState(() => a.publicPrefs[key] = v);
                        a.save();
                        svc.updatePublicProfile();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Glass(
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TITLE ROAD',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 2, color: DC.dim)),
                  const SizedBox(height: 10),
                  for (final (r, t) in const [
                    (1500, 'Beginner'),
                    (1700, 'Specialist'),
                    (1900, 'Expert'),
                    (2100, 'Master'),
                    (2300, 'Candidate Master'),
                    (2600, 'Chakra'),
                    (2900, 'Trishul'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(
                            a.contestRating >= r
                                ? Icons.check_circle
                                : Icons.lock_outline,
                            size: 16,
                            color: a.contestRating >= r
                                ? DC.contestColor(r)
                                : DC.dim),
                        const SizedBox(width: 8),
                        Text(t,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: a.contestRating >= r
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                                color: a.contestRating >= r
                                    ? DC.contestColor(r)
                                    : DC.dim)),
                        const Spacer(),
                        Text('$r+',
                            style: TextStyle(fontSize: 11, color: DC.dim)),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                  a.authMethod == 'guest'
                      ? 'Guest account — create an account to sync across devices'
                      : 'Signed in via ${a.authMethod}',
                  style: TextStyle(fontSize: 11, color: DC.dim)),
            ),
            const SizedBox(height: 16),
            GhostButton(
                label: 'LOG OUT',
                icon: Icons.logout,
                height: 46,
                onPressed: _logout),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _deleteAccount,
                icon: Icon(Icons.delete_forever_outlined,
                    size: 18, color: DC.danger),
                label: Text('Delete account & data',
                    style: TextStyle(fontSize: 13, color: DC.danger)),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log out?'),
        content: const Text(
            'You\'ll return to the welcome screen. Progress on this device will be cleared.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await svc.signOut();
    resetWelcome(); // rocket plays again on the next login
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        (r) => false);
  }

  /// Permanent deletion — required by Google Play's account policy.
  Future<void> _deleteAccount() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete account?'),
        content: const Text(
            'This permanently deletes your account, profile, coins, XP, '
            'ratings and progress — on this device and in the cloud. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: DC.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete forever')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final note = await svc.deleteAccount();
    resetWelcome(); // rocket plays again for whatever account comes next
    if (!mounted) return;
    if (note != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
    }
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        (r) => false);
  }

  Widget _social(String label, int count, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Text('$count',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(fontSize: 11, color: DC.dim)),
        ]),
      );
}
