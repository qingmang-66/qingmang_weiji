import 'dart:async';

import 'package:flutter/material.dart';

import '../models/achievement_progress.dart';
import '../screens/achievement_center_screen.dart';
import '../services/di_container.dart';
import '../theme/fluid_theme.dart';
import '../utils/translations.dart';

/// 阶段四：成就解锁横幅（全局）
///
/// 监听 AchievementService.newlyUnlockedStream。
/// 每条成就停留 3 秒，逐条播放；点击跳转成就中心。
class UnlockCelebrationBanner extends StatefulWidget {
  final Widget child;
  const UnlockCelebrationBanner({super.key, required this.child});

  @override
  State<UnlockCelebrationBanner> createState() =>
      _UnlockCelebrationBannerState();
}

class _UnlockCelebrationBannerState extends State<UnlockCelebrationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  StreamSubscription<List<AchievementProgress>>? _sub;
  final List<AchievementProgress> _queue = [];
  AchievementProgress? _current;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sub = DIContainer.instance.achievementRepository.newlyUnlockedStream
        .listen(_onNewlyUnlocked);
  }

  void _onNewlyUnlocked(List<AchievementProgress> unlocked) {
    if (_disposed || unlocked.isEmpty) return;
    _queue.addAll(unlocked);
    _showNext();
  }

  Future<void> _showNext() async {
    if (_current != null || _queue.isEmpty || _disposed) return;
    setState(() => _current = _queue.removeAt(0));
    try {
      await _ctrl.forward();
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || _disposed) return;
    try {
      await _ctrl.reverse();
    } catch (_) {}
    if (!mounted || _disposed) return;
    setState(() => _current = null);
    _showNext();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _ctrl,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: _buildBanner(context, _current!),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner(BuildContext context, AchievementProgress p) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AchievementCenterScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: FluidTheme.warningFluidGradient),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr.achievementUnlocked,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _trTitle(context, p.definition.titleKey),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () async {
                    try {
                      await _ctrl.reverse();
                    } catch (_) {}
                    if (!mounted || _disposed) return;
                    setState(() => _current = null);
                    _showNext();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 标题翻译映射（与 AchievementTile 一致）
  String _trTitle(BuildContext context, String key) {
    final tr = context.tr;
    switch (key) {
      case 'ach.study10Title':
        return tr.achStudy10Title;
      case 'ach.study50Title':
        return tr.achStudy50Title;
      case 'ach.study100Title':
        return tr.achStudy100Title;
      case 'ach.study500Title':
        return tr.achStudy500Title;
      case 'ach.study1000Title':
        return tr.achStudy1000Title;
      case 'ach.review10Title':
        return tr.achReview10Title;
      case 'ach.review50Title':
        return tr.achReview50Title;
      case 'ach.review200Title':
        return tr.achReview200Title;
      case 'ach.review1000Title':
        return tr.achReview1000Title;
      case 'ach.streak3Title':
        return tr.achStreak3Title;
      case 'ach.streak7Title':
        return tr.achStreak7Title;
      case 'ach.streak30Title':
        return tr.achStreak30Title;
      case 'ach.streak100Title':
        return tr.achStreak100Title;
      case 'ach.favFirstTitle':
        return tr.achFavFirstTitle;
      case 'ach.fav20Title':
        return tr.achFav20Title;
      case 'ach.fav100Title':
        return tr.achFav100Title;
      case 'ach.favGroup3Title':
        return tr.achFavGroup3Title;
      case 'ach.favStudiedTitle':
        return tr.achFavStudiedTitle;
      case 'ach.setFirstTitle':
        return tr.achSetFirstTitle;
      case 'ach.set5Title':
        return tr.achSet5Title;
      case 'ach.setStudiedTitle':
        return tr.achSetStudiedTitle;
      case 'ach.planWeek3Title':
        return tr.achPlanWeek3Title;
      case 'ach.planWeek5Title':
        return tr.achPlanWeek5Title;
      case 'ach.planWeek7Title':
        return tr.achPlanWeek7Title;
      case 'ach.planStudy5Title':
        return tr.achPlanStudy5Title;
      case 'ach.planStudy7Title':
        return tr.achPlanStudy7Title;
      case 'ach.wrongStreak3Title':
        return tr.achWrongStreak3Title;
      case 'ach.wrongStreak10Title':
        return tr.achWrongStreak10Title;
      case 'ach.mastery50Title':
        return tr.achMastery50Title;
      case 'ach.mastery80Title':
        return tr.achMastery80Title;
      default:
        return key;
    }
  }
}
