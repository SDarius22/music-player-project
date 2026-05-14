import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';

@Entity()
class AudioSettings {
  @Id()
  int id = 0;

  @Transient()
  bool playing = false;

  bool repeat = false;
  bool shuffle = false;
  bool autoPlay = false;
  int autoPlayRecommendationsPage = 0;

  double pitch = 0.0;
  double speed = 1.0;
  double volume = 1.0;

  int sliderInSeconds = 0;

  AudioSettings();

  factory AudioSettings.fromJson(Map<String, dynamic> json) {
    final audioSettings = AudioSettings();
    audioSettings.repeat = (json['repeat'] as bool?) ?? false;
    audioSettings.shuffle = (json['shuffle'] as bool?) ?? false;
    audioSettings.autoPlay = (json['autoPlay'] as bool?) ?? false;
    audioSettings.autoPlayRecommendationsPage =
        (json['autoPlayRecommendationsPage'] as num?)?.toInt() ?? 0;
    audioSettings.pitch = (json['pitch'] as num?)?.toDouble() ?? 0.0;
    audioSettings.speed = (json['speed'] as num?)?.toDouble() ?? 1.0;
    audioSettings.volume = (json['volume'] as num?)?.toDouble() ?? 1.0;
    audioSettings.sliderInSeconds =
        (json['sliderInSeconds'] as num?)?.toInt() ?? 0;
    return audioSettings;
  }

  Map<String, dynamic> toJson() => {
    'repeat': repeat,
    'shuffle': shuffle,
    'autoPlay': autoPlay,
    'autoPlayRecommendationsPage': autoPlayRecommendationsPage,
    'pitch': pitch,
    'speed': speed,
    'volume': volume,
    'sliderInSeconds': sliderInSeconds,
  };
}
