import 'dart:convert';
import 'dart:io';
import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:biocaldensmartlifefabrica/mqtt/mqtt_certificates.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:provider/provider.dart';

MqttServerClient? mqttAWSFlutterClient;

Future<bool> setupMqtt() async {
  try {
    printLog('Haciendo setup');
    String deviceId = 'FlutterFabrica/${generateRandomNumbers(32)}';
    String broker = 'a3fm8tbrbcxfbf-ats.iot.sa-east-1.amazonaws.com';

    mqttAWSFlutterClient = MqttServerClient(broker, deviceId);

    mqttAWSFlutterClient!.secure = true;
    mqttAWSFlutterClient!.port = 8883; // Puerto estándar para MQTT sobre TLS
    mqttAWSFlutterClient!.securityContext = SecurityContext.defaultContext;

    mqttAWSFlutterClient!.securityContext
        .setTrustedCertificatesBytes(utf8.encode(caCert));
    mqttAWSFlutterClient!.securityContext
        .useCertificateChainBytes(utf8.encode(certChain));
    mqttAWSFlutterClient!.securityContext
        .usePrivateKeyBytes(utf8.encode(privateKey));

    mqttAWSFlutterClient!.logging(on: true);
    mqttAWSFlutterClient!.onDisconnected = mqttonDisconnected;

    // Configuración de las credenciales
    mqttAWSFlutterClient!.setProtocolV311();
    mqttAWSFlutterClient!.keepAlivePeriod = 3;
    try {
      await mqttAWSFlutterClient!.connect();
      printLog('Usuario conectado a mqtt');

      return true;
    } catch (e) {
      printLog('Error intentando conectar: $e');

      return false;
    }
  } catch (e, s) {
    printLog('Error setup mqtt $e $s');
    return false;
  }
}

void mqttonDisconnected() {
  printLog('Desconectado de mqtt');
  reconnectMqtt();
}

void reconnectMqtt() async {
  await setupMqtt().then((value) {
    if (value) {
      listenToTopics();
    } else {
      reconnectMqtt();
    }
  });
}

void sendMessagemqtt(String topic, String message) {
  printLog('Voy a mandar $message');
  printLog('A el topic $topic');
  final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
  builder.addString(message);

  printLog('${builder.payload} : ${utf8.decode(builder.payload!)}');

  try {
    mqttAWSFlutterClient!
        .publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    printLog('Mensaje enviado');
  } catch (e, s) {
    printLog('Error sending message $e $s');
  }
}

void subToTopicMQTT(String topic) {
  try {
    mqttAWSFlutterClient!.subscribe(topic, MqttQos.atLeastOnce);
    printLog('Subscrito correctamente a $topic');
  } catch (e) {
    printLog('Error al subscribir al topic $topic, $e');
  }
}

void unSubToTopicMQTT(String topic) {
  mqttAWSFlutterClient!.unsubscribe(topic);
  printLog('Me desuscribo de $topic');
}

void listenToTopics() {
  mqttAWSFlutterClient!.updates!.listen((c) {
    printLog('LLego algo(mqtt)');
    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String topic = c[0].topic;
    var listNames = topic.split('/');
    final List<int> message = recMess.payload.message;
    String keyName = "${listNames[1]}/${listNames[2]}";
    printLog('Keyname: $keyName');

    final String messageString = utf8.decode(message);
    printLog('Mensaje: $messageString');
    try {
      final Map<String, dynamic> messageMap = json.decode(messageString);

      if (messageMap['esp_res'] != null) {
        if (messageMap['esp_res'].toString().contains(':')) {
          List<String> parts = messageMap['esp_res'].toString().split(':');
          deviceResponseMqtt =
              'SoftVer: ${parts[2]}\nHardVer: ${parts[3]}';
        } else {
          deviceResponseMqtt = messageMap['esp_res'].toString();
        }
      }else{
        deviceResponseMqtt = 'No hubo respuesta';
      }

      GlobalDataNotifier notifier = Provider.of<GlobalDataNotifier>(
          navigatorKey.currentContext!,
          listen: false);
      notifier.updateData(deviceResponseMqtt);

      printLog('Received message: $messageMap from topic: $topic');
    } catch (e) {
      printLog('Error decoding message: $e');
    }
  });
}
