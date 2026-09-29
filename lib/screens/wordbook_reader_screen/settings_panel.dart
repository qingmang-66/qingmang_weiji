part of '../wordbook_reader_screen.dart';

/// 阅读设置面板：二级卡片导航
///
/// 一级只列分组入口（文字/间距/背景/翻页/书签/标记），
/// 点入某分组才展开该分组的控件，避免所有内容平铺一屏。
///
/// 性能约定：面板本身不订阅 [ReaderSettingsProvider]。
/// 字号滑块、色轮、壁纸滑块等高频交互各自拆成子组件持有本地状态，
/// 拖拽时只重建那一小块；低频选项用 context.select 精确订阅，
/// 避免任一设置变化都重建整个面板（原本会连带重建两个色轮）。
class _ReaderSettingsPanel extends StatefulWidget {
  final ValueChanged<bool> onVolumeTurnChanged;
  final Future<void> Function() pickBgImage;

  const _ReaderSettingsPanel({
    required this.onVolumeTurnChanged,
    required this.pickBgImage,
  });

  @override
  State<_ReaderSettingsPanel> createState() => _ReaderSettingsPanelState();
}

class _ReaderSettingsPanelState extends State<_ReaderSettingsPanel> {
  /// 当前打开的分组下标；null=一级列表
  int? _group;

