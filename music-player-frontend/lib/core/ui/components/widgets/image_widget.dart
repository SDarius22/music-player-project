import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';


class ImageWidget extends StatefulWidget {
  final Widget? hoveredChild;
  final Widget? child;
  final List<Widget> otherStackChildren;
  final BaseEntity entity;
  final bool fadeBottom;

  const ImageWidget({
    super.key,
    this.hoveredChild,
    this.child,
    required this.entity,
    this.fadeBottom = false,
    this.otherStackChildren = const [],
  });

  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  final ValueNotifier<bool> isHovered = ValueNotifier(false);
  late Widget _imageWidget;

  @override
  void initState() {
    super.initState();
    _imageWidget = _getImageWidget(context);
  }

  @override
  void didUpdateWidget(covariant ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity != widget.entity) {
      _imageWidget = _getImageWidget(context);
    }
  }

  @override
  void dispose() {
    isHovered.dispose();
    super.dispose();
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

  Widget _getImageWidget(BuildContext context) {
    try {
      return context.read<CoverService>().getWidget(widget.entity);
    } catch (e) {
      debugPrint(
        'ImageWidget: failed to get image for entity ${widget.entity.cloudId}: $e',
      );
    }

    return Container(
      color: Colors.black,
      child: Icon(
        FluentIcons.music,
        color: Colors.white.withValues(alpha: 0.25),
        size: MediaQuery.of(context).size.width * 0.1,
      ),
    );
  }

  Widget _buildImageLayer() {
    final shouldFadeImageOnly = widget.fadeBottom && widget.child != null;

    if (!shouldFadeImageOnly) return _imageWidget;

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
      child: _imageWidget,
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
          children: [
            _buildImageLayer(),
            _buildForeground(),
            ...widget.otherStackChildren,
          ],
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
