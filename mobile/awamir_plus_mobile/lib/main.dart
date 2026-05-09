import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/auth_controller.dart';
import 'screens/accounting_screen.dart';
import 'screens/cashier_closures_screen.dart';
import 'screens/daily_cash_screen.dart';
import 'screens/distribution_screen.dart';
import 'screens/driver_orders_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/pickup_orders_screen.dart';
import 'screens/production_screen.dart';
import 'screens/role_feature_screen.dart';
import 'screens/supervisor_approvals_screen.dart';
import 'controllers/app_controller.dart';
import 'core/constants/environment.dart';
import 'core/permissions/access_control.dart';
import 'core/theme/app_theme.dart';
import 'models/app_models.dart';
import 'repositories/auth_repository.dart';
import 'services/mock_service.dart';
import 'widgets/app_header.dart';
import 'widgets/state_views.dart';

void main() {
  runApp(const AwamirPlusApp());
}

class AwamirPlusApp extends StatelessWidget {
  const AwamirPlusApp({
    super.key,
    this.useMockData = AppEnvironment.useMockData,
  });

  final bool useMockData;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أوامر بلس',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AuthGate(useMockData: useMockData),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.useMockData});

  final bool useMockData;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final MockService _mockService = MockService();
  late final AuthController _authController = AuthController(
    authRepository: AuthRepository(
      mockService: _mockService,
      useMockData: widget.useMockData,
    ),
  );

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        if (!_authController.hasCheckedSession && _authController.isLoading) {
          return const Scaffold(body: LoadingStateView());
        }

        final user = _authController.currentUser;
        if (user == null) {
          return LoginScreen(controller: _authController);
        }

