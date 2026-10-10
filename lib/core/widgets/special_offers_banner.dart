import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../../features/restaurant/domain/models.dart';

class SpecialOffersCard extends StatelessWidget {
  final CouponModel? coupon;
  final VoidCallback? onOrderNowTap;

  const SpecialOffersCard({
    super.key,
    this.coupon,
    this.onOrderNowTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoupon = coupon != null;
    final badgeText = hasCoupon ? (coupon!.code.isNotEmpty ? coupon!.code : 'OFFER') : 'EXPLORE & ENJOY';
    final mainTitle = hasCoupon
        ? (coupon!.discountType == 'PERCENTAGE'
            ? '${coupon!.discountValue}% OFF'
            : (coupon!.discountType == 'FREE_DELIVERY'
                ? 'FREE DELIVERY'
                : '₹${coupon!.discountValue ~/ 100} OFF'))
        : 'Discover Top Restaurants';
    final subtitle = hasCoupon
        ? (coupon!.description.isNotEmpty ? coupon!.description : coupon!.title)
        : 'Fresh & tasty meals delivered to your doorstep';
    final buttonText = hasCoupon ? 'Claim Offer' : 'Explore Menu';

    return Container(
      height: 165,
      decoration: BoxDecoration(
        color: const Color(0xFF13221C), // Deep forest dark card
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Right Side Food Image
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 170,
              child: CachedNetworkImage(
                imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
                fit: BoxFit.cover,
                placeholder: (_, __) => Shimmer.fromColors(
                  baseColor: Colors.black26,
                  highlightColor: Colors.white12,
                  child: Container(color: Colors.black26),
                ),
                errorWidget: (_, __, ___) => const Icon(Icons.fastfood_rounded, color: Colors.white30, size: 48),
              ),
            ),

            // Left Gradient Mask
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF13221C),
                      const Color(0xFF13221C).withValues(alpha: 0.95),
                      const Color(0xFF13221C).withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Text Content & CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mainTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(110, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    onPressed: onOrderNowTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonText,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