  /// 返回一级的胶囊按钮：两种界面风格各用各的材质。
  ///
  /// 玻璃模式下用发光玻璃片（嵌套在设置弹窗的玻璃内会自动降级为果冻片，
  /// 即 iOS 的"不做嵌套模糊"），经典模式用主色淡底胶囊 ——
  /// 若统一写死成实色块，玻璃面板里就会突兀地出现一小片不透明色。
  Widget _backPill(bool isDark, String label, VoidCallback onTap) {
    final accent = FluidTheme.primaryFluidGradient[0];
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.arrow_back_ios_new,
          size: 13,
          color: FluidTheme.primaryAccessible(isDark),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FluidTheme.primaryAccessible(isDark),
          ),
        ),
      ],
    );
    if (context.isLiquidGlass) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassSurface(
          borderRadius: 999,
          emphasized: true,
          glowColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: content,
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: content,
      ),
    );
  }

  /// 二级分组里按系统返回键先回到一级列表。
  ///
  /// 此前返回键直接关掉整个设置弹窗：用户在二级卡片里按返回，
  /// 期待的是"退回上一级"，结果整个面板消失、直接回到阅读页。
  /// 这里把返回拆成两级：二级 → 一级 → 关闭（再按一次才关）。
  Widget _withGroupBackScope(Widget child) {
    return PopScope(
      canPop: _group == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _group == null) return;
        setState(() => _group = null);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = context.tr;
    if (_group != null) {
      final titles = [
        tr.groupText,
        tr.groupSpacing,
        tr.groupBackground,
        tr.groupPageTurn,
        tr.groupBookmark,
        tr.readerMarkSection,
      ];
      return _withGroupBackScope(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 返回一级：有底的胶囊按钮，"能不能点、点回哪里"一眼可见
            // （原来是纯文字 + 箭头，没有背景，点击区域也难判断）
            Row(
              children: [
                _backPill(
                  isDark,
                  tr.back,
                  () => setState(() => _group = null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titles[_group!],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: FluidTheme.getTextSecondaryColor(isDark),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildGroupBody(context, isDark),
          ],
        ),
      );
    }
    final groups = [
      (icon: Icons.text_fields, title: tr.groupText, desc: tr.groupTextDesc),
      (
        icon: Icons.format_line_spacing_outlined,
        title: tr.groupSpacing,
        desc: tr.groupSpacingDesc,
      ),
      (
        icon: Icons.wallpaper_outlined,
        title: tr.groupBackground,
        desc: tr.groupBackgroundDesc,
      ),
      (
        icon: Icons.auto_stories_outlined,
        title: tr.groupPageTurn,
        desc: tr.groupPageTurnDesc,
      ),
      (
        icon: Icons.bookmark_border,
        title: tr.groupBookmark,
        desc: tr.groupBookmarkDesc,
      ),
      (
        icon: Icons.check_circle_outline,
        title: tr.readerMarkSection,
        desc: tr.groupMarkDesc,
      ),
    ];
    return _withGroupBackScope(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _GroupEntry(
              icon: groups[i].icon,
              title: groups[i].title,
              desc: groups[i].desc,
              onTap: () => setState(() => _group = i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupBody(BuildContext context, bool isDark) {
    final tr = context.tr;
    switch (_group!) {
      case 0:
        return _settingsSection(context, tr.groupText, isDark, [
          //字体大小：拖拽中仅本地预览，松手后一次性重排，避免卡顿
          const _FontSizeRow(),
          const SizedBox(height: 8),
          Text(
            tr.fontWeightLabel,
            style: FluidTheme.labelLarge(
              isDark,
            ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
          ),
          const SizedBox(height: 8),
          const _FontWeightRow(),
        ], icon: Icons.text_fields);
      case 1:
        return _settingsSection(context, tr.groupSpacing, isDark, [
          const _SpacingSection(),
        ], icon: Icons.format_line_spacing_outlined);
      case 2:
        return _BackgroundGroup(pickBgImage: widget.pickBgImage);
      case 3:
        return _settingsSection(context, tr.groupPageTurn, isDark, [
          const _TransitionRow(),
          const SizedBox(height: 8),
          const _TapTurnRow(),
          if (isAndroidPlatform)
            _VolumeTurnRow(onChanged: widget.onVolumeTurnChanged),
        ], icon: Icons.auto_stories_outlined);
      case 4:
        return _settingsSection(context, tr.groupBookmark, isDark, [
          _NamingRow(value: ReaderBookmarkNaming.word, label: tr.namingByWord),
          _NamingRow(
            value: ReaderBookmarkNaming.number,
            label: tr.namingByNumber,
          ),
          _NamingRow(
            value: ReaderBookmarkNaming.custom,
            label: tr.namingCustom,
          ),
        ], icon: Icons.bookmark_border);
      default:
        // 标记设置：「记住了」的三种标记方式 + 收藏星标
        return _settingsSection(context, tr.readerMarkSection, isDark, [
          const _MarkSection(),
        ], icon: Icons.check_circle_outline);
    }
  }
}

/// 一级分组入口行：图标 + 标题 + 摘要 + 箭头
class _GroupEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _GroupEntry({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
      child: _settingsCard(
        context,
        isDark,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: FluidTheme.primaryFluidGradient[0]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FluidTheme.labelLarge(
                        isDark,
                      ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        color: FluidTheme.getTextSecondaryColor(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: FluidTheme.getTextSecondaryColor(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分组卡片容器：液态玻璃模式用 GlassSurface，经典模式用渐变背景
Widget _settingsCard(BuildContext context, bool isDark, Widget child) {
  if (context.select<ThemeProvider, bool>((p) => p.isLiquidGlass)) {
    return GlassSurface(
      margin: EdgeInsets.zero,
      borderRadius: FluidTheme.cardBorderRadius,
      child: child,
    );
  }
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: FluidTheme.getSurfaceGradientColors(isDark),
      ),
      borderRadius: BorderRadius.circular(FluidTheme.cardBorderRadius),
      border: Border.all(color: FluidTheme.getBorderColor(isDark)),
    ),
    child: child,
  );
}

/// 二级分组容器：渐变分组标题（带图标）+ 内容
Widget _settingsSection(
  BuildContext context,
  String title,
  bool isDark,
  List<Widget> children, {
  IconData? icon,
}) {
  //渐变分组标题（可带图标，一眼区分五个分组）
  final header = Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          //原渐变在浅色玻璃上仅 ~1.9:1，小号标题几乎不可读；
          //浅色下用压暗变体，深色下沿用原渐变
          colors: FluidTheme.textGradient(isDark),
        ).createShader(bounds);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 6)],
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
  final body = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      header,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    ],
  );
  return _settingsCard(context, isDark, body);
}

/// 「背景」分组：背景色与自定义背景图互斥，需要按「是否已选壁纸」切换控件，
/// 拆成独立组件让 hasBgImage 的订阅只重建这一块
class _BackgroundGroup extends StatelessWidget {
  final Future<void> Function() pickBgImage;

  const _BackgroundGroup({required this.pickBgImage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = context.tr;
    //壁纸铺满阅读区后纯色底色被完全遮住，再留着色板就成了
    //「拖了没反应」的假控件，所以有壁纸时收起色板只留提示。
    //（移除壁纸后原背景色会原样恢复，不需要用户重新调）
    final hasBgImage = context.select<ReaderSettingsProvider, bool>(
      (s) => s.bgImagePath != null,
    );
    return _settingsSection(context, tr.groupBackground, isDark, [
      if (hasBgImage)
        _SettingNotice(
          icon: Icons.image_outlined,
          text: tr.bgColorLockedByImage,
        )
      else ...[
        const _BgColorSection(),
        const SizedBox(height: 12),
      ],
      const _TextColorSection(),
      if (!kIsWeb) _WallpaperSection(pickBgImage: pickBgImage),
    ], icon: Icons.wallpaper_outlined);
  }
}

/// 「间距」分组：行段间距 + 页面边距，各自预设档位 + 自定义滑块
class _SpacingSection extends StatelessWidget {
  const _SpacingSection();

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = FluidTheme.labelLarge(
      isDark,
    ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr.lineSpacingLabel, style: labelStyle),
        const SizedBox(height: 8),
        const _SpacingScaleRow(),
        const SizedBox(height: 16),
        Text(tr.pageMarginLabel, style: labelStyle),
        const SizedBox(height: 8),
        const _PageMarginRow(),
      ],
    );
  }
}

/// 行段间距：预设档位 + 自定义滑块（拖拽中仅本地预览，松手重排）
class _SpacingScaleRow extends StatefulWidget {
  const _SpacingScaleRow();

  @override
  State<_SpacingScaleRow> createState() => _SpacingScaleRowState();
}

class _SpacingScaleRowState extends State<_SpacingScaleRow> {
  late bool _custom;

  @override
  void initState() {
    super.initState();
    final v = context.read<ReaderSettingsProvider>().spacingScale;
    _custom = !ReaderSettingsProvider.spacingPresets.any(
      (p) => (p - v).abs() < 0.001,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final presets = ReaderSettingsProvider.spacingPresets;
    final value = context.select<ReaderSettingsProvider, double>(
      (s) => s.spacingScale,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidSegmented<double>(
          segments: [
            for (var i = 0; i < presets.length; i++)
              LiquidSegment(
                value: presets[i],
                label: [
                  tr.sizeSmall,
                  tr.sizeMedium,
                  tr.sizeLarger,
                  tr.sizeLarge,
                ][i],
              ),
            LiquidSegment(value: -1.0, label: tr.sizeCustom),
          ],
          value: _custom ? -1.0 : value,
          onChanged: (v) {
            if (v < 0) {
              setState(() => _custom = true);
              return;
            }
            setState(() => _custom = false);
            context.read<ReaderSettingsProvider>().setSpacingScale(v);
          },
        ),
        if (_custom)
          _LiveSliderRow(
            initial: value,
            min: ReaderSettingsProvider.minSpacing,
            max: ReaderSettingsProvider.maxSpacing,
            divisions: 16,
            format: (v) => '${(v * 100).round()}%',
            preview: (v) =>
                context.read<ReaderSettingsProvider>().previewSpacingScale(v),
            commit: (v) =>
                context.read<ReaderSettingsProvider>().setSpacingScale(v),
          ),
      ],
    );
  }
}

/// 页面边距：预设档位 + 自定义滑块
class _PageMarginRow extends StatefulWidget {
  const _PageMarginRow();

  @override
  State<_PageMarginRow> createState() => _PageMarginRowState();
}

class _PageMarginRowState extends State<_PageMarginRow> {
  late bool _custom;

  @override
  void initState() {
    super.initState();
    final v = context.read<ReaderSettingsProvider>().pageMargin;
    _custom = !ReaderSettingsProvider.pageMarginPresets.any(
      (p) => (p - v).abs() < 0.001,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final presets = ReaderSettingsProvider.pageMarginPresets;
    final value = context.select<ReaderSettingsProvider, double>(
      (s) => s.pageMargin,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidSegmented<double>(
          segments: [
            for (var i = 0; i < presets.length; i++)
              LiquidSegment(
                value: presets[i],
                label: [
                  tr.sizeSmall,
                  tr.sizeMedium,
                  tr.sizeLarger,
                  tr.sizeLarge,
                ][i],
              ),
            LiquidSegment(value: -1.0, label: tr.sizeCustom),
          ],
          value: _custom ? -1.0 : value,
          onChanged: (v) {
            if (v < 0) {
              setState(() => _custom = true);
              return;
            }
            setState(() => _custom = false);
            context.read<ReaderSettingsProvider>().setPageMargin(v);
          },
        ),
        if (_custom)
          _LiveSliderRow(
            initial: value,
            min: ReaderSettingsProvider.minPageMargin,
            max: ReaderSettingsProvider.maxPageMargin,
            divisions:
                (ReaderSettingsProvider.maxPageMargin -
                        ReaderSettingsProvider.minPageMargin)
                    .round(),
            format: (v) => '${v.round()}px',
            preview: (v) =>
                context.read<ReaderSettingsProvider>().previewPageMargin(v),
            commit: (v) =>
                context.read<ReaderSettingsProvider>().setPageMargin(v),
          ),
      ],
    );
  }
}

/// 拖拽中实时预览、松手落盘的通用滑块（仿 _FontSizeRow 模式）
class _LiveSliderRow extends StatefulWidget {
  final double initial;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) format;
  final ValueChanged<double> preview;
  final ValueChanged<double> commit;

  const _LiveSliderRow({
    required this.initial,
    required this.min,
    required this.max,
    required this.format,
    required this.preview,
    required this.commit,
    this.divisions,
  });

  @override
  State<_LiveSliderRow> createState() => _LiveSliderRowState();
}

class _LiveSliderRowState extends State<_LiveSliderRow> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.format(_value),
            style: TextStyle(
              color: FluidTheme.getTextSecondaryColor(isDark),
              fontSize: 13,
            ),
          ),
          LiquidSlider(
            value: _value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            activeColor: FluidTheme.primaryFluidGradient[0],
            onChanged: (v) {
              setState(() => _value = v);
              widget.preview(v);
            },
            onChangeEnd: (v) {
              setState(() => _value = v);
              widget.commit(v);
            },
          ),
        ],
      ),
    );
  }
}

