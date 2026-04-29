import 'package:flutter_test/flutter_test.dart';
import 'package:parentledger/util/subscription_limits.dart';

void main() {
  test('free tier expense cap matches Cloud Functions FREE_MAX_EXPENSES', () {
    expect(SubscriptionLimits.freeMaxExpenses, 5);
  });
}
