import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:muse_operation_ui/model/station_path.dart';
import '../cognito/cognito_client.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

const region = 'ap-northeast-1';
const iotApiUrl = 'https://iot.$region.amazonaws.com/target-policies';
const scheme = 'wss://';
const urlPath = '/mqtt';
const port = 443;

// aws
const policyName = 'Discovery20000';
const baseUrl = 'al6jwhaqk4xll-ats.iot.ap-northeast-1.amazonaws.com';
const clientId = 'iotconsole-c684e8c5-e665-4335-93e3-770b04d33f63';

class MQTTClientManager {
  MqttBrowserClient client = MqttBrowserClient('', '');
  Future<int> connect(CognitoAuthSession session) async {
    String accessKey = session.credentialsResult.value.accessKeyId;
    String secretKey = session.credentialsResult.value.secretAccessKey;
    String sessionToken =
        session.credentialsResult.value.sessionToken.toString();
    String identityId = session.identityIdResult.value;
    String signedUrl = await getWebSocketURL(
        accessKey: accessKey,
        secretKey: secretKey,
        sessionToken: sessionToken,
        region: region,
        scheme: scheme,
        endpoint: baseUrl,
        urlPath: urlPath);
    client = MqttBrowserClient.withPort(signedUrl, identityId, port);

    client.logging(on: true);
    client.keepAlivePeriod = 60;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
    client.pongCallback = pong;
    final MqttConnectMessage connMess =
        MqttConnectMessage().withClientIdentifier(identityId);
    client.connectionMessage = connMess;

    try {
      await attachPolicy(
          accessKey: accessKey,
          secretKey: secretKey,
          sessionToken: sessionToken,
          identityId: identityId,
          region: region,
          policyName: policyName,
          iotApiUrl: iotApiUrl);
      await client.connect();
    } on NoConnectionException catch (e) {
      print('MQTTClient::Client exception - $e');
      client.disconnect();
    } on Exception catch (e) {
      print('MQTTClient exception - $e');
      client.disconnect();
    }

    return 0;
  }

  void disconnect() {
    client.disconnect();
  }

  void subscribe(String topic) {
    client.subscribe(topic, MqttQos.atLeastOnce);
  }

  void unSubscribe(String topic) {
    client.unsubscribe(topic);
  }

  void onConnected() {
    print('MQTTClient::Connected');
  }

  void onDisconnected() {
    print('MQTTClient::Disconnected');
  }

  void onSubscribed(String topic) {
    print('MQTTClient::Subscribed to topic: $topic');
  }

  void pong() {
    print('MQTTClient::Ping response received');
  }

  void publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<int> publishUpdateScenarioMessage(
      String robotId, String mapId, List<String> scenarioId) async {
    final builder = MqttClientPayloadBuilder();
    var topic = "Cube/fromServer/$robotId/UpdateScenario";
    builder.addString(json.encode({
      "Map_ID": mapId,
      "Station_IDs": scenarioId,
    }));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    return 0;
  }

  Future<int> publishUpdateJobsMessage(
      String robotId, List<StationPath> stationPath) async {
    final builder = MqttClientPayloadBuilder();
    var topic = "Cube/fromServer/$robotId/UpdateJobs";
    print(json.encode(stationPath.map((e) => e.toJson()).toList()).toString());
    builder.addString(json.encode(stationPath));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    return 0;
  }

  Future<int> publishUpdateControlMessage(String robotId, String action) async {
    final builder = MqttClientPayloadBuilder();
    var topic = "Cube/fromServer/$robotId/event";

    builder.addString(json.encode(
        {"Robot_ID": robotId, "Robot_action": action, "Stage_action": "none"}));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    return 0;
  }

  Future<int> publishUpdateStartPose(
      String robotId, String action, String x, String y, String theta) async {
    final builder = MqttClientPayloadBuilder();
    var topic = "Cube/fromServer/$robotId/UpdateStartPose";

    builder.addString(json.encode({"x": x, "y": y, "theta": theta}));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    return 0;
  }

  Future<int> publishRestartMessage(String robotId) async {
    final builder = MqttClientPayloadBuilder();
    var topic = "Cube/fromServer/$robotId/Restart";

    builder.addString(json.encode({}));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    return 0;
  }

  Stream<List<MqttReceivedMessage<MqttMessage>>>? getMessagesStream() {
    return client.updates;
  }

  Future<void> updateControl(
      CognitoAuthSession session, String robotId, String action) async {
    final mqtt = MQTTClientManager();
    try {
      final identityId = session.identityIdResult.value;
      print("Current user's identity ID: $identityId");
      await mqtt.connect(session);
      await mqtt.publishUpdateControlMessage(robotId, action);
    } on AuthException catch (e) {
      print('Error retrieving auth session: ${e.message}');
    }
  }

  Future<void> restartControl(
      CognitoAuthSession session, String robotId) async {
    final mqtt = MQTTClientManager();
    try {
      final identityId = session.identityIdResult.value;
      print("Current user's identity ID: $identityId");
      await mqtt.connect(session);
      await mqtt.publishRestartMessage(robotId);
    } on AuthException catch (e) {
      print('Error retrieving auth session: ${e.message}');
    }
  }

  Future<int> publishUpdateStartPoseControlMessage(
      String robotId, double x, double y, double theta) async {
    final builder = MqttClientPayloadBuilder();
    var topic = "Cube/fromServer/$robotId/UpdateStartPose";

    builder.addString(json.encode({
      "x": x,
      "y": y,
      "theta": theta,
    }));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    return 0;
  }
}
