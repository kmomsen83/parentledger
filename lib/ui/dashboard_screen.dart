import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';
import 'package:parentledger/ui/legal_hub_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'messages_inbox_screen.dart';
import 'calendar_month_view_screen.dart';
import 'proposals_list_screen.dart';
import 'expenses_list_screen.dart';
import 'documents_library_screen.dart';
import 'compromise_dashboard_screen.dart';
import 'upcoming_exchanges_list_screen.dart';
import 'parenting_time_report_screen.dart';
import 'custody_risk_screen.dart';
import 'notifications_center_screen.dart';
import 'recent_activity_timeline_screen.dart';
import 'pending_expenses_detail_screen.dart';
import 'profile_screen.dart';
import 'exchange_checkin_screen.dart';

import '../services/exchange_service.dart';
import '../models/exchange_model.dart';

class DashboardScreen extends StatefulWidget {
const DashboardScreen({super.key});

@override
State<DashboardScreen> createState() =>
_DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
with TickerProviderStateMixin {

ExchangeModel? nextExchange;
bool loadingExchange = true;

StreamSubscription? sub;

late AnimationController pulseController;

String? photoUrl;

@override
void initState() {
super.initState();

pulseController = AnimationController(
vsync: this,
duration: const Duration(seconds: 2),
)..repeat(reverse: true);

_loadUserPhoto();

final user = FirebaseAuth.instance.currentUser;

if (user == null) {
loadingExchange = false;
return;
}

sub = ExchangeService
.watchNextExchange(user.uid)
.listen((exchange) {
if (!mounted) return;

setState(() {
nextExchange = exchange;
loadingExchange = false;
});
});
}

Future<void> _loadUserPhoto() async {
final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid == null) return;

final doc = await FirebaseFirestore.instance
.collection("users")
.doc(uid)
.get();

if (!mounted) return;

setState(() {
photoUrl = doc.data()?["photoUrl"];
});
}

@override
void dispose() {
sub?.cancel();
pulseController.dispose();
super.dispose();
}

void go(Widget screen) {
Navigator.push(
context,
MaterialPageRoute(builder: (_) => screen),
);
}

String exchangeCountdown() {
if (nextExchange == null) return "No upcoming";

final diff =
nextExchange!.scheduledTime.difference(DateTime.now());

if (diff.isNegative) return "In progress";

return "${diff.inHours}h ${diff.inMinutes % 60}m";
}

bool get isActiveExchange {
if (nextExchange == null) return false;

final diff =
nextExchange!.scheduledTime.difference(DateTime.now());

return diff.inMinutes <= 15;
}

Future<void> openMaps() async {
if (nextExchange == null) return;

final uri = Uri.parse(
"https://www.google.com/maps/dir/?api=1&destination=${nextExchange!.lat},${nextExchange!.lng}",
);

await launchUrl(uri,
mode: LaunchMode.externalApplication);
}

Widget pressable({required Widget child, required VoidCallback onTap}) {
return GestureDetector(
onTap: onTap,
child: AnimatedScale(
duration: const Duration(milliseconds: 120),
scale: 1,
child: child,
),
);
}

Widget insight(Color c, String title, String sub, VoidCallback tap) {
return Expanded(
child: pressable(
onTap: tap,
child: Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [c.withOpacity(.18), PLDesign.card],
),
borderRadius: PLDesign.r20,
border: Border.all(color: c.withOpacity(.35)),
boxShadow: PLDesign.softShadow,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(Icons.analytics_rounded, color: c, size: 26),
const SizedBox(height: 18),
Text(title, style: PLDesign.sectionTitle),
const SizedBox(height: 6),
Text(sub, style: PLDesign.caption),
],
),
),
),
);
}

Widget actionCard(
IconData icon,
String title,
String sub,
Color color,
VoidCallback tap,
) {
return Expanded(
child: pressable(
onTap: tap,
child: AnimatedBuilder(
animation: pulseController,
builder: (_, child) {
final glow = isActiveExchange
? 0.3 + (pulseController.value * 0.3)
: 0.18;

return Container(
padding: const EdgeInsets.symmetric(
vertical: 22, horizontal: 12),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [color.withOpacity(glow), PLDesign.card],
),
borderRadius: PLDesign.r20,
border: Border.all(
color: color.withOpacity(.4)),
boxShadow: [
BoxShadow(
color: color.withOpacity(glow),
blurRadius: isActiveExchange ? 25 : 12,
)
],
),
child: Column(
children: [
Icon(icon, color: color, size: 26),
const SizedBox(height: 14),
Text(title,
textAlign: TextAlign.center,
style: PLDesign.body.copyWith(
fontWeight: FontWeight.w700,
color: Colors.white)),
const SizedBox(height: 4),
Text(sub,
textAlign: TextAlign.center,
style: PLDesign.caption),
],
),
);
},
),
),
);
}

Widget statusCard(
IconData icon,
String title,
String sub,
VoidCallback tap,
) {
return Expanded(
child: pressable(
onTap: tap,
child: Container(
padding: const EdgeInsets.symmetric(
vertical: 22, horizontal: 12),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Column(
children: [
Icon(icon, color: PLDesign.primary, size: 26),
const SizedBox(height: 14),
Text(title,
textAlign: TextAlign.center,
style: PLDesign.body.copyWith(
fontWeight: FontWeight.w700)),
const SizedBox(height: 4),
Text(sub, style: PLDesign.caption),
],
),
),
),
);
}

