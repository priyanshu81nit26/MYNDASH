import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/community_design.dart';
import '../ui/glass.dart';
import 'arena_redesign.dart';
import 'friends_search.dart';

/// Verified College and Corporate community space.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.type});

  /// `college` or `company`.
  final String type;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final svc = AccountService.instance;
  final input = TextEditingController();
  final emailInput = TextEditingController();
  final otpInput = TextEditingController();
  Map<String, dynamic>? org;
  bool loading = false;
  bool busy = false;
  bool otpSent = false;
  String? verificationError;
  String pendingName = '';
  int page = 0;

  bool get isCollege => widget.type == 'college';
  String get myOrg => isCollege ? AppData.i.college : AppData.i.company;
  String get label => isCollege ? 'COLLEGE' : 'CORPORATE';
  String get orgTag => '${widget.type}:$myOrg';
  IconData get spaceIcon =>
      isCollege ? Icons.school_rounded : Icons.business_rounded;

  @override
  void initState() {
    super.initState();
    if (myOrg.isNotEmpty) _load();
  }

  @override
  void dispose() {
    input.dispose();
    emailInput.dispose();
    otpInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final result = await svc.fetchOrg(widget.type, myOrg);
    if (!mounted) return;
    setState(() {
      org = result;
      loading = false;
    });
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _sendOtp() async {
    final name = input.text.trim();
    final email = emailInput.text.trim();
    if (name.length < 3) {
      _notice('Enter your full ${isCollege ? 'college' : 'company'} name.');
      return;
    }
    if (!email.contains('@')) {
      _notice('Enter a valid organization email address.');
      return;
    }
    setState(() {
      busy = true;
      verificationError = null;
    });
    final error = await svc.sendCorpEmailOtp(
      email,
      college: isCollege,
      orgName: name,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (error != null) {
      setState(() => verificationError = error);
      _notice(error);
      return;
    }
    setState(() {
      pendingName = name;
      otpSent = true;
    });
    _notice('Code sent to $email. Check your inbox and spam folder.');
  }

  Future<void> _verifyAndJoin() async {
    final email = emailInput.text.trim();
    final code = otpInput.text.trim();
    if (code.length != 6) {
      _notice('Enter the complete 6-digit verification code.');
      return;
    }
    setState(() {
      busy = true;
      verificationError = null;
    });
    final verifyError = await svc.verifyCorpEmailOtp(email, code);
    if (!mounted) return;
    if (verifyError != null) {
      setState(() {
        busy = false;
        verificationError = verifyError;
      });
      _notice(verifyError);
      return;
    }
    final (error, createdNew) = await svc.joinOrg(widget.type, pendingName);
    if (!mounted) return;
    setState(() {
      busy = false;
      otpSent = false;
    });
    if (error != null) {
      _notice(error);
      return;
    }
    _notice(
      createdNew
          ? '$pendingName is now on MYNDASH. You are founding member #1.'
          : 'Welcome to $pendingName.',
    );
    otpInput.clear();
    await _load();
  }

  Future<void> _openProfile(String username, String? uid) async {
    final id = uid ?? await svc.findUser(username);
    if (id == null) {
      _notice('Could not load @$username’s profile.');
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(uid: id, username: username),
      ),
    );
  }

  Future<void> _openOrgArena() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationArenaScreen(
          organizationTag: orgTag,
          organizationName: myOrg,
          college: isCollege,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openMyArenas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyArenasScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CommunityColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.logout_rounded, color: DC.danger),
        title: Text('Leave $myOrg?'),
        content: Text(
          'You will leave its member board and private arenas. You can '
          'rejoin later by verifying the organization email again.',
          style: TextStyle(color: DC.dim, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DC.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave != true) return;
    await svc.leaveOrg(widget.type);
    if (!mounted) return;
    setState(() {
      org = null;
      page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CommunityBackdrop(
        child: SafeArea(
          child: ListView(
            padding: communityPagePadding(context),
            children: [
              CommunityPageHeader(
                title: label,
                subtitle: isCollege
                    ? 'Verified campus community'
                    : 'Verified workplace community',
                trailing: myOrg.isEmpty
                    ? null
                    : CommunityIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh community',
                        onTap: loading ? null : _load,
                      ),
              ),
              const SizedBox(height: 20),
              if (myOrg.isEmpty) _enterOrg() else ..._orgBoard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enterOrg() {
    return Column(
      children: [
        CommunityHeroCard(
          icon: spaceIcon,
          eyebrow: otpSent ? 'STEP 2 OF 2' : 'VERIFIED ACCESS',
          title: isCollege
              ? 'Represent your campus.'
              : 'Compete with your workplace.',
          subtitle: otpSent
              ? 'We sent a six-digit code to ${emailInput.text.trim()}. '
                  'Enter it below to unlock the member board.'
              : isCollege
                  ? 'Use your official college email to unlock your campus '
                      'ranking, members and college-only arenas.'
                  : 'Use your official work email to unlock your company '
                      'ranking, members and organization-only arenas.',
          metrics: [
            const CommunityMetric(
              icon: Icons.verified_user_outlined,
              value: 'DOMAIN',
              label: 'email verified',
            ),
            CommunityMetric(
              icon: Icons.lock_outline_rounded,
              value: 'PRIVATE',
              label: 'member arenas',
              color: CommunityColors.sky,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _VerificationSteps(active: otpSent ? 1 : 0),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CommunityColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: CommunityColors.border),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: otpSent ? _otpForm() : _identityForm(),
          ),
        ),
      ],
    );
  }

  Widget _identityForm() {
    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CommunitySectionTitle(
          icon: Icons.badge_outlined,
          title: 'IDENTIFY YOUR ORGANIZATION',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: input,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 16),
          decoration: communityInputDecoration(
            label: isCollege ? 'College name' : 'Company name',
            hint: isCollege ? 'e.g. IIT Delhi' : 'e.g. Infosys',
            icon: spaceIcon,
            helper: 'Use the full official name shown by your organization.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailInput,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => busy ? null : _sendOtp(),
          style: const TextStyle(fontSize: 16),
          decoration: communityInputDecoration(
            label: isCollege ? 'College email' : 'Work email',
            hint: isCollege ? 'you@college.ac.in' : 'you@yourcompany.com',
            icon: Icons.alternate_email_rounded,
            helper: isCollege
                ? 'Academic .edu and .ac domains are accepted.'
                : 'Personal email providers are not accepted.',
          ),
        ),
        const SizedBox(height: 16),
        if (verificationError != null) ...[
          _VerificationError(message: verificationError!),
          const SizedBox(height: 12),
        ],
        NeonButton(
          label: busy ? 'SENDING CODE…' : 'EMAIL MY CODE',
          icon: Icons.mark_email_unread_outlined,
          colors: CommunityColors.actionGradient,
          onPressed: busy ? null : _sendOtp,
        ),
      ],
    );
  }

  Widget _otpForm() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CommunitySectionTitle(
          icon: Icons.password_rounded,
          title: 'ENTER VERIFICATION CODE',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: otpInput,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          textAlign: TextAlign.center,
          onSubmitted: (_) => busy ? null : _verifyAndJoin(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 7,
          ),
          decoration: communityInputDecoration(
            label: 'Six-digit code',
            hint: '000000',
            icon: Icons.lock_open_rounded,
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 14),
        if (verificationError != null) ...[
          _VerificationError(message: verificationError!),
          const SizedBox(height: 12),
        ],
        NeonButton(
          label: busy ? 'VERIFYING…' : 'VERIFY & JOIN',
          icon: Icons.verified_rounded,
          colors: CommunityColors.actionGradient,
          onPressed: busy ? null : _verifyAndJoin,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: busy
                ? null
                : () => setState(() {
                      otpSent = false;
                      otpInput.clear();
                      verificationError = null;
                    }),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Change email or resend'),
          ),
        ),
        Text(
          'For security, the code is delivered only to your email and is '
          'never displayed inside the app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: DC.dim, fontSize: 10.5, height: 1.4),
        ),
      ],
    );
  }

  List<Widget> _orgBoard() {
    final memberMap = (org?['members'] as Map?) ?? {};
    final memberCount = memberMap.length;
    final ranked = <MapEntry<String, num>>[];
    memberMap.forEach((key, value) {
      final details = Map<String, dynamic>.from(value as Map);
      ranked.add(
        MapEntry(
          '$key',
          details['contestRating'] as num? ?? 0,
        ),
      );
    });
    ranked.sort((a, b) => b.value.compareTo(a.value));
    final myRank =
        ranked.indexWhere((item) => item.key == AppData.i.username) + 1;
    final widgets = <Widget>[
      CommunityHeroCard(
        icon: spaceIcon,
        eyebrow: '$label SPACE',
        title: myOrg,
        subtitle: isCollege
            ? 'Your verified campus home on MYNDASH.'
            : 'Your verified workplace home on MYNDASH.',
        metrics: [
          CommunityMetric(
            icon: Icons.groups_rounded,
            value: '$memberCount',
            label: 'members',
          ),
          CommunityMetric(
            icon: Icons.leaderboard_outlined,
            value: myRank > 0 ? '#$myRank' : '—',
            label: 'your rank',
            color: CommunityColors.sky,
          ),
        ],
        action: Column(
          children: [
            NeonButton(
              label: 'OPEN ORGANIZATION ARENA',
              icon: Icons.stadium_outlined,
              height: 50,
              colors: CommunityColors.actionGradient,
              onPressed: _openOrgArena,
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'MY HOSTED ARENAS',
              icon: Icons.event_available_outlined,
              onPressed: _openMyArenas,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];

    if (loading) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: CommunityColors.mint),
          ),
        ),
      );
      return widgets;
    }
    if (org == null) {
      widgets.add(_offlineCard());
    } else {
      final members = <MapEntry<String, Map<String, dynamic>>>[];
      memberMap.forEach((key, value) {
        members.add(
          MapEntry('$key', Map<String, dynamic>.from(value as Map)),
        );
      });
      members.sort(
        (a, b) => ((b.value['contestRating'] as num?) ?? 0)
            .compareTo((a.value['contestRating'] as num?) ?? 0),
      );
      final pages = (members.length / 10).ceil().clamp(1, 999);
      if (page >= pages) page = pages - 1;
      final start = page * 10;
      final visible = members.skip(start).take(10).toList();

      widgets.add(
        CommunitySectionTitle(
          icon: Icons.leaderboard_rounded,
          title: 'MEMBER LEADERBOARD',
          trailing: Text(
            '${members.length} total',
            style: TextStyle(color: DC.dim, fontSize: 10.5),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
      if (members.isEmpty) {
        widgets.add(
          const _EmptyMembers(
            message: 'The member board is ready. New verified members will '
                'appear here.',
          ),
        );
      }
      for (var i = 0; i < visible.length; i++) {
        final globalRank = start + i + 1;
        final rating =
            (visible[i].value['contestRating'] as num?)?.toInt() ?? 1500;
        final username = visible[i].key;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MemberRow(
              rank: globalRank,
              username: username,
              subtitle: DC.contestTitle(rating),
              value: '$rating',
              mine: username == AppData.i.username,
              onTap: () =>
                  _openProfile(username, visible[i].value['uid'] as String?),
            ),
          ),
        );
      }
      if (pages > 1) {
        widgets.add(const SizedBox(height: 4));
        widgets.add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < pages; index++)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: page == index
                          ? CommunityColors.mintSoft
                          : CommunityColors.surface,
                      side: BorderSide(
                        color: page == index
                            ? CommunityColors.mint
                            : CommunityColors.border,
                      ),
                    ),
                    onPressed: () => setState(() => page = index),
                    child: Text('${index + 1}'),
                  ),
                ),
            ],
          ),
        );
      }
    }
    widgets.add(const SizedBox(height: 18));
    widgets.add(
      GhostButton(
        label: 'LEAVE ${isCollege ? 'COLLEGE' : 'COMPANY'}',
        icon: Icons.logout_rounded,
        onPressed: _leave,
      ),
    );
    return widgets;
  }

  Widget _offlineCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CommunityColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CommunityColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: CommunityColors.sky, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Member board unavailable',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Your verified membership is safe. Check your connection and retry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 12),
          NeonButton(
            label: 'RETRY',
            icon: Icons.refresh_rounded,
            height: 46,
            colors: CommunityColors.actionGradient,
            onPressed: _load,
          ),
        ],
      ),
    );
  }
}

