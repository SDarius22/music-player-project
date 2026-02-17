import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/volume_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class AndroidVolumeWidget extends VolumeWidget {
  const AndroidVolumeWidget({super.key});

  @override
  State<VolumeWidget> createState() => _VolumeWidgetState();
}

class _VolumeWidgetState extends VolumeWidgetState {
  late final AudioProvider _audioProvider;

  @override
  void initState() {
    super.initState();
    _audioProvider = Provider.of<AudioProvider>(context, listen: false);
  }

  @override
  Widget buildVolumeWidget(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: width * 0.25,
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
        ValueListenableBuilder(
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
      ],
    );
  }
}
