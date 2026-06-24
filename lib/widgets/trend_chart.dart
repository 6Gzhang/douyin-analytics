import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 趋势折线图组件
class TrendChart extends StatelessWidget {
  final List<double>? data;

  const TrendChart({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final chartData = data ?? List.generate(7, (_) => 0.0);
    final maxY = chartData.isEmpty ? 10.0 : (chartData.reduce((a, b) => a > b ? a : b) * 1.2).clamp(10.0, double.infinity);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.15),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value >= 10000 ? '${(value / 10000).toStringAsFixed(0)}万' : value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['一', '二', '三', '四', '五', '六', '日'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(days[value.toInt()], style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: const Color(0xFFFE2C55),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFFFE2C55),
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFFE2C55).withOpacity(0.08),
            ),
          ),
        ],
        minY: 0,
        maxY: maxY,
      ),
    );
  }
}
