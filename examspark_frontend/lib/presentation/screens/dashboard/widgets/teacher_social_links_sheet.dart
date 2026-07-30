import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/sheet_scaffold.dart';

/// Dashboard quick editor — optional social / trust links (not full profile create).
Future<TeacherProfileModel?> showTeacherSocialLinksSheet(
  BuildContext context, {
  required TeacherProfileModel profile,
  required Future<TeacherProfileModel> Function(TeacherProfileModel) onSave,
}) {
  return showModalBottomSheet<TeacherProfileModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SheetScaffold(
      child: _TeacherSocialLinksSheet(profile: profile, onSave: onSave),
    ),
  );
}

class _TeacherSocialLinksSheet extends StatefulWidget {
  final TeacherProfileModel profile;
  final Future<TeacherProfileModel> Function(TeacherProfileModel) onSave;

  const _TeacherSocialLinksSheet({
    required this.profile,
    required this.onSave,
  });

  @override
  State<_TeacherSocialLinksSheet> createState() =>
      _TeacherSocialLinksSheetState();
}

class _TeacherSocialLinksSheetState extends State<_TeacherSocialLinksSheet> {
  late final Map<TeacherSocialKind, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final kind in TeacherSocialKind.values)
        kind: TextEditingController(text: widget.profile.linkFor(kind) ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final links = <TeacherSocialKind, String?>{};
      for (final kind in TeacherSocialKind.values) {
        links[kind] = TeacherProfileModel.normalizeSocialInput(
          kind,
          _controllers[kind]!.text,
        );
      }
      final updated = widget.profile.withSocialLinks(links);
      final saved = await widget.onSave(updated);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSheetSnackBar(context, 'Could not save links: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.getCardBorder(context),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Social links (optional)',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Students see these on your profile for trust. Leave blank to hide. No chat inside Sonaxia.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  for (final kind in TeacherSocialKind.values) ...[
                    TextField(
                      controller: _controllers[kind],
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: kind.label,
                        hintText: kind.hint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save links'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
