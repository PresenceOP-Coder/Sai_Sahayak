import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sign/ui.dart';
import '../../object/ui.dart';
import '../../currency/screens/currency_detector_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../auth/screens/login_screen.dart';

class SahayakHome extends StatefulWidget {
  const SahayakHome({super.key});

  @override
  State<SahayakHome> createState() => _SahayakHomeState();
}

// Retained as alias for backward compatibility
typedef SignBridgeHome = SahayakHome;

class _SahayakHomeState extends State<SahayakHome>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const pageBg = Color(0xFFF5F7FF);

  final List<Widget> _screens = const [
    _HomeTab(),
    SignToSpeechScreen(),
    BlindPathNavigatorScreen(),
    CurrencyDetectorScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;
    _fadeCtrl.reset();
    setState(() => _selectedIndex = index);
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const accentColor = Color(0xFF4B6CF7);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
              _navItem(1, Icons.sign_language_outlined, Icons.sign_language, 'Sign AI'),
              _navItem(2, Icons.explore_outlined, Icons.explore, 'Navigator'),
              _navItem(3, Icons.payments_outlined, Icons.payments, 'Currency'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 16 : 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? accentColor : Colors.grey,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  static const pageBg = Color(0xFFF5F7FF);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final String initial = (auth.email ?? 'G')[0].toUpperCase();
    final String greeting = _greeting();

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          _AppHeader(
            initial: initial,
            greeting: greeting,
            email: auth.email,
            isLoggedIn: auth.isLoggedIn,
            onLogout: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
            onLogin: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero banner
                  _HeroBanner(
                    onGetStarted: () {
                      final home = context
                          .findAncestorStateOfType<_SahayakHomeState>();
                      home?._onNavTap(1);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Assistive AI Tools Grid (Sign + Navigator)
                  const _SectionLabel(label: 'Assistive AI Tools'),
                  const SizedBox(height: 12),
                  _AssistiveToolsGrid(
                    onSignAI: () {
                      final home = context
                          .findAncestorStateOfType<_SahayakHomeState>();
                      home?._onNavTap(1);
                    },
                    onNavigator: () {
                      final home = context
                          .findAncestorStateOfType<_SahayakHomeState>();
                      home?._onNavTap(2);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Assistive AI: Currency Detector
                  const _SectionLabel(label: 'Offline Currency Detection'),
                  const SizedBox(height: 12),
                  _CurrencyBanner(
                    onOpen: () {
                      final home = context
                          .findAncestorStateOfType<_SahayakHomeState>();
                      home?._onNavTap(3);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Quick actions
                  const _SectionLabel(label: 'Quick actions'),
                  const SizedBox(height: 12),
                  _QuickActions(
                    onSignAI: () {
                      final home = context
                          .findAncestorStateOfType<_SahayakHomeState>();
                      home?._onNavTap(1);
                    },
                    onNavigator: () {
                      final home = context
                          .findAncestorStateOfType<_SahayakHomeState>();
                      home?._onNavTap(2);
                    },
                    onCurrency: () {
                      final home = context
                          .findAncestorStateOfType<_SahayakHomeState>();
                      home?._onNavTap(3);
                    },
                    onSettings: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // About & Features section
                  const _SectionLabel(label: 'Information & Settings'),
                  const SizedBox(height: 12),
                  const _SupportCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.initial,
    required this.greeting,
    required this.email,
    required this.isLoggedIn,
    required this.onLogout,
    required this.onLogin,
  });

  final String initial;
  final String greeting;
  final String? email;
  final bool isLoggedIn;
  final VoidCallback onLogout;
  final VoidCallback onLogin;

  static const primaryColor = Color(0xFF1E2158);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand row + avatar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.accessibility_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sahayak',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),

                  if (isLoggedIn)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'logout') onLogout();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'email',
                          enabled: false,
                          child: Text(email ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Logout',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: onLogin,
                      child: const Text('Login',
                          style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                greeting,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text(
                'Welcome back!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2D5D), Color(0xFF4B6CF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -10, right: 50,
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Assistive AI Suite',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sahayak\nSmart Accessibility',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign-to-speech translation, obstacle navigation for the visually impaired, and currency detection.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.5),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2B2D5D),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: onGetStarted,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text(
                  'Launch Sign AI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistiveToolsGrid extends StatelessWidget {
  const _AssistiveToolsGrid({
    required this.onSignAI,
    required this.onNavigator,
  });

  final VoidCallback onSignAI;
  final VoidCallback onNavigator;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToolCard(
            icon: Icons.sign_language_rounded,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4B6CF7),
            title: 'Sign AI',
            subtitle: 'Gesture → Voice',
            description:
                'Point camera at hand signs for real-time speech translation.',
            chipLabel: 'MediaPipe AI',
            chipBg: const Color(0xFFEEF2FF),
            chipColor: const Color(0xFF4B6CF7),
            onTap: onSignAI,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToolCard(
            icon: Icons.explore_rounded,
            iconBg: const Color(0xFFFEF3E2),
            iconColor: const Color(0xFFBA7517),
            title: 'Navigator',
            subtitle: 'Path Guidance',
            description:
                'Real-time obstacle detection & spoken guidance for navigation.',
            chipLabel: 'Vision AI',
            chipBg: const Color(0xFFFEF3E2),
            chipColor: const Color(0xFFBA7517),
            onTap: onNavigator,
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.chipLabel,
    required this.chipBg,
    required this.chipColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final String chipLabel;
  final Color chipBg;
  final Color chipColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2158))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(chipLabel,
                  style: TextStyle(
                      color: chipColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyBanner extends StatelessWidget {
  const _CurrencyBanner({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F6E56), Color(0xFF00A86B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F6E56).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.payments_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Currency Detector',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ONNX AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Point camera to identify Indian Rupee notes & hear denomination spoken aloud.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onSignAI,
    required this.onNavigator,
    required this.onCurrency,
    required this.onSettings,
  });

  final VoidCallback onSignAI;
  final VoidCallback onNavigator;
  final VoidCallback onCurrency;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QAButton(
            icon: Icons.sign_language_rounded,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4B6CF7),
            label: 'Sign AI',
            onTap: onSignAI,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QAButton(
            icon: Icons.explore_rounded,
            iconBg: const Color(0xFFFEF3E2),
            iconColor: const Color(0xFFBA7517),
            label: 'Navigator',
            onTap: onNavigator,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QAButton(
            icon: Icons.payments_rounded,
            iconBg: const Color(0xFFE6FAF3),
            iconColor: const Color(0xFF0F6E56),
            label: 'Currency',
            onTap: onCurrency,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QAButton(
            icon: Icons.settings_rounded,
            iconBg: const Color(0xFFF1EFE8),
            iconColor: const Color(0xFF5F5E5A),
            label: 'Settings',
            onTap: onSettings,
          ),
        ),
      ],
    );
  }
}

class _QAButton extends StatelessWidget {
  const _QAButton({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.accessibility_new_rounded, color: Color(0xFF4B6CF7)),
            SizedBox(width: 10),
            Text('About Sahayak', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sahayak is an all-in-one assistive AI suite designed to empower deaf, mute, and visually impaired individuals.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '• Sign AI: Real-time sign language translation to voice.\n'
              '• Navigator: Obstacle detection & path alerts for the blind.\n'
              '• Currency Detector: Offline Indian Rupee recognition.\n'
              '• Version: 1.0.0',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF0F6E56)),
            SizedBox(width: 10),
            Text('Privacy & Offline', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your camera frames and audio guidance are processed locally on-device. No live video stream or personal image is sent or saved to external servers, guaranteeing maximum privacy and speed.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _tile(
            icon: Icons.shield_outlined,
            iconBg: const Color(0xFFE6FAF3),
            iconColor: const Color(0xFF0F6E56),
            title: 'Privacy & Offline AI',
            subtitle: 'Camera feeds processed locally on-device',
            onTap: () => _showPrivacyDialog(context),
            isFirst: true,
          ),
          const Divider(height: 1, indent: 66, endIndent: 16),
          _tile(
            icon: Icons.settings_outlined,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4B6CF7),
            title: 'Preferences & Settings',
            subtitle: 'Audio volume, dark mode, language',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 66, endIndent: 16),
          _tile(
            icon: Icons.info_outline_rounded,
            iconBg: const Color(0xFFF1EFE8),
            iconColor: const Color(0xFF5F5E5A),
            title: 'About Sahayak',
            subtitle: 'Version 1.0.0 · Assistive AI Suite',
            onTap: () => _showAboutDialog(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E2158))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black45,
        letterSpacing: 0.7,
      ),
    );
  }
}
