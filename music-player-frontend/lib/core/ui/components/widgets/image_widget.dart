import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

enum ImageWidgetType { asset, song, network, bytes }

class ImageWidget extends StatefulWidget {
  final Widget? hoveredChild;
  final Widget? child;
  final BaseEntity entity;
  final bool fadeBottom;

  const ImageWidget({
    super.key,
    this.hoveredChild,
    this.child,
    required this.entity,
    this.fadeBottom = false,
  });

  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  ValueNotifier<bool> isHovered = ValueNotifier(false);

  @override
  void didUpdateWidget(covariant ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity != widget.entity) {
      setState(() {});
    }
  }

  Widget _buildForeground() {
    if (widget.hoveredChild != null) {
      return ValueListenableBuilder(
        valueListenable: isHovered,
        builder: (context, value, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: value ? 0.0 : 1.0, child: widget.child),
              Opacity(
                opacity: value ? 1.0 : 0.0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      alignment: Alignment.center,
                      child: widget.hoveredChild,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return widget.child ?? const SizedBox.shrink();
  }

  Future<Widget> _getImageWidget() async {
    if (widget.entity.coverArt == null) {
      if (widget.entity.serverId != -1) {
        return CachedNetworkImage(
          imageUrl:
              "${Constants.apiBaseUrl}/songs/${widget.entity.serverId}/cover",
          httpHeaders: {
            "Authorization":
                "Bearer ${Provider.of<AuthService>(context, listen: false).accessToken}",
          },
          fit: BoxFit.cover,
          errorWidget:
              (context, url, error) => Container(
                color: Colors.black,
                child: Icon(
                  FluentIcons.music,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 64,
                ),
              ),
        );
      }
      return Container(
        color: Colors.black,
        child: Icon(
          FluentIcons.music,
          color: Colors.white.withValues(alpha: 0.25),
          size: 64,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          fit: BoxFit.cover,
          image: MemoryImage(widget.entity.coverArt!),
        ),
      ),
    );
  }

  Widget _buildImageLayer() {
    return FutureBuilder<Widget>(
      future: _getImageWidget(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.black);
        } else if (snapshot.hasError) {
          return Container(color: Colors.black);
        } else {
          final shouldFadeImageOnly = widget.fadeBottom && widget.child != null;

          if (!shouldFadeImageOnly) return snapshot.data!;

          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.white, Colors.white, Colors.transparent],
                stops: <double>[0.0, 2.0 / 3.0, 1.0],
              ).createShader(bounds);
            },
            child: snapshot.data!,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget tile = AspectRatio(
      aspectRatio: 1.0,
      child: MouseRegion(
        onEnter: (event) => isHovered.value = true,
        onExit: (event) => isHovered.value = false,
        child: Stack(
          fit: StackFit.expand,
          children: [_buildImageLayer(), _buildForeground()],
        ),
      ),
    );

    final shouldFadeWholeTile = widget.fadeBottom && widget.child == null;
    if (!shouldFadeWholeTile) return tile;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.white, Colors.white, Colors.transparent],
          stops: <double>[0.0, 2.0 / 3.0, 1.0],
        ).createShader(bounds);
      },
      child: tile,
    );
  }
}
