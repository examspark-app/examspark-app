import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  bool _loading = true;
  String? _error;
  String _code = '';
  int _earned = 0;
  List<Map<String, dynamic>> _referrals = const [];

  String get _link => 'https://sonaxia.com/invite?ref=$_code';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await LectureService.instance.getReferralSummary();
      if (!mounted) return;
      setState(() {
        _code = data['code']?.toString() ?? '';
        _earned = (data['earned_credits'] as num?)?.toInt() ?? 0;
        _referrals = (data['referrals'] as List? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = '$e';
        });
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _share() => Share.share(
    'Join me on Sonaxia and get started learning. Use my referral code $_code: $_link',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                children: [
                  _summary(),
                  const SizedBox(height: 16),
                  _referralCard(),
                  const SizedBox(height: 24),
                  Text(
                    'Credits History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_referrals.isEmpty)
                    const Text('Your referral rewards will appear here.'),
                  for (final referral in _referrals)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_add_alt_1_rounded),
                      title: Text(
                        '+${referral['credits_given'] ?? 30} credits',
                      ),
                      subtitle: Text('A new user joined using your code'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _summary() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.getCardBackground(context),
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      border: Border.all(color: AppTheme.getCardBorder(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Earned from referrals'),
        const SizedBox(height: 4),
        Text(
          '$_earned credits',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _share,
          icon: const Icon(Icons.share_rounded),
          label: const Text('Invite & Earn 30 Credits'),
        ),
      ],
    ),
  );

  Widget _referralCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your referral code',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _code,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copy(_code, 'Code'),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          const Divider(),
          const Text(
            'Shareable link',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              Expanded(child: Text(_link, overflow: TextOverflow.ellipsis)),
              IconButton(
                onPressed: () => _copy(_link, 'Link'),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
