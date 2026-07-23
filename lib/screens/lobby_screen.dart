import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'game_screen.dart';

/// Waiting room: shows the shareable code, joined players,
/// and moves everyone into the duel when it starts.
class LobbyScreen extends StatefulWidget {
  final String code;
  final bool quick;
  final bool joined; // true if this user joined someone else's room
  const LobbyScreen(
      {super.key, required this.code, this.quick = false, this.joined = false});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with WidgetsBindingObserver {
  final svc = FirebaseService.instance;
  StreamSubscription<Room?>? _sub;
  Room? _room;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = svc.roomStream(widget.code).listen((room) {
      if (!mounted) return;
      setState(() => _room = room);
      if (room != null && room.state == 'playing' && !_navigated) {
        _navigated = true;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => GameScreen(code: widget.code)));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from WhatsApp / a brief background — re-assert online so the
    // room keeps us listed while we're still waiting here.
    if (state == AppLifecycleState.resumed && !_navigated && mounted) {
      svc.keepAlive(widget.code);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (widget.quick && !widget.joined) {
      await svc.cancelQuickMatch(widget.code);
    } else if (!widget.joined) {
      await svc.leaveRoom(widget.code);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final isHost = room?.hostUid == svc.uid;
    final full = room?.full ?? false;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(8),
                      radius: 18,
                      onTap: _cancel,
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                    const Spacer(),
                    Text(widget.quick ? 'QUICK MATCH' : 'PRIVATE ROOM',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    const SizedBox(width: 36),
                  ],
                ),
                const Spacer(),
                if (!widget.quick) ...[
                  Center(
                    child: Text('ROOM CODE',
                        style: TextStyle(
                            letterSpacing: 4,
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Code copied — send it to a friend!')));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.code,
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                    letterSpacing: 10,
                                    color: RDColors.cyan,
                                    fontSize: 36)),
                        const SizedBox(width: 12),
                        Icon(Icons.copy,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Tap to copy · share it with your rival',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5))),
                  ),
                ] else ...[
                  const Center(
                      child: SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: RDColors.cyan))),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Searching for an opponent…',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
                const SizedBox(height: 32),
                GlassCard(
                  child: Column(
                    children: [
                      for (final p in (room?.players.values ?? <RoomPlayer>[]))
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p.uid == room?.hostUid
                                ? RDColors.cyan.withOpacity(0.25)
                                : RDColors.magenta.withOpacity(0.25),
                            child: Text(
                                p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ),
                          title: Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: Icon(Icons.circle,
                              size: 12,
                              color: p.connected
                                  ? RDColors.lime
                                  : RDColors.danger),
                        ),
                      if (!full)
                        ListTile(
                          leading: const CircleAvatar(child: Text('?')),
                          title: Text('Waiting for opponent…',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5))),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!widget.quick && isHost)
                  NeonButton(
                    label: full ? 'START DUEL' : 'WAITING FOR PLAYER 2…',
                    icon: Icons.sports_mma,
                    onPressed: full ? () => svc.startMatch(widget.code) : null,
                  ),
                if (!isHost || widget.quick)
                  Center(
                    child: Text(
                      full && !widget.quick
                          ? 'Waiting for host to start…'
                          : 'Match starts automatically',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                    ),
                  ),
                const SizedBox(height: 12),
                GlassButton(label: 'CANCEL', onPressed: _cancel, height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
