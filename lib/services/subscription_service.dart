import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
static Future<void> init(String userId) async {
await Purchases.setLogLevel(LogLevel.debug);

final apiKey = Platform.isIOS
? "YOUR_IOS_KEY"
: "YOUR_ANDROID_KEY";

await Purchases.configure(
PurchasesConfiguration(apiKey)
..appUserID = userId,
);
}

static Future<bool> isPremium() async {
final info = await Purchases.getCustomerInfo();
return info.entitlements.all["premium"]?.isActive ?? false;
}

static Future<Package?> getMonthly() async {
final offerings = await Purchases.getOfferings();
return offerings.current?.monthly;
}

static Future<Package?> getAnnual() async {
final offerings = await Purchases.getOfferings();
return offerings.current?.annual;
}

static Future<void> purchase(Package package) async {
await Purchases.purchasePackage(package);
}
}
