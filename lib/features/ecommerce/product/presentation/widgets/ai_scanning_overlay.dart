import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

class AiScanningOverlay extends StatefulWidget {
  final File imageFile;
  final Future<String?> analysisFuture;
  final VoidCallback onCancel;

  const AiScanningOverlay({
    super.key,
    required this.imageFile,
    required this.analysisFuture,
    required this.onCancel,
  });

  @override
  State<AiScanningOverlay> createState() => _AiScanningOverlayState();
}

class _AiScanningOverlayState extends State<AiScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  final List<String> _steps = [
    '⚡ Đang chuẩn bị dữ liệu hình ảnh...',
    '🧠 Kết nối cổng AI OpenRouter Server...',
    '🔍 Đang phân tích kiểu dáng & màu sắc...',
    '🎯 Đối chiếu danh mục sản phẩm cửa hàng...',
    '🎉 Đang tối ưu kết quả hiển thị...',
  ];
  int _currentStepIndex = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    // 1. Setup Laser Line Animation
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // 2. Setup rotating status messages every 1500ms
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _currentStepIndex = (_currentStepIndex + 1) % _steps.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFEE4D2D), Color(0xFFFF8C00)],
                  ).createShader(bounds),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'SHARECO AI SEARCH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hệ Thống Trực Quan Nhận Diện Hình Ảnh Nhãn Hàng',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Laser Image Container
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ring shadow
                    Container(
                      width: 248,
                      height: 248,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEE4D2D).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    // Image display
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 240,
                        height: 240,
                        color: Colors.grey.shade900,
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Laser Scan line overlay
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: 4 + (_scanAnimation.value * 232),
                          left: 8,
                          right: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Glow bar
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFFFF3D00),
                                      Color(0xFFFFEA00),
                                      Color(0xFFFF3D00),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF5722).withOpacity(0.9),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              // Trail gradient
                              Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFFFF5722).withOpacity(0.25),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 44),

                // Step progress label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEE4D2D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _steps[_currentStepIndex],
                          key: ValueKey<int>(_currentStepIndex),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Cancel Button
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
                  label: const Text(
                    'Hủy phân tích',
                    style: TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.04),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