Widget tool(IconData icon, String label, VoidCallback tap) {
return pressable(
onTap: tap,
child: Container(
padding: const EdgeInsets.symmetric(vertical: 24),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(icon, color: PLDesign.primary, size: 30),
const SizedBox(height: 14),
Text(label,
textAlign: TextAlign.center,
style: PLDesign.body.copyWith(
fontWeight: FontWeight.w600)),
],
),
),
);
}

@override
Widget build(BuildContext context) {
final width = MediaQuery.of(context).size.width;
final crossCount = width > 430 ? 4 : 3;

final user = FirebaseAuth.instance.currentUser;
final initial =
(user?.email?.isNotEmpty ?? false)
? user!.email![0].toUpperCase()
: "P";

return Scaffold(
backgroundColor: PLDesign.background,
body: SafeArea(
child: ListView(
padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
children: [

/// HEADER
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
const Text("ParentLedger",
style: PLDesign.sectionTitle),
Row(children: [
IconButton(
onPressed: () =>
go(const NotificationsCenterScreen()),
icon: const Icon(Icons.notifications_none),
),
const SizedBox(width: 6),

CircleAvatar(
radius: 18,
backgroundImage:
photoUrl != null ? NetworkImage(photoUrl!) : null,
child: photoUrl == null
? Text(initial)
: null,
),
])
],
),

const SizedBox(height: 28),

const Text("Dashboard", style: PLDesign.pageTitle),
const SizedBox(height: 6),
const Text("Here’s what’s happening today",
style: PLDesign.body),

const SizedBox(height: 28),

/// INSIGHTS
Row(children: [
insight(Colors.indigoAccent, "Custody Risk",
"Moderate risk detected",
() => go(const CustodyRiskScreen())),
const SizedBox(width: 16),
insight(Colors.greenAccent, "Compliance",
"92% this month",
() => go(const ParentingTimeReportScreen())),
]),

const SizedBox(height: 30),

/// ACTIONS
Row(children: [
actionCard(
Icons.gps_fixed,
"Exchange Check-In",
loadingExchange
? "Loading..."
: nextExchange == null
? "No upcoming"
: "Verify arrival",
PLDesign.success,
() {
if (loadingExchange || nextExchange == null) return;

/// ✅ ALWAYS go to check-in screen
go(ExchangeCheckinScreen(
exchangeId: nextExchange!.id,
scheduledTime: nextExchange!.scheduledTime,
exchangeLat: nextExchange!.lat,
exchangeLng: nextExchange!.lng,
locationName: nextExchange!.locationName,
));
},
),
const SizedBox(width: 14),
actionCard(Icons.map, "Navigate",
"Open location", PLDesign.info,
() => openMaps()),
]),

const SizedBox(height: 30),

/// STATUS
Row(children: [
statusCard(Icons.calendar_today, "Upcoming Exchange",
exchangeCountdown(),
() {
if (nextExchange == null) {
go(const UpcomingExchangesListScreen());
return;
}

/// ✅ SMART ROUTING
if (isActiveExchange) {
go(ExchangeCheckinScreen(
exchangeId: nextExchange!.id,
scheduledTime: nextExchange!.scheduledTime,
exchangeLat: nextExchange!.lat,
exchangeLng: nextExchange!.lng,
locationName: nextExchange!.locationName,
));
} else {
go(const UpcomingExchangesListScreen());
}
},
),
const SizedBox(width: 14),
statusCard(Icons.chat_bubble_outline, "New Messages",
"2 unread",
() => go(const MessagesInboxScreen())),
const SizedBox(width: 14),
statusCard(Icons.attach_money, "Pending Expenses",
"\$142.50",
() => go(const PendingExpensesDetailScreen())),
]),

const SizedBox(height: 34),

/// GRID
GridView.count(
crossAxisCount: crossCount,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
mainAxisSpacing: 18,
crossAxisSpacing: 18,
childAspectRatio: .92,
children: [
tool(Icons.calendar_month, "Calendar",
() => go(const CalendarMonthViewScreen())),
tool(Icons.handshake, "Proposals",
() => go(const ProposalsListScreen())),
tool(Icons.attach_money, "Expenses",
() => go(const ExpensesListScreen())),
tool(Icons.folder, "Documents",
() => go(const DocumentsLibraryScreen())),
tool(Icons.scale, "Compromise",
() => go(const CompromiseDashboardScreen())),
tool(Icons.bar_chart, "Reports",
() => go(const ParentingTimeReportScreen())),
tool(Icons.gavel, "Legal Hub",
() => go(const LegalHubScreen())),
],
),

const SizedBox(height: 40),
],
),
),

bottomNavigationBar: BottomNavigationBar(
currentIndex: 0,
selectedItemColor: PLDesign.primary,
backgroundColor: PLDesign.surface,
type: BottomNavigationBarType.fixed,
onTap: (i) {
if (i == 1) go(const CustodyRiskScreen());
if (i == 2) go(const RecentActivityTimelineScreen());
if (i == 3) go(const UpcomingExchangesListScreen());
if (i == 4) go(const ProfileScreen());
},
items: const [
BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
BottomNavigationBarItem(icon: Icon(Icons.psychology), label: "AI"),
BottomNavigationBarItem(icon: Icon(Icons.timeline), label: "Timeline"),
BottomNavigationBarItem(icon: Icon(Icons.location_pin), label: "Exchange"),
BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
],
),
);
}
}