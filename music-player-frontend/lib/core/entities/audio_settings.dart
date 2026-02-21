import 'package:objectbox/objectbox.dart';

@Entity()
class AudioSettings {
  @Id()
  int id = 0;

  @Transient()
  bool playing = false;

  bool repeat = false;
  bool shuffle = false;

  double pitch = 0.0;
  double speed = 1.0;
  double volume = 1.0;

  int sliderInSeconds = 0;
}
