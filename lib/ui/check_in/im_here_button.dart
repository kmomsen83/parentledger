import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../services/check_in_service.dart';
import 'check_in_optional_photo_sheet.dart';

/// One-tap “I'm here” — foreground location only; shows errors via [onMessage].
class ImHereButton extends StatelessWidget {
  const ImHereButton({
    super.key,
    required this.caseId,
    required this.onMessage,
    this.onCompleted,
    this.localPhotoPath,
    this.reverseGeocode = true,
    this.offerOptionalPhotoAfterSave = false,
  });

  final String caseId;
  final void Function(String message, {bool isError}) onMessage;
  final void Function(CheckInRecordResult result)? onCompleted;
  final String? localPhotoPath;
  final bool reverseGeocode;

  /// Opens [showCheckInOptionalPhotoSheet] when the save succeeds (no inline photo).
  final bool offerOptionalPhotoAfterSave;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () async => _run(context),
      icon: const Icon(Icons.where_to_vote_rounded),
      label: const Text("I'm here"),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: PLDesign.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _run(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await CheckInService.recordPresence(
      caseId: caseId,
      reverseGeocode: reverseGeocode,
      localPhotoPath: localPhotoPath,
    );
    if (!context.mounted) return;
    if (!r.ok) {
      onMessage(r.errorMessage ?? 'Check-in failed', isError: true);
      messenger?.showSnackBar(
        SnackBar(content: Text(r.errorMessage ?? 'Check-in failed')),
      );
      return;
    }
    onMessage('Check-in saved', isError: false);
    messenger?.showSnackBar(
      const SnackBar(content: Text('Location check-in saved')),
    );
    final warn = r.secondaryWarning;
    if (warn != null && warn.isNotEmpty) {
      messenger?.showSnackBar(SnackBar(content: Text(warn)));
    }
    onCompleted?.call(r);
    final lid = r.ledger?.eventId;
    if (offerOptionalPhotoAfterSave &&
        lid != null &&
        (localPhotoPath == null || localPhotoPath!.isEmpty) &&
        (r.enrichmentPhotoUrl == null || r.enrichmentPhotoUrl!.isEmpty)) {
      await showCheckInOptionalPhotoSheet(
        context: context,
        caseId: caseId,
        ledgerEventId: lid,
      );
    }
  }
}
