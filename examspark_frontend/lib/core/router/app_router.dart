import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/presentation/screens/auth/login_screen.dart';
import 'package:examspark_frontend/presentation/shell/app_shell.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/student_portal_screen.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/teacher_dashboard_screen.dart';
import 'package:examspark_frontend/presentation/screens/groups/group_dashboard_screen.dart';
import 'package:examspark_frontend/presentation/screens/groups/group_info_screen.dart';
import 'package:examspark_frontend/presentation/screens/groups/groups_list_screen.dart';
import 'package:examspark_frontend/presentation/screens/groups/join_invite_screen.dart';
import 'package:examspark_frontend/presentation/screens/legal/legal_center_screen.dart';
import 'package:examspark_frontend/presentation/screens/legal/legal_webview_screen.dart';
import 'package:examspark_frontend/presentation/screens/recording/notes_result_screen.dart';
import 'package:examspark_frontend/presentation/screens/recording/recorder_screen.dart';
import 'package:examspark_frontend/presentation/screens/recording/processing_screen.dart';
import 'package:examspark_frontend/presentation/screens/recording/study_workspace_page.dart';
import 'package:examspark_frontend/presentation/screens/subscription/subscription_screen.dart';
import 'package:examspark_frontend/presentation/screens/credits/credits_history_screen.dart';
import 'package:examspark_frontend/presentation/screens/profile/help_screen.dart';
import 'package:examspark_frontend/presentation/screens/profile/settings_screen.dart';
import 'package:examspark_frontend/presentation/screens/referrals/refer_earn_screen.dart';
import 'package:examspark_frontend/presentation/screens/admin/admin_payment_hub_screen.dart';
import 'package:examspark_frontend/presentation/screens/admin/admin_payment_screens.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;
    final name = settings.name ?? '';

    // Deep link: /join/485022 → open teacher group (join if needed).
    if (name.startsWith('/join/')) {
      final code = name.substring('/join/'.length).split('?').first.trim();
      return MaterialPageRoute(
        builder: (_) => JoinInviteScreen(joinCode: code),
        settings: settings,
      );
    }
    if (name == '/join') {
      final code = (args?['code'] as String?) ?? '';
      return MaterialPageRoute(
        builder: (_) => JoinInviteScreen(joinCode: code),
        settings: settings,
      );
    }

    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(
          builder: (_) => LoginScreen(
            startInSignUp: args?['startInSignUp'] as bool? ?? false,
            inviteJoinHint: args?['inviteJoinHint'] as bool? ?? false,
          ),
          settings: settings,
        );
      case '/home':
        return MaterialPageRoute(
          builder: (_) => const AppShell(),
          settings: settings,
        );
      case '/recorder':
        return MaterialPageRoute(
          builder: (_) => RecorderScreen(
            subject: args?['subject'] as String?,
            topic: args?['topic'] as String?,
            initialInputMethod: args?['initialInputMethod'] as String?,
            teacherRecordOnly: args?['teacherRecordOnly'] as bool? ?? false,
          ),
          settings: settings,
        );
      case '/recording_setup':
        // Legacy route — redirect into consolidated Recorder (Subject/Topic
        // live on setup step 1; no fake camera/mic placeholder page).
        return MaterialPageRoute(
          builder: (_) => RecorderScreen(
            initialInputMethod: args?['initialInputMethod'] as String?,
            subject: args?['subject'] as String?,
            topic: args?['topic'] as String?,
            teacherRecordOnly: args?['teacherRecordOnly'] as bool? ?? false,
          ),
          settings: settings,
        );
      case '/processing':
        return MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            lectureId: args?['lectureId'] as String? ?? '',
            retryFileBytes: args?['retryFileBytes'] as Uint8List?,
            retryFilename: args?['retryFilename'] as String?,
            retrySourceType: args?['retrySourceType'] as String?,
            retryHighAccuracy: args?['retryHighAccuracy'] as bool? ?? false,
            retryDurationMinutes: args?['retryDurationMinutes'] as int?,
            retryYoutubeUrl: args?['retryYoutubeUrl'] as String?,
          ),
          settings: settings,
        );
      case '/study_workspace':
        return MaterialPageRoute(
          builder: (_) => StudyWorkspacePage(
            lectureId: args?['lectureId'] as String? ?? '',
            title: args?['title'] as String? ?? 'Lecture',
            subject: args?['subject'] as String?,
            showDuplicateNotice: args?['duplicateNotice'] as bool? ?? false,
            initialTabIndex: args?['initialTabIndex'] as int?,
            readOnly: args?['readOnly'] as bool? ?? false,
          ),
          settings: settings,
        );
      case '/notes_result':
      case '/results':
        return MaterialPageRoute(
          builder: (_) =>
              NotesResultScreen(lectureId: args?['lectureId'] as String? ?? ''),
          settings: settings,
        );
      case '/subscription':
        return MaterialPageRoute(
          builder: (_) => const SubscriptionScreen(),
          settings: settings,
        );
      case '/credits/history':
        return MaterialPageRoute(
          builder: (_) => const CreditsHistoryScreen(),
          settings: settings,
        );
      case '/refer-earn':
        return MaterialPageRoute(
          builder: (_) => const ReferEarnScreen(),
          settings: settings,
        );
      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case '/help':
        return MaterialPageRoute(
          builder: (_) => const HelpScreen(),
          settings: settings,
        );
      // ===== Legal Consent & Legal Center =====
      case '/legal-center':
        return MaterialPageRoute(
          builder: (_) => const LegalCenterScreen(),
          settings: settings,
        );
      case '/legal-viewer':
        return MaterialPageRoute(
          builder: (_) => LegalWebViewScreen(
            title: args?['title'] as String? ?? 'Legal',
            url: args?['url'] as String? ?? '',
          ),
          settings: settings,
        );
      case '/teacher':
        return MaterialPageRoute(
          builder: (_) => TeacherDashboardScreen(
            openEditOnLoad: args?['openEdit'] as bool? ?? false,
          ),
          settings: settings,
        );
      case '/student':
        return MaterialPageRoute(
          builder: (_) => const StudentPortalScreen(),
          settings: settings,
        );
      case '/groups':
        return MaterialPageRoute(
          builder: (_) => const GroupsListScreen(),
          settings: settings,
        );
      case '/group_info':
        return MaterialPageRoute(
          builder: (_) =>
              GroupInfoScreen(groupId: args?['groupId'] as String? ?? ''),
          settings: settings,
        );
      case '/group_dashboard':
        return MaterialPageRoute(
          builder: (_) => GroupDashboardScreen(
            classId: args?['classId'] as String? ?? '',
            name: args?['name'] as String? ?? 'Study Group',
            joinCode: args?['joinCode'] as String? ?? '',
            subject: args?['subject'] as String? ?? '',
            joinApprovalMode: args?['joinApprovalMode'] as String? ?? 'auto',
          ),
          settings: settings,
        );
      case '/admin/payments':
        return MaterialPageRoute(
          builder: (_) => const AdminPaymentHubScreen(),
          settings: settings,
        );
      case '/admin/payments/list':
        return MaterialPageRoute(
          builder: (_) => const AdminPaymentsListScreen(),
          settings: settings,
        );
      case '/admin/subscriptions':
        return MaterialPageRoute(
          builder: (_) => const AdminSubscriptionsScreen(),
          settings: settings,
        );
      case '/admin/payments/failed':
        return MaterialPageRoute(
          builder: (_) => const AdminFailedPaymentsScreen(),
          settings: settings,
        );
      case '/admin/refunds':
        return MaterialPageRoute(
          builder: (_) => const AdminRefundsScreen(),
          settings: settings,
        );
      case '/admin/credits/manual':
        return MaterialPageRoute(
          builder: (_) => const AdminManualCreditsScreen(),
          settings: settings,
        );
      case '/admin/transactions':
        return MaterialPageRoute(
          builder: (_) => const AdminTransactionsScreen(),
          settings: settings,
        );
      case '/admin/revenue':
        return MaterialPageRoute(
          builder: (_) => const AdminRevenueScreen(),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
