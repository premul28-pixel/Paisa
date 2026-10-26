import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/transaction_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _touchedPieIndex = -1;

  // Curated color map for expense categories
  static const Map<String, Color> _categoryColors = {
    'Food': Color(0xFFF97316), // Orange
    'Transport': Color(0xFF0EA5E9), // Sky Blue
    'Shopping': Color(0xFF8B5CF6), // Purple
    'Bills': Color(0xFFEF4444), // Crimson
    'Education': Color(0xFF10B981), // Emerald
    'Entertainment': Color(0xFFF59E0B), // Amber
    'Healthcare': Color(0xFF14B8A6), // Teal
    'Others': Color(0xFF64748B), // Slate Grey
  };

  Color _getCategoryColor(String category) {
    return _categoryColors[category] ?? const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    // Watches transactions dynamically from SQLite
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics & Reports'),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final now = DateTime.now();

          // 1. Weekly spending calculation (from Monday of this week)
          final startOfWeek = DateTime(now.year, now.month, now.day).subtract(
            Duration(days: now.weekday - 1),
          );
          final weeklyExpenses = transactions
              .where((t) => t.isExpense && !t.date.isBefore(startOfWeek))
              .fold<double>(0.0, (s, t) => s + t.amount);

          // 2. Monthly spending calculation (from 1st day of this month)
          final startOfMonth = DateTime(now.year, now.month, 1);
          final monthlyExpenses = transactions
              .where((t) => t.isExpense && !t.date.isBefore(startOfMonth))
              .fold<double>(0.0, (s, t) => s + t.amount);

          final monthlyIncome = transactions
              .where((t) => t.isIncome && !t.date.isBefore(startOfMonth))
              .fold<double>(0.0, (s, t) => s + t.amount);

          // All-time totals
          final totalIncome = transactions
              .where((t) => t.isIncome)
              .fold<double>(0.0, (s, t) => s + t.amount);

          final totalExpense = transactions
              .where((t) => t.isExpense)
              .fold<double>(0.0, (s, t) => s + t.amount);

          // Category-wise expense grouping
          final Map<String, double> categorySums = {};
          for (final t in transactions.where((t) => t.isExpense)) {
            final cat = t.category ?? 'Others';
            categorySums[cat] = (categorySums[cat] ?? 0.0) + t.amount;
          }

          final sortedCategories = categorySums.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(transactionsProvider.notifier).loadTransactions();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // =============================================================
                // STEP 2: WEEKLY & MONTHLY SPENDING SUMMARY TEXT CARDS
                // =============================================================
                _buildSectionTitle('Spending Overview'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // WEEKLY SPENDING CARD
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.orange.withOpacity(0.15),
                                    child: const Icon(Icons.date_range, color: Colors.orange, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'This Week',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                CurrencyFormatter.format(weeklyExpenses),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Mon – Today',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // MONTHLY SPENDING CARD
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.expenseColor.withOpacity(0.15),
                                    child: const Icon(Icons.calendar_month, color: AppTheme.expenseColor, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'This Month',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                CurrencyFormatter.format(monthlyExpenses),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Net: ${CurrencyFormatter.format(monthlyIncome - monthlyExpenses)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (monthlyIncome >= monthlyExpenses) ? AppTheme.incomeColor : AppTheme.expenseColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // =============================================================
                // STEP 2: CATEGORY-WISE PIE CHART FOR EXPENSES
                // =============================================================
                _buildSectionTitle('Expense Distribution by Category'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: sortedCategories.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No expense records to analyze',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Log expenses to see your category breakdown chart.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event.isInterestedForInteractions ||
                                              pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection == null) {
                                            _touchedPieIndex = -1;
                                            return;
                                          }
                                          _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                        });
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 40,
                                    sections: _buildPieSections(sortedCategories, totalExpense),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 8),
                              // Category Legend List
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sortedCategories.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = sortedCategories[idx];
                                  final percentage = totalExpense > 0
                                      ? (item.value / totalExpense * 100).toStringAsFixed(1)
                                      : '0';
                                  final color = _getCategoryColor(item.key);

                                  return Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.key,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        '$percentage%',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        CurrencyFormatter.format(item.value),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // =============================================================
                // STEP 2: INCOME VS EXPENSE BAR CHART
                // =============================================================
                _buildSectionTitle('Income vs Expense Comparison'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: (totalIncome == 0 && totalExpense == 0)
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'No transaction data available',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add income and expenses to compare your cash flows.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildLegendIndicator(AppTheme.incomeColor, 'Total Income'),
                                  const SizedBox(width: 24),
                                  _buildLegendIndicator(AppTheme.expenseColor, 'Total Expenses'),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 220,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: _computeMaxY(totalIncome, totalExpense),
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          final label = groupIndex == 0 ? 'Total Income' : 'Total Expense';
                                          return BarTooltipItem(
                                            '$label\n${CurrencyFormatter.format(rod.toY)}',
                                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (val, meta) {
                                            if (val.toInt() == 0) {
                                              return const Padding(
                                                padding: EdgeInsets.only(top: 8),
                                                child: Text('Income', style: TextStyle(fontWeight: FontWeight.bold)),
                                              );
                                            } else if (val.toInt() == 1) {
                                              return const Padding(
                                                padding: EdgeInsets.only(top: 8),
                                                child: Text('Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: const FlGridData(show: false),
                                    barGroups: [
                                      BarChartGroupData(
                                        x: 0,
                                        barRods: [
                                          BarChartRodData(
                                            toY: totalIncome,
                                            color: AppTheme.incomeColor,
                                            width: 38,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              topRight: Radius.circular(8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 1,
                                        barRods: [
                                          BarChartRodData(
                                            toY: totalExpense,
                                            color: AppTheme.expenseColor,
                                            width: 38,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              topRight: Radius.circular(8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading reports: $e')),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    List<MapEntry<String, double>> categories,
    double totalExpense,
  ) {
    return List.generate(categories.length, (i) {
      final isTouched = i == _touchedPieIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 65.0 : 52.0;
      final item = categories[i];
      final percentage = totalExpense > 0
          ? ((item.value / totalExpense) * 100).toStringAsFixed(0)
          : '0';

      return PieChartSectionData(
        color: _getCategoryColor(item.key),
        value: item.value,
        title: '$percentage%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  double _computeMaxY(double a, double b) {
    final maxVal = a > b ? a : b;
    if (maxVal <= 0) return 100.0;
    return maxVal * 1.25;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLegendIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
