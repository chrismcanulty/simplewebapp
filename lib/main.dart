import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

import 'amplifyconfiguration.dart';
import 'models/ModelProvider.dart';

import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(const MyApp());
}

Future<void> _configureAmplify() async {
  try {
    // Create the API plugin.
    //
    // If `ModelProvixder.instance` is not available, try running
    // `amplify codegen models` from the root of your project.
    final api = AmplifyAPI(
        options: APIPluginOptions(modelProvider: ModelProvider.instance));

    // Create the Auth plugin.
    final auth = AmplifyAuthCognito();

    // Add the plugins and configure Amplify for your app.
    await Amplify.addPlugins([api, auth]);
    await Amplify.configure(amplifyconfig);

    safePrint('Successfully configured');
  } on Exception catch (e) {
    safePrint('Error configuring Amplify: $e');
  }
}

// Main application

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // GoRouter configuration
  static final _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      // Can add the robot detail screen here later
      GoRoute(
        path: '/robot-details',
        name: 'details',
        builder: (context, state) => const RobotDetailsScreen(),
        // ManageBudgetEntryScreen(budgetEntry: state.extra as BudgetEntry?,
        // ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Authenticator(
      child: MaterialApp.router(
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        builder: Authenticator.builder(),
      ),
    );
  }
}

// RobotDetailsScreen

class RobotDetailsScreen extends StatefulWidget {
  const RobotDetailsScreen({Key? key}) : super(key: key);

  @override
  _RobotDetailsScreenState createState() => _RobotDetailsScreenState();
}

class _RobotDetailsScreenState extends State<RobotDetailsScreen> {
  String robotName = '';
  String robotId = '';
  late MQTTManager mqttManager;

  @override
  void initState() {
    super.initState();
    mqttManager = MQTTManager();
    mqttManager.initializeMQTTClient();
    mqttManager.connect();
  }

  @override
  void dispose() {
    mqttManager.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT JSON Data'),
      ),
      body: Center(
        child: StreamBuilder(
          stream: mqttManager.messageStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final data = snapshot.data.toString();
              final decodedData = jsonDecode(data);
              if (decodedData is List && decodedData.isNotEmpty) {
                final firstRobot = decodedData[0];
                robotName = firstRobot['robotName'] ?? '';
                robotId = firstRobot['robotId'] ?? '';
              }
            }
            return robotName.isNotEmpty && robotId.isNotEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Robot Name: $robotName'),
                      Text('Robot ID: $robotId'),
                    ],
                  )
                : const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}

enum MQTTAppConnectionState { connected, disconnected, connecting }

class MQTTManager {
  MQTTAppConnectionState _currentState = MQTTAppConnectionState.disconnected;
  MqttBrowserClient? _client;
  final String _identifier = 'flutter_client';
  final String _host = 'broker.hivemq.com';
  final String _topic = 'robot/data';
  final StreamController<String> _messageStreamController =
      StreamController<String>();

  Stream<String> get messageStream => _messageStreamController.stream;

