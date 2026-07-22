import 'package:flutter/material.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace.dart';

/// Full-page Study Workspace after lecture processing (Notes · Summary · Quiz…).
///
/// Replaces the old `/notes_result` feel while keeping Generate chips + Ask AI
/// that work inside [StudyWorkspace] (same as Library).
class StudyWorkspacePage extends StatefulWidget {
  final String lectureId;
  final String title;
  final String? subject;
  final bool showDuplicateNotice;
  final int? initialTabIndex;

  const StudyWorkspacePage({
    super.key,
    required this.lectureId,
    this.title = 'Lecture',
    this.subject,
    this.showDuplicateNotice = false,
    this.initialTabIndex,
  });

  @override
  State<StudyWorkspacePage> createState() => _StudyWorkspacePageState();
}

class _StudyWorkspacePageState extends State<StudyWorkspacePage> {
  @override
  void initState() {
    super.initState();
    if (widget.showDuplicateNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "This looks like content you've already added — "
              'here are your existing notes for it. No credits were charged.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StudyWorkspace(
          key: ValueKey('study-page-${widget.lectureId}'),
          lectureId: widget.lectureId,
          title: widget.title.trim().isEmpty ? 'Lecture' : widget.title.trim(),
          subject: widget.subject,
          initialTabIndex: widget.initialTabIndex,
          onClose: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }
}