/// 开关行：标签 + LiquidSwitch
///
/// 委托到 [fluidSettingsSwitchRow]（错题集/收藏夹的设置面板也用它），
/// 避免三处各写一份开关行，视觉随主题漂移。
Widget _switchRow(
  BuildContext context,
  String label,
  bool value,
  ValueChanged<bool> onChanged,
) => fluidSettingsSwitchRow(
  context: context,
  label: label,
  value: value,
  onChanged: onChanged,
);

/// 「标记」分区：记住了的三种标记方式 + 标记颜色 + 收藏星标
///
/// 单独成组件是为了不让设置变化重建整个面板（见文件头部的性能约定）。
class _MarkSection extends StatelessWidget {
  const _MarkSection();

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    // 只订阅这四个开关：ReaderSettingsProvider 在色轮/壁纸滑块拖拽期间逐帧
    // notify，用 watch 会让这一整块（4 行开关 + 标题 + 色点行）跟着每帧重建
    final mark = context
        .select<
          ReaderSettingsProvider,
          ({bool icon, bool row, bool word, bool star})
        >(
          (s) => (
            icon: s.rememberedMarkIcon,
            row: s.rememberedMarkRow,
            word: s.rememberedMarkWord,
            star: s.showFavoriteStar,
          ),
        );
    final provider = context.read<ReaderSettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        fluidSettingsSwitchRow(
          context: context,
          label: tr.rememberedMarkIcon,
          value: mark.icon,
          onChanged: provider.setRememberedMarkIcon,
        ),
        fluidSettingsSwitchRow(
          context: context,
          label: tr.rememberedMarkRow,
          value: mark.row,
          onChanged: provider.setRememberedMarkRow,
        ),
        fluidSettingsSwitchRow(
          context: context,
          label: tr.rememberedMarkWord,
          value: mark.word,
          onChanged: provider.setRememberedMarkWord,
        ),
        const SizedBox(height: 12),
        Text(
          tr.markColorLabel,
          style:
              FluidTheme.labelLarge(
                Theme.of(context).brightness == Brightness.dark,
              ).copyWith(
                color: FluidTheme.getTextPrimaryColor(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
        ),
        const SizedBox(height: 8),
        const _MarkColorRow(),
        const SizedBox(height: 12),
        fluidSettingsSwitchRow(
          context: context,
          label: tr.showFavoriteStar,
          hint: tr.showFavoriteStarHint,
          value: mark.star,
          onChanged: provider.setShowFavoriteStar,
        ),
      ],
    );
  }
}

