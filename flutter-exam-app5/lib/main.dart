import 'package:flutter/material.dart';
import 'models/exam.dart';
import '../screens/calendar.dart';
import 'models/location.dart';
import '../maps/map.dart';
import 'maps/path.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const ApiKey = 'API AKO VI TREBA KE VI GO PRATAM NA MAIL';
GoogleMapsPlaces _places = GoogleMapsPlaces(
    apiKey: ApiKey, baseUrl: 'https://maps.googleapis.com/maps/api');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('bd_logo');

  final IOSInitializationSettings initializationSettingsIOS =
      IOSInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          onDidReceiveLocalNotification:
              (int id, String? title, String? body, String? payload) async {});

  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String? payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }
  });
  initializeDateFormatting().then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  // This widget is the root of your application.
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isLoggedIn = false;
  var title = '';
  List<Exam> exams = [];
  bool toggleForm = false;

  final _inputKey = GlobalKey<FormState>();
  final _messangerKey = GlobalKey<ScaffoldMessengerState>();

  String? name = "";
  String? username = "";
  DateTime currentDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  LocationData? selectedLocation = null;

  late TextEditingController txt;
  late TextEditingController user;

  @override
  void initState() {
    super.initState();
    txt = TextEditingController()
      ..addListener(() {
        // print(txt.text);
      });

    user = TextEditingController()
      ..addListener(() {
        // print(txt.text);
      });

    bg.BackgroundGeolocation.onGeofence(_onGeofence);

    bg.BackgroundGeolocation.ready(bg.Config(
            desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
            distanceFilter: 10.0,
            stopOnTerminate: false,
            startOnBoot: true,
            debug: false,
            logLevel: bg.Config.LOG_LEVEL_OFF))
        .then((bg.State state) {
      if (!state.enabled) {
        bg.BackgroundGeolocation.startGeofences();
      }
    });
  }

  @override
  void dispose() {
    txt.dispose();
    user.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: DateTime(2010),
        lastDate: DateTime(2100));
    if (pickedDate != null && pickedDate != currentDate)
      setState(() {
        currentDate = pickedDate;
      });
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked_s = await showTimePicker(
        context: context,
        initialTime: selectedTime,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          );
        });

    if (picked_s != null && picked_s != selectedTime)
      setState(() {
        selectedTime = picked_s;
      });
  }

  Future<List<Exam>> _get(String username) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? examsString = await prefs.getString(username);

    List<Exam> exams = [];

    if (examsString != null) exams = Exam.decode(examsString);

    return exams;
  }

  Future<void> _set(String username, List<Exam> exams) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String encodedData = Exam.encode(exams);

    await prefs.setString(username, encodedData);
  }

  Future<Null> savePrediction(Prediction? p) async {
    print("savepredictionOne");
    if (p != null) {
      print("savepredictionTwo");
      PlacesDetailsResponse detail =
          await _places.getDetailsByPlaceId(p.placeId!);
      if (detail.result.geometry != null) {
        print(detail);
        setState(() {
          selectedLocation = new LocationData(
              description: p.description,
              latitude: detail.result.geometry!.location.lat,
              longitude: detail.result.geometry!.location.lng);
        });
      }
    }
  }

  void showError(PlacesAutocompleteResponse response) {
    print('showError:');
    print(response.errorMessage);
  }

  void _addGeofence(String desc, double lat, double long) {
    bg.BackgroundGeolocation.addGeofence(bg.Geofence(
      identifier: desc,
      radius: 150,
      latitude: lat,
      longitude: long,
      notifyOnEntry: true,
      notifyOnExit: false,
      notifyOnDwell: false,
      loiteringDelay: 30000,
    )).then((bool success) {
      print('[addGeofence] success with $lat and $long');
    }).catchError((error) {
      print('[addGeofence] FAILURE: $error');
    });
  }

  void _onGeofence(bg.GeofenceEvent event) {
    print('onGeofence $event');

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'exam_notif_channel_id', 'exam_notif_channel',
        channelDescription: 'Channel for Exam notification',
        icon: 'finki_logo',
        sound: RawResourceAndroidNotificationSound('a_long_cold_sting'),
        largeIcon: DrawableResourceAndroidBitmap('finki_logo'));

    var iOSPlatformChannelSpecifics = IOSNotificationDetails(
        sound: 'a_long_cold_sting.wav',
        presentAlert: true,
        presentBadge: true,
        presentSound: true);

    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    flutterLocalNotificationsPlugin
        .show(
            0,
            'You are nearby!',
            'The exam location is right around the corner: ' + event.identifier,
            platformChannelSpecifics)
        .then((result) {})
        .catchError((showError) {
      print('[flutterLocalNotificationsPlugin.show] ERROR: $showError');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messangerKey,
      title: '',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: isLoggedIn
            ? SingleChildScrollView(
                child: Column(children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                  child: Text(
                    'Exams',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                Card(
                    elevation: 5,
                    child: Form(
                      key: _inputKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: exams.length,
                            itemBuilder: (contx, index) {
                              return Column(children: [
                                Card(
                                  key: Key(exams[index].name!),
                                  elevation: 2,
                                  child: Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.all(18),
                                    child: Column(children: [
                                      Container(
                                          padding: EdgeInsets.all(5),
                                          margin: EdgeInsets.all(5),
                                          child: Text(
                                              exams[index].name.toString(),
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      Container(
                                          padding: EdgeInsets.all(5),
                                          margin: EdgeInsets.all(5),
                                          child: Text(
                                              exams[index]
                                                      .date
                                                      .toString()
                                                      .split(" ")[0] +
                                                  " " +
                                                  exams[index]
                                                      .time!
                                                      .format(context),
                                              style: TextStyle(
                                                  color: Colors.grey))),
                                      Container(
                                          padding: EdgeInsets.all(5),
                                          margin: EdgeInsets.all(5),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: <Widget>[
                                                Padding(
                                                    padding: EdgeInsets.all(5),
                                                    child: Text(
                                                        exams[index]
                                                            .location
                                                            .toString(),
                                                        style: TextStyle(
                                                            color:
                                                                Colors.grey))),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            TermShortestPath(
                                                                exams[index])),
                                                  ),
                                                  child:
                                                      const Text('Directions'),
                                                )
                                              ]))
                                    ]),
                                  ),
                                ),
                              ]);
                            },
                          ),
                          Padding(
                              padding: EdgeInsets.all(15),
                              child: TextFormField(
                                  controller: txt,
                                  decoration: InputDecoration(
                                    hintText: 'Add new exam',
                                  ),
                                  validator: (inputString) {
                                    name = inputString;
                                    if (inputString!.length < 1) {
                                      return 'Input must be filled';
                                    }
                                    return null;
                                  })),
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(
                                        currentDate.toString().split(" ")[0])),
                                ElevatedButton(
                                    onPressed: () => _selectDate(context),
                                    child: Text('Add date')),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(selectedTime.format(context))),
                                ElevatedButton(
                                    onPressed: () => _selectTime(context),
                                    child: Text('Add time')),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(selectedLocation != null
                                        ? selectedLocation!.description!
                                        : 'None')),
                                ElevatedButton(
                                    onPressed: () async {
                                      print("Pressed");
                                      Prediction? p =
                                          await PlacesAutocomplete.show(
                                              offset: 0,
                                              radius: 1000,
                                              types: [],
                                              strictbounds: false,
                                              region: "uk",
                                              context: context,
                                              apiKey: ApiKey,
                                              mode: Mode.overlay,
                                              language: "en",
                                              components: [
                                                new Component(
                                                    Component.country, 'gb')
                                              ],
                                              onError: showError);
                                      print("Pressed 2");
                                      await savePrediction(p);
                                    },
                                    child: Text('Add location')),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(0),
                            child: ElevatedButton(
                              onPressed: () {
                                if (_inputKey.currentState!.validate()) {
                                  name = txt.text;
                                  currentDate = new DateTime(
                                      currentDate.year,
                                      currentDate.month,
                                      currentDate.day,
                                      selectedTime.hour,
                                      selectedTime.minute);
                                  Exam obj = new Exam(
                                      name: name!,
                                      date: currentDate,
                                      time: selectedTime);
                                  scheduler(obj);
                                  exams.add(obj);
                                  _set(username!, exams);
                                  setState(() {
                                    txt.text = "";
                                    name = "";
                                    currentDate = DateTime.now();
                                    selectedTime = TimeOfDay.now();
                                  });
                                  _messangerKey.currentState?.showSnackBar(
                                      SnackBar(content: Text('Exam added')));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 50.0),
                                textStyle: TextStyle(fontSize: 35.0),
                              ),
                              child: const Text('Add'),
                            ),
                          ),
                          Padding(
                              padding: EdgeInsets.all(15),
                              child: Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(0),
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TermMap(this.exams),
                                          ),
                                        ),
                                        child: const Text(
                                          'Map',
                                          style: TextStyle(fontSize: 20),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize:
                                              Size(double.infinity, 55),
                                        ),
                                      )))),
                        ],
                      ),
                    )),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(15),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TableEventsExample(this.exams),
                                ),
                              ),
                              icon: Icon(Icons.calendar_today),
                              label: Text(''),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(15),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: ElevatedButton(
                              onPressed: () => setState(
                                  () => {username = "", isLoggedIn = false}),
                              child: Icon(Icons.logout, size: 30),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ]))
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'Enter your index to see your exams',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 5,
                    child: Form(
                      key: _inputKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(15),
                            child: TextFormField(
                              controller: user,
                              decoration: InputDecoration(
                                hintText: 'YOUR INDEX',
                              ),
                              validator: (inputString) {
                                username = inputString;
                                if (inputString!.length < 1) {
                                  return 'PLEASE USE YOUR INDEX';
                                }
                                return null;
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                if (_inputKey.currentState!.validate()) {
                                  username = user.text;
                                  user.text = "";
                                  _get(username!).then((List<Exam> exams) => {
                                        setState(() {
                                          this.exams = exams;
                                          isLoggedIn = true;
                                        })
                                      });
                                  _messangerKey.currentState?.showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Logged in successfully')));
                                }
                              },
                              child: const Text('Login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void scheduler(Exam exam) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'exam_notif_channel_id', 'exam_notif_channel',
        channelDescription: 'Channel for Exam notification',
        icon: 'bd_logo',
        sound: RawResourceAndroidNotificationSound('a_long_cold_sting'),
        largeIcon: DrawableResourceAndroidBitmap('bd_logo'));

    var iOSPlatformChannelSpecifics = IOSNotificationDetails(
        sound: 'a_long_cold_sting.wav',
        presentAlert: true,
        presentBadge: true,
        presentSound: true);

    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    var dayBefore = exam.date?.subtract(const Duration(days: 1));

    await flutterLocalNotificationsPlugin.schedule(
        0, 'Exam', exam.name, dayBefore!, platformChannelSpecifics);
  }
}
