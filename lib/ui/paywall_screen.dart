import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaywallScreen extends StatefulWidget {
const PaywallScreen({super.key});

@override
State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
Package? _package;
bool _loading = true;
String? _error;

@override
void initState() {
super.initState();
_loadOffer();
}

Future<void> _loadOffer() async {
try {
final offerings = await Purchases.getOfferings();

if (offerings.current != null &&
offerings.current!.availablePackages.isNotEmpty) {
setState(() {
_package = offerings.current!.availablePackages.first;
_loading = false;
});
} else {
setState(() {
_error = "No products found";
_loading = false;
});
}
} catch (e) {
setState(() {
_error = e.toString();
_loading = false;
});
}
}

Future<void> _purchase() async {
try {
final result = await Purchases.purchasePackage(_package!);

if (result.customerInfo.entitlements.active.isNotEmpty) {
if (!mounted) return;
Navigator.pop(context, true); // success
}
} catch (e) {
debugPrint("Purchase error: $e");
}
}

Future<void> _restore() async {
try {
final result = await Purchases.restorePurchases();

if (result.entitlements.active.isNotEmpty) {
if (!mounted) return;
Navigator.pop(context, true);
}
} catch (e) {
debugPrint("Restore error: $e");
}
}

@override
Widget build(BuildContext context) {
if (_loading) {
return const Scaffold(
body: Center(child: CircularProgressIndicator()),
);
}

if (_error != null) {
return Scaffold(
body: Center(child: Text(_error!)),
);
}

final price = _package!.storeProduct.priceString;

return Scaffold(
appBar: AppBar(title: const Text("Upgrade")),
body: Padding(
padding: const EdgeInsets.all(20),
child: Column(
children: [
const Spacer(),

const Text(
"Go Premium",
style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
),

const SizedBox(height: 20),

const Text("✔ Track shared expenses"),
const Text("✔ Manage co-parent finances"),
const Text("✔ Real-time balance updates"),
const Text("✔ Organized payment history"),

const SizedBox(height: 30),

Text(
price,
style: const TextStyle(
fontSize: 26,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 20),

ElevatedButton(
onPressed: _purchase,
child: const Text("Subscribe"),
),

TextButton(
onPressed: _restore,
child: const Text("Restore Purchases"),
),

const Spacer(),
],
),
),
);
}
}
