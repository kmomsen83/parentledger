import 'package:flutter/material.dart';

import 'terms_screen.dart';

/// Legacy screen kept for backwards compatibility.
/// Routes and imports that still reference this class now reuse [TermsScreen].
class AppLegalTermsScreen extends StatelessWidget {
  const AppLegalTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TermsScreen();
  }
}
