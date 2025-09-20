import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/volume_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class LinuxVolumeWidget extends VolumeWidget {
  const LinuxVolumeWidget({super.key});

  @override
  State<VolumeWidget> createState() => _VolumeWidgetState();
}

class _VolumeWidgetState extends VolumeWidgetState {
  final ValueNotifier<bool> _visible = ValueNotifier(false);
  late final AbstractAudioProvider _audioProvider;

  @override
  void initState() {
    super.initState();
    _audioProvider = Provider.of<AbstractAudioProvider>(context, listen: false);
  }

  @override
  Widget buildVolumeWidget(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Visibility(
          visible: _visible.value,
          child: MouseRegion(
            onEnter: (event) {
              _visible.value = true;
            },
            onExit: (event) {
              _visible.value = false;
            },
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
        MouseRegion(
          onEnter: (event) {
            _visible.value = true;
          },
          onExit: (event) {
            _visible.value = false;
          },
          child: ValueListenableBuilder(
            valueListenable: _audioProvider.volumeNotifier,
            builder: (context, value, child) {
              return IconButton(
                icon:
                    value > 0.0
                        ? Icon(
                          FluentIcons.volumeOn,
                          size: height * 0.0175,
                          color: Colors.white,
                        )
                        : Icon(
                          FluentIcons.volumeOff,
                          size: height * 0.0175,
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
      ],
    );
  }
}