        return HomeShell(
          key: ValueKey(user.id),
          currentUser: user,
          mockService: _mockService,
          useMockData: widget.useMockData,
          onLogout: () => _authController.logout(),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.currentUser,
    required this.mockService,
    required this.useMockData,
    required this.onLogout,
  });

  final AppUser currentUser;
  final MockService mockService;
  final bool useMockData;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const double _headerHeight = 124;

  late final AppController _controller = AppController(
    currentUser: widget.currentUser,
    mockService: widget.mockService,
    useMockData: widget.useMockData,
  );
  AppFeature _selectedFeature = AppFeature.home;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const LoadingStateView();
          }
          if (_controller.hasError) {
            return ErrorStateView(
              message: _controller.errorMessage,
              onRetry: _controller.loadInitialData,
            );
          }
          if (_controller.isEmpty) {
            return EmptyStateView(
              message: _controller.appState.message ?? 'لا توجد بيانات حالياً',
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: _headerHeight),
                  child: AppHeaderScope(
                    suppressEmbeddedHeaders: true,
                    child: _buildPage(),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: _headerHeight,
                  child: AppHeader(
                    title: _headerTitle(),
                    subtitle: _headerSubtitle(),
                    notificationCount: _controller.unreadNotifications,
                    onNotificationTap: () =>
                        _openFeature(AppFeature.notifications),
                    trailing: _HeaderLogoutButton(onTap: widget.onLogout),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return _BottomNav(
            selectedFeature: _selectedFeature,
            features: _controller.navigationFeatures,
            notificationCount: _controller.unreadNotifications,
            onChanged: _openFeature,
          );
        },
      ),
    );
  }

  String _headerTitle() {
    if (_selectedFeature == AppFeature.home) {
      return 'مرحباً، ${_controller.currentUser.fullName}';
    }
    return _selectedFeature.label;
  }

  String _headerSubtitle() {
    if (_selectedFeature == AppFeature.home) {
      return _controller.currentUser.branchName;
    }
    return '${_controller.currentUser.role.label} — ${_controller.currentUser.branchName}';
  }

  Widget _buildPage() {
    if (!_controller.canAccess(_selectedFeature)) {
      return const AccessDeniedStateView();
    }

    switch (_selectedFeature) {
      case AppFeature.home:
        return HomeScreen(controller: _controller, onOpenFeature: _openFeature);
      case AppFeature.branchOrders:
        return OrdersScreen(controller: _controller);
      case AppFeature.branchApprovals:
        return SupervisorApprovalsScreen(controller: _controller);
      case AppFeature.distribution:
      case AppFeature.approvedOrders:
        return DistributionScreen(controller: _controller);
      case AppFeature.manufacturingOrders:
      case AppFeature.productionInProgress:
      case AppFeature.readyForPickupDelivery:
        return ProductionScreen(controller: _controller);
      case AppFeature.assignedDeliveries:
      case AppFeature.onTheWay:
        return DriverOrdersScreen(controller: _controller);
      case AppFeature.createOrder:
        return NewOrderScreen(
          controller: _controller,
          onFinished: () => _openFeature(AppFeature.branchOrders),
        );
      case AppFeature.dailyCashClosure:
        return DailyCashScreen(controller: _controller, showBack: false);
      case AppFeature.employeeCashClosures:
      case AppFeature.receiveCashClosure:
      case AppFeature.cashDifferences:
        return CashierClosuresScreen(controller: _controller);
      case AppFeature.deliveredOrders:
        return AccessControl.hasPermission(
              _controller.currentUser,
              AppPermission.deliveryViewAssigned,
            )
            ? DriverOrdersScreen(controller: _controller)
            : PickupOrdersScreen(controller: _controller);
      case AppFeature.notifications:
        return NotificationsScreen(controller: _controller);
      case AppFeature.payments:
      case AppFeature.invoices:
      case AppFeature.paymentEntry:
        return AccountingScreen(controller: _controller);
      default:
        return RoleFeatureScreen(
          user: _controller.currentUser,
          feature: _selectedFeature,
        );
    }
  }

  void _openFeature(AppFeature feature) {
    if (!_controller.canAccess(feature)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية للوصول إلى هذه الصفحة')),
      );
      return;
    }

    setState(() => _selectedFeature = feature);
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedFeature,
    required this.features,
    required this.notificationCount,
    required this.onChanged,
  });

  final AppFeature selectedFeature;
  final List<AppFeature> features;
  final int notificationCount;
  final ValueChanged<AppFeature> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasCreateOrder = features.contains(AppFeature.createOrder);
    final sideItems = hasCreateOrder
        ? features.where((item) => item != AppFeature.createOrder).toList()
        : features;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final height = 118.0 + bottomInset;
    final itemBottom = bottomInset > 0 ? bottomInset + 8.0 : 10.0;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BottomNavBarPainter(showNotch: hasCreateOrder),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: itemBottom,
            child: Row(
              children: [
                for (var index = 0; index < sideItems.length; index++) ...[
                  if (hasCreateOrder && index == 2)
                    const Expanded(child: SizedBox(height: 74)),
                  Expanded(
                    child: _BottomNavItem(
                      item: sideItems[index],
                      selected: selectedFeature == sideItems[index],
                      badge: sideItems[index] == AppFeature.notifications
                          ? notificationCount
                          : 0,
                      onTap: () => onChanged(sideItems[index]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasCreateOrder)
            Positioned(
              top: 0,
              child: _CreateOrderNavButton(
                selected: selectedFeature == AppFeature.createOrder,
                onTap: () => onChanged(AppFeature.createOrder),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNavBarPainter extends CustomPainter {
  const _BottomNavBarPainter({required this.showNotch});

  final bool showNotch;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 38.0;
    const cornerRadius = 38.0;
    const notchHalfWidth = 106.0;
    const notchBottom = 95.0;

    final centerX = size.width / 2;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, top + cornerRadius)
      ..quadraticBezierTo(0, top, cornerRadius, top);

    if (showNotch) {
      path
        ..lineTo(centerX - notchHalfWidth, top)
        ..cubicTo(
          centerX - 78,
          top,
          centerX - 74,
          notchBottom,
          centerX,
          notchBottom,
        )
        ..cubicTo(
          centerX + 74,
          notchBottom,
          centerX + 78,
          top,
          centerX + notchHalfWidth,
          top,
        );
    }

    path
      ..lineTo(size.width - cornerRadius, top)
      ..quadraticBezierTo(size.width, top, size.width, top + cornerRadius)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.18), 18, true);

    final fillPaint = Paint()..color = AppColors.white;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = AppColors.creamDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BottomNavBarPainter oldDelegate) {
    return showNotch != oldDelegate.showNotch;
  }
}

class _HeaderLogoutButton extends StatelessWidget {
  const _HeaderLogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.22)),
        ),
        child: const Icon(
          Icons.logout_rounded,
          color: AppColors.white,
          size: 21,
        ),
      ),
    );
  }
}

class _CreateOrderNavButton extends StatelessWidget {
  const _CreateOrderNavButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(44),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.26 : 0.2),
                  blurRadius: selected ? 26 : 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.white,
              size: 44,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final AppFeature item;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      color: selected ? Colors.black : const Color(0xFF8B96A3),
                      size: 30,
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -8,
                        right: -10,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.black : const Color(0xFF8B96A3),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
