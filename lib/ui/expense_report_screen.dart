import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_expense_service.dart';
import '../services/case_switcher_service.dart';
import 'legal_export_center_screen.dart';

/// Live expense intelligence for the active case (Firestore-backed).
class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  String _range = 'Last 90 Days';

  static const _ranges = [
    'Last 30 Days',
    'Last 90 Days',
    '6 Months',
    'Full History',
  ];

  bool _inRange(DateTime? createdAt, String range) {
    if (createdAt == null) return range == 'Full History';
    final now = DateTime.now();
    switch (range) {
      case 'Last 30 Days':
        return createdAt.isAfter(now.subtract(const Duration(days: 30)));
      case 'Last 90 Days':
        return createdAt.isAfter(now.subtract(const Duration(days: 90)));
      case '6 Months':
        return createdAt.isAfter(now.subtract(const Duration(days: 182)));
      case 'Full History':
      default:
        return true;
    }
  }

  DateTime? _createdAt(Map<String, dynamic> m) {
    final v = m['createdAt'];
    if (v is Timestamp) return v.toDate();
    return null;
  }

  String _statusLabel(Map<String, dynamic> m) {
    final paid = m['paid'] == true || m['status'] == 'paid';
    if (paid) return 'Paid';
    final st = '${m['status'] ?? ''}'.toLowerCase();
    if (st.contains('dispute')) return 'Disputed';
    return 'Unpaid';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Paid':
        return PLDesign.success;
      case 'Disputed':
        return PLDesign.warning;
      default:
        return PLDesign.danger;
    }
  }

  double _amount(Map<String, dynamic> m) {
    final a = m['amount'];
    if (a is num) return a.toDouble();
    return double.tryParse('$a') ?? 0;
  }

  String _title(Map<String, dynamic> m) {
    final d = m['description'] ?? m['title'] ?? 'Expense';
    return '$d'.trim().isEmpty ? 'Expense' : '$d';
  }

  String _category(Map<String, dynamic> m) {
    final c = m['category'];
    if (c != null && '$c'.trim().isNotEmpty) return '$c';
    return 'General';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final switcher = context.watch<CaseSwitcherService>();
    final caseId = session.isAttorney
        ? (switcher.selectedCaseId ?? session.caseId)
        : session.caseId;

    return Scaffold(
      backgroundColor: PLDesign.background,
      body: Container(
        decoration: PLDesign.screenGradient,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                    ),
                    const Expanded(
                      child: Text(
                        'Financial intelligence',
                        style: PLDesign.pageTitle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: caseId == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'Link your case to see shared expenses.',
                            textAlign: TextAlign.center,
                            style: PLDesign.body,
                          ),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: CaseExpenseService.watchExpenses(caseId),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                'Could not load expenses.',
                                style: PLDesign.body,
                              ),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(color: PLDesign.primary),
                            );
                          }

                          final docs = snap.data!.docs.where((d) {
                            final t = _createdAt(d.data());
                            return _inRange(t, _range);
                          }).toList();

                          double total = 0;
                          double unpaid = 0;
                          for (final d in docs) {
                            final m = d.data();
                            final amt = _amount(m);
                            total += amt;
                            if (_statusLabel(m) != 'Paid') {
                              unpaid += amt;
                            }
                          }

                          final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                            children: [
                              _insightBanner(docs.length, unpaid, fmt),
                              const SizedBox(height: 16),
                              _summaryCard(fmt.format(total), fmt.format(unpaid)),
                              const SizedBox(height: 14),
                              _rangeDropdown(),
                              const SizedBox(height: 18),
                              if (docs.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Text(
                                    'No expenses in this range. Log expenses from the dashboard.',
                                    style: PLDesign.body,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                ...docs.map((d) => _expenseRow(d.data())),
                              const SizedBox(height: 18),
                              PLDesign.primaryButton(
                                label: 'Court-ready expense export (PDF)',
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LegalExportCenterScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Exports use your live case data. Pro may be required for full packets without watermarks.',
                                style: PLDesign.caption.copyWith(height: 1.35),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightBanner(int count, double unpaidSum, NumberFormat fmt) {
    final tone = unpaidSum > 0 ? PLDesign.warning : PLDesign.success;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PLDesign.legalCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: PLDesign.ai, size: 22),
              const SizedBox(width: 8),
              Text(
                'Case snapshot',
                style: PLDesign.sectionTitle.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count == 0
                ? 'No expenses in this filter window.'
                : '$count entr${count == 1 ? 'y' : 'ies'} · ${fmt.format(unpaidSum)} still outstanding in view',
            style: PLDesign.legalBody.copyWith(color: tone.withValues(alpha: 0.95)),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String totalStr, String unpaidStr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PLDesign.exportTileDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total (range)', style: PLDesign.caption),
              Text(totalStr, style: PLDesign.statNumber.copyWith(fontSize: 26)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Outstanding', style: PLDesign.caption),
              Text(
                unpaidStr,
                style: PLDesign.statNumber.copyWith(
                  fontSize: 26,
                  color: PLDesign.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: PLDesign.exportTileDecoration,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _range,
          isExpanded: true,
          dropdownColor: PLDesign.surface,
          style: PLDesign.sectionTitle.copyWith(fontSize: 15),
          items: _ranges
              .map(
                (r) => DropdownMenuItem(value: r, child: Text(r)),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _range = v);
          },
        ),
      ),
    );
  }

  Widget _expenseRow(Map<String, dynamic> m) {
    final status = _statusLabel(m);
    final color = _statusColor(status);
    final created = _createdAt(m);
    final dateStr = created != null
        ? DateFormat.yMMMd().format(created)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: PLDesign.exportTileDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(m), style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '${_category(m)} · $dateStr',
                  style: PLDesign.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(symbol: r'$').format(_amount(m)),
                style: PLDesign.sectionTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