/// 标记颜色：4 个预设色点，选中描一圈外框
class _MarkColorRow extends StatelessWidget {
  const _MarkColorRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final index = context.select<ReaderSettingsProvider, int>(
      (s) => s.markColorIndex,
    );
    return Row(
      children: [
        for (var i = 0; i < ReaderSettingsProvider.markColors.length; i++)
          Padding(
            padding: EdgeInsets.only(
              right: i == ReaderSettingsProvider.markColors.length - 1 ? 0 : 2,
            ),
            child: GestureDetector(
              onTap: () =>
                  context.read<ReaderSettingsProvider>().setMarkColorIndex(i),
              behavior: HitTestBehavior.opaque,
              // 色点本身保持 30dp 的视觉大小，外面撑到 44dp：
              // 手机上直接点 30dp 的圆点很容易点偏（桌面端鼠标无所谓）
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: ReaderSettingsProvider.markColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: index == i
                            ? FluidTheme.getTextPrimaryColor(isDark)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: index == i
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

//玻璃模式用玻璃描边胶囊按钮，经典模式保留 OutlinedButton
Widget _outlineButton(
  BuildContext context,
  IconData icon,
  String label,
  VoidCallback onPressed,
) {
  if (context.isLiquidGlass) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: GlassSurface(
        borderRadius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
  return OutlinedButton.icon(
    icon: Icon(icon),
    label: Text(label),
    onPressed: onPressed,
  );
}

/// 互斥提示：某个设置被另一项覆盖时，用它替代原本的控件，
/// 避免出现"能拖但没反应"的假控件
class _SettingNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SettingNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = FluidTheme.getTextSecondaryColor(isDark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}

// ========== 字体 ==========

/// 字号滑块：本地持有拖拽值，拖动过程不触发面板其他部分重建
class _FontSizeRow extends StatefulWidget {
  const _FontSizeRow();

  @override
  State<_FontSizeRow> createState() => _FontSizeRowState();
}

class _FontSizeRowState extends State<_FontSizeRow> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = context.read<ReaderSettingsProvider>().fontSize;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.tr.fontSizeLabel}：${_value.round()}',
          style: FluidTheme.labelLarge(isDark).copyWith(color: textPrimary),
        ),
        LiquidSlider(
          value: _value,
          min: ReaderSettingsProvider.minFontSize,
          max: ReaderSettingsProvider.maxFontSize,
          divisions:
              (ReaderSettingsProvider.maxFontSize -
                      ReaderSettingsProvider.minFontSize)
                  .round(),
          activeColor: FluidTheme.primaryFluidGradient[0],
          onChanged: (v) {
            setState(() => _value = v);
            //仅更新内存值，不通知阅读器重排
            context.read<ReaderSettingsProvider>().previewFontSize(v);
          },
          onChangeEnd: (v) =>
              context.read<ReaderSettingsProvider>().setFontSize(v),
        ),
      ],
    );
  }
}

