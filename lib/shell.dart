import 'package:flutter/material.dart';

import 'data.dart';
import 'home_page.dart';
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
          onOpenReels: () => setState(() => _index = 2),
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
    return Scaffold(
      body: _page(),
      bottomNavigationBar: BottomBar(
        index: _index,
        dark: _index == 2,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class BottomBar extends StatelessWidget {
  final int index;
  final bool dark;
  final ValueChanged<int> onTap;
  const BottomBar({
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
    final bg = dark ? AppColors.darkNav : Colors.white;
    final active = dark ? AppColors.darkAccent : AppColors.blue;
    final idle = dark ? AppColors.darkMuted : const Color(0xFF5B6472);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < _labels.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == index ? _iconsOn[i] : _icons[i],
                          size: 26,
                          color: i == index ? active : idle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                            color: i == index ? active : idle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
