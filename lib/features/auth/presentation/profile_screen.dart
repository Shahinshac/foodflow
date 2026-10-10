import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/motion_system.dart';
import 'auth_providers.dart';

class AddressItem {
  final int id;
  final String label;
  final String streetAddress;
  final String city;
  final String pincode;
  final bool isDefault;

  AddressItem({
    required this.id,
    required this.label,
    required this.streetAddress,
    required this.city,
    required this.pincode,
    required this.isDefault,
  });

  factory AddressItem.fromJson(Map<String, dynamic> json) {
    return AddressItem(
      id: json['id'],
      label: json['label'] ?? 'HOME',
      streetAddress: json['street_address'] ?? '',
      city: json['city'] ?? 'City',
      pincode: json['pincode'] ?? '',
      isDefault: json['is_default'] ?? false,
    );
  }
}

final userAddressesProvider = FutureProvider<List<AddressItem>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.dio.get('/users/addresses');
  return (response.data as List).map((e) => AddressItem.fromJson(e)).toList();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showAddAddressDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final streetController = TextEditingController();
    final cityController = TextEditingController(text: 'Innovation City');
    final pinController = TextEditingController(text: '100001');
    String selectedLabel = 'HOME';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Address',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: ['HOME', 'WORK', 'OTHER'].map((label) {
                    final isSel = selectedLabel == label;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedLabel = label);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street Address & Flat / Building',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter address' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'City required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: pinController,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Pincode required' : null,
                      ),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              setModalState(() => isSubmitting = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                await api.dio.post(
                                  '/users/addresses',
                                  data: {
                                    'label': selectedLabel,
                                    'street_address': streetController.text.trim(),
                                    'city': cityController.text.trim(),
                                    'pincode': pinController.text.trim(),
                                    'is_default': false,
                                  },
                                );
                                ref.invalidate(userAddressesProvider);
                                if (modalCtx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (modalCtx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ApiClient.formatError(e)),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } finally {
                                if (modalCtx.mounted) setModalState(() => isSubmitting = false);
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                          )
                        : const Text('Save Address', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteAddress(BuildContext context, WidgetRef ref, int addressId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/users/addresses/$addressId');
      ref.invalidate(userAddressesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted successfully'),
            backgroundColor: AppColors.veg,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.formatError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final addressesAsync = ref.watch(userAddressesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userAddressesProvider);
          await ref.read(authProvider.notifier).checkAuth();
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (user?.fullName.isNotEmpty == true) ? user!.fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'FoodFlow User',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user?.role ?? 'CUSTOMER',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
              const SizedBox(height: 28),

              // Saved Addresses Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Addresses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddAddressDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                    label: const Text('Add New', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),

              addressesAsync.when(
                data: (addresses) {
                  if (addresses.isEmpty) {
                    return CustomEmptyView(
                      title: 'No saved addresses yet',
                      description: 'Add your home or work address for quick one-tap checkout.',
                      icon: Icons.location_off_rounded,
                      actionButton: ElevatedButton.icon(
                        onPressed: () => _showAddAddressDialog(context, ref),
                        icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                        label: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final addr = addresses[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              addr.label == 'HOME'
                                  ? Icons.home_rounded
                                  : (addr.label == 'WORK' ? Icons.work_rounded : Icons.location_on_rounded),
                              color: AppColors.primary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                addr.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              if (addr.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.veg.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(color: AppColors.veg, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${addr.streetAddress}, ${addr.city} ${addr.pincode}',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontSize: 13,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            onPressed: () => _deleteAddress(context, ref, addr.id),
                          ),
                        ),
                      ).animate().fadeIn(delay: (index * 80).ms);
                    },
                  );
                },
                loading: () => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 2,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const FoodShimmerLoading(width: double.infinity, height: 72),
                ),
                error: (err, _) => CustomErrorView(
                  message: ApiClient.formatError(err),
                  onRetry: () => ref.invalidate(userAddressesProvider),
                ),
              ),
              const SizedBox(height: 36),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