  void initializeMQTTClient() {
    _client = MqttBrowserClient('ws://$_host:8000/mqtt', _identifier);
    _client!.setProtocolV311();
    _client!.port = 8000;
    _client!.keepAlivePeriod = 60;
    _client!.logging(on: true);
    _client!.onDisconnected = onDisconnected;
    _client!.onConnected = onConnected;
    _client!.onSubscribed = onSubscribed;
    _client!.onUnsubscribed = onUnsubscribed;

    final MqttConnectMessage connMess = MqttConnectMessage()
        .withClientIdentifier(_identifier)
        .withWillTopic('willTopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMess;
  }

  void connect() async {
    try {
      await _client!.connect();
      _currentState = MQTTAppConnectionState.connected;
    } on Exception catch (e) {
      print('Error connecting: $e');
      disconnect();
    }
  }

  void disconnect() {
    _client!.disconnect();
    _currentState = MQTTAppConnectionState.disconnected;
  }

  void onSubscribed(String topic) {
    print('Subscribed to $topic');
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String message =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      _messageStreamController.add(message);
    });
  }

  void onUnsubscribed(String? topic) {
    print('Unsubscribed from $topic');
  }

  void onDisconnected() {
    print('Disconnected');
    _currentState = MQTTAppConnectionState.disconnected;
  }

  void onConnected() {
    print('Connected');
    _currentState = MQTTAppConnectionState.connected;
    _client!.subscribe(_topic, MqttQos.atMostOnce);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Robot>> futureRobots;

  @override
  void initState() {
    super.initState();
    futureRobots = fetchRobots();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Robot List'),
        ),
        body: Center(
          child: FutureBuilder<List<Robot>>(
            future: futureRobots,
            builder: (context, AsyncSnapshot<List<Robot>> snapshot) {
              // ignore: avoid_print
              if (snapshot.hasData) {
                final robots = snapshot.data;
                return buildRobots(robots!);
              } else if (snapshot.hasError) {
                return Text('${snapshot.error}');
              }

              // By default, show a loading spinner.
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}

Widget buildRobots(List<Robot> robots) {
  return ListView.builder(
    itemCount: robots.length,
    itemBuilder: (context, index) {
      final robot = robots[index];
      final robotName = robot.robotName;
      final mapId = robot.mapId;
      final updatedAt = robot.updatedAt;
      final createdAt = robot.createdAt;
      final mapName = robot.mapName;
      final robotId = robot.robotId;
      return Container(
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Robot id: $robotId'),
                  Text('Robot name: $robotName'),
                  Text('Map ID: $mapId'),
                  Text('Map name: $mapName'),
                  Text('Created at: $createdAt'),
                  Text('Updated at: $updatedAt'),
                  ElevatedButton(
                    child: const Text('Robot details'),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RobotDetailsScreen(),
                              settings: RouteSettings(arguments: robot)));
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<List<Robot>> fetchRobots() async {
  var url = Uri.parse('https://map-api.ik-robot.com/master/robot');
  final response =
      await http.get(url, headers: {"Content-Type": "application/json"});

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.

    final List body = json.decode(response.body);

    return body.map((e) => Robot.fromJson(e)).toList();
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load');
  }
}

// Create classes for individual Robot data

List<Robot> robotFromJson(String str) =>
    List<Robot>.from(json.decode(str).map((x) => Robot.fromJson(x)));

String robotToJson(List<Robot> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Robot {
  List<MapInfo> mapInfo;
  String? mapId;
  int updatedAt;
  int createdAt;
  String? mapName;
  String robotName;
  String robotId;

  Robot({
    required this.mapInfo,
    this.mapId,
    required this.updatedAt,
    required this.createdAt,
    this.mapName,
    required this.robotName,
    required this.robotId,
  });

  factory Robot.fromJson(Map<String, dynamic> json) => Robot(
        mapInfo:
            List<MapInfo>.from(json["mapInfo"].map((x) => MapInfo.fromJson(x))),
        mapId: json["mapId"],
        updatedAt: json["updatedAt"],
        createdAt: json["createdAt"],
        mapName: json["mapName"],
        robotName: json["robotName"],
        robotId: json["robotId"],
      );

  Map<String, dynamic> toJson() => {
        "mapInfo": List<dynamic>.from(mapInfo.map((x) => x.toJson())),
        "mapId": mapId,
        "updatedAt": updatedAt,
        "createdAt": createdAt,
        "mapName": mapName,
        "robotName": robotName,
        "robotId": robotId,
      };
}

class MapInfo {
  List<String>? homePointList;
  String mapId;
  List<String>? localizePointList;
  List<MapPointList> mapPointList;
  String? mapName;

  MapInfo({
    this.homePointList,
    required this.mapId,
    this.localizePointList,
    required this.mapPointList,
    this.mapName,
  });

  factory MapInfo.fromJson(Map<String, dynamic> json) => MapInfo(
        homePointList: json["homePointList"] == null
            ? []
            : List<String>.from(json["homePointList"]!.map((x) => x)),
        mapId: json["mapId"],
        localizePointList: json["localizePointList"] == null
            ? []
            : List<String>.from(json["localizePointList"]!.map((x) => x)),
        mapPointList: List<MapPointList>.from(
            json["mapPointList"].map((x) => MapPointList.fromJson(x))),
        mapName: json["mapName"],
      );

  Map<String, dynamic> toJson() => {
        "homePointList": homePointList == null
            ? []
            : List<dynamic>.from(homePointList!.map((x) => x)),
        "mapId": mapId,
        "localizePointList": localizePointList == null
            ? []
            : List<dynamic>.from(localizePointList!.map((x) => x)),
        "mapPointList": List<dynamic>.from(mapPointList.map((x) => x.toJson())),
        "mapName": mapName,
      };
}

class MapPointList {
  String mapId;
  List<StationDeg> stationDeg;
  double x;
  double y;
  Category category;
  int createdAt;
  String pointId;
  String? areaId;
  String id;
  String? pointName;
  List<String>? tags;
  double? direction;

  MapPointList({
    required this.mapId,
    required this.stationDeg,
    required this.x,
    required this.y,
    required this.category,
    required this.createdAt,
    required this.pointId,
    this.areaId,
    required this.id,
    this.pointName,
    this.tags,
    this.direction,
  });

  factory MapPointList.fromJson(Map<String, dynamic> json) => MapPointList(
        mapId: json["mapId"],
        stationDeg: List<StationDeg>.from(
            json["stationDeg"].map((x) => StationDeg.fromJson(x))),
        x: json["x"]?.toDouble(),
        y: json["y"]?.toDouble(),
        category: categoryValues.map[json["category"]]!,
        createdAt: json["createdAt"],
        pointId: json["pointId"],
        areaId: json["areaId"],
        id: json["id"],
        pointName: json["pointName"],
        tags: json["tags"] == null
            ? []
            : List<String>.from(json["tags"]!.map((x) => x)),
        direction: json["direction"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "mapId": mapId,
        "stationDeg": List<dynamic>.from(stationDeg.map((x) => x.toJson())),
        "x": x,
        "y": y,
        "category": categoryValues.reverse[category],
        "createdAt": createdAt,
        "pointId": pointId,
        "areaId": areaId,
        "id": id,
        "pointName": pointName,
        "tags": tags == null ? [] : List<dynamic>.from(tags!.map((x) => x)),
        "direction": direction,
      };
}

enum Category { LOCALIZE, NONE, ROUTE }

final categoryValues = EnumValues({
  "LOCALIZE": Category.LOCALIZE,
  "NONE": Category.NONE,
  "ROUTE": Category.ROUTE
});

class StationDeg {
  double rad;
  String stationId;
  String dstId;

  StationDeg({
    required this.rad,
    required this.stationId,
    required this.dstId,
  });

  factory StationDeg.fromJson(Map<String, dynamic> json) => StationDeg(
        rad: json["rad"]?.toDouble(),
        stationId: json["stationId"],
        dstId: json["dstId"],
      );

  Map<String, dynamic> toJson() => {
        "rad": rad,
        "stationId": stationId,
        "dstId": dstId,
      };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
