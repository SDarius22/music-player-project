import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';

enum ImageWidgetType {
  asset,
  song,
  network,
  bytes,
}

class ImageWidget extends StatefulWidget {
  final String path;
  final Widget? hoveredChild;
  final Widget? child;
  final ImageWidgetType type;

  const ImageWidget({super.key,required this.path, required this.type, this.hoveredChild, this.child});

  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  ValueNotifier<bool> isHovered = ValueNotifier(false);
  late Future imageFuture;
  final ImageProvider image = Image.asset('assets/logo.png', fit: BoxFit.cover,).image;

  @override
  void initState() {
    super.initState();
    imageFuture = getImage();
  }

  @override
  void didUpdateWidget(covariant ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.type != widget.type) {
      setState(() {
        imageFuture = getImage();
      });
    }
  }

  Future<Uint8List> decodeImage(String path) async {
    return base64Decode(path);
  }

  Future getImage() {
    if (widget.type == ImageWidgetType.bytes) {
      return Future(() async {
        final image = await decodeImage(widget.path);
        return Image.memory(image).image;
      });
    }
    if (widget.type == ImageWidgetType.song) {
      return Future(() async {
        final image = await FileService.getImage(widget.path);
        return Image.memory(image).image;
      });
    }
    if (widget.type == ImageWidgetType.network) {
      return Future(() async {
        return Image.network(widget.path).image;
      });
    }
    if (widget.type == ImageWidgetType.asset) {
      return Future(() async {
        return Image.asset(widget.path).image;
      });
    }
    return Future(() async {
      return Image.asset('assets/logo.png', fit: BoxFit.cover,).image;
    });
  }

  Widget imageWidget(ImageProvider image) {
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
              image: image,
            ),
          ),
          child: widget.hoveredChild != null?
          ValueListenableBuilder(
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
              }
          ) :
          widget.child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return imageWidget(image);
        }
        return imageWidget(snapshot.data ?? image);
      },
    );
  }
}
