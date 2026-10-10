import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
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
  final double? latitude;
  final double? longitude;

  AddressItem({
    required this.id,
    required this.label,
    required this.streetAddress,
    required this.city,
    required this.pincode,
    required this.isDefault,
    this.latitude,
    this.longitude,
  });

  factory AddressItem.fromJson(Map<String, dynamic> json) {
    return AddressItem(
      id: json['id'],
      label: json['label'] ?? 'HOME',
      streetAddress: json['street_address'] ?? '',
      city: json['city'] ?? 'City',
      pincode: json['pincode'] ?? '',
      isDefault: json['is_default'] ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
    double? selectedLat;
    double? selectedLng;
    bool isLocating = false;

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
            child: SingleChildScrollView(
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLocating
                              ? null
                              : () async {
                                  setModalState(() => isLocating = true);
                                  final pos = await LocationService.determinePosition(
                                    onError: (err) {
                                      if (modalCtx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
                                      }
                                    },
                                  );
                                  if (pos != null) {
                                    final addr = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
                                    setModalState(() {
                                      selectedLat = pos.latitude;
                                      selectedLng = pos.longitude;
                                      streetController.text = addr;
                                      isLocating = false;
                                    });
                                  } else {
                                    setModalState(() => isLocating = false);
                                  }
                                },
                          icon: isLocating
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(isLocating ? 'Locating...' : 'Use GPS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await LocationService.showMapPicker(
                              context,
                              initialCenter: (selectedLat != null && selectedLng != null) ? LatLng(selectedLat!, selectedLng!) : null,
                              initialAddress: streetController.text,
                              title: 'Pin Delivery Address',
                              subtitle: 'Move pin to your doorstep for accurate deliveries',
                              confirmButtonText: 'Confirm Address Location',
                            );
                            if (result != null) {
                              setModalState(() {
                                selectedLat = result.coordinates.latitude;
                                selectedLng = result.coordinates.longitude;
                                streetController.text = result.address;
                              });
                            }
                          },
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: const Text('Pick on Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedLat != null && selectedLng != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'GPS Pinned (${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)})',
                              style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                                      'latitude': selectedLat,
                                      'longitude': selectedLng,
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
      ),
    );
  }

  void _showEditAddressDialog(BuildContext context, WidgetRef ref, AddressItem addr) {
    final formKey = GlobalKey<FormState>();
    final streetController = TextEditingController(text: addr.streetAddress);
    final cityController = TextEditingController(text: addr.city);
    final pinController = TextEditingController(text: addr.pincode);
    String selectedLabel = addr.label;
    bool isSubmitting = false;
    double? selectedLat = addr.latitude;
    double? selectedLng = addr.longitude;
    bool isLocating = false;

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Address',
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLocating
                              ? null
                              : () async {
                                  setModalState(() => isLocating = true);
                                  final pos = await LocationService.determinePosition(
                                    onError: (err) {
                                      if (modalCtx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
                                      }
                                    },
                                  );
                                  if (pos != null) {
                                    final newAddr = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
                                    setModalState(() {
                                      selectedLat = pos.latitude;
                                      selectedLng = pos.longitude;
                                      streetController.text = newAddr;
                                      isLocating = false;
                                    });
                                  } else {
                                    setModalState(() => isLocating = false);
                                  }
                                },
                          icon: isLocating
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: Text(isLocating ? 'Locating...' : 'Use GPS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await LocationService.showMapPicker(
                              context,
                              initialCenter: (selectedLat != null && selectedLng != null) ? LatLng(selectedLat!, selectedLng!) : null,
                              initialAddress: streetController.text,
                              title: 'Edit Delivery Address Pin',
                              subtitle: 'Move pin to your exact delivery location',
                              confirmButtonText: 'Save Address Location',
                            );
                            if (result != null) {
                              setModalState(() {
                                selectedLat = result.coordinates.latitude;
                                selectedLng = result.coordinates.longitude;
                                streetController.text = result.address;
                              });
                            }
                          },
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: const Text('Pick on Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedLat != null && selectedLng != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'GPS Pinned (${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)})',
                              style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                                  await api.dio.put(
                                    '/users/addresses/${addr.id}',
                                    data: {
                                      'label': selectedLabel,
                                      'street_address': streetController.text.trim(),
                                      'city': cityController.text.trim(),
                                      'pincode': pinController.text.trim(),
                                      'latitude': selectedLat,
                                      'longitude': selectedLng,
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
                          : const Text('Update Address', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${addr.streetAddress}, ${addr.city} ${addr.pincode}',
                                style: TextStyle(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  fontSize: 13,
                                ),
                              ),
                              if (addr.latitude != null && addr.longitude != null) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.pin_drop_rounded, size: 12, color: AppColors.veg),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pin: ${addr.latitude!.toStringAsFixed(4)}, ${addr.longitude!.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.veg, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 3),
                                const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.pending),
                                    SizedBox(width: 4),
                                    Text(
                                      'No map pin (tap edit to set)',
                                      style: TextStyle(fontSize: 11, color: AppColors.pending, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                tooltip: 'Edit Address & Pin',
                                onPressed: () => _showEditAddressDialog(context, ref, addr),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                tooltip: 'Delete Address',
                                onPressed: () => _deleteAddress(context, ref, addr.id),
                              ),
                            ],
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
