import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';
import '../../models/check_in_event_data.dart';
import '../../models/timeline_event_model.dart';
import '../../services/check_in_service.dart';

/// Full-screen map, metadata, optional enrichment photo for a ledger `check_in` row.
class CheckInDetailScreen extends StatelessWidget {
  const CheckInDetailScreen({
    super.key,
    required this.caseId,
    required this.event,
  });

  final String caseId;
  final TimelineEventModel event;

  @override
  Widget build(BuildContext context) {
    final base = CheckInEventData.fromTimelineEvent(event);
    final timeFmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Check-in detail'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            timeFmt.format(event.createdAt.toLocal()),
            style: PLDesign.heroTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Recorded by ${event.actorName.isNotEmpty ? event.actorName : 'Participant'}',
            style: PLDesign.caption,
          ),
          const SizedBox(height: 20),
          if (base.hasCoordinates) ...[
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: PLDesign.r16,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(base.lat!, base.lng!),
                    zoom: 16,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('check_in'),
                      position: LatLng(base.lat!, base.lng!),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _metaTile(
            icon: Icons.place_outlined,
            label: 'Address',
            value: base.address ?? '—',
          ),
          if (base.accuracyMeters != null)
            _metaTile(
              icon: Icons.gps_fixed_rounded,
              label: 'GPS accuracy',
              value: '±${base.accuracyMeters!.toStringAsFixed(0)} m',
            ),
          if (base.linkedExchangeId != null &&
              base.linkedExchangeId!.isNotEmpty)
            _metaTile(
              icon: Icons.swap_horiz_rounded,
              label: 'Exchange link',
              value: 'Linked (id: ${base.linkedExchangeId})',
            ),
          const SizedBox(height: 16),
          Text('Photo', style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: CheckInService.watchEnrichment(caseId, event.id),
            builder: (context, snap) {
              final enrich = snap.data?.data();
              final merged = base.mergeEnrichment(enrich);
              final url = merged.photoUrl;
              if (url == null || url.isEmpty) {
                return Text(
                  'No photo attached.',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                );
              }
              return ClipRRect(
                borderRadius: PLDesign.r16,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metaTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: PLDesign.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: PLDesign.caption),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
