import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parentledger/models/case_ledger_write_result.dart';
import 'package:parentledger/services/check_in_service.dart';
import 'package:parentledger/services/location_service.dart';

void main() {
  test('ok result can carry secondaryWarning without failing', () {
    const ledger = CaseLedgerWriteResult(
      eventId: 'e1',
      hash: 'h',
      previousHash: 'p',
    );
    const fix = ExchangeLocationFix(
      latLng: LatLng(1, 2),
      accuracyMeters: 3,
    );
    final r = CheckInRecordResult.ok(
      ledger: ledger,
      fix: fix,
      deviceTime: DateTime.utc(2026, 1, 1),
      secondaryWarning: 'Photo not attached',
    );
    expect(r.ok, isTrue);
    expect(r.secondaryWarning, 'Photo not attached');
  });
}
