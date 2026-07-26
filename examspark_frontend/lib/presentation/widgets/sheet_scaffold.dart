import 'package:flutter/material.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// SnackBars behind modal sheets stay hidden. Use this wrapper so
/// the sheet has its own [Scaffold] messenger host when needed.
class SheetScaffold extends StatelessWidget {
  final Widget child;

  const SheetScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: child,
    );
  }
}

/// Always on top of every popup / sheet / dialog (root Overlay).
void showSheetSnackBar(
  BuildContext context,
  String message, {
  bool isError = true,
}) {
  AppToast.show(message, isError: isError, context: context);
}
