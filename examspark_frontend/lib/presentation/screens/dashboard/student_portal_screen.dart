import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/teacher_dashboard_screen.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';

/// Screen 7: Student Portal & Restricted View Feed
/// Secure view-only feed for students with RAG chat integration
class StudentPortalScreen extends StatefulWidget {
  const StudentPortalScreen({super.key});

  @override
  State<StudentPortalScreen> createState() => _StudentPortalScreenState();
}

class _StudentPortalScreenState extends State<StudentPortalScreen> {
  final List<SharedLecture> _sharedLectures = [
    SharedLecture(
      id: '1',
      title: 'Chapter 1: Kinematics',
      date: 'Jan 15, 2026',
      duration: '45 min',
      className: 'Physics Class 12',
      summary: 'Introduction to motion, displacement, velocity, and acceleration concepts.',
      keyPoints: [
        'Motion is relative to a reference frame',
        'Displacement is a vector quantity',
        'Velocity is rate of change of displacement',
        'Acceleration is rate of change of velocity',
      ],
      cleanNotes: '''# Kinematics

## Introduction
Kinematics is the branch of mechanics that describes the motion of objects without considering the forces that cause the motion.

## Key Concepts

### Displacement
Displacement is the change in position of an object. It is a vector quantity, meaning it has both magnitude and direction.

### Velocity
Velocity is the rate of change of displacement with respect to time. It is also a vector quantity.

### Acceleration
Acceleration is the rate of change of velocity with respect to time.

## Equations of Motion
- v = u + at
- s = ut + ½at²
- v² = u² + 2as''',
    ),
    SharedLecture(
      id: '2',
      title: 'Newton\'s Laws of Motion',
      date: 'Jan 18, 2026',
      duration: '52 min',
      className: 'Physics Class 12',
      summary: 'Understanding the three fundamental laws governing motion and forces.',
      keyPoints: [
        'First law: Law of inertia',
        'Second law: F = ma',
        'Third law: Action and reaction pairs',
        'Force is a vector quantity',
      ],
      cleanNotes: '''# Newton's Laws of Motion

## First Law (Law of Inertia)
An object at rest stays at rest, and an object in motion stays in motion with the same speed and in the same direction unless acted upon by an unbalanced force.

## Second Law
The acceleration of an object is directly proportional to the net force acting on it and inversely proportional to its mass.

F = ma

## Third Law
For every action, there is an equal and opposite reaction.

## Applications
- Rocket propulsion
- Walking
- Swimming''',
    ),
    SharedLecture(
      id: '3',
      title: 'Organic Chemistry Basics',
      date: 'Jan 20, 2026',
      duration: '38 min',
      className: 'NEET Batch A',
      summary: 'Introduction to organic compounds, functional groups, and nomenclature.',
      keyPoints: [
        'Carbon forms four covalent bonds',
        'Functional groups determine chemical properties',
        'IUPAC naming conventions',
        'Hydrocarbons classification',
      ],
      cleanNotes: '''# Organic Chemistry Basics

## Introduction
Organic chemistry is the study of carbon compounds. Carbon is unique because it can form long chains and complex structures.

## Functional Groups
- Hydroxyl (-OH): Alcohols
- Carbonyl (C=O): Aldehydes and Ketones
- Carboxyl (-COOH): Carboxylic acids
- Amino (-NH₂): Amines

## Nomenclature
IUPAC system provides systematic naming for organic compounds based on their structure.

## Classification
- Alkanes: Single bonds only
- Alkenes: At least one double bond
- Alkynes: At least one triple bond''',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
  }

  void _enableScreenshotProtection() {
    SystemChannels.platform.invokeMethod('SystemChrome.enableSecureUI');
  }

  void _disableScreenshotProtection() {
    SystemChannels.platform.invokeMethod('SystemChrome.disableSecureUI');
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Student Feed',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => showSimpleJoinDialog(context),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Join New Class'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
            ),
          ),
        ],
      ),
      body: _sharedLectures.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              itemCount: _sharedLectures.length,
              itemBuilder: (context, index) {
                final lecture = _sharedLectures[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SharedLectureCard(
                    lecture: lecture,
                    onTap: () => _openSecureReader(lecture),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: AppTheme.getSecondaryText(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No lectures available',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join a class to see shared lectures',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => showSimpleJoinDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Join New Class'),
          ),
        ],
      ),
    );
  }

  void _openSecureReader(SharedLecture lecture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureNotesReaderView(lecture: lecture),
      ),
    );
  }
}

// ==================== SHARED LECTURE CARD ====================

class _SharedLectureCard extends StatelessWidget {
  final SharedLecture lecture;
  final VoidCallback onTap;

  const _SharedLectureCard({
    required this.lecture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.getAccentTint(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lecture.className,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.getSecondaryText(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lecture.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lecture.summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.getSecondaryText(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppTheme.getSecondaryText(context),
                ),
                const SizedBox(width: 4),
                Text(
                  lecture.date,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.getSecondaryText(context),
                ),
                const SizedBox(width: 4),
                Text(
                  lecture.duration,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SECURE NOTES READER VIEW ====================

class SecureNotesReaderView extends StatefulWidget {
  final SharedLecture lecture;

  const SecureNotesReaderView({
    super.key,
    required this.lecture,
  });

  @override
  State<SecureNotesReaderView> createState() => _SecureNotesReaderViewState();
}

class _SecureNotesReaderViewState extends State<SecureNotesReaderView> {
  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
  }

  void _enableScreenshotProtection() {
    SystemChannels.platform.invokeMethod('SystemChrome.enableSecureUI');
  }

  void _disableScreenshotProtection() {
    SystemChannels.platform.invokeMethod('SystemChrome.disableSecureUI');
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
  }

  void _openRAGChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RagChatBottomSheet(
        lectureId: widget.lecture.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.lecture.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        // SECURITY: No export, print, download, or share buttons
        actions: const [],
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.getAccentTint(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.lecture.className,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Short Summary
                  _buildSectionHeader('SUMMARY'),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    child: Text(
                      widget.lecture.summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Key Points
                  _buildSectionHeader('KEY POINTS'),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.lecture.keyPoints.map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                point,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clean Notes
                  _buildSectionHeader('NOTES'),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    child: Text(
                      widget.lecture.cleanNotes,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Security notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.getAccentTint(context),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(
                        color: AppTheme.accentColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppTheme.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'View-only mode. Content is protected.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.accentColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky AI interaction button
          Container(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: InkWell(
              onTap: _openRAGChat,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.getCardBorder(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ask AI about this lecture... (1 credit/query)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.getSecondaryText(context),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
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
      child: child,
    );
  }
}

// ==================== SHARED LECTURE MODEL ====================

class SharedLecture {
  final String id;
  final String title;
  final String date;
  final String duration;
  final String className;
  final String summary;
  final List<String> keyPoints;
  final String cleanNotes;

  SharedLecture({
    required this.id,
    required this.title,
    required this.date,
    required this.duration,
    required this.className,
    required this.summary,
    required this.keyPoints,
    required this.cleanNotes,
  });
}