class _FontWeightRow extends StatelessWidget {
  const _FontWeightRow();

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final value = context.select<ReaderSettingsProvider, int>(
      (s) => s.fontWeightIndex,
    );
    return LiquidSegmented<int>(
      segments: [
        LiquidSegment(value: 0, label: tr.weightNormal),
        LiquidSegment(value: 1, label: tr.weightMedium),
        LiquidSegment(value: 2, label: tr.weightBold),
      ],
      value: value,
      onChanged: (v) =>
          context.read<ReaderSettingsProvider>().setFontWeightIndex(v),
    );
  }
}

// ========== 翻页 ==========

class _TransitionRow extends StatelessWidget {
  const _TransitionRow();

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final value = context.select<ReaderSettingsProvider, ReaderPageTransition>(
      (s) => s.pageTransition,
    );
    return LiquidSegmented<ReaderPageTransition>(
      segments: [
        LiquidSegment(
          value: ReaderPageTransition.none,
          label: tr.transitionNone,
        ),
        LiquidSegment(
          value: ReaderPageTransition.slide,
          label: tr.transitionSlide,
        ),
        LiquidSegment(
          value: ReaderPageTransition.curl,
          label: tr.transitionCurl,
        ),
      ],
      value: value,
      onChanged: (v) =>
          context.read<ReaderSettingsProvider>().setPageTransition(v),
    );
  }
}

