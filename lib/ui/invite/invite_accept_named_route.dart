import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../../services/invite_link_service.dart';
import '../../services/invite_service.dart';

/// Handles `Navigator.pushNamed(context, '/accept-invite', arguments: inviteId)`.
/// Stores the invite on [InviteLinkService] / [InviteService] then replaces the stack with [AppRouter].
class InviteAcceptNamedRoute extends StatefulWidget {
  const InviteAcceptNamedRoute({super.key});

  @override
  State<InviteAcceptNamedRoute> createState() => _InviteAcceptNamedRouteState();
}

class _InviteAcceptNamedRouteState extends State<InviteAcceptNamedRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      final id = args is String ? args.trim() : '';
      if (id.isNotEmpty) {
        InviteLinkService.pendingInviteId.value = id;
        InviteService.pendingInviteId = id;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AppRouter()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
