import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

class EventLeaderboardScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<List<MapEntry<String, int>>?> Function() loadScores;

  const EventLeaderboardScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loadScores,
  });

  @override
  State<EventLeaderboardScreen> createState() => _EventLeaderboardScreenState();
}

class _EventLeaderboardScreenState extends State<EventLeaderboardScreen> {
  List<MapEntry<String, int>>? _scores;
  bool _loading = true;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _unavailable = false;
    });
    final scores = await widget.loadScores();
    if (!mounted) return;
    setState(() {
      _scores = scores;
      _loading = false;
      _unavailable = scores == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scores = _scores ?? const <MapEntry<String, int>>[];
    final me = AppData.i.username;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 20,
                      child: Glass(
                        radius: 16,
                        padding: EdgeInsets.zero,
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 80),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: DC.dim, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 20,
                      child: IconButton(
                        tooltip: 'Refresh leaderboard',
                        onPressed: _loading ? null : _load,
                        constraints: const BoxConstraints.tightFor(
                            width: 48, height: 48),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Glass(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: DC.amber.withOpacity(0.12),
                        ),
                        child: Icon(
                          Icons.emoji_events_rounded,
                          color: DC.amber,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FINAL STANDINGS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Results remain available after the event ends.',
                              style: TextStyle(
                                color: DC.dim,
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _unavailable
                        ? _LeaderboardMessage(
                            icon: Icons.cloud_off_outlined,
                            title: 'Leaderboard unavailable',
                            message:
                                'Check your connection, then refresh this board.',
                            onRetry: _load,
                          )
                        : scores.isEmpty
                            ? const _LeaderboardMessage(
                                icon: Icons.leaderboard_outlined,
                                title: 'No final scores yet',
                                message:
                                    'The board will fill as participants finish.',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 28),
                                itemCount: scores.length.clamp(0, 100),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final entry = scores[index];
                                  final mine = entry.key == me;
                                  return Glass(
                                    radius: 18,
                                    tint: mine ? DC.cyan : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 38,
                                          height: 38,
                                          child: index < 3
                                              ? Icon(
                                                  Icons
                                                      .workspace_premium_rounded,
                                                  color: [
                                                    DC.amber,
                                                    DC.dim,
                                                    const Color(0xFFB87333),
                                                  ][index],
                                                )
                                              : Center(
                                                  child: Text(
                                                    '#${index + 1}',
                                                    style: TextStyle(
                                                      color: DC.dim,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '@${entry.key}${mine ? '  YOU' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: mine
                                                  ? FontWeight.w900
                                                  : FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${entry.value}',
                                          style: TextStyle(
                                            color: mine ? DC.cyan : DC.text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _LeaderboardMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: DC.dim),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('TRY AGAIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
