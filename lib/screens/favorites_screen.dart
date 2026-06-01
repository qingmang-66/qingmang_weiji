import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/di_container.dart';
import '../services/providers/providers.dart';
import '../theme/fluid_theme.dart';
import '../utils/error_handler.dart';
import '../utils/page_transitions.dart';
import '../widgets/fluid_background.dart';
import '../widgets/fluid_button.dart';
import '../widgets/fluid_card.dart';
import '../widgets/study_mode_picker.dart';
import 'pre_study_screen.dart';
import 'word_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Word> _words = [];
  List<MapEntry<String, int>> _groups = [];
  String? _selectedGroup;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final di = DIContainer.instance;
      final groups = await di.favoriteRepository.getGroups();
      final words = await di.favoriteRepository.getFavoriteWords(
        groupName: _selectedGroup,
      );
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _words = words;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorHandler.showError(context, '加载收藏夹失败');
    }
  }

  Future<void> _startStudy() async {
    if (_words.isEmpty) return;
    final mode = await showStudyModePicker(context);
    if (mode == null || !mounted) return;
    final di = DIContainer.instance;
    final request = await di.specializedStudyService.buildFavoritesRequest(
      wordBookId: null,
      groupName: _selectedGroup,
      studyMode: mode,
    );
    if (!mounted) return;
    if (request == null) {
      ErrorHandler.showError(context, '当前收藏夹没有可学习单词');
      return;
    }
    Navigator.of(context)
        .push(
          PageTransitions.slideFromRight(
            page: PreStudyScreen.specialized(request: request, words: _words),
          ),
        )
        .then((_) => _load());
  }

  Future<void> _remove(Word word) async {
    final wordId = word.id;
    if (wordId == null) return;
    await DIContainer.instance.favoriteRepository.removeFavorite(wordId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = FluidTheme.getTextPrimaryColor(isDark);
    final textSecondary = FluidTheme.getTextSecondaryColor(isDark);

    return FluidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textPrimary),
          title: Text(
            '收藏夹',
            style: FluidTheme.headingMedium(
              isDark,
            ).copyWith(color: textPrimary),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.play_circle_outline, color: textPrimary),
              onPressed: _words.isEmpty ? null : _startStudy,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: FluidTheme.primaryFluidGradient[0],
                ),
              )
            : Column(
                children: [
                  if (_groups.isNotEmpty)
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ChoiceChip(
                            label: Text(
                              '全部 (${_groups.fold<int>(0, (sum, g) => sum + g.value)})',
                            ),
                            selected: _selectedGroup == null,
                            onSelected: (_) {
                              setState(() => _selectedGroup = null);
                              _load();
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._groups.map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('${group.key} (${group.value})'),
                                selected: _selectedGroup == group.key,
                                onSelected: (_) {
                                  setState(() => _selectedGroup = group.key);
                                  _load();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _words.isEmpty
                        ? Center(
                            child: Text(
                              '还没有收藏单词',
                              style: FluidTheme.bodyMedium(
                                isDark,
                              ).copyWith(color: textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _words.length,
                            itemBuilder: (context, index) {
                              final word = _words[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: FluidCard(
                                  enableShimmer: false,
                                  padding: const EdgeInsets.all(14),
                                  onTap: () => Navigator.of(context)
                                      .push(
                                        PageTransitions.slideFromRight(
                                          page: WordDetailScreen(word: word),
                                        ),
                                      )
                                      .then((_) => _load()),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              word.word,
                                              style: FluidTheme.labelLarge(
                                                isDark,
                                              ).copyWith(color: textPrimary),
                                            ),
                                            if (word.definition.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                word.definition,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    FluidTheme.bodySmall(
                                                      isDark,
                                                    ).copyWith(
                                                      color: textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.bookmark_remove,
                                          color: FluidTheme.error,
                                        ),
                                        onPressed: () => _remove(word),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FluidButton(
                      text: '开始收藏夹专项学习',
                      icon: Icons.play_arrow,
                      expanded: true,
                      isEnabled: _words.isNotEmpty,
                      onPressed: _words.isEmpty ? null : _startStudy,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
