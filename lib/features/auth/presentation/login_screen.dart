import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/upload_providers.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? forcedRole; // 'CUSTOMER', 'ADMIN', 'RESTAURANT_OWNER', 'DELIVERY_PARTNER'

  const LoginScreen({super.key, this.forcedRole});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      final success = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (success && mounted) {
        final role = ref.read(authProvider).user?.role ?? 'CUSTOMER';
        if (!kIsWeb && (role == 'ADMIN' || role == 'RESTAURANT_OWNER')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin and Restaurant Owner portals are accessible via the Web platform.'),
              backgroundColor: AppColors.error,
            ),
          );
          ref.read(authProvider.notifier).logout();
          return;
        }

        final targetRole = widget.forcedRole ?? 'CUSTOMER';
        if (targetRole == 'ADMIN' && role != 'ADMIN') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Administrator privileges required.'),
              backgroundColor: AppColors.error,
            ),
          );
          ref.read(authProvider.notifier).logout();
          return;
        }
        if (targetRole == 'RESTAURANT_OWNER' && role != 'RESTAURANT_OWNER') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Restaurant Owner account required.'),
              backgroundColor: AppColors.error,
            ),
          );
          ref.read(authProvider.notifier).logout();
          return;
        }
        if (targetRole == 'DELIVERY_PARTNER' && role != 'DELIVERY_PARTNER') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Delivery Rider account required.'),
              backgroundColor: AppColors.error,
            ),
          );
          ref.read(authProvider.notifier).logout();
          return;
        }

        if (role == 'RESTAURANT_OWNER') {
          context.go('/owner');
        } else if (role == 'DELIVERY_PARTNER') {
          context.go('/rider');
        } else if (role == 'ADMIN') {
          context.go('/admin');
        } else {
          context.go('/');
        }
      }
    }
  }

  void _handleGoogleSignIn() async {
    final success = await ref.read(authProvider.notifier).signInWithGoogle();
    if (success == true && mounted) {
      context.go('/');
    }
  }

  void _showOwnerRegistrationDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final restNameCtrl = TextEditingController();
    final cuisineCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final delFeeCtrl = TextEditingController(text: '30');
    final minOrderCtrl = TextEditingController(text: '100');
    final estTimeCtrl = TextEditingController(text: '25-35 min');
    String? uploadedImageUrl;
    bool isUploading = false;
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Partner Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Register your restaurant with FoodFlow for admin review.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(height: 24),
                  const Text('OWNER ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const Divider(height: 32),
                  const Text('RESTAURANT DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: restNameCtrl,
                    decoration: const InputDecoration(labelText: 'Restaurant Name *', prefixIcon: Icon(Icons.storefront_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cuisineCtrl,
                    decoration: const InputDecoration(labelText: 'Cuisine (e.g. North Indian, Biryani) *', prefixIcon: Icon(Icons.restaurant_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Full Address *', prefixIcon: Icon(Icons.location_on_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Bio / Description', prefixIcon: Icon(Icons.notes_outlined)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  // Cover Image Picker
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: uploadedImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(uploadedImageUrl!, fit: BoxFit.cover),
                              )
                            : (isUploading
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.image_outlined, color: Colors.grey)),
                      ),
                      const SizedBox(width: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text(uploadedImageUrl != null ? 'Change Photo' : 'Upload Cover'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkAction, foregroundColor: Colors.white),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                                if (file != null) {
                                  setModalState(() => isUploading = true);
                                  try {
                                    final uploader = ref.read(uploadRepositoryProvider);
                                    final url = await uploader.uploadImage(file);
                                    setModalState(() {
                                      uploadedImageUrl = url;
                                      isUploading = false;
                                    });
                                  } catch (e) {
                                    setModalState(() => isUploading = false);
                                    if (modalCtx.mounted) {
                                      ScaffoldMessenger.of(modalCtx).showSnackBar(
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
                        backgroundColor: AppColors.darkAction,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (formKey.currentState!.validate()) {
                                setModalState(() => isSubmitting = true);
                                try {
                                  final authNotifier = ref.read(authProvider.notifier);
                                  final success = await authNotifier.registerOwner(
                                    fullName: nameCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    password: passCtrl.text,
                                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                    restaurantName: restNameCtrl.text.trim(),
                                    cuisine: cuisineCtrl.text.trim(),
                                    addressText: addressCtrl.text.trim(),
                                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                    deliveryFeePaise: (int.tryParse(delFeeCtrl.text.trim()) ?? 30) * 100,
                                    minOrderPaise: (int.tryParse(minOrderCtrl.text.trim()) ?? 100) * 100,
                                    estimatedDeliveryTime: estTimeCtrl.text.trim(),
                                    imageUrl: uploadedImageUrl,
                                  );

                                  if (success && modalCtx.mounted) {
                                    Navigator.pop(ctx);
                                    if (mounted) {
                                      context.go('/owner-dashboard');
                                    }
                                  }
                                } catch (e) {
                                  if (modalCtx.mounted) {
                                    ScaffoldMessenger.of(modalCtx).showSnackBar(
                                      SnackBar(content: Text('Registration failed: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                } finally {
                                  if (modalCtx.mounted) setModalState(() => isSubmitting = false);
                                }
                              }
                            },
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFBF9F5),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            // DESKTOP SPLIT SCREEN (Reference Image 2)
            return Row(
              children: [
                // Left Hero Column (45%)
                Expanded(
                  flex: 45,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF13221C), // Deep forest dark branding
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Dish Photo
                        CachedNetworkImage(
                          imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=1000&q=80',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: const Color(0xFF13221C)),
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFF13221C)),
                        ),
                        // Dark Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF13221C).withValues(alpha: 0.8),
                                const Color(0xFF13221C).withValues(alpha: 0.95),
                              ],
                            ),
                          ),
                        ),
                        // Brand Content
                        Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Logo
                              InkWell(
                                onTap: () => context.go('/'),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'FoodFlow',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Main Message
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Good Food\nBetter Days',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.15,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Fresh meals from your favourite restaurants, delivered to your doorstep.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  _HeroFeatureItem(icon: Icons.dinner_dining_rounded, label: 'Wide variety of cuisines'),
                                  const SizedBox(height: 12),
                                  _HeroFeatureItem(icon: Icons.local_offer_rounded, label: 'Great offers and deals'),
                                  const SizedBox(height: 12),
                                  _HeroFeatureItem(icon: Icons.bolt_rounded, label: 'Fast and reliable delivery'),
                                ],
                              ),

                              // Platform Trust Badge
                              Row(
                                children: const [
                                  Icon(Icons.shield_outlined, color: Colors.white60, size: 16),
                                  SizedBox(width: 8),
                                  Text('Secure & Authorized Access Only', style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Login Form Column (55%)
                Expanded(
                  flex: 55,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _buildLoginForm(authState, isDark, true),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // MOBILE LAYOUT
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      // Header Logo & Branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.warmHeroGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppColors.primaryGlow,
                            ),
                            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Food',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const TextSpan(
                                  text: 'Flow',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.forcedRole == 'DELIVERY_PARTNER' ? '🛵 DELIVERY FLEET' : 'FAST • FRESH • DELIVERED',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Card Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppColors.softShadow,
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: _buildLoginForm(authState, isDark, false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginForm(AuthState authState, bool isDark, bool isDesktop) {
    final targetRole = widget.forcedRole ?? 'CUSTOMER';
    final isCustomer = targetRole == 'CUSTOMER';
    final isAdmin = targetRole == 'ADMIN';
    final isOwner = targetRole == 'RESTAURANT_OWNER';
    final isRider = targetRole == 'DELIVERY_PARTNER';

    String titleText = 'Welcome Back';
    String subtitleText = 'Sign in to order your favourite meals';
    if (isAdmin) {
      titleText = 'Admin Portal';
      subtitleText = 'Sign in with administrator credentials';
    } else if (isOwner) {
      titleText = 'Restaurant Partner Login';
      subtitleText = 'Manage your menu, live orders, and store operations';
    } else if (isRider) {
      titleText = 'Delivery Rider Login';
      subtitleText = 'Access delivery assignments and rider earnings';
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titleText,
            style: TextStyle(
              fontSize: isDesktop ? 28 : 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitleText,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 22),

          // Email Input
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: isAdmin ? 'admin@foodflow.com' : (isOwner ? 'owner@foodflow.com' : (isRider ? 'rider@foodflow.com' : 'name@example.com')),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9CA3AF), size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FD),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password Input
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF9CA3AF), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF9CA3AF),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FD),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 10),

          // Remember Me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset link sent to email if registered.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          if (authState.error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Login Button
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: isRider ? null : AppColors.primaryGradient,
              color: isRider ? AppColors.darkAction : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isRider ? null : AppColors.primaryGlow,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: authState.isLoading ? null : _submit,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      isAdmin
                          ? 'Sign In as Admin'
                          : (isOwner
                              ? 'Sign In as Owner'
                              : (isRider ? 'Sign In as Rider' : 'Sign In to FoodFlow')),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
            ),
          ),

          if (isCustomer) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
                side: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 26, color: AppColors.primary),
              label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              onPressed: authState.isLoading ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280), fontSize: 13),
                  ),
                  InkWell(
                    onTap: () => context.push('/register'),
                    child: const Text(
                      'Create an account',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Rider Entry Point for Mobile Customers
            Center(
              child: InkWell(
                onTap: () => context.go('/rider'),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: const [
                      Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Delivering with FoodFlow? Rider Login',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Web-Only Restaurant Owner Registration
          if (kIsWeb && isOwner) ...[
            const SizedBox(height: 24),
            Center(
              child: InkWell(
                onTap: _showOwnerRegistrationDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🏪 Register Your Restaurant as Partner',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (isRider) ...[
            const SizedBox(height: 20),
            Center(
              child: InkWell(
                onTap: () => context.go('/rider/register'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.two_wheeler_rounded, color: Color(0xFF10B981), size: 18),
                      SizedBox(width: 8),
                      Text(
                        '🛵 Register as Delivery Rider',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: InkWell(
                onTap: () => context.go('/login'),
                child: const Text(
                  'Customer? Switch to Food Ordering',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroFeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroFeatureItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF34D399), size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
