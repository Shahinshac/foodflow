import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/upload_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/dashboard_sidebar.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/motion_system.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../notifications/presentation/notification_sheet.dart';
import '../../restaurant/domain/models.dart';

final ownerRestaurantProvider = FutureProvider<RestaurantModel>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/owner/restaurant');
  return RestaurantModel.fromJson(response.data);
});

final ownerOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/owner/orders');
  return (response.data as List).map((e) => OrderModel.fromJson(e)).toList();
});

final ownerFoodsProvider = FutureProvider<List<FoodItemModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/owner/foods');
  return (response.data as List).map((e) => FoodItemModel.fromJson(e)).toList();
});

final ownerPromotionsProvider = FutureProvider<List<CouponModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/owner/promotions');
  return (response.data as List).map((e) => CouponModel.fromJson(e)).toList();
});

final ownerAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/owner/analytics');
  return Map<String, dynamic>.from(response.data);
});

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Timer? _refreshTimer;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(ownerOrdersProvider);
      ref.invalidate(ownerRestaurantProvider);
    });
  }

  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _tabController.dispose();
    super.dispose();
  }

  void _updateOrderStatus(int orderId, String newStatus) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/owner/orders/$orderId/status', data: {'status': newStatus});
      ref.invalidate(ownerOrdersProvider);
      ref.invalidate(ownerAnalyticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.replaceAll("_", " ")}'),
            backgroundColor: AppColors.veg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _toggleFoodAvailability(int foodId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/owner/foods/$foodId/toggle-availability');
      ref.invalidate(ownerFoodsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle availability: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _toggleStoreStatus(bool isOpen) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/owner/restaurant/settings', data: {'is_open': isOpen});
      ref.invalidate(ownerRestaurantProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOpen ? 'Restaurant is now OPEN & accepting orders' : 'Restaurant is now CLOSED'),
            backgroundColor: isOpen ? AppColors.veg : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update store status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _updatePrepTime(int minutes) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/owner/restaurant/settings', data: {'prep_time_minutes': minutes});
      ref.invalidate(ownerRestaurantProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estimated preparation time updated to $minutes mins'),
            backgroundColor: AppColors.veg,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update prep time: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCreatePromoDialog() {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '20');
    final minOrderCtrl = TextEditingController(text: '200');
    final maxDiscountCtrl = TextEditingController(text: '100');
    String discountType = 'PERCENTAGE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create Restaurant Offer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Coupon Code', hintText: 'e.g. SPECIAL25'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Offer Title', hintText: 'e.g. 25% OFF Weekend Feast'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Get 25% off on orders above ₹200'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Discount Value (%)', suffixText: '%'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minOrderCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Min Order (₹)', prefixText: '₹ '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxDiscountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max Discount Cap (₹)', prefixText: '₹ '),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (codeCtrl.text.trim().isEmpty) return;
                      try {
                        final apiClient = ref.read(apiClientProvider);
                        final minOrderPaise = (double.parse(minOrderCtrl.text.trim()) * 100).toInt();
                        final maxDiscountPaise = (double.parse(maxDiscountCtrl.text.trim()) * 100).toInt();
                        final discountVal = int.parse(discountCtrl.text.trim());

                        await apiClient.dio.post(
                          '/owner/promotions',
                          data: {
                            'code': codeCtrl.text.trim().toUpperCase(),
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'discount_type': discountType,
                            'discount_value': discountVal,
                            'min_order_paise': minOrderPaise,
                            'max_discount_paise': maxDiscountPaise,
                            'usage_limit': 500,
                            'per_user_limit': 3,
                          },
                        );
                        ref.invalidate(ownerPromotionsProvider);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Offer created successfully!'), backgroundColor: AppColors.veg),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to create offer: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Publish Promotion', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFoodDialog() => _showFoodFormDialog();

  void _showEditFoodDialog(FoodItemModel food) => _showFoodFormDialog(existingFood: food);

  void _showFoodFormDialog({FoodItemModel? existingFood}) {
    final isEditing = existingFood != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingFood?.name ?? '');
    final descController = TextEditingController(text: existingFood?.description ?? '');
    final basePrice = existingFood != null ? (existingFood.pricePaise / 100).toStringAsFixed(0) : '';
    final priceController = TextEditingController(text: basePrice);

    bool isVeg = existingFood?.isVeg ?? true;
    String? uploadedImageUrl = existingFood?.imageUrl;
    bool isUploading = false;

    bool hasPortions = existingFood?.portions != null && existingFood!.portions!.isNotEmpty;
    bool quarterOverridden = isEditing;
    bool halfOverridden = isEditing;
    bool threeQuarterOverridden = isEditing;
    bool fullOverridden = isEditing;

    final quarterCtrl = TextEditingController(
      text: existingFood?.portions?['QUARTER'] != null
          ? (existingFood!.portions!['QUARTER']! / 100).toStringAsFixed(0)
          : '',
    );
    final halfCtrl = TextEditingController(
      text: existingFood?.portions?['HALF'] != null
          ? (existingFood!.portions!['HALF']! / 100).toStringAsFixed(0)
          : '',
    );
    final threeQuarterCtrl = TextEditingController(
      text: existingFood?.portions?['THREE_QUARTER'] != null
          ? (existingFood!.portions!['THREE_QUARTER']! / 100).toStringAsFixed(0)
          : '',
    );
    final fullCtrl = TextEditingController(
      text: existingFood?.portions?['FULL'] != null
          ? (existingFood!.portions!['FULL']! / 100).toStringAsFixed(0)
          : basePrice,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void updatePortionsFromBase(String val) {
            final parsed = double.tryParse(val.trim());
            if (parsed == null || parsed <= 0) return;
            if (!quarterOverridden) {
              quarterCtrl.text = (parsed * 0.35).round().toString();
            }
            if (!halfOverridden) {
              halfCtrl.text = (parsed * 0.60).round().toString();
            }
            if (!threeQuarterOverridden) {
              threeQuarterCtrl.text = (parsed * 0.85).round().toString();
            }
            if (!fullOverridden) {
              fullCtrl.text = parsed.round().toString();
            }
          }

          return Container(
            padding: EdgeInsets.only(
              top: 24,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Dish Details' : 'Add New Food Item',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Dish Name', hintText: 'e.g. Tandoori Paneer Tikka'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'Ingredients, flavor notes, portion'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceController,
                            decoration: const InputDecoration(labelText: 'Base / Full Price (₹)', prefixText: '₹ '),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              if (hasPortions) {
                                setModalState(() => updatePortionsFromBase(val));
                              }
                            },
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Price required';
                              if (double.tryParse(v) == null) return 'Invalid number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: Text(isVeg ? 'VEG 🟢' : 'NON-VEG 🔴'),
                          selected: true,
                          selectedColor: isVeg ? AppColors.veg.withValues(alpha: 0.15) : AppColors.nonVeg.withValues(alpha: 0.15),
                          onSelected: (_) => setModalState(() => isVeg = !isVeg),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Portion Management Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Portion-Based Pricing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                    'Quarter (35%), Half (60%), 3/4 (85%), Full (100%)',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              Switch(
                                value: hasPortions,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) {
                                  setModalState(() {
                                    hasPortions = val;
                                    if (hasPortions) {
                                      updatePortionsFromBase(priceController.text);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (hasPortions) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: quarterCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Quarter (₹)', prefixText: '₹ '),
                                    onChanged: (_) => quarterOverridden = true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: halfCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Half (₹)', prefixText: '₹ '),
                                    onChanged: (_) => halfOverridden = true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: threeQuarterCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: '3/4 Portion (₹)', prefixText: '₹ '),
                                    onChanged: (_) => threeQuarterOverridden = true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: fullCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Full (₹)', prefixText: '₹ '),
                                    onChanged: (_) => fullOverridden = true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: isUploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_a_photo_outlined),
                          label: Text(uploadedImageUrl != null ? 'Image Attached' : 'Attach Photo'),
                          onPressed: isUploading
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                  if (img != null) {
                                    setModalState(() => isUploading = true);
                                    try {
                                      final uploadRepo = ref.read(uploadRepositoryProvider);
                                      final url = await uploadRepo.uploadImage(img);
                                      setModalState(() {
                                        uploadedImageUrl = url;
                                        isUploading = false;
                                      });
                                    } catch (e) {
                                      setModalState(() => isUploading = false);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Upload failed: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                        ),
                        if (uploadedImageUrl != null) ...[
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: AppConstants.resolveImageUrl(uploadedImageUrl),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              final priceRupees = double.parse(priceController.text.trim());
                              final pricePaise = (priceRupees * 100).toInt();

                              Map<String, int>? portionsMap;
                              if (hasPortions) {
                                final fullP = fullCtrl.text.isNotEmpty
                                    ? (double.parse(fullCtrl.text.trim()) * 100).toInt()
                                    : pricePaise;
                                portionsMap = {'FULL': fullP};
                                if (quarterCtrl.text.isNotEmpty) {
                                  portionsMap['QUARTER'] = (double.parse(quarterCtrl.text.trim()) * 100).toInt();
                                }
                                if (halfCtrl.text.isNotEmpty) {
                                  portionsMap['HALF'] = (double.parse(halfCtrl.text.trim()) * 100).toInt();
                                }
                                if (threeQuarterCtrl.text.isNotEmpty) {
                                  portionsMap['THREE_QUARTER'] = (double.parse(threeQuarterCtrl.text.trim()) * 100).toInt();
                                }
                              }

                              final apiClient = ref.read(apiClientProvider);
                              final payload = {
                                'name': nameController.text.trim(),
                                'description': descController.text.trim(),
                                'price_paise': pricePaise,
                                'is_veg': isVeg,
                                'image_url': uploadedImageUrl,
                                'is_available': true,
                                'portions': portionsMap,
                              };

                              if (isEditing) {
                                await apiClient.dio.put('/owner/foods/${existingFood.id}', data: payload);
                              } else {
                                await apiClient.dio.post('/owner/foods', data: payload);
                              }

                              ref.invalidate(ownerFoodsProvider);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEditing ? 'Dish updated successfully!' : 'Dish added to menu!'),
                                    backgroundColor: AppColors.veg,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save dish: $e'), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          }
                        },
                        child: Text(isEditing ? 'Update Dish' : 'Add Dish to Menu', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOnboardRestaurantDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final cuisineCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final delFeeCtrl = TextEditingController(text: '30');
    final minOrderCtrl = TextEditingController(text: '100');
    final estTimeCtrl = TextEditingController(text: '25-35 min');
    String? uploadedImageUrl;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Register Your Restaurant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Restaurant Name', hintText: 'e.g. Royal Biryani House'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cuisineCtrl,
                    decoration: const InputDecoration(labelText: 'Cuisines Offered', hintText: 'e.g. Biryani, North Indian, Kebabs'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Cuisines required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Short Description', hintText: 'e.g. Authentic aromatic Dum Biryanis'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Complete Address / Location', hintText: 'e.g. Shop 4B, 100ft Road, Indiranagar'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Address required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: delFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Delivery Fee (₹)', prefixText: '₹ '),
                          validator: (v) => v == null || double.tryParse(v) == null ? 'Fee required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: minOrderCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Order (₹)', prefixText: '₹ '),
                          validator: (v) => v == null || double.tryParse(v) == null ? 'Min order required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: estTimeCtrl,
                    decoration: const InputDecoration(labelText: 'Estimated Delivery Time', hintText: 'e.g. 25-35 min'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_a_photo_outlined),
                        label: Text(uploadedImageUrl != null ? 'Banner Photo Attached' : 'Attach Cover Photo'),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                if (img != null) {
                                  setModalState(() => isUploading = true);
                                  try {
                                    final uploadRepo = ref.read(uploadRepositoryProvider);
                                    final url = await uploadRepo.uploadImage(img);
                                    setModalState(() {
                                      uploadedImageUrl = url;
                                      isUploading = false;
                                    });
                                  } catch (e) {
                                    setModalState(() => isUploading = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            final delFeePaise = (double.parse(delFeeCtrl.text.trim()) * 100).toInt();
                            final minOrderPaise = (double.parse(minOrderCtrl.text.trim()) * 100).toInt();

                            final apiClient = ref.read(apiClientProvider);
                            await apiClient.dio.post(
                              '/owner/restaurant',
                              data: {
                                'name': nameCtrl.text.trim(),
                                'cuisine': cuisineCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'address_text': addressCtrl.text.trim(),
                                'delivery_fee_paise': delFeePaise,
                                'min_order_paise': minOrderPaise,
                                'estimated_delivery_time': estTimeCtrl.text.trim(),
                                'image_url': uploadedImageUrl,
                                'is_open': true,
                                'prep_time_minutes': 25,
                              },
                            );
                            ref.invalidate(ownerRestaurantProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Restaurant profile submitted! Awaiting Admin approval.'),
                                  backgroundColor: AppColors.veg,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Submission failed: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Submit Restaurant for Review', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(ownerRestaurantProvider);
    final ordersAsync = ref.watch(ownerOrdersProvider);
    final foodsAsync = ref.watch(ownerFoodsProvider);
    final promosAsync = ref.watch(ownerPromotionsProvider);
    final analyticsAsync = ref.watch(ownerAnalyticsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_tabController.index != 0) {
          _tabController.animateTo(0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit FoodFlow'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: restaurantAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Restaurant Partner Portal', style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Restaurant Partner Portal', style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, size: 72, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to FoodFlow Partner',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'No restaurant is associated with this account yet. Register your restaurant details to submit for Super Admin approval and start receiving orders.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _showOnboardRestaurantDialog,
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Register Restaurant Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (restaurant) => LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          final tabViews = TabBarView(
            controller: _tabController,
            children: [
                  // TAB 1: LIVE ORDERS
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownerOrdersProvider),
            color: AppColors.primary,
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const CustomEmptyView(
                    title: 'No Incoming Orders',
                    description: 'Your store is ready. New incoming customer orders will appear here automatically.',
                    icon: Icons.receipt_long_outlined,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    Color statusColor = Colors.orange;
                    Color statusBgColor = Colors.orange.shade50;
                    if (order.status == 'PREPARING') {
                      statusColor = Colors.purple;
                      statusBgColor = Colors.purple.shade50;
                    } else if (order.status == 'READY_FOR_PICKUP' || order.status == 'DELIVERED') {
                      statusColor = Colors.green;
                      statusBgColor = Colors.green.shade50;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order #${order.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    order.status.replaceAll('_', ' '),
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('${order.items.length} items • ${CurrencyFormatter.formatPaise(order.totalPaise)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Deliver to: ${order.deliveryAddress}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14.0),
                              child: Divider(height: 1),
                            ),
                            if (order.status == 'PLACED' || order.status == 'RESTAURANT_CONFIRMED' || order.status == 'PREPARING')
                              Row(
                                children: [
                                  if (order.status == 'PLACED') ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _updateOrderStatus(order.id, 'REJECTED'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: const BorderSide(color: AppColors.error),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _updateOrderStatus(order.id, 'RESTAURANT_CONFIRMED'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.veg,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Accept'),
                                      ),
                                    ),
                                  ],
                                  if (order.status == 'RESTAURANT_CONFIRMED')
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _updateOrderStatus(order.id, 'PREPARING'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Start Preparing Food'),
                                      ),
                                    ),
                                  if (order.status == 'PREPARING')
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _updateOrderStatus(order.id, 'READY_FOR_PICKUP'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.veg,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Mark Food Ready for Delivery'),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (index * 60).ms);
                  },
                );
              },
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 160),
              ),
              error: (err, _) => CustomErrorView(
                message: 'Failed to load orders: ${ApiClient.formatError(err)}',
                onRetry: () => ref.invalidate(ownerOrdersProvider),
              ),
            ),
          ),

          // TAB 2: MENU ITEMS
          Scaffold(
            backgroundColor: Colors.grey.shade50,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _showAddFoodDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Dish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            body: RefreshIndicator(
              onRefresh: () async => ref.invalidate(ownerFoodsProvider),
              color: AppColors.primary,
              child: foodsAsync.when(
                data: (foods) {
                  if (foods.isEmpty) {
                    return const CustomEmptyView(
                      title: 'No Dishes on Menu',
                      description: 'Your menu is empty. Tap "Add Dish" to add your first delicious item.',
                      icon: Icons.restaurant_menu_rounded,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: foods.length,
                    itemBuilder: (context, index) {
                      final food = foods[index];
                      final resolvedImg = AppConstants.resolveImageUrl(food.imageUrl);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: resolvedImg,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(color: Colors.grey.shade200),
                              errorWidget: (c, u, e) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.fastfood, color: Colors.grey),
                              ),
                            ),
                          ),
                          title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(CurrencyFormatter.formatPaise(food.pricePaise), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                              if (food.portions != null && food.portions!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    'Portions: ${food.portions!.entries.map((e) => '${e.key}: ₹${e.value ~/ 100}').join(' | ')}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                tooltip: 'Edit dish',
                                onPressed: () => _showEditFoodDialog(food),
                              ),
                              Switch(
                                value: food.isAvailable,
                                activeThumbColor: AppColors.veg,
                                onChanged: (v) => _toggleFoodAvailability(food.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 75),
                ),
                error: (err, _) => CustomErrorView(
                  message: 'Failed to load menu dishes: ${ApiClient.formatError(err)}',
                  onRetry: () => ref.invalidate(ownerFoodsProvider),
                ),
              ),
            ),
          ),

          // TAB 3: PROMOTIONS / OFFERS
          Scaffold(
            backgroundColor: Colors.grey.shade50,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _showCreatePromoDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            body: RefreshIndicator(
              onRefresh: () async => ref.invalidate(ownerPromotionsProvider),
              color: AppColors.primary,
              child: promosAsync.when(
                data: (promos) {
                  if (promos.isEmpty) {
                    return const CustomEmptyView(
                      title: 'No Active Offers',
                      description: 'Boost your restaurant revenue by launching a special coupon discount.',
                      icon: Icons.local_offer_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: promos.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final promo = promos[index];
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    promo.code,
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                                  ),
                                ),
                                Switch(
                                  value: promo.isActive,
                                  activeThumbColor: AppColors.veg,
                                  onChanged: (v) async {
                                    final apiClient = ref.read(apiClientProvider);
                                    await apiClient.dio.put('/owner/promotions/${promo.id}/toggle');
                                    ref.invalidate(ownerPromotionsProvider);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(promo.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(promo.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _kpiSmall('Used', '${promo.usedCount}/${promo.usageLimit}'),
                                const SizedBox(width: 16),
                                _kpiSmall('Min Order', '₹${promo.minOrderPaise ~/ 100}'),
                                const SizedBox(width: 16),
                                _kpiSmall('Max Discount', '₹${promo.maxDiscountPaise ~/ 100}'),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 110),
                ),
                error: (err, _) => CustomErrorView(
                  message: 'Failed to load store offers: ${ApiClient.formatError(err)}',
                  onRetry: () => ref.invalidate(ownerPromotionsProvider),
                ),
              ),
            ),
          ),

          // TAB 4: RESTAURANT ANALYTICS
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownerAnalyticsProvider),
            color: AppColors.primary,
            child: analyticsAsync.when(
              data: (analytics) {
                final bestSellers = (analytics['best_selling_items'] as List?) ?? [];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Business Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      // KPI Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Today\'s Revenue',
                              CurrencyFormatter.formatPaise(analytics['today_revenue_paise'] ?? 0),
                              Icons.currency_rupee_rounded,
                              AppColors.veg,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'Today\'s Orders',
                              '${analytics['today_orders'] ?? 0}',
                              Icons.receipt_rounded,
                              AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Weekly Sales',
                              CurrencyFormatter.formatPaise(analytics['weekly_revenue_paise'] ?? 0),
                              Icons.trending_up_rounded,
                              AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'Monthly Sales',
                              CurrencyFormatter.formatPaise(analytics['monthly_revenue_paise'] ?? 0),
                              Icons.calendar_month_rounded,
                              AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Average Order Value',
                              CurrencyFormatter.formatPaise(analytics['average_order_value_paise'] ?? 0),
                              Icons.shopping_basket_rounded,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'Cancellation Rate',
                              '${analytics['cancellation_rate_percent'] ?? 0}%',
                              Icons.cancel_rounded,
                              AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Best Selling Dishes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (bestSellers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Completed delivered orders will populate top dishes.'),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppColors.softShadow,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: bestSellers.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = bestSellers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  child: Text('#${index + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${item['quantity_sold']} units sold'),
                                trailing: Text(
                                  CurrencyFormatter.formatPaise(item['sales_paise'] ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                        SizedBox(width: 12),
                        Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                        SizedBox(width: 12),
                        Expanded(child: FoodShimmerLoading(width: double.infinity, height: 95)),
                      ],
                    ),
                  ],
                ),
              ),
              error: (err, _) => CustomErrorView(
                message: 'Failed to load restaurant analytics: ${ApiClient.formatError(err)}',
                onRetry: () => ref.invalidate(ownerAnalyticsProvider),
              ),
            ),
          ),

          // TAB 5: STORE OPERATIONS & CONTROLS
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Operations Controls Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Store Operating Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(restaurant.isOpen ? 'Currently Open & Accepting Orders' : 'Currently Closed'),
                        subtitle: const Text('Toggle to pause or resume customer orders'),
                        value: restaurant.isOpen,
                        activeThumbColor: AppColors.veg,
                        onChanged: (val) => _toggleStoreStatus(val),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('Average Prep Time', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [15, 20, 25, 30, 45].map((mins) {
                          final isSel = restaurant.prepTimeMinutes == mins;
                          return ChoiceChip(
                            label: Text('$mins mins'),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                            onSelected: (_) => _updatePrepTime(mins),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Store Profile Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: CachedNetworkImage(
                              imageUrl: AppConstants.resolveImageUrl(restaurant.imageUrl),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: ElevatedButton.icon(
                              onPressed: () => _updateCoverPhoto(restaurant),
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              label: const Text('Change Cover Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black.withValues(alpha: 0.7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(restaurant.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                                ),
                                _buildApprovalBadge(restaurant),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(restaurant.cuisine, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            if (restaurant.addressText != null) ...[
                              const SizedBox(height: 4),
                              Text(restaurant.addressText!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text('${restaurant.rating} Rating', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 20),
                                const Icon(Icons.timer_outlined, color: Colors.grey, size: 18),
                                const SizedBox(width: 4),
                                Text(restaurant.estimatedDeliveryTime),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

          if (isDesktop) {
            return Scaffold(
              backgroundColor: const Color(0xFFFBF9F5),
              body: Row(
                children: [
                  DashboardSidebar(
                    portalTitle: 'Owner Portal',
                    portalSubtitle: restaurant.name,
                    selectedIndex: _tabController.index,
                    onItemSelected: (idx) => setState(() => _tabController.index = idx),
                    items: const [
                      SidebarItem(index: 0, label: 'Live Orders', icon: Icons.receipt_long_rounded),
                      SidebarItem(index: 1, label: 'Menu Items', icon: Icons.restaurant_menu_rounded),
                      SidebarItem(index: 2, label: 'Offers', icon: Icons.local_offer_rounded),
                      SidebarItem(index: 3, label: 'Analytics', icon: Icons.insights_rounded),
                      SidebarItem(index: 4, label: 'Store Controls', icon: Icons.storefront_rounded),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    restaurant.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    restaurant.isApproved ? 'Verified Partner' : 'Pending Verification',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: restaurant.isApproved ? AppColors.veg : Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Text(
                                    restaurant.isOpen ? 'OPEN' : 'CLOSED',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: restaurant.isOpen ? AppColors.veg : AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Switch(
                                    value: restaurant.isOpen,
                                    activeThumbColor: AppColors.veg,
                                    onChanged: _toggleStoreStatus,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined),
                                onPressed: () => NotificationSheet.show(context),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                tooltip: 'Refresh',
                                onPressed: () {
                                  ref.invalidate(ownerRestaurantProvider);
                                  ref.invalidate(ownerOrdersProvider);
                                  ref.invalidate(ownerFoodsProvider);
                                  ref.invalidate(ownerPromotionsProvider);
                                  ref.invalidate(ownerAnalyticsProvider);
                                },
                              ),
                            ],
                          ),
                        ),
                        _buildApprovalBanner(restaurant),
                        Expanded(child: tabViews),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Text(restaurant.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => NotificationSheet.show(context),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AppColors.primary,
                isScrollable: true,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Live Orders'),
                  Tab(icon: Icon(Icons.restaurant_menu_rounded), text: 'Menu Items'),
                  Tab(icon: Icon(Icons.local_offer_rounded), text: 'Offers'),
                  Tab(icon: Icon(Icons.insights_rounded), text: 'Analytics'),
                  Tab(icon: Icon(Icons.storefront_rounded), text: 'Store Controls'),
                ],
              ),
            ),
            body: Column(
              children: [
                _buildApprovalBanner(restaurant),
                Expanded(child: tabViews),
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _buildApprovalBadge(RestaurantModel restaurant) {
    if (restaurant.rejectionReason != null && restaurant.rejectionReason!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'REJECTED',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }
    if (restaurant.isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.veg.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'APPROVED',
          style: TextStyle(color: AppColors.veg, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'UNDER REVIEW',
        style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildApprovalBanner(RestaurantModel restaurant) {
    if (restaurant.rejectionReason != null && restaurant.rejectionReason!.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: AppColors.error.withValues(alpha: 0.12),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Registration Rejected: "${restaurant.rejectionReason}". Please contact support to resolve.',
                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    if (!restaurant.isApproved) {
      final dateText = restaurant.createdAt != null
          ? ' (Submitted: ${restaurant.createdAt.toString().split(' ').first})'
          : '';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: Colors.amber.shade100,
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Store under review. Super Admin will verify and activate your restaurant soon.$dateText',
                style: TextStyle(color: Colors.brown.shade800, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _updateCoverPhoto(RestaurantModel restaurant) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading cover photo...'), duration: Duration(seconds: 2)),
        );
      }
      final uploadRepo = ref.read(uploadRepositoryProvider);
      final url = await uploadRepo.uploadImage(img);
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.put('/owner/restaurant/settings', data: {'image_url': url});
      ref.invalidate(ownerRestaurantProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover photo updated successfully!'), backgroundColor: AppColors.veg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update cover photo: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _kpiSmall(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
