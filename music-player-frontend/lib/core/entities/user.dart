import 'package:objectbox/objectbox.dart';

@Entity()
class User{
  @Id()
  int id = 0;

  String mongoID = '';
  String email = '';
  String password = '';
  List<String> deviceList = [];
  String primaryDevice = '';

  // Map<String, dynamic> toMap() {
  //   return {
  //     'index': index,
  //     'email': email,
  //     'password': password,
  //     'deviceList': deviceList,
  //     'primaryDevice': primaryDevice,
  //     'firstTime': firstTime,
  //     'systemTray': systemTray,
  //     'fullClose': fullClose,
  //     'appNotifications': appNotifications,
  //     'deezerARL': deezerARL,
  //     'queueAdd': queueAdd,
  //     'queuePlay': queuePlay,
  //     'queue': queue,
  //     'missingSongs': missingSongs,
  //   };
  // }
  //
  // void fromMap(Map<String, dynamic> map) {
  //   mongoID = map['id'];
  //   deviceList = List<String>.from(map['deviceList']);
  //   primaryDevice = map['primaryDevice'];
  //   index = map['index'];
  //   firstTime = map['firstTime'];
  //   systemTray = map['systemTray'];
  //   fullClose = map['fullClose'];
  //   appNotifications = map['appNotifications'];
  //   deezerARL = map['deezerARL'];
  //   queueAdd = map['queueAdd'];
  //   queuePlay = map['queuePlay'];
  //   queue = List<String>.from(map['queue']);
  //   missingSongs = List<String>.from(map['missingSongs']);
  // }
}