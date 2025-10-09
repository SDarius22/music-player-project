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

  const ImageWidget({
    super.key,
    this.hoveredChild,
    this.child,
    this.entity,
    this.imageBytes,
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
    if (oldWidget.entity != widget.entity) {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: imageFuture,
      builder: (context, snapshot) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: MouseRegion(
            onEnter: (event) {
              isHovered.value = true;
            },
            onExit: (event) {
              isHovered.value = false;
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image:
                      snapshot.connectionState == ConnectionState.waiting
                          ? const AssetImage("assets/logo.png")
                          : snapshot.data!,
                ),
              ),
              child:
                  widget.hoveredChild != null
                      ? ValueListenableBuilder(
                        valueListenable: isHovered,
                        builder: (context, value, child) {
                          return Stack(
                            children: [
                              Opacity(
                                opacity: value ? 0.0 : 1.0,
                                child: widget.child,
                              ),
                              Opacity(
                                opacity: value ? 1.0 : 0.0,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      alignment: Alignment.center,
                                      child: widget.hoveredChild,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                      : widget.child,
            ),
          ),
        );
      },
    );
  }
}
