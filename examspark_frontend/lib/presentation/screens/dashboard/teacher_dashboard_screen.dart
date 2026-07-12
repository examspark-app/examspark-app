import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_profile_card.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_profile_edit_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/buy_plan_sheet.dart';

/// Teacher business dashboard — full spec: TEACHER_PLATFORM.md (founder saved Jul 2026).
///
/// Phase 4: Students / Groups / Credits cards read real Supabase data
/// (`class_folders`, `class_memberships`, `users.credits_balance`).
/// Revenue / Subscribers / Analytics stay placeholders — they depend on the
/// payment tables + PostHog wiring that are explicitly Phase 5.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key, this.openEditOnLoad = false});

  /// Set when arriving straight from the role-selection screen
  /// ("I'm a Teacher") — auto-opens the "Edit Teacher Profile" sheet once
  /// the (blank, for a brand-new teacher) profile has loaded, so they land
  /// directly in the form instead of an empty-looking dashboard.
  final bool openEditOnLoad;

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int? _creditBalance;
  TeacherProfileModel? _teacherProfile;
  List<ClassFolder> _classFolders = [];
  int _totalStudents = 0;
  bool _loadingClasses = true;
  double? _estimatedCommission;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
    _loadClasses();
    _loadCredits();
    _loadCommission();
  }

  Future<void> _loadTeacherProfile() async {
    final profile = await GroupsRepository.instance.fetchOwnTeacherProfile();
    if (!mounted) return;
    setState(() => _teacherProfile = profile);
    if (widget.openEditOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditProfile();
      });
    }
  }

  Future<void> _loadClasses() async {
    try {
      final rows = await ClassService.instance.getTeacherClasses();
      final classIds = rows.map((r) => r['id'] as String).toList();
      final counts = await ClassService.instance.getStudentCountsForClasses(classIds);

      if (!mounted) return;
      setState(() {
        _classFolders = rows
            .map(
              (r) => ClassFolder(
                id: r['id'] as String,
                name: r['name'] as String,
                studentCount: counts[r['id']] ?? 0,
                joinCode: r['join_code'] as String? ?? '',
              ),
            )
            .toList();
        _totalStudents = counts.values.fold(0, (sum, count) => sum + count);
        _loadingClasses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadCredits() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await SupabaseClient.instance.getUserProfile(userId);
      if (!mounted || profile == null) return;
      setState(() => _creditBalance = profile['credits_balance'] as int?);
    } catch (_) {
      // Supabase not configured yet — leave as placeholder dash.
    }
  }

  /// Display-only estimate — 30% recurring commission on every Group
  /// member's active paid plan attributed to this teacher
  /// (CREDIT_ECONOMY.md §Teacher Commission). No real payout — Phase 5.
  Future<void> _loadCommission() async {
    final commission = await GroupsRepository.instance.fetchEstimatedCommission();
    if (!mounted) return;
    setState(() => _estimatedCommission = commission);
  }

  void _openEditProfile() {
    final profile = _teacherProfile;
    if (profile == null) return;
    showTeacherProfileEditSheet(
      context,
      profile: profile,
      onSave: (updated) async {
        final saved = await GroupsRepository.instance.updateOwnTeacherProfile(updated);
        if (!mounted) return;
        setState(() => _teacherProfile = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateClassDialog,
            tooltip: 'Create New Class Folder',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher public profile — photo, subject, qualification, stats
            _teacherProfile == null
                ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                : TeacherProfileCard(profile: _teacherProfile!, onEdit: _openEditProfile),
            const SizedBox(height: 20),

            // Business metric cards — placeholder data (Phase 4/5 wiring)
            _buildBusinessCards(),
            const SizedBox(height: 24),

            // Class folders header
            Text(
              'Your Classes',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Class folders list
            if (_loadingClasses)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_classFolders.isEmpty)
              Text(
                'No classes yet — tap + to create your first one.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _classFolders.length,
                itemBuilder: (context, index) {
                  final folder = _classFolders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ClassFolderCard(
                      folder: folder,
                      onShareInvite: () => _shareInviteCode(folder),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCards() {
    final cards = [
      _MetricCard(icon: Icons.people_outline, label: 'Students', value: '$_totalStudents'),
      _MetricCard(icon: Icons.person_add_outlined, label: 'Subscribers', value: '—', isPlaceholder: true),
      _MetricCard(icon: Icons.currency_rupee, label: 'Revenue', value: '—', isPlaceholder: true),
      _MetricCard(
        icon: Icons.handshake_outlined,
        label: 'Est. Commission',
        value: _estimatedCommission == null ? '—' : '₹${_estimatedCommission!.toStringAsFixed(0)}',
        tooltip: '30% of active paid-plan students attributed to you — recurring monthly, display-only estimate.',
      ),
      _MetricCard(icon: Icons.bolt, label: 'Credits', value: _creditBalance == null ? '—' : '$_creditBalance'),
      _MetricCard(icon: Icons.cloud_outlined, label: 'Storage', value: '—', isPlaceholder: true),
      _MetricCard(icon: Icons.groups_outlined, label: 'Groups', value: '${_classFolders.length}'),
      _MetricCard(icon: Icons.insights_outlined, label: 'Analytics', value: '—', isPlaceholder: true),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Overview',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 620
                    ? 3
                    : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: cards,
            );
          },
        ),
      ],
    );
  }

  void _showCreateClassDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Create New Class Folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter class name',
            labelText: 'Class Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _createClassFolder(nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createClassFolder(String name) async {
    try {
      final row = await ClassService.instance.createClass(
        name: name,
        subject: _teacherProfile?.subject ?? '',
      );
      if (!mounted) return;
      setState(() {
        _classFolders.add(
          ClassFolder(
            id: row['id'] as String,
            name: row['name'] as String,
            studentCount: 0,
            joinCode: row['join_code'] as String,
          ),
        );
      });
    } catch (_) {
      // Supabase not configured yet — keep the class visible locally so the
      // founder can still test the UI; it will not persist until Phase 4
      // SQL has been run.
      if (!mounted) return;
      setState(() {
        _classFolders.add(
          ClassFolder(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            studentCount: 0,
            joinCode: _generateJoinCode(),
          ),
        );
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Class "$name" created successfully'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(random + i * 17) % chars.length];
    }
    return code;
  }

  void _shareInviteCode(ClassFolder folder) {
    final inviteLink = 'examspark.app/join/${folder.joinCode}';
    
    Clipboard.setData(ClipboardData(text: inviteLink));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, size: 20),
            const SizedBox(width: 8),
            Text('Invite link copied: $inviteLink'),
          ],
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Share Code',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: folder.joinCode));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Code copied: ${folder.joinCode}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================== METRIC CARD ====================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPlaceholder;
  final String? tooltip;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.isPlaceholder = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentColor, size: 20),
              if (isPlaceholder) ...[
                const Spacer(),
                Text(
                  'Phase 5',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    if (tooltip == null) return card;
    return Tooltip(message: tooltip!, child: card);
  }
}

// ==================== CLASS FOLDER CARD ====================

class _ClassFolderCard extends StatelessWidget {
  final ClassFolder folder;
  final VoidCallback onShareInvite;

  const _ClassFolderCard({
    required this.folder,
    required this.onShareInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.getAccentTint(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: AppTheme.getSecondaryText(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${folder.studentCount} Students',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: onShareInvite,
                tooltip: 'Share Invite Link',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            color: AppTheme.getCardBorder(context),
          ),
          const SizedBox(height: 12),
          // "Copy Code" was removed (founder decision, Jul 12, 2026) —
          // Share Invite Link is now the only way to invite students, so
          // there's a single unmistakable action instead of two similar
          // ones.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShareInvite,
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Share Invite Link'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ==================== CLASS FOLDER MODEL ====================

class ClassFolder {
  final String id;
  final String name;
  final int studentCount;
  final String joinCode;

  ClassFolder({
    required this.id,
    required this.name,
    required this.studentCount,
    required this.joinCode,
  });
}

// ==================== SIMPLE JOIN DIALOG ====================

class SimpleJoinDialog extends StatefulWidget {
  const SimpleJoinDialog({super.key});

  @override
  State<SimpleJoinDialog> createState() => _SimpleJoinDialogState();
}

class _SimpleJoinDialogState extends State<SimpleJoinDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    if (_isLoading) return;
    final code = _codeController.text.trim().toUpperCase();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-character code';
      });
      return;
    }

    // Spinner set FIRST (before any await) so the button shows busy
    // feedback on the very first tap instead of sitting there doing
    // nothing while the group-limit check round-trips to the server —
    // that gap was making it look unresponsive and inviting a second tap.
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
    if (!eligibility.allowed) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showBuyPlanSheet(context, eligibility);
      return;
    }

    try {
      await ClassService.instance.joinClassByCode(code);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined class!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or expired join code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      title: const Text('Join a Class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the 6-character group code provided by your teacher',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              counterText: '',
              errorText: _errorMessage,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 120,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _joinClass,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Join Class'),
          ),
        ),
      ],
    );
  }
}

// ==================== HELPER FUNCTION ====================

/// Shows the SimpleJoinDialog as a bottom sheet
Future<bool?> showSimpleJoinDialog(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: const SimpleJoinDialog(),
    ),
  );
}
