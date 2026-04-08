import 'package:flutter/material.dart';

class ExpensesListScreen extends StatefulWidget {
const ExpensesListScreen({super.key});

@override
State<ExpensesListScreen> createState() =>
_ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {

final List<Map<String, dynamic>> expenses = [
{
"title": "Soccer Registration",
"child": "Jordan",
"amount": 120,
"status": "Pending",
"owedByYou": true,
"time": "Today"
},
{
"title": "Dental Visit",
"child": "Ava",
"amount": 240,
"status": "Approved",
"owedByYou": false,
"time": "Yesterday"
},
{
"title": "School Supplies",
"child": "Jordan",
"amount": 60,
"status": "Disputed",
"owedByYou": true,
"time": "Mon"
},
];

Color statusColor(String s) {
switch (s) {
case "Approved":
return Colors.green;
case "Disputed":
return Colors.red;
default:
return Colors.orange;
}
}

Widget expenseCard(Map<String, dynamic> e) {
return GestureDetector(
onTap: () {
/// ⭐ Navigate to Expense Detail Screen
},
child: Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.04),
blurRadius: 14,
offset: const Offset(0, 6),
)
],
),
child: Column(
children: [

/// HEADER
Row(
children: [

CircleAvatar(
radius: 22,
backgroundColor:
Colors.green.withOpacity(.1),
child: const Icon(
Icons.receipt_long,
color: Colors.green,
),
),

const SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

Text(
e["title"],
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 17,
),
),

const SizedBox(height: 4),

Text(
e["child"],
style: const TextStyle(
color: Colors.black54),
),
],
),
),

Column(
crossAxisAlignment:
CrossAxisAlignment.end,
children: [

Text(
"\$${e["amount"]}",
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 18,
),
),

const SizedBox(height: 4),

Text(
e["time"],
style: const TextStyle(
color: Colors.black45,
fontSize: 11),
)
],
)
],
),

const SizedBox(height: 14),

/// STATUS + WHO OWES
Row(
children: [

Container(
padding:
const EdgeInsets.symmetric(
horizontal: 10,
vertical: 5),
decoration: BoxDecoration(
color: statusColor(
e["status"])
.withOpacity(.15),
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
fontSize: 12,
),
),
),

const SizedBox(width: 10),

Expanded(
child: Text(
e["owedByYou"]
? "You owe reimbursement"
: "Co-parent owes you",
style: TextStyle(
fontWeight: FontWeight.w600,
color: e["owedByYou"]
? Colors.orange
: Colors.green,
),
),
)
],
),

const SizedBox(height: 14),

/// ACTIONS
Row(
children: [

Expanded(
child: OutlinedButton(
onPressed: () {},
child:
const Text("View Detail"),
),
),

const SizedBox(width: 10),

Expanded(
child: ElevatedButton(
onPressed: () {},
child:
const Text("Resolve"),
),
),
],
)
],
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Expenses"),
elevation: 0,
backgroundColor: Colors.white,
foregroundColor: Colors.black,
actions: [

IconButton(
icon: const Icon(Icons.summarize),
onPressed: () {
/// ⭐ Expense Balance Summary Screen
},
),

IconButton(
icon: const Icon(Icons.add),
onPressed: () {
/// ⭐ Submit Expense Screen
},
)
],
),

body: ListView.builder(
padding: const EdgeInsets.all(20),
itemCount: expenses.length,
itemBuilder: (c, i) =>
expenseCard(expenses[i]),
),
);
}
}
