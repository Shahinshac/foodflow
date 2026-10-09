import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../presentation/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Smooth redirect after animation completes
    _redirectTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        final role = authState.user?.role ?? 'CUSTOMER';
        if (role == 'RESTAURANT_OWNER') {
          context.go('/owner-dashboard');
        } else if (role == 'DELIVERY_PARTNER') {
          context.go('/delivery-dashboard');
        } else if (role == 'ADMIN') {
          context.go('/admin-dashboard');
        } else {
          context.go('/');
        }
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxHeight < 600;
            final logoSize = isSmallScreen ? 84.0 : 104.0;
            final iconSize = isSmallScreen ? 44.0 : 54.0;
            final titleFontSize = isSmallScreen ? 32.0 : 38.0;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Perfectly centered responsive ambient glow orb
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) => Container(
                    width: (isSmallScreen ? 200 : 260) * _glowAnimation.value,
                    height: (isSmallScreen ? 200 : 260) * _glowAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(
                        alpha: 0.22 * _glowAnimation.value,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.3 * _glowAnimation.value,
                          ),
                          blurRadius: 90,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),

                // Core Branding Card and Tagline
                Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // App Logo Mark
                              Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  gradient: AppColors.warmHeroGradient,
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 24 : 28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.45),
                                      blurRadius: 28,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: iconSize,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 26),

                              // App Brand Title
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Food',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Flow',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Tagline
                              Text(
                                'Crave. Order. Relish.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: isSmallScreen ? 13 : 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom subtle loader
                Positioned(
                  bottom: isSmallScreen ? 24 : 40,
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