class _VerificationSteps extends StatelessWidget {
  const _VerificationSteps({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.badge_outlined, 'Identify'),
      (Icons.mark_email_read_outlined, 'Verify'),
      (Icons.emoji_events_outlined, 'Compete'),
    ];
    return Semantics(
      label: 'Verification progress. Step ${active + 1} of 3.',
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: i <= active
                      ? CommunityColors.mintSoft
                      : CommunityColors.surface,
                  border: Border.all(
                    color: i <= active
                        ? CommunityColors.mint
                        : CommunityColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      steps[i].$1,
                      size: 18,
                      color: i <= active ? CommunityColors.mint : DC.dim,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      steps[i].$2,
                      style: TextStyle(
                        color: i <= active ? CommunityColors.mint : DC.dim,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != steps.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _VerificationError extends StatelessWidget {
  const _VerificationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DC.danger.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DC.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: DC.danger, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: DC.danger,
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.rank,
    required this.username,
    required this.subtitle,
    required this.value,
    required this.mine,
    required this.onTap,
  });

  final int rank;
  final String username;
  final String subtitle;
  final String value;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = rank <= 3 ? CommunityColors.mint : CommunityColors.sky;
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: rank <= 3
                      ? Icon(Icons.workspace_premium_outlined,
                          color: accent, size: 19)
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$username${mine ? ' · YOU' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: DC.dim, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
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

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CommunityColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CommunityColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45),
      ),
    );
  }
}