class _TapTurnRow extends StatelessWidget {
  const _TapTurnRow();

  @override
  Widget build(BuildContext context) {
    final value = context.select<ReaderSettingsProvider, bool>(
      (s) => s.tapTurnEnabled,
    );
    return _switchRow(context, context.tr.tapTurnLabel, value, (v) {
      context.read<ReaderSettingsProvider>().setTapTurnEnabled(v);
    });
  }
}

class _VolumeTurnRow extends StatelessWidget {
  final ValueChanged<bool> onChanged;

  const _VolumeTurnRow({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final value = context.select<ReaderSettingsProvider, bool>(
      (s) => s.volumeTurnEnabled,
    );
    return _switchRow(context, context.tr.volumeTurnLabel, value, (v) {
      context.read<ReaderSettingsProvider>().setVolumeTurnEnabled(v);
      onChanged(v);
    });
  }
}

// ========== 书签命名 ==========

class _NamingRow extends StatelessWidget {
  final ReaderBookmarkNaming value;
  final String label;

  const _NamingRow({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final selected =
        context.select<ReaderSettingsProvider, ReaderBookmarkNaming>(
          (s) => s.naming,
        ) ==
        value;
    final textPrimary = FluidTheme.getTextPrimaryColor(
      Theme.of(context).brightness == Brightness.dark,
    );
    return InkWell(
      onTap: () => context.read<ReaderSettingsProvider>().setNaming(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            LiquidRadio(
              selected: selected,
              onTap: () =>
                  context.read<ReaderSettingsProvider>().setNaming(value),
              color: FluidTheme.primaryFluidGradient[0],
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: textPrimary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ========== 背景 ==========

/// 预设色点：单独订阅当前背景色，色轮拖拽时只有这一行重建
class _PresetColors extends StatelessWidget {
  final ValueChanged<Color> onPick;

  const _PresetColors({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final current = context.select<ReaderSettingsProvider, int>(
      (s) => s.bgColor.toARGB32(),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final v in ReaderSettingsProvider.presetBgColors)
          LiquidColorDot(
            color: Color(v),
            selected: current == v,
            showCheck: true,
            size: 38,
            onTap: () => onPick(Color(v)),
          ),
      ],
    );
  }
}

/// 背景取色：预设色 + 色轮，色相状态本地持有
class _BgColorSection extends StatefulWidget {
  const _BgColorSection();

  @override
  State<_BgColorSection> createState() => _BgColorSectionState();
}

class _BgColorSectionState extends State<_BgColorSection> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(context.read<ReaderSettingsProvider>().bgColor);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PresetColors(
          onPick: (c) {
            setState(() => _hsv = HSVColor.fromColor(c));
            context.read<ReaderSettingsProvider>().setBgColor(c);
          },
        ),
        const SizedBox(height: 12),
        ColorWheelPicker(
          hsv: _hsv,
          onPreview: (h) {
            setState(() => _hsv = h);
            //颜色变化不触发重排，可以逐帧实时预览
            context.read<ReaderSettingsProvider>().setBgColorLive(h.toColor());
          },
          onCommit: (h) =>
              context.read<ReaderSettingsProvider>().setBgColor(h.toColor()),
        ),
      ],
    );
  }
}

/// 文字颜色：自动（按背景亮度）或自定义
class _TextColorSection extends StatefulWidget {
  const _TextColorSection();

