import 'package:flutter/material.dart';

import 'data.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import 'posts_page.dart';
import 'profile_page.dart';
import 'reels_page.dart';
import 'social.dart';
import 'stories_page.dart';
import 'theme.dart';
import 'update.dart';

class HomeShell extends StatefulWidget {
  final Profile profile;
  const HomeShell({super.key, required this.profile});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    currentProfile = widget.profile;
    NotifService.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      checkForUpdate(context);
      if (widget.profile.isAdmin) {
        cleanupExpiredStories();
      }
    });
  }

  @override
  void dispose() {
    NotifService.stop();
    currentProfile = null;
    super.dispose();
  }

  Widget _page() {
    switch (_index) {
      case 0:
        return HomePage(
          profile: widget.profile,
          onCompose: () => setState(() => _index = 1),
        );
      case 1:
        return PostsPage(profile: widget.profile);
      case 2:
        return ReelsPage(profile: widget.profile);
      case 3:
        return StoriesPage(profile: widget.profile);
      default:
        return ProfilePage(profile: widget.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reels = _index == 2;
    return Scaffold(
      backgroundColor: reels ? AppColors.darkBg : AppColors.bg,
      body: Column(
        children: [
          Container(
            color: reels ? AppColors.darkNav : Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!reels)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 10, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'لمّتنا',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blue,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const NotificationBell(),
                        ],
                      ),
                    ),
                  TopTabs(
                    index: _index,
                    dark: reels,
                    onTap: (i) => setState(() => _index = i),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _page(),
            ),
          ),
        ],
      ),
    );
  }
}

/// تبويبات علوية بأيقونات على طريقة فيس بوك
class TopTabs extends StatelessWidget {
  final int index;
  final bool dark;
  final ValueChanged<int> onTap;
  const TopTabs({
    super.key,
    required this.index,
    required this.dark,
    required this.onTap,
  });

  static const _labels = ['الرئيسية', 'منشورات', 'ريلز', 'ستوري', 'حسابي'];
  static const _icons = [
    Icons.home_outlined,
    Icons.forum_outlined,
    Icons.play_circle_outline_rounded,
    Icons.donut_large_rounded,
    Icons.person_outline_rounded,
  ];
  static const _iconsOn = [
    Icons.home_rounded,
    Icons.forum_rounded,
    Icons.play_circle_rounded,
    Icons.donut_large_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final active = dark ? AppColors.darkAccent : AppColors.blue;
    final idle = dark ? AppColors.darkMuted : AppColors.muted;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xFF26323F) : AppColors.line,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: _labels[i],
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: i == index ? active : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Icon(
                      i == index ? _iconsOn[i] : _icons[i],
                      size: 26,
                      color: i == index ? active : idle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
