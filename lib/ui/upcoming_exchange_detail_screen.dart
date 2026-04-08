import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/exchange_model.dart';
import '../../services/exchange_service.dart';
import '../../providers/case_context.dart';
import '../../design/design.dart';

import 'exchange_checkin_screen.dart';

class UpcomingExchangeDetailScreen extends StatelessWidget {
final ExchangeModel exchange;

const UpcomingExchangeDetailScreen({
super.key,
required this.exchange,
});

/// ================================
/// 🧭 OPEN MAPS (SAFE)
/// ================================
Future<void> openMaps(BuildContext context) async {
try {
final uri = Uri.parse(
"https://www.google.com/maps/dir/?api=1&destination=${exchange.lat},${exchange.lng}&travelmode=driving",
);

final launched = await launchUrl(
uri,
mode: LaunchMode.externalApplication,
);

if (!launched && context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Could not open maps")),
);
}
} catch (_) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Error opening maps")),
);
}
}
}

/// ================================
/// 🗑 DELETE (CONFIRMED)
/// ================================
Future<void> deleteExchange(BuildContext context) async {
final confirm = await showDialog<bool>(
context: context,
builder: (_) => AlertDialog(
title: const Text("Delete Exchange"),
content: const Text(
"Are you sure you want to delete this exchange?",
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context, false),
child: const Text("Cancel"),
),
TextButton(
onPressed: () => Navigator.pop(context, true),
child: const Text("Delete"),
),
],
),
);

if (confirm != true) return;

final caseId =
Provider.of<CaseContext>(context, listen: false).caseId;

if (caseId == null) return;

try {
await ExchangeService.deleteExchange(
caseId: caseId,
exchangeId: exchange.id,
);

if (!context.mounted) return;

Navigator.pop(context);

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Exchange deleted")),
);
} catch (_) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Failed to delete")),
);
}
}
}

/// ================================
/// ⏱ ACTIVE CHECK (IMPORTANT)
/// ================================
bool get isActive {
final diff =
exchange.scheduledTime.difference(DateTime.now());

return diff.inMinutes <= 15;
}

/// ================================
/// 🧱 BUILD
/// ================================
@override
Widget build(BuildContext context) {
final formattedTime =
DateFormat.yMMMd().add_jm().format(exchange.scheduledTime);

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Exchange Details"),
actions: [
IconButton(
icon: const Icon(Icons.delete),
onPressed: () => deleteExchange(context),
)
],
),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// ================================
/// ⭐ HERO CARD
/// ================================
Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
PLDesign.primary.withValues(alpha: .18),
PLDesign.card
],
),
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(exchange.locationName,
style: PLDesign.pageTitle),

const SizedBox(height: 10),

Text(formattedTime, style: PLDesign.caption),

const SizedBox(height: 14),

Row(
children: [
_badge(
exchange.type.toUpperCase(),
Colors.blueAccent,
),
const SizedBox(width: 10),
_badge(
exchange.status.toUpperCase(),
exchange.status == "completed"
? Colors.green
: Colors.orange,
),
],
)
],
),
),

const SizedBox(height: 24),

/// ================================
/// ⭐ ACTIONS
/// ================================
Row(
children: [
Expanded(
child: _actionButton(
icon: Icons.gps_fixed,
label: isActive
? "Check-In"
: "Not Active Yet",
color: isActive
? PLDesign.success
: Colors.grey,
onTap: isActive
? () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
ExchangeCheckinScreen(
exchangeId: exchange.id,
scheduledTime:
exchange.scheduledTime,
exchangeLat: exchange.lat,
exchangeLng: exchange.lng,
locationName:
exchange.locationName,
),
),
);
}
: () {
ScaffoldMessenger.of(context)
.showSnackBar(
const SnackBar(
content: Text(
"Check-in opens 15 min before"),
),
);
},
),
),

const SizedBox(width: 14),

Expanded(
child: _actionButton(
icon: Icons.map,
label: "Navigate",
color: PLDesign.info,
onTap: () => openMaps(context),
),
),
],
),

const SizedBox(height: 30),

/// ================================
/// ⭐ DETAILS PANEL
/// ================================
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_row("Child ID", exchange.childId),
_row("Exchange Type", exchange.type),
_row("Status", exchange.status),

if (exchange.arrivalLat != null)
_row(
"Arrival Verified",
"${exchange.arrivalLat}, ${exchange.arrivalLng}",
),
],
),
),
],
),
);
}

/// ================================
/// UI HELPERS
/// ================================
Widget _row(String label, String value) {
return Padding(
padding: const EdgeInsets.only(bottom: 12),
child: Row(
children: [
SizedBox(
width: 130,
child: Text(label, style: PLDesign.caption),
),
Expanded(
child: Text(value, style: PLDesign.body),
),
],
),
);
}

Widget _badge(String text, Color c) {
return Container(
padding:
const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: c.withValues(alpha: .18),
borderRadius: BorderRadius.circular(10),
border: Border.all(color: c.withValues(alpha: .35)),
),
child: Text(
text,
style: TextStyle(
color: c,
fontWeight: FontWeight.w700,
),
),
);
}

Widget _actionButton({
required IconData icon,
required String label,
required Color color,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap: onTap,
child: Container(
padding: const EdgeInsets.symmetric(vertical: 20),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
color.withValues(alpha: .18),
PLDesign.card
],
),
borderRadius: PLDesign.r20,
border: Border.all(
color: color.withValues(alpha: .35),
),
),
child: Column(
children: [
Icon(icon, color: color),
const SizedBox(height: 8),
Text(label, style: PLDesign.body),
],
),
),
);
}
}
