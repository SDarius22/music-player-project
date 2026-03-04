import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';

enum ImageWidgetType { asset, song, network, bytes }

class ImageWidget extends StatefulWidget {
  final Widget? hoveredChild;
  final Widget? child;
  final BaseEntity? entity;
  final Uint8List? imageBytes;
  final bool fadeBottom;

  const ImageWidget({
    super.key,
    this.hoveredChild,
    this.child,
    this.entity,
    this.imageBytes,
    this.fadeBottom = false,
  }) : assert(
         entity == null || imageBytes == null,
         'Cannot provide both entity and imageBytes',
       ),
       assert(
         entity != null || imageBytes != null,
         'Must provide either entity or imageBytes',
       );

  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  ValueNotifier<bool> isHovered = ValueNotifier(false);
  late Future imageFuture;

  @override
  void initState() {
    super.initState();
    imageFuture = getImage();
  }

  @override
  void didUpdateWidget(covariant ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity != widget.entity ||
        oldWidget.imageBytes != widget.imageBytes) {
      setState(() {
        imageFuture = getImage();
      });
    }
  }

  Future<ImageProvider> getImage() async {
    if (widget.imageBytes != null) {
      return MemoryImage(widget.imageBytes!);
    }
    return MemoryImage(widget.entity!.coverArt);
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

  Widget _buildImageLayer(ImageProvider provider) {
    final image = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(fit: BoxFit.cover, image: provider),
      ),
    );

    final shouldFadeImageOnly = widget.fadeBottom && widget.child != null;

    if (!shouldFadeImageOnly) return image;

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
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: imageFuture,
      builder: (context, snapshot) {
        final ImageProvider provider =
            snapshot.connectionState == ConnectionState.waiting
                ? const AssetImage('assets/logo.png')
                : (snapshot.data! as ImageProvider);

        Widget tile = AspectRatio(
          aspectRatio: 1.0,
          child: MouseRegion(
            onEnter: (event) => isHovered.value = true,
            onExit: (event) => isHovered.value = false,
            child: Stack(
              fit: StackFit.expand,
              children: [_buildImageLayer(provider), _buildForeground()],
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
      },
    );
  }
}
