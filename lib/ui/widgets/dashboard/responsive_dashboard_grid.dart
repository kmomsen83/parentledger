import 'package:flutter/material.dart';

import 'dashboard_tool_grid_constants.dart';

/// Uniform cell geometry: responsive columns, fixed aspect ratio, equal gaps.
class ResponsiveDashboardGrid extends StatelessWidget {
  const ResponsiveDashboardGrid({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final n = DashboardToolGridConstants.crossAxisCountForWidth(w);
        final gap = DashboardToolGridConstants.gridGap;
        final aspect = DashboardToolGridConstants.childAspectRatioForWidth(w);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: aspect,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}
