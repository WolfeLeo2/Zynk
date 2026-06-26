import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/utils/currency.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum ChartType { line, bar, pie }

enum MetricType {
  revenue,
  orders,
  lowStock,
  aov,
  conversion,
  customers,
  expenses,
  netProfit,
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class OrderItem {
  final String id;
  final String name;
  final String total;
  final String status;
  final DateTime timestamp;

  OrderItem(this.id, this.name, this.total, this.status, this.timestamp);

  bool get isCompleted => status == 'Completed';
  bool get isPending => status == 'Pending';
  bool get isPreparing => status == 'Preparing';
}

class ProductItem {
  final String name;
  final String subtitle;
  final String price;
  final double progress;

  ProductItem(this.name, this.subtitle, this.price, this.progress);
}

class MetricDetailData {
  final MetricType type;
  final String title;
  final String value;
  final double? rawValue;
  final String subtitle;
  final List<MetricRelation> relatedMetrics;
  final List<ChartPoint> chartData;

  MetricDetailData({
    required this.type,
    required this.title,
    required this.value,
    this.rawValue,
    required this.subtitle,
    required this.relatedMetrics,
    required this.chartData,
  });
}

class MetricRelation {
  final String label;
  final String value;
  final PhosphorIconData icon;
  final Color color;
  final double? change;

  MetricRelation({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.change,
  });
}

class ChartPoint {
  final String label;
  final double value;

  ChartPoint(this.label, this.value);
}

class ActionData {
  final String label;
  final PhosphorIconData icon;
  final VoidCallback onTap;

  ActionData(this.label, this.icon, this.onTap);
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER FUNCTIONS
// ─────────────────────────────────────────────────────────────────────────────

Color getStatusColor(String status) {
  return switch (status) {
    'Completed' => Colors.green,
    'Preparing' => Colors.orange,
    'Pending' => Colors.blue,
    _ => Colors.grey,
  };
}

PhosphorIconData getStatusIcon(String status) {
  return switch (status) {
    'Completed' => PhosphorIconsRegular.checkCircle,
    'Preparing' => PhosphorIconsRegular.cookingPot,
    'Pending' => PhosphorIconsRegular.clock,
    _ => PhosphorIconsRegular.question,
  };
}

String formatTimeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final localTimestamp = timestamp.toLocal();
  final diff = now.difference(localTimestamp);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else {
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC DETAIL DATA BUILDERS
// ─────────────────────────────────────────────────────────────────────────────

MetricDetailData createRevenueDetailData(
  double revenue,
  ColorScheme colorScheme,
) {
  return MetricDetailData(
    type: MetricType.revenue,
    title: 'Revenue Details',
    value: CurrencyHelper.format(revenue),
    rawValue: revenue,
    subtitle: "Today's total revenue",
    relatedMetrics: [
      MetricRelation(
        label: 'Total Revenue',
        value: CurrencyHelper.format(revenue),
        icon: PhosphorIconsRegular.money,
        color: colorScheme.primary,
      ),
    ],
    chartData: [],
  );
}

MetricDetailData createOrdersDetailData(int orders, ColorScheme colorScheme) {
  return MetricDetailData(
    type: MetricType.orders,
    title: 'Orders Details',
    value: '$orders',
    subtitle: "Today's total orders",
    relatedMetrics: [
      MetricRelation(
        label: 'Total Orders',
        value: '$orders',
        icon: PhosphorIconsRegular.receipt,
        color: colorScheme.primary,
      ),
    ],
    chartData: [],
  );
}

MetricDetailData createAOVDetailData(double aov, ColorScheme colorScheme) {
  return MetricDetailData(
    type: MetricType.aov,
    title: 'Average Order Value',
    value: CurrencyHelper.format(aov),
    subtitle: 'Average per transaction today',
    relatedMetrics: [
      MetricRelation(
        label: 'Avg Order Value',
        value: CurrencyHelper.format(aov),
        icon: PhosphorIconsRegular.chartBar,
        color: colorScheme.primary,
      ),
    ],
    chartData: [],
  );
}

MetricDetailData createLowStockDetailData(int count, ColorScheme colorScheme) {
  return MetricDetailData(
    type: MetricType.lowStock,
    title: 'Low Stock Items',
    value: '$count',
    subtitle: 'Items at or below reorder level',
    relatedMetrics: [
      MetricRelation(
        label: 'Items to Reorder',
        value: '$count',
        icon: PhosphorIconsRegular.warning,
        color: count > 0 ? Colors.red : Colors.green,
      ),
    ],
    chartData: [],
  );
}

MetricDetailData createExpensesDetailData(
  double expenses,
  ColorScheme colorScheme,
) {
  return MetricDetailData(
    type: MetricType.expenses,
    title: 'Expenses Details',
    value: CurrencyHelper.format(expenses),
    rawValue: expenses,
    subtitle: "Today's total expenses",
    relatedMetrics: [
      MetricRelation(
        label: 'Total Expenses',
        value: CurrencyHelper.format(expenses),
        icon: PhosphorIconsRegular.receipt,
        color: Colors.red,
      ),
    ],
    chartData: [],
  );
}

MetricDetailData createNetProfitDetailData(
  double netProfit,
  ColorScheme colorScheme,
) {
  return MetricDetailData(
    type: MetricType.netProfit,
    title: 'Net Profit Details',
    value: CurrencyHelper.format(netProfit),
    rawValue: netProfit,
    subtitle: "Today's net profit (Revenue - Expenses)",
    relatedMetrics: [
      MetricRelation(
        label: 'Net Profit',
        value: CurrencyHelper.format(netProfit),
        icon: PhosphorIconsRegular.wallet,
        color: netProfit >= 0 ? Colors.green : Colors.red,
      ),
    ],
    chartData: [],
  );
}
