import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/hover_widget/hover_container.dart';
import 'package:web/web.dart' as web;

class _PlatformDownload {
  final String platform;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String url;
  final String filename;

  const _PlatformDownload({
    required this.platform,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.url,
    required this.filename,
  });
}

const _downloads = [
  _PlatformDownload(
    platform: 'Android',
    subtitle: 'Android 8.0+',
    icon: Icons.android,
    color: Color(0xFF3DDC84),
    url:
        'https://music.dariussala.com/downloads/music-player-android/app-release.apk',
    filename: 'music-player.apk',
  ),
  _PlatformDownload(
    platform: 'Linux',
    subtitle: 'x86_64 AppImage',
    icon: Icons.terminal,
    color: Color(0xFFF7941D),
    url:
        'https://music.dariussala.com/downloads/music-player-linux/music-player-linux.tar.gz',
    filename: 'music-player.tar.gz',
  ),
  _PlatformDownload(
    platform: 'Windows',
    subtitle: 'Windows 10+  •  x64',
    icon: Icons.laptop_windows,
    color: Color(0xFF0078D7),
    url:
        'https://music.dariussala.com/downloads/music-player-windows/music-player-windows.zip',
    filename: 'music-player.zip',
  ),
  _PlatformDownload(
    platform: 'macOS',
    subtitle: 'macOS 12+  •  Universal',
    icon: Icons.laptop_mac,
    color: Color(0xFFAAAAAA),
    url:
        'https://music.dariussala.com/downloads/music-player-macos/music-player-macos.zip',
    filename: 'music-player.zip',
  ),
  _PlatformDownload(
    platform: 'iOS',
    subtitle: 'iOS 16+',
    icon: Icons.phone_iphone,
    color: Color(0xFF007AFF),
    url: '',
    // TODO: URL once builds are available
    filename: 'music-player.ipa',
  ),
];

class EndDrawerWidget extends StatelessWidget {
  const EndDrawerWidget({super.key});

  void _triggerDownload(String url, String filename) {
    if (url.isEmpty) return;
    final anchor =
        web.HTMLAnchorElement()
          ..href = url
          ..setAttribute('download', filename)
          ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.55),
      borderColor: Colors.white.withValues(alpha: 0.08),
      blur: 48.0,
      borderWidth: 1.0,
      elevation: 8.0,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.topCenter,
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.01,
        vertical: size.height * 0.0125,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(size),
            SizedBox(height: size.height * 0.025),
            Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
            SizedBox(height: size.height * 0.018),
            ..._downloads.map(
              (item) => _DownloadCard(
                item: item,
                size: size,
                onTap:
                    item.url.isEmpty
                        ? null
                        : () => _triggerDownload(item.url, item.filename),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(size.height * 0.01),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(size.height * 0.01),
          ),
          child: Icon(
            Icons.download_rounded,
            color: Colors.indigoAccent.shade100,
            size: size.height * 0.032,
          ),
        ),
        SizedBox(width: size.width * 0.01),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Download',
              style: MusicPlayerTheme.getTheme().textTheme.headlineSmall!
                  .copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
            ),
            Text(
              'Get the native app for your platform',
              style: MusicPlayerTheme.getTheme().textTheme.bodySmall!.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final _PlatformDownload item;
  final Size size;
  final VoidCallback? onTap;

  const _DownloadCard({
    required this.item,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: size.height * 0.012),
      child: HoverContainer(
        hoverColor: Colors.white.withValues(alpha: 0.06),
        normalColor: Colors.white.withValues(alpha: 0.03),
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.018,
          vertical: size.height * 0.018,
        ),
        child: Row(
          children: [
            Container(
              width: size.height * 0.058,
              height: size.height * 0.058,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(size.height * 0.01),
                border: Border.all(
                  color: item.color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: size.height * 0.028,
              ),
            ),
            SizedBox(width: size.width * 0.015),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.platform,
                    style: MusicPlayerTheme.getTheme().textTheme.bodyLarge!
                        .copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: size.height * 0.003),
                  Text(
                    item.subtitle,
                    style: MusicPlayerTheme.getTheme().textTheme.bodySmall!
                        .copyWith(color: Colors.white.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
            _DownloadButton(color: item.color, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final Color color;
  final VoidCallback? onTap;

  const _DownloadButton({required this.color, required this.onTap});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final available = widget.onTap != null;

    return MouseRegion(
      cursor:
          available ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color:
                available
                    ? (_hovered
                        ? widget.color.withValues(alpha: 0.25)
                        : widget.color.withValues(alpha: 0.12))
                    : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  available
                      ? widget.color.withValues(alpha: _hovered ? 0.6 : 0.3)
                      : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                available ? Icons.download_rounded : Icons.hourglass_empty,
                size: 15,
                color:
                    available
                        ? widget.color.withValues(alpha: _hovered ? 1.0 : 0.8)
                        : Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Text(
                available ? 'Download' : 'Soon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      available
                          ? widget.color.withValues(alpha: _hovered ? 1.0 : 0.8)
                          : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
