import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../models/check_in_event_data.dart';

/// Compact map thumbnail + exchange link line for the unified case timeline.
class CheckInTimelinePreview extends StatelessWidget {
  const CheckInTimelinePreview({
    super.key,
    required this.metadata,
  });

  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final d = CheckInEventData.fromMetadata(metadata);
    final mapUrl = d.staticMapUrl ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mapUrl.isNotEmpty)
          ClipRRect(
            borderRadius: PLDesign.r16,
            child: AspectRatio(
              aspectRatio: 2.25,
              child: Image.network(
                mapUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: PLDesign.card,
                  alignment: Alignment.center,
                  child: Text(
                    'Map preview unavailable',
                    style: PLDesign.caption,
                  ),
                ),
              ),
            ),
          ),
        if (d.linkedExchangeId != null && d.linkedExchangeId!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: mapUrl.isNotEmpty ? 10 : 0),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 18, color: PLDesign.primary),
                const SizedBox(width: 8),
                Text(
                  'Linked to exchange',
                  style: PLDesign.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: PLDesign.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
