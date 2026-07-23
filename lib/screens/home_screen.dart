import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'lobby_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final app = AppState.instance;
  late final TextEditingController _name =
      TextEditingController(text: app.profile.name);
  bool _busy = false;

  void _saveName() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    app.profile.name = n;
    app.persistLocal();
    if (app.online) FirebaseService.instance.saveProfile(app.profile);
  }

  Future<void> _quickMatch() async {
    _saveName();
    setState(() => _busy = true);
    try {
      final code = await FirebaseService.instance.quickMatch(app.profile.name);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LobbyScreen(code: code, quick: true)),
      );
    } catch (e) {
      _toast('Could not start quick match. Check your connection.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _createRoom() async {
    _saveName();
    setState(() => _busy = true);
    try {
      final code = await FirebaseService.instance.createRoom(app.profile.name);
      if (!mounted) return;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => LobbyScreen(code: code)));
    } catch (e) {
      _toast('Could not create room. Check your connection.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _joinRoom() async {
    _saveName();
    final code = await _askCode();
    if (code == null || code.trim().isEmpty) return;
    setState(() => _busy = true);
    final err = await FirebaseService.instance.joinRoom(code, app.profile.name);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(err);
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                LobbyScreen(code: code.trim().toUpperCase(), joined: true)));
  }

  Future<String?> _askCode() => showDialog<String>(
        context: context,
        builder: (context) {
          final c = TextEditingController();
          return AlertDialog(
            backgroundColor:
                Theme.of(context).colorScheme.surface.withOpacity(0.95),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Join Room'),
            content: TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                  fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: 'ROOM CODE'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, c.text),
                  child: const Text('Join')),
            ],
          );
        },
      );

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final online = app.online;
    final p = app.profile;
    final rank = Rank.forXp(p.xp);
    final next = Rank.next(p.xp);

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        radius: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.military_tech,
                                color: rank.color, size: 20),
                            const SizedBox(width: 6),
                            Text(rank.name,
                                style: TextStyle(
                                    color: rank.color,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      GlassCard(
                        padding: const EdgeInsets.all(8),
                        radius: 20,
                        onTap: () {
                          app.themeMode.value =
                              app.themeMode.value == ThemeMode.dark
                                  ? ThemeMode.light
                                  : ThemeMode.dark;
                          app.persistLocal();
                        },
                        child: Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                                  colors: [RDColors.cyan, RDColors.magenta])
                              .createShader(r),
                          child: Text('REFLEX\nDUEL',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                      color: Colors.white, height: 1.05)),
                        ),
                        const SizedBox(height: 8),
                        Text('Fastest mind wins.',
                            style: TextStyle(
                                letterSpacing: 3,
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  GlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _name,
                          onSubmitted: (_) => _saveName(),
                          onTapOutside: (_) {
                            _saveName();
                            FocusScope.of(context).unfocus();
                          },
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Your battle name',
                            prefixIcon: const Icon(Icons.edit, size: 16),
                            prefixIconColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                        ),
                        const Divider(height: 8),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ScorePill(label: 'WINS', value: '${p.wins}'),
                            ScorePill(
                                label: 'STREAK',
                                value: '${p.streak}🔥',
                                color: RDColors.amber),
                            ScorePill(
                                label: next == null
                                    ? 'XP · MAX RANK'
                                    : 'XP · ${next.minXp - p.xp} to ${next.name}',
                                value: '${p.xp}',
                                color: RDColors.cyan),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  NeonButton(
                    label: 'QUICK MATCH',
                    icon: Icons.flash_on,
                    onPressed: online && !_busy ? _quickMatch : null,
                  ),
                  const SizedBox(height: 14),
                  NeonButton(
                    label: 'CREATE ROOM',
                    icon: Icons.add_circle_outline,
                    colors: const [RDColors.magenta, RDColors.violet],
                    onPressed: online && !_busy ? _createRoom : null,
                  ),
                  const SizedBox(height: 14),
                  GlassButton(
                    label: 'JOIN ROOM WITH CODE',
                    icon: Icons.meeting_room_outlined,
                    onPressed: online && !_busy ? _joinRoom : null,
                  ),
                  const SizedBox(height: 14),
                  GlassButton(
                    label: 'PRACTICE VS BOT',
                    icon: Icons.smart_toy_outlined,
                    onPressed: _busy
                        ? null
                        : () {
                            _saveName();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PracticeScreen()));
                          },
                  ),
                  if (!online) ...[
                    const SizedBox(height: 18),
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      tint: RDColors.amber,
                      child: const Text(
                        'Online play is off — connect your Firebase project '
                        '(one command, see README.md) to unlock Quick Match '
                        'and Rooms.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
