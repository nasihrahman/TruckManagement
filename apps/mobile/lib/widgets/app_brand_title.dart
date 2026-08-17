import 'package:flutter/material.dart';

/// AppBar title showing the company logo next to the screen's title text.
class AppBrandTitle extends StatelessWidget {
  const AppBrandTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/branding/logo_icon.png', height: 28, width: 28),
        const SizedBox(width: 10),
        Text(title),
      ],
    );
  }
}
