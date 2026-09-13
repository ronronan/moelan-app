import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/monthly_stat.dart';
import '../players/players_providers.dart';

const _monthLabels = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

/// Fixed categorical order (slot 1 = blue, slot 2 = orange) from the
/// validated dataviz palette — never remapped by rank, so a series keeps
/// its color everywhere it appears. Each of the two grouped-bar charts on
/// this screen is its own independent 2-series set and starts again at
/// slot 1; there's no shared identity between "bières" and "amendes" that
/// would require them to share a hue.
class _Palette {
  static Color slot1(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);
  static Color slot2(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFD95926) : const Color(0xFFEB6834);
  static Color gridline(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2C2C2A) : const Color(0xFFE1E0D9);
  static Color muted(Brightness b) => const Color(0xFF898781);
}

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(monthlyStatsProvider(_year));

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Année précédente',
                  onPressed: () => setState(() => _year -= 1),
                ),
                Text(
                  '$_year',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Année suivante',
                  onPressed: _year >= DateTime.now().year
                      ? null
                      : () => setState(() => _year += 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (stats) {
                if (stats.isEmpty) {
                  return const Center(
                    child: Text('Aucune donnée pour cette année.'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ChartCard(
                      title: 'Bières & softs',
                      child: _ConsumptionChart(stats: stats),
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Amendes & crédits',
                      child: _MoneyChart(stats: stats),
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Solde cumulé de la cagnotte',
                      child: _BalanceChart(stats: stats),
                    ),
                    const SizedBox(height: 24),
                    _StatsTable(stats: stats),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

/// A legend is mandatory once a chart carries two or more series — color
/// alone must never be the only way to tell them apart.
class _Legend extends StatelessWidget {
  const _Legend({required this.entries});

  final List<(Color, String)> entries;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 16,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: textStyle),
            ],
          ),
      ],
    );
  }
}

double _niceMax(double maxValue) {
  if (maxValue <= 0) return 1;
  final magnitude = _pow10Floor(maxValue);
  final normalized = maxValue / magnitude;
  final niceNormalized = normalized <= 1
      ? 1.0
      : normalized <= 2
      ? 2.0
      : normalized <= 5
      ? 5.0
      : 10.0;
  return niceNormalized * magnitude;
}

double _pow10Floor(double value) {
  var magnitude = 1.0;
  while (magnitude * 10 <= value) {
    magnitude *= 10;
  }
  return magnitude;
}

class _ConsumptionChart extends StatelessWidget {
  const _ConsumptionChart({required this.stats});

  final List<MonthlyStat> stats;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final beerColor = _Palette.slot1(brightness);
    final softColor = _Palette.slot2(brightness);
    final maxCount = stats.fold<int>(
      0,
      (m, s) => [m, s.beerCount, s.softCount].reduce((a, b) => a > b ? a : b),
    );
    final maxY = _niceMax(maxCount.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: _Palette.gridline(brightness),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: _titlesData(brightness, stats, (v) => v.round().toString()),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final label = rodIndex == 0 ? 'Bières' : 'Softs';
                    return BarTooltipItem(
                      '${_monthLabels[group.x]}\n$label : ${rod.toY.round()}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < stats.length; i++)
                  BarChartGroupData(
                    x: stats[i].month.month - 1,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(
                        toY: stats[i].beerCount.toDouble(),
                        color: beerColor,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: stats[i].softCount.toDouble(),
                        color: softColor,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Legend(entries: [(beerColor, 'Bières'), (softColor, 'Softs')]),
      ],
    );
  }
}

class _MoneyChart extends StatelessWidget {
  const _MoneyChart({required this.stats});

  final List<MonthlyStat> stats;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fineColor = _Palette.slot1(brightness);
    final creditColor = _Palette.slot2(brightness);
    final maxEuros = stats.fold<double>(
      0,
      (m, s) => [
        m,
        s.fineTotalCents / 100,
        s.creditTotalCents / 100,
      ].reduce((a, b) => a > b ? a : b),
    );
    final maxY = _niceMax(maxEuros);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: _Palette.gridline(brightness),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: _titlesData(
                brightness,
                stats,
                (v) => '${v.round()}€',
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final label = rodIndex == 0 ? 'Amendes' : 'Crédits';
                    return BarTooltipItem(
                      '${_monthLabels[group.x]}\n$label : ${formatCents((rod.toY * 100).round())}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < stats.length; i++)
                  BarChartGroupData(
                    x: stats[i].month.month - 1,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(
                        toY: stats[i].fineTotalCents / 100,
                        color: fineColor,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: stats[i].creditTotalCents / 100,
                        color: creditColor,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Legend(entries: [(fineColor, 'Amendes'), (creditColor, 'Crédits')]),
      ],
    );
  }
}

/// Single series over time — the sequential default hue (blue), no legend
/// box needed since the card title already names what's plotted.
class _BalanceChart extends StatelessWidget {
  const _BalanceChart({required this.stats});

  final List<MonthlyStat> stats;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = _Palette.slot1(brightness);
    final spots = [
      for (var i = 0; i < stats.length; i++)
        FlSpot(
          stats[i].month.month - 1.0,
          stats[i].balanceCents / 100,
        ),
    ];
    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.15).clamp(1, double.infinity);

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: _Palette.gridline(brightness), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titlesData(brightness, stats, (v) => '${v.round()}€'),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${_monthLabels[s.x.round()]}\n${formatCents((s.y * 100).round())}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: Theme.of(context).colorScheme.surface,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

FlTitlesData _titlesData(
  Brightness brightness,
  List<MonthlyStat> stats,
  String Function(double) formatY,
) {
  final axisStyle = TextStyle(color: _Palette.muted(brightness), fontSize: 11);
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final i = value.round();
          if (i < 0 || i > 11) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_monthLabels[i], style: axisStyle),
          );
        },
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) =>
            Text(formatY(value), style: axisStyle),
      ),
    ),
  );
}

/// The accessible fallback for every chart above: the same monthly figures
/// as plain text, for anyone who can't (or would rather not) read the
/// charts.
class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.stats});

  final List<MonthlyStat> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Mois')),
              DataColumn(label: Text('Bières'), numeric: true),
              DataColumn(label: Text('Softs'), numeric: true),
              DataColumn(label: Text('Amendes'), numeric: true),
              DataColumn(label: Text('Crédits'), numeric: true),
              DataColumn(label: Text('Solde fin de mois'), numeric: true),
            ],
            rows: [
              for (final s in stats)
                DataRow(
                  cells: [
                    DataCell(Text(_monthLabels[s.month.month - 1])),
                    DataCell(Text('${s.beerCount}')),
                    DataCell(Text('${s.softCount}')),
                    DataCell(Text(formatCents(s.fineTotalCents))),
                    DataCell(Text(formatCents(s.creditTotalCents))),
                    DataCell(Text(formatCents(s.balanceCents))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
