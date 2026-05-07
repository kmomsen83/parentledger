import 'package:flutter/material.dart';

import '../models/child_model.dart';
import 'add_edit_child_screen.dart';
import 'case_insights_screen.dart';
import 'timeline_violations_screen.dart';

/// Named routes for case-scoped tools (`arguments` = `caseId`).
class CaseRoutes {
  CaseRoutes._();

  static const String insights = '/insights';
  static const String violations = '/violations';

  /// [arguments] must be a [ChildModel] (edit existing child).
  static const String editChild = '/editChild';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case editChild:
        final child = settings.arguments;
        if (child is! ChildModel) {
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text('No child to edit.'),
              ),
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => AddEditChildScreen(initialChild: child),
          settings: settings,
        );
      case insights:
        final caseId = settings.arguments as String?;
        if (caseId == null || caseId.isEmpty) {
          return MaterialPageRoute<void>(
            builder: (_) => const _MissingCaseScreen(title: 'Insights'),
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => CaseInsightsScreen(caseId: caseId),
          settings: settings,
        );
      case violations:
        final caseId = settings.arguments as String?;
        if (caseId == null || caseId.isEmpty) {
          return MaterialPageRoute<void>(
            builder: (_) => const _MissingCaseScreen(title: 'Violations'),
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => TimelineViolationsScreen(caseId: caseId),
          settings: settings,
        );
      default:
        return null;
    }
  }
}

class _MissingCaseScreen extends StatelessWidget {
  const _MissingCaseScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No case is linked yet. Complete setup to use this screen.'),
        ),
      ),
    );
  }
}