  @override
  State<_TextColorSection> createState() => _TextColorSectionState();
}

class _TextColorSectionState extends State<_TextColorSection> {
  late bool _auto;
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    final s = context.read<ReaderSettingsProvider>();
    _auto = s.textColor == null;
    _hsv = HSVColor.fromColor(s.textColor ?? const Color(0xFF1A1A1A));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = context.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr.textColorLabel,
                style: FluidTheme.labelLarge(
                  isDark,
                ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
              ),
            ),
            Text(
              tr.textColorAuto,
              style: TextStyle(
                color: FluidTheme.getTextSecondaryColor(isDark),
                fontSize: 13,
              ),
            ),
            LiquidSwitch(
              value: !_auto,
              activeColor: FluidTheme.primaryFluidGradient[0],
              onChanged: (v) {
                setState(() => _auto = !v);
                context.read<ReaderSettingsProvider>().setTextColor(
                  v ? _hsv.toColor() : null,
                );
              },
            ),
          ],
        ),
        if (!_auto)
          ColorWheelPicker(
            hsv: _hsv,
            onPreview: (h) {
              setState(() => _hsv = h);
              context.read<ReaderSettingsProvider>().setTextColorLive(
                h.toColor(),
              );
            },
            onCommit: (h) => context
                .read<ReaderSettingsProvider>()
                .setTextColor(h.toColor()),
          ),
      ],
    );
  }
}

/// 壁纸景深/蒙层滑块：本地持有拖拽值，逐帧实时预览，松手才落盘
class _WallpaperSlider extends StatefulWidget {
  final String label;
  final double max;
  final bool percent;
  final double initial;
  final void Function(double) preview;
  final Future<void> Function(double) commit;

  const _WallpaperSlider({
    required this.label,
    required this.max,
    required this.percent,
    required this.initial,
    required this.preview,
    required this.commit,
  });

  @override
  State<_WallpaperSlider> createState() => _WallpaperSliderState();
}

class _WallpaperSliderState extends State<_WallpaperSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  String get _display => widget.percent
      ? '${widget.label}：${(_value * 100).round()}%'
      : '${widget.label}：${_value.round()}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _display,
          style: TextStyle(
            color: FluidTheme.getTextSecondaryColor(isDark),
            fontSize: 13,
          ),
        ),
        LiquidSlider(
          value: _value,
          min: 0,
          max: widget.max,
          activeColor: FluidTheme.primaryFluidGradient[0],
          onChanged: (v) {
            setState(() => _value = v);
            widget.preview(v);
          },
          onChangeEnd: widget.commit,
        ),
      ],
    );
  }
}

/// 壁纸：选择/移除图片 + 景深与蒙层微调
class _WallpaperSection extends StatelessWidget {
  final Future<void> Function() pickBgImage;

  const _WallpaperSection({required this.pickBgImage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = context.tr;
    //只在图片路径变化时重建这一块，拖滑块不会连带重建
    final path = context.select<ReaderSettingsProvider, String?>(
      (s) => s.bgImagePath,
    );
    final s = context.read<ReaderSettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          tr.bgImageLabel,
          style: FluidTheme.labelLarge(
            isDark,
          ).copyWith(color: FluidTheme.getTextPrimaryColor(isDark)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _outlineButton(
              context,
              Icons.image_outlined,
              tr.chooseImageBtn,
              pickBgImage,
            ),
            if (path != null)
              _outlineButton(
                context,
                Icons.image_not_supported_outlined,
                tr.removeImageBtn,
                () => s.setBgImage(null),
              ),
          ],
        ),
        if (path != null) ...[
          const SizedBox(height: 8),
          _WallpaperSlider(
            label: tr.bgDepthLabel,
            max: 20,
            percent: false,
            initial: s.bgBlur,
            preview: (v) {
              s.previewBgBlur(v);
              s.notifyBgLive();
            },
            commit: s.setBgBlur,
          ),
          _WallpaperSlider(
            label: tr.bgOverlayLabel,
            max: 0.8,
            percent: true,
            initial: s.bgOverlay,
            preview: (v) {
              s.previewBgOverlay(v);
              s.notifyBgLive();
            },
            commit: s.setBgOverlay,
          ),
        ],
      ],
    );
  }
}
