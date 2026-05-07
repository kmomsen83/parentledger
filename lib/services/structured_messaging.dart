/// Message / timeline facet types stored in ledger `type` or `metadata.messageKind`.
class StructuredMessageKind {
  StructuredMessageKind._();

  static const text = 'text';
  static const systemEvent = 'system_event';
  static const exchangeEvent = 'exchange_event';
  static const expenseEvent = 'expense_event';
  static const checkIn = 'check_in';
}
