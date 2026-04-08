import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class ExpenseReportScreen extends StatefulWidget {
const ExpenseReportScreen({super.key});

@override
State<ExpenseReportScreen> createState() =>
_ExpenseReportScreenState();
}

class _ExpenseReportScreenState
extends State<ExpenseReportScreen> {

String range = "Last 90 Days";

final List<Map<String, dynamic>> expenses = [
{
"title": "Soccer Registration",
"amount": 220,
"status": "Unpaid",
"date": "Mar 12",
"category": "Activity"
},
{
"title": "Medical Copay",
"amount": 45,
"status": "Paid",
"date": "Mar 08",
"category": "Medical"
},
{
"title": "School Supplies",
"amount": 72,
"status": "Disputed",
"date": "Feb 25",
"category": "Education"
},
];

Color statusColor(String s) {
switch (s) {
case "Paid":
return PLDesign.success;
case "Disputed":
return PLDesign.warning;
default:
return PLDesign.danger;
}
}

Widget aiHeader() {
return Container(
padding: const EdgeInsets.all(22),
decoration: PLDesign.legalCard,
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Row(
children: [
Icon(Icons.psychology, color: PLDesign.ai),
SizedBox(width: 8),
Text(
"AI Financial Insight",
style: PLDesign.sectionTitle,
),
],
),

SizedBox(height: 8),

Text(
"Reimbursement behavior trend shows delayed payments "
"and 1 disputed expense this period.",
style: PLDesign.legalBody,
)
],
),
);
}

Widget summaryCard() {

double total = expenses
.map((e) => e["amount"] as int)
.reduce((a, b) => a + b)
.toDouble();

double unpaid = expenses
.where((e) => e["status"] == "Unpaid")
.map((e) => e["amount"] as int)
.fold(0, (a, b) => a + b)
.toDouble();

return Container(
padding: const EdgeInsets.all(22),
decoration: PLDesign.exportTileDecoration,
child: Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [

Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

const Text("Total Expenses",
style: PLDesign.caption),

Text(
"\$${total.toStringAsFixed(0)}",
style: PLDesign.statNumber,
)
],
),

Column(
crossAxisAlignment:
CrossAxisAlignment.end,
children: [

const Text("Unpaid",
style: PLDesign.caption),

Text(
"\$${unpaid.toStringAsFixed(0)}",
style: PLDesign.statNumber.copyWith(
color: PLDesign.danger),
)
],
),
],
),
);
}

Widget rangeSelector() {
return Container(
padding: const EdgeInsets.all(18),
decoration: PLDesign.exportTileDecoration,
child: DropdownButton<String>(
value: range,
isExpanded: true,
dropdownColor: PLDesign.surface,
style: PLDesign.sectionTitle,
items: const [
DropdownMenuItem(
value: "Last 30 Days",
child: Text("Last 30 Days")),
DropdownMenuItem(
value: "Last 90 Days",
child: Text("Last 90 Days")),
DropdownMenuItem(
value: "6 Months",
child: Text("6 Months")),
DropdownMenuItem(
value: "Full History",
child: Text("Full History")),
],
onChanged: (v) {
setState(() {
range = v!;
});
},
),
);
}

Widget expenseCard(Map<String, dynamic> e) {
return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(18),
decoration: PLDesign.exportTileDecoration,
child: Row(
children: [

Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: statusColor(e["status"])
.withOpacity(.15),
borderRadius:
BorderRadius.circular(12),
),
child: Icon(Icons.receipt_long,
color: statusColor(e["status"])),
),

const SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

Text(e["title"],
style: PLDesign.sectionTitle),

const SizedBox(height: 4),

Text(
"${e["category"]} • ${e["date"]}",
style: PLDesign.caption,
)
],
),
),

Column(
crossAxisAlignment:
CrossAxisAlignment.end,
children: [

Text(
"\$${e["amount"]}",
style: PLDesign.sectionTitle,
),

const SizedBox(height: 6),

Container(
padding:
const EdgeInsets.symmetric(
horizontal: 10,
vertical: 4),
decoration: BoxDecoration(
color: statusColor(e["status"])
.withOpacity(.2),
borderRadius:
BorderRadius.circular(20),
),
child: Text(
e["status"],
style: TextStyle(
color:
statusColor(e["status"]),
fontWeight:
FontWeight.bold,
fontSize: 11),
),
)
],
)
],
),
);
}

Widget exportButton() {
return Padding(
padding: const EdgeInsets.only(top: 10),
child: PLDesign.primaryButton(
label: "Export Expense Report",
onTap: () {
/// FLOW → Legal Export → Court Case Export
},
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,
body: PLDesign.screen(
title: "Expense Report",
child: Column(
children: [

aiHeader(),

const SizedBox(height: 18),

summaryCard(),

const SizedBox(height: 14),

rangeSelector(),

const SizedBox(height: 18),

...expenses.map((e) => expenseCard(e)),

exportButton(),

const SizedBox(height: 40),

],
),
),
);
}
}
