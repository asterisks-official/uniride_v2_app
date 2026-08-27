import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The app's one ScaffoldMessenger, for messages that outlive the screen that
/// caused them.
///
/// Needed because some things are announced by the server, not by a tap: a
/// ride cancelled on someone else's phone has to say so wherever its recipient
/// happens to be, and the code that hears it holds no BuildContext.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Like [showAppSnack], but from anywhere — no context required.
///
/// Silently does nothing before the app has mounted, which is correct: there
/// is no one to tell yet.
void showGlobalSnack(String message, {bool isError = false}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  _show(messenger, message, isError);
}

/// Floating, rounded toast in the app's own palette.
///
/// Material's default snackbar is a square slab pinned to the bottom edge,
/// which reads as a different app next to the rest of these screens. This keeps
/// the same information in the same place, dressed to match.
void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  _show(messenger, message, isError);
}

void _show(ScaffoldMessengerState messenger, String message, bool isError) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.error : AppColors.dark,
        elevation: 0,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 19,
              color: Colors.white,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
