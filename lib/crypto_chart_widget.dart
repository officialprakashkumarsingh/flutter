import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class CryptoChartWidget extends StatefulWidget {
  final Map<String, dynamic> cryptoData;
  final String chartType;
  final double height;

  const CryptoChartWidget({
    super.key,
    required this.cryptoData,
    this.chartType = 'line',
    this.height = 400,
  });

  @override
  State<CryptoChartWidget> createState() => _CryptoChartWidgetState();
}

class _CryptoChartWidgetState extends State<CryptoChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String _selectedTimeframe = '24h';
  bool _showVolume = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cryptoData['success'] != true) {
      return _buildErrorWidget();
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8F9FA),
            const Color(0xFFE9ECEF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildHeader(),
            _buildTimeframeSelector(),
            Expanded(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return _buildChart();
                },
              ),
            ),
            if (_showVolume) _buildVolumeChart(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
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
              'Failed to load crypto data',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.cryptoData['error'] ?? 'Unknown error',
              style: GoogleFonts.inter(
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

  Widget _buildHeader() {
    final data = _getCoinData();
    if (data == null) return const SizedBox.shrink();

    final price = data['current_price']?.toString() ?? '0';
    final change = data['price_change_percentage_24h']?.toString() ?? '0';
    final changeValue = double.tryParse(change) ?? 0;
    final isPositive = changeValue >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Coin info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          data['symbol']?.toString().toUpperCase().substring(0, 2) ?? 'C',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name']?.toString() ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          data['symbol']?.toString().toUpperCase() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Price info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${_formatPrice(price)}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isPositive ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${changeValue.toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final timeframes = ['1h', '24h', '7d', '30d', '1y'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: timeframes.map((timeframe) {
                  final isSelected = _selectedTimeframe == timeframe;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTimeframe = timeframe;
                      });
                      _animationController.reset();
                      _animationController.forward();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        timeframe,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showVolume = !_showVolume;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showVolume ? const Color(0xFF6366F1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showVolume ? const Color(0xFF6366F1) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 16,
                    color: _showVolume ? Colors.white : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Volume',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _showVolume ? Colors.white : const Color(0xFF6B7280),
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

  Widget _buildChart() {
    final priceData = _getPriceData();
    if (priceData.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6366F1),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        painter: CryptoPricePainter(
          priceData: priceData,
          animation: _animation,
          selectedIndex: _selectedIndex,
          timeframe: _selectedTimeframe,
        ),
        child: GestureDetector(
          onTapDown: (details) {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            final chartWidth = renderBox.size.width - 32;
            final index = ((localPosition.dx - 16) / chartWidth * (priceData.length - 1)).round();
            
            if (index >= 0 && index < priceData.length) {
              setState(() {
                _selectedIndex = index;
              });
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeChart() {
    final volumeData = _getVolumeData();
    if (volumeData.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: CustomPaint(
        painter: CryptoVolumePainter(
          volumeData: volumeData,
          animation: _animation,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final data = _getCoinData();
    if (data == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          _buildStatItem('Market Cap', '\$${_formatLargeNumber(data['market_cap']?.toString() ?? '0')}'),
          _buildStatItem('Volume 24h', '\$${_formatLargeNumber(data['total_volume']?.toString() ?? '0')}'),
          _buildStatItem('Supply', _formatLargeNumber(data['circulating_supply']?.toString() ?? '0')),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getCoinData() {
    if (widget.cryptoData['data'] is Map) {
      final data = widget.cryptoData['data'] as Map<String, dynamic>;
      return data.values.first as Map<String, dynamic>?;
    }
    return null;
  }

  List<double> _getPriceData() {
    // Generate sample price data based on current price and timeframe
    final data = _getCoinData();
    if (data == null) return [];

    final currentPrice = double.tryParse(data['current_price']?.toString() ?? '0') ?? 0;
    final change24h = double.tryParse(data['price_change_percentage_24h']?.toString() ?? '0') ?? 0;
    
    // Generate realistic price movement data
    final random = math.Random(currentPrice.toInt());
    final points = _selectedTimeframe == '1h' ? 60 : 
                   _selectedTimeframe == '24h' ? 24 :
                   _selectedTimeframe == '7d' ? 7 :
                   _selectedTimeframe == '30d' ? 30 : 365;
    
    final priceData = <double>[];
    final volatility = currentPrice * 0.02; // 2% volatility
    
    for (int i = 0; i < points; i++) {
      final progress = i / (points - 1);
      final trendValue = currentPrice * (1 + (change24h / 100) * progress);
      final noise = (random.nextDouble() - 0.5) * volatility;
      priceData.add(math.max(0, trendValue + noise));
    }
    
    return priceData;
  }

  List<double> _getVolumeData() {
    final data = _getCoinData();
    if (data == null) return [];

    final currentVolume = double.tryParse(data['total_volume']?.toString() ?? '0') ?? 0;
    final random = math.Random(currentVolume.toInt());
    
    final points = _selectedTimeframe == '1h' ? 60 : 
                   _selectedTimeframe == '24h' ? 24 :
                   _selectedTimeframe == '7d' ? 7 :
                   _selectedTimeframe == '30d' ? 30 : 365;
    
    final volumeData = <double>[];
    
    for (int i = 0; i < points; i++) {
      final variation = 0.5 + random.nextDouble();
      volumeData.add(currentVolume * variation);
    }
    
    return volumeData;
  }

  String _formatPrice(String price) {
    final value = double.tryParse(price) ?? 0;
    if (value >= 1) {
      return value.toStringAsFixed(2);
    } else {
      return value.toStringAsFixed(6);
    }
  }

  String _formatLargeNumber(String numberStr) {
    final number = double.tryParse(numberStr) ?? 0;
    if (number >= 1e12) {
      return '${(number / 1e12).toStringAsFixed(2)}T';
    } else if (number >= 1e9) {
      return '${(number / 1e9).toStringAsFixed(2)}B';
    } else if (number >= 1e6) {
      return '${(number / 1e6).toStringAsFixed(2)}M';
    } else if (number >= 1e3) {
      return '${(number / 1e3).toStringAsFixed(2)}K';
    } else {
      return number.toStringAsFixed(2);
    }
  }
}

class CryptoPricePainter extends CustomPainter {
  final List<double> priceData;
  final Animation<double> animation;
  final int? selectedIndex;
  final String timeframe;

  CryptoPricePainter({
    required this.priceData,
    required this.animation,
    this.selectedIndex,
    required this.timeframe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (priceData.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6366F1).withOpacity(0.3),
          const Color(0xFF6366F1).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final minPrice = priceData.reduce(math.min);
    final maxPrice = priceData.reduce(math.max);
    final priceRange = maxPrice - minPrice;
    
    if (priceRange == 0) return;

    final path = Path();
    final fillPath = Path();
    
    // Calculate animated length
    final animatedLength = (priceData.length * animation.value).round();
    
    for (int i = 0; i < animatedLength; i++) {
      final x = (i / (priceData.length - 1)) * size.width;
      final y = size.height - ((priceData[i] - minPrice) / priceRange) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // Complete fill path
    if (animatedLength > 0) {
      final lastX = ((animatedLength - 1) / (priceData.length - 1)) * size.width;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();
    }

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < animatedLength; i++) {
      final x = (i / (priceData.length - 1)) * size.width;
      final y = size.height - ((priceData[i] - minPrice) / priceRange) * size.height;
      
      if (i == selectedIndex) {
        // Highlight selected point
        canvas.drawCircle(Offset(x, y), 6, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
        
        // Draw tooltip
        _drawTooltip(canvas, Offset(x, y), priceData[i], size);
      } else if (i % (priceData.length ~/ 10) == 0) {
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
      }
    }
  }

  void _drawTooltip(Canvas canvas, Offset point, double value, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '\$${value.toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(point.dx, point.dy - 30),
        width: textPainter.width + 16,
        height: textPainter.height + 8,
      ),
      const Radius.circular(8),
    );
    
    canvas.drawRRect(
      tooltipRect,
      Paint()..color = const Color(0xFF1F2937),
    );
    
    textPainter.paint(
      canvas,
      Offset(
        tooltipRect.center.dx - textPainter.width / 2,
        tooltipRect.center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(CryptoPricePainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
           oldDelegate.selectedIndex != selectedIndex ||
           oldDelegate.timeframe != timeframe;
  }
}

class CryptoVolumePainter extends CustomPainter {
  final List<double> volumeData;
  final Animation<double> animation;

  CryptoVolumePainter({
    required this.volumeData,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (volumeData.isEmpty) return;

    final maxVolume = volumeData.reduce(math.max);
    final barWidth = size.width / volumeData.length;
    final animatedLength = (volumeData.length * animation.value).round();

    for (int i = 0; i < animatedLength; i++) {
      final barHeight = (volumeData[i] / maxVolume) * size.height;
      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth * 0.8,
        barHeight,
      );

      final paint = Paint()
        ..color = const Color(0xFF6366F1).withOpacity(0.6);

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(CryptoVolumePainter oldDelegate) {
    return oldDelegate.animation.value != animation.value;
  }
}