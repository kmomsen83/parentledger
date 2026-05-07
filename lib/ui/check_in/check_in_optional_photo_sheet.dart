import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import '../../services/check_in_service.dart';

/// After a successful ledger write, offers camera capture and attaches to
/// `cases/{caseId}/check_in_enrichments/{ledgerEventId}`.
Future<void> showCheckInOptionalPhotoSheet({
  required BuildContext context,
  required String caseId,
  required String ledgerEventId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: PLDesign.surface,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add a photo?',
                style: PLDesign.sectionTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Optional — attached to this check-in for your records.',
                style: PLDesign.caption.copyWith(height: 1.35),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final img = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (img == null) return;
                  try {
                    await CheckInService.attachPhotoAfterCheckIn(
                      caseId: caseId,
                      ledgerEventId: ledgerEventId,
                      localPhotoPath: img.path,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Photo attached')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not attach photo: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
