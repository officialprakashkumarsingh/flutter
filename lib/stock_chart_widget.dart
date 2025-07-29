import 'package:flutter/material.dart';
import 'dart:math' as math;

class StockChartWidget extends StatelessWidget {
  final Map<String, dynamic> stockData;
  final double height;

  const StockChartWidget({
    super.key,
    required this.stockData,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (stockData['success'] != true) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load stock data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stockData['error'] ?? 'Unknown error',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final stockInfo = stockData['stock_info'] as Map<String, dynamic>?;
    final chartData = stockData['chart_data'] as List<dynamic>? ?? [];
    final chartStats = stockData['chart_stats'] as Map<String, dynamic>?;

    if (stockInfo == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No stock information available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          // Stock Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F8F8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: const Color(0xFF000000),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            stockInfo['symbol'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getTrendColor(stockInfo['trend']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${stockInfo['market_state'] ?? 'CLOSED'}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        stockInfo['name'] ?? 'Unknown Company',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stockInfo['currency'] ?? 'USD'} ${stockInfo['current_price']?.toStringAsFixed(2) ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    if (stockInfo['price_change'] != null && stockInfo['price_change_percent'] != null)
                      Row(
                        children: [
                          Icon(
                            stockInfo['trend'] == 'up' ? Icons.arrow_upward_rounded : 
                            stockInfo['trend'] == 'down' ? Icons.arrow_downward_rounded : 
                            Icons.remove_rounded,
                            size: 16,
                            color: _getTrendColor(stockInfo['trend']),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stockInfo['price_change']?.toStringAsFixed(2)} (${stockInfo['price_change_percent']?.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getTrendColor(stockInfo['trend']),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Chart Area
          if (chartData.isNotEmpty) 
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Chart
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: StockChartPainter(
                          chartData: chartData.cast<Map<String, dynamic>>(),
                          stockInfo: stockInfo,
                        ),
                      ),
                    ),
                    
                    // Chart Stats
                    if (chartStats != null && chartStats['available'] == true)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('High', '${chartStats['period_high']?.toStringAsFixed(2)}'),
                            _buildStatItem('Low', '${chartStats['period_low']?.toStringAsFixed(2)}'),
                            _buildStatItem('Avg', '${chartStats['average_price']?.toStringAsFixed(2)}'),
                            _buildStatItem('Return', '${chartStats['total_return_percent']?.toStringAsFixed(1)}%'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No chart data available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF000000),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Color _getTrendColor(String? trend) {
    switch (trend) {
      case 'up':
        return Colors.green.shade600;
      case 'down':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

class StockChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> chartData;
  final Map<String, dynamic> stockInfo;

  StockChartPainter({
    required this.chartData,
    required this.stockInfo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    // Extract price data
    final prices = chartData
        .map((d) => (d['close'] as num?)?.toDouble())
        .where((p) => p != null)
        .cast<double>()
        .toList();

    if (prices.isEmpty) return;

    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final priceRange = maxPrice - minPrice;

    if (priceRange == 0) return;

    // Chart dimensions
    const padding = 20.0;
    final chartWidth = size.width - (padding * 2);
    final chartHeight = size.height - (padding * 2);

    // Create price line path
    final pricePath = Path();
    final gradientPath = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = padding + (i / (prices.length - 1)) * chartWidth;
      final y = padding + (1 - (prices[i] - minPrice) / priceRange) * chartHeight;

      if (i == 0) {
        pricePath.moveTo(x, y);
        gradientPath.moveTo(x, size.height - padding);
        gradientPath.lineTo(x, y);
      } else {
        pricePath.lineTo(x, y);
        gradientPath.lineTo(x, y);
      }
    }

    // Complete gradient path
    gradientPath.lineTo(padding + chartWidth, size.height - padding);
    gradientPath.close();

    // Determine trend color
    final firstPrice = prices.first;
    final lastPrice = prices.last;
    final isUpTrend = lastPrice >= firstPrice;
    
    final trendColor = isUpTrend ? Colors.green.shade600 : Colors.red.shade600;
    final gradientColor = isUpTrend ? Colors.green.shade100 : Colors.red.shade100;

    // Draw gradient fill
    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        gradientColor.withOpacity(0.3),
        gradientColor.withOpacity(0.05),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(gradientPath, fillPaint);

    // Draw price line
    paint.color = trendColor;
    canvas.drawPath(pricePath, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = trendColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < prices.length; i += math.max(1, prices.length ~/ 20)) {
      final x = padding + (i / (prices.length - 1)) * chartWidth;
      final y = padding + (1 - (prices[i] - minPrice) / priceRange) * chartHeight;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padding + (i / 4) * chartHeight;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    // Draw labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Price labels
    for (int i = 0; i <= 4; i++) {
      final price = maxPrice - (i / 4) * priceRange;
      final y = padding + (i / 4) * chartHeight;
      
      textPainter.text = TextSpan(
        text: price.toStringAsFixed(2),
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF666666),
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}