import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PwaInstallGuideDialog extends StatefulWidget {
  const PwaInstallGuideDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PwaInstallGuideDialog(),
    );
  }

  @override
  State<PwaInstallGuideDialog> createState() => _PwaInstallGuideDialogState();
}

class _PwaInstallGuideDialogState extends State<PwaInstallGuideDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.get_app_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Install FoodFlow App',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Enjoy a full-screen, standalone app experience',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.apple_rounded, size: 20), text: 'iPhone / iPad'),
                  Tab(icon: Icon(Icons.desktop_windows_rounded, size: 20), text: 'Windows 10 / 11'),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIosGuide(isDark),
                    _buildWindowsGuide(isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PWA runs without app store downloads. Live orders, tracking, and payments require an internet connection.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIosGuide(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _StepTile(
            number: '1',
            title: 'Open in Safari',
            description: 'Visit FoodFlow on your iPhone or iPad using the Safari browser.',
            icon: Icons.public_rounded,
            isDark: isDark,
          ),
          _StepTile(
            number: '2',
            title: 'Tap the Share Button',
            description: 'Tap the Share icon [↑] in the bottom Safari toolbar.',
            icon: Icons.ios_share_rounded,
            isDark: isDark,
          ),
          _StepTile(
            number: '3',
            title: 'Select "Add to Home Screen"',
            description: 'Scroll down the share sheet and tap "Add to Home Screen".',
            icon: Icons.add_box_outlined,
            isDark: isDark,
          ),
          _StepTile(
            number: '4',
            title: 'Tap "Add"',
            description: 'Tap "Add" in the top-right corner. FoodFlow is now on your home screen!',
            icon: Icons.check_circle_outline_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsGuide(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _StepTile(
            number: '1',
            title: 'Open Chrome or Microsoft Edge',
            description: 'Navigate to FoodFlow in Chrome or Edge on Windows 10/11.',
            icon: Icons.laptop_chromebook_rounded,
            isDark: isDark,
          ),
          _StepTile(
            number: '2',
            title: 'Click the Install Icon in Address Bar',
            description: 'Look for the "Install App" icon (⊕) on the right side of the address bar.',
            icon: Icons.download_rounded,
            isDark: isDark,
          ),
          _StepTile(
            number: '3',
            title: 'Or use Browser Menu (⋮)',
            description: 'Click browser menu → "Apps" / "Save and share" → "Install FoodFlow".',
            icon: Icons.more_vert_rounded,
            isDark: isDark,
          ),
          _StepTile(
            number: '4',
            title: 'Confirm Desktop Shortcut',
            description: 'Check "Create Desktop shortcut" and click "Install". FoodFlow will open in an isolated desktop window.',
            icon: Icons.desktop_mac_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final bool isDark;

  const _StepTile({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
