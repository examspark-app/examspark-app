import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Teacher business dashboard — full spec: TEACHER_PLATFORM.md (founder saved Jul 2026).
/// Current UI: class folders scaffold only. Pending: analytics, revenue, student list.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _creditBalance = 450;
  final List<ClassFolder> _classFolders = [
    ClassFolder(
      id: '1',
      name: 'Class 12 Physics',
      studentCount: 45,
      joinCode: 'PHYS12',
    ),
    ClassFolder(
      id: '2',
      name: 'NEET Batch A',
      studentCount: 32,
      joinCode: 'NEETA1',
    ),
    ClassFolder(
      id: '3',
      name: 'JEE Mains Prep',
      studentCount: 28,
      joinCode: 'JEEM1',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Classes & Folders',
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
            // Profile summary card
            _buildProfileSummaryCard(),
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

  Widget _buildProfileSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.getAccentTint(context),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_creditBalance Credits',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              // Navigate to subscription/credits page
              Navigator.pushNamed(context, '/subscription');
            },
            tooltip: 'Add Credits',
          ),
        ],
      ),
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

  void _createClassFolder(String name) {
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShareInvite,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Share Invite Link'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyJoinCode(context, folder.joinCode),
                  icon: const Icon(Icons.code, size: 16),
                  label: const Text('Copy Code'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyJoinCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code copied: $code'),
        duration: const Duration(seconds: 2),
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
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-character code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Mock backend call to join class
      await Future.delayed(const Duration(seconds: 1));

      // Simulate successful join
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined class!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
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
