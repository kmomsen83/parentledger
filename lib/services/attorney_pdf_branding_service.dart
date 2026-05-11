import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Loads counsel letterhead fields from Firestore for court-facing PDF exports.
class AttorneyPdfBrandingService {
  AttorneyPdfBrandingService._();

  static Future<AttorneyPdfBrandData?> loadForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final d = snap.data();
    if (d == null) return null;
    final role = (d['role'] ?? '').toString().toLowerCase();
    if (role != 'attorney') return null;

    final fn = (d['firstName'] ?? '').toString().trim();
    final ln = (d['lastName'] ?? '').toString().trim();
    final display = '$fn $ln'.trim();
    final firm = (d['firmName'] ?? '').toString().trim();
    final bar = (d['barNumber'] ?? '').toString().trim();
    final phone = (d['phone'] ?? d['phoneNumber'] ?? '').toString().trim();
    final email = (d['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
        .toString()
        .trim();
    final website = (d['website'] ?? d['firmWebsite'] ?? '').toString().trim();
    final address = (d['address'] ?? d['firmAddress'] ?? '').toString().trim();
    final bio = (d['biography'] ?? d['bio'] ?? '').toString().trim();
    final specialty = (d['specialty'] ?? d['practiceAreas'] ?? '').toString().trim();
    final jurisdiction =
        (d['jurisdiction'] ?? d['barState'] ?? '').toString().trim();
    final logoUrl = (d['firmLogoUrl'] ?? d['logoUrl'] ?? '').toString().trim();

    pw.ImageProvider? logo;
    if (logoUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(logoUrl));
        if (res.statusCode >= 200 &&
            res.statusCode < 300 &&
            res.bodyBytes.isNotEmpty) {
          logo = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {
        logo = null;
      }
    }

    return AttorneyPdfBrandData(
      attorneyName: display.isEmpty ? 'Counsel' : display,
      firmName: firm,
      barNumber: bar,
      phone: phone,
      email: email,
      website: website,
      address: address,
      biography: bio,
      specialty: specialty,
      jurisdiction: jurisdiction,
      logo: logo,
    );
  }

  static pw.Widget buildLetterhead(AttorneyPdfBrandData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.logo != null)
          pw.Container(
            height: 42,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Image(data.logo!, fit: pw.BoxFit.contain),
          ),
        pw.Text(
          data.attorneyName,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        if (data.firmName.isNotEmpty)
          pw.Text(data.firmName, style: const pw.TextStyle(fontSize: 10)),
        if (data.specialty.isNotEmpty)
          pw.Text(data.specialty, style: const pw.TextStyle(fontSize: 9)),
        if (data.barNumber.isNotEmpty)
          pw.Text('Bar No. ${data.barNumber}', style: const pw.TextStyle(fontSize: 9)),
        if (data.jurisdiction.isNotEmpty)
          pw.Text(data.jurisdiction, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        if (data.phone.isNotEmpty) pw.Text(data.phone, style: const pw.TextStyle(fontSize: 9)),
        if (data.email.isNotEmpty) pw.Text(data.email, style: const pw.TextStyle(fontSize: 9)),
        if (data.website.isNotEmpty) pw.Text(data.website, style: const pw.TextStyle(fontSize: 9)),
        if (data.address.isNotEmpty)
          pw.Text(data.address, style: const pw.TextStyle(fontSize: 9)),
        if (data.biography.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            data.biography.length > 400
                ? '${data.biography.substring(0, 400)}…'
                : data.biography,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.6),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget buildFooter(AttorneyPdfBrandData data) {
    final parts = <String>[
      if (data.firmName.isNotEmpty) data.firmName,
      if (data.attorneyName.isNotEmpty) data.attorneyName,
      if (data.phone.isNotEmpty) data.phone,
      if (data.email.isNotEmpty) data.email,
    ];
    final line = parts.join(' · ');
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        line.isEmpty ? 'ParentLedger' : '$line — ParentLedger',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    );
  }
}

class AttorneyPdfBrandData {
  const AttorneyPdfBrandData({
    required this.attorneyName,
    required this.firmName,
    required this.barNumber,
    required this.phone,
    required this.email,
    required this.website,
    required this.address,
    required this.biography,
    required this.specialty,
    this.jurisdiction = '',
    this.logo,
  });

  final String attorneyName;
  final String firmName;
  final String barNumber;
  final String phone;
  final String email;
  final String website;
  final String address;
  final String biography;
  final String specialty;
  final String jurisdiction;
  final pw.ImageProvider? logo;
}
