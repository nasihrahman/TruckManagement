import 'package:flutter/material.dart';

/// Shared confirmation dialog for the logout button — both the Driver and
/// Owner shells had a bare tap-to-logout with no confirmation, so a stray tap
/// signed people out with zero warning. Returns true only if the user
/// explicitly confirms; a dismissed dialog (back button, tap outside) reads
/// as false, same as tapping Cancel.
Future<bool> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out'),
      content: const Text('Are you sure you want to log out of your account?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Log Out'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
