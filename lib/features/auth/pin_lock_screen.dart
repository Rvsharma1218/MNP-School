import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/session_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import 'login_screen.dart';

/// Second security layer, shown right after a successful email/password
/// sign-in. Behaviour is unchanged from the original PIN screen: first
/// launch asks the user to set a 4-digit PIN, every launch after that asks
/// them to enter it.
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with TickerProviderStateMixin {
  static const _pinKey = 'app_pin';
  static const _pinSetKey = 'app_pin_set';

  String _enteredPin = '';
  bool _isPinSet = false;
  bool _isConfirming = false;
  String _firstPin = '';
  String _errorMsg = '';
  bool _loading = true;

  late AnimationController _shakeCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _shakeAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _checkPinSet();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isPinSet = prefs.getBool(_pinSetKey) ?? false;
        _loading = false;
      });
    }
  }

  void _onDigit(String d) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += d;
      _errorMsg = '';
    });
    if (_enteredPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _handleComplete);
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  Future<void> _handleComplete() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    if (!_isPinSet) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        if (_enteredPin == _firstPin) {
          await prefs.setString(_pinKey, _enteredPin);
          await prefs.setBool(_pinSetKey, true);
          if (!mounted) return;
          _goToDashboard();
        } else {
          _shake();
          setState(() {
            _enteredPin = '';
            _firstPin = '';
            _isConfirming = false;
            _errorMsg = 'PINs do not match. Try again.';
          });
        }
      }
    } else {
      final saved = prefs.getString(_pinKey);
      if (_enteredPin == saved) {
        if (!mounted) return;
        _goToDashboard();
      } else {
        _shake();
        HapticFeedback.heavyImpact();
        setState(() {
          _enteredPin = '';
          _errorMsg = 'Incorrect PIN. Try again.';
        });
      }
    }
  }

  void _goToDashboard() {
    if (SessionService.instance.role == AppRole.parent) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const ParentDashboardScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const DashboardScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (route) => false,
    );
  }

  void _shake() => _shakeCtrl.forward(from: 0);

  Future<void> _resetPin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppColors.error),
            SizedBox(width: 8),
            Text('Reset PIN'),
          ],
        ),
        content: const Text(
            'This will remove the current PIN. You will need to set a new one on next launch.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
      await prefs.remove(_pinSetKey);
      setState(() {
        _isPinSet = false;
        _isConfirming = false;
        _firstPin = '';
        _enteredPin = '';
        _errorMsg = '';
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Log Out'),
          ],
        ),
        content: const Text('You will need to sign in again with your email and password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService.instance.signOut();
    await SessionService.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    String title, subtitle;
    if (!_isPinSet) {
      title = _isConfirming ? 'Confirm PIN' : 'Set Security PIN';
      subtitle = _isConfirming
          ? 'Enter the PIN again to confirm'
          : 'Create a 4-digit PIN to secure your app';
    } else {
      title = 'Welcome Back!';
      subtitle = 'Enter your 4-digit PIN to continue';
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF07182D),
              Color(0xFF0D2C54),
              Color(0xFF051221),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ── Official School Logo ────────────────────────────────
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFDAA520),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDAA520).withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 95,
                        height: 95,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── App Name ─────────────────────────────────────────────
                const Text(
                  'Mission Navodaya',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'PUBLIC SCHOOL MORA',
                  style: TextStyle(
                    color: Color(0xFFDAA520),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title & Subtitle ─────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey(title),
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── PIN Dots ─────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (ctx, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? Colors.white : Colors.transparent,
                          border: Border.all(
                            color: filled
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: filled
                              ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),

                // ── Error Message ────────────────────────────────────────
                const SizedBox(height: 16),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _errorMsg.isNotEmpty
                      ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(_errorMsg,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),

                const Spacer(),

                // ── Numpad ───────────────────────────────────────────────
                _buildNumpad(),
                const SizedBox(height: 16),

                // ── Reset PIN / Log Out ──────────────────────────────────
                if (_isPinSet)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _resetPin,
                        icon: Icon(Icons.lock_reset,
                            color: Colors.white.withOpacity(0.6), size: 16),
                        label: Text(
                          'Forgot PIN? Reset',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6), fontSize: 13),
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 1,
                        color: Colors.white.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      TextButton.icon(
                        onPressed: _logout,
                        icon: Icon(Icons.logout_rounded,
                            color: Colors.white.withOpacity(0.6), size: 16),
                        label: Text(
                          'Log Out',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((d) {
                if (d.isEmpty) return const SizedBox(width: 76, height: 76);
                return _NumKey(
                  label: d,
                  isBackspace: d == '⌫',
                  onTap: () => d == '⌫' ? _onBackspace() : _onDigit(d),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Numpad Key ──────────────────────────────────────────────────────────────

class _NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isBackspace;
  const _NumKey(
      {required this.label, required this.onTap, this.isBackspace = false});

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
              ? Colors.white.withOpacity(0.35)
              : Colors.white.withOpacity(0.12),
          border: Border.all(
            color: Colors.white.withOpacity(_pressed ? 0.6 : 0.2),
            width: 1.5,
          ),
          boxShadow: _pressed
              ? null
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: widget.isBackspace
              ? Icon(Icons.backspace_outlined,
              color: Colors.white.withOpacity(0.9), size: 24)
              : Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}