import 'package:flutter/material.dart';

/// Root navigator access from outside the widget tree — used by
/// `RoleSelectionScreen` to jump straight to the Teacher Dashboard right
/// after `AuthGate` swaps to `AppShell` (one frame later), without needing
/// `AuthGate` itself to know about dashboard routing.
class AppNavigation {
  AppNavigation._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
}
