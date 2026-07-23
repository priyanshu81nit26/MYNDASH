import 'package:flutter/material.dart';

import '../theme_district.dart';
import '../ui/glass.dart';

/// Compatibility shim for older routes.
///
/// MYNDASH v1 no longer sells a PRO subscription and no feature should call this
/// as an entitlement gate. Returning true keeps legacy callers open to every
/// player while the file remains available for a future v2 payment redesign.
@Deprecated('PRO subscriptions are disabled; features are available to all.')
bool requirePro(BuildContext context, String feature) => true;

/// Kept only so a stale deep link cannot land on a broken payment route.
/// There are deliberately no prices, checkout buttons, or provider SDK calls.
@Deprecated('PRO subscriptions are not offered in v1.')
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Glass(
                      radius: 16,
                      padding: const EdgeInsets.all(8),
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'FEATURES FOR EVERYONE',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const Spacer(),
                Glass(
                  radius: 26,
                  tint: DC.cyan,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        size: 54,
                        color: DC.cyan,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No subscription required',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PRO purchases are not offered in this version. '
                        'AI Trainer and its analysis tools are available to every player.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DC.dim, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
