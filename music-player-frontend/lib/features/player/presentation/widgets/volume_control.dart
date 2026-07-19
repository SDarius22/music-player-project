import 'package:flutter/material.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class VolumeControl extends StatefulWidget {
  const VolumeControl({super.key});

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  final ValueNotifier<bool> visible = ValueNotifier(false);
  late final AudioProvider _audioProvider;

  @override
  void initState() {
    super.initState();
    _audioProvider = Provider.of<AudioProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: visible,
      builder: (context, value, child) {
        return buildVolumeWidget(context);
      },
    );
  }

  Widget buildVolumeWidget(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: (event) {
            visible.value = true;
          },
          onExit: (event) {
            visible.value = false;
          },
          child: ValueListenableBuilder(
            valueListenable: _audioProvider.volumeNotifier,
            builder: (context, value, child) {
              return IconButton(
                icon:
                    value > 0.0
                        ? const Icon(
                          FluentIcons.volumeOn,
                          size: 20,
                          color: Colors.white,
                        )
                        : const Icon(
                          FluentIcons.volumeOff,
                          size: 20,
                          color: Colors.white,
                        ),
                onPressed: () {
                  if (value > 0.0) {
                    _audioProvider.setVolume(0.0);
                  } else {
                    _audioProvider.setVolume(0.25);
                  }
                },
              );
            },
          ),
        ),
        if (ResponsiveBreakpoints.of(context).isMobile) ...[
          SizedBox(
            width: width * 0.35,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: height * 0.0075,
                ),
              ),
              child: ValueListenableBuilder(
                valueListenable: _audioProvider.volumeNotifier,
                builder: (context, value, child) {
                  return Slider(
                    min: 0.0,
                    max: 1.0,
                    mouseCursor: SystemMouseCursors.click,
                    value: value,
                    activeColor: Colors.white,
                    thumbColor: Colors.white,
                    inactiveColor: Colors.white,
                    onChangeEnd: (double value) {
                      _audioProvider.setVolume(value);
                    },
                    onChanged: (double value) {
                      _audioProvider.volumeNotifier.value = value;
                    },
                  );
                },
              ),
            ),
          ),
        ] else ...[
          MouseRegion(
            onEnter: (event) {
              visible.value = true;
            },
            onExit: (event) {
              visible.value = false;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: visible.value ? width * 0.15 : 0.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: width * 0.1,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: height * 0.0075,
                      ),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: _audioProvider.volumeNotifier,
                      builder: (context, value, child) {
                        return Slider(
                          min: 0.0,
                          max: 1.0,
                          mouseCursor: SystemMouseCursors.click,
                          value: value,
                          activeColor: Colors.white,
                          thumbColor: Colors.white,
                          inactiveColor: Colors.white,
                          onChangeEnd: (double value) {
                            _audioProvider.setVolume(value);
                          },
                          onChanged: (double value) {
                            _audioProvider.volumeNotifier.value = value;
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
