import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => MenuPageState();
}

class MenuPageState extends State<MenuPage> {

  @override
  void initState(){
    super.initState();
    startBluetoothMonitoring();
  }

  //!Visual
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B124C),
        ),
        useMaterial3: true,
      ),
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: const Color(0xff190019),
          appBar: AppBar(
            backgroundColor: const Color(0xFF522B5B),
            foregroundColor: const Color(0xfffbe4d8),
            title: const Text('BSL Fábrica'),
            bottom: const TabBar(
              labelColor: Color(0xffdfb6b2),
              unselectedLabelColor: Color(0xff190019),
              indicatorColor: Color(0xffdfb6b2),
              tabs: [
                Tab(
                  icon: Icon(Icons.bluetooth_searching),
                ),
                Tab(
                  icon: Icon(Icons.assignment),
                ),
                Tab(
                  icon: Icon(Icons.thermostat),
                ),
                Tab(icon: Icon(Icons.send)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              ScanTab(),
              ControlTab(),
              RegbankTab(),
              Ota2Tab(),
            ],
          ),
        ),
      ),
    );
  }
}

//SCAN TAB //Scan and connection tab

class ScanTab extends StatefulWidget {
  const ScanTab({super.key});
  @override
  ScanTabState createState() => ScanTabState();
}

class ScanTabState extends State<ScanTab> {
  List<BluetoothDevice> devices = [];
  List<BluetoothDevice> filteredDevices = [];
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();
  late EasyRefreshController _controller;
  final FocusNode searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    filteredDevices = devices;
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
    );
    scan();
  }

  void scan() async {
    if (bluetoothOn) {
      printLog('Entre a escanear');
      try {
        await FlutterBluePlus.startScan(
            withKeywords: [
              'Eléctrico',
              'Gas',
              'Detector',
              'Radiador',
              'Módulo',
              'RB'
            ],
            timeout: const Duration(seconds: 30),
            androidUsesFineLocation: true,
            continuousUpdates: false);
        FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult result in results) {
            if (!devices
                .any((device) => device.remoteId == result.device.remoteId)) {
              setState(() {
                devices.add(result.device);
                devices
                    .sort((a, b) => a.platformName.compareTo(b.platformName));
                filteredDevices = devices;
              });
            }
          }
        });
      } catch (e, stackTrace) {
        printLog('Error al escanear $e $stackTrace');
        showToast('Error al escanear, intentelo nuevamente');
        // handleManualError(e, stackTrace);
      }
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 6));
      deviceName = device.platformName;
      myDeviceid = device.remoteId.toString();

      printLog('Teoricamente estoy conectado');

      MyDevice myDevice = MyDevice();

      device.connectionState.listen((BluetoothConnectionState state) {
        printLog('Estado de conexión: $state');
        switch (state) {
          case BluetoothConnectionState.disconnected:
            {
              showToast('Dispositivo desconectado');
              calibrationValues.clear();
              regulationValues.clear();
              toolsValues.clear();
              nameOfWifi = '';
              connectionFlag = false;
              alreadySubCal = false;
              alreadySubReg = false;
              alreadySubOta = false;
              alreadySubDebug = false;
              alreadySubWork = false;
              alreadySubIO = false;
              printLog(
                  'Razon: ${myDevice.device.disconnectReason?.description}');
              navigatorKey.currentState?.pushReplacementNamed('/menu');
              break;
            }
          case BluetoothConnectionState.connected:
            {
              if (!connectionFlag) {
                connectionFlag = true;
                FlutterBluePlus.stopScan();
                myDevice.setup(device).then((valor) {
                  printLog('RETORNASHE $valor');
                  if (valor) {
                    navigatorKey.currentState?.pushReplacementNamed('/loading');
                  } else {
                    connectionFlag = false;
                    printLog('Fallo en el setup');
                    showToast('Error en el dispositivo, intente nuevamente');
                    myDevice.device.disconnect();
                  }
                });
              } else {
                printLog('Las chistosadas se apoderan del mundo');
              }
              break;
            }
          default:
            break;
        }
      });
    } catch (e, stackTrace) {
      if (e is FlutterBluePlusException && e.code == 133) {
        printLog('Error específico de Android con código 133: $e');
        showToast('Error de conexión, intentelo nuevamente');
      } else {
        printLog('Error al conectar: $e $stackTrace');
        showToast('Error al conectar, intentelo nuevamente');
        // handleManualError(e, stackTrace);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

//! Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xfffbe4d8),
          title: TextField(
            focusNode: searchFocusNode,
            controller: searchController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xfffbe4d8)),
            decoration: const InputDecoration(
              icon: Icon(Icons.search),
              iconColor: Color(0xfffbe4d8),
              hintText: "Buscar dispositivo",
              hintStyle: TextStyle(color: Color(0xfffbe4d8)),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                filteredDevices = devices
                    .where((device) => device.platformName
                        .toLowerCase()
                        .contains(value.toLowerCase()))
                    .toList();
              });
            },
          )),
      body: EasyRefresh(
        controller: _controller,
        header: const ClassicHeader(
          dragText: 'Desliza para reescanear',
          armedText:
              'Suelta para reescanear\nO desliza para arriba para cancelar',
          readyText: 'Reescaneando dispositivos',
          processingText: 'Reescaneando dispositivos',
          processedText: 'Reescaneo completo',
          showMessage: false,
          textStyle: TextStyle(color: Color(0xffdfb6b2)),
          iconTheme: IconThemeData(color: Color(0xffdfb6b2)),
        ),
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 2));
          await FlutterBluePlus.stopScan();
          setState(() {
            devices.clear();
            filteredDevices.clear();
          });
          scan();
          _controller.finishRefresh();
        },
        child: ListView.builder(
          itemCount: filteredDevices.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(
                filteredDevices[index].platformName,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffdfb6b2)),
              ),
              subtitle: Text(
                '${filteredDevices[index].remoteId}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xfffbe4d8),
                ),
              ),
              onTap: () {
                connectToDevice(filteredDevices[index]);
                showToast('Intentando conectarse al dispositivo...');
              },
            );
          },
        ),
      ),
    );
  }
}

//REGISTER TAB //Register the devices in the spreadsheet

class ControlTab extends StatefulWidget {
  const ControlTab({super.key});
  @override
  ControlTabState createState() => ControlTabState();
}

class ControlTabState extends State<ControlTab> {
  final TextEditingController snController = TextEditingController();
  final TextEditingController comController = TextEditingController();
  String serialNumber = '';
  bool stateSell = false;
  bool isRegister = false;

  void updateGoogleSheet() async {
    printLog('mande alguito');

    setState(() {
      isRegister = true;
    });

    String status = stateSell ? 'Si' : 'No';
    const String url =
        'https://script.google.com/macros/s/AKfycbw3QKsCGNn5kMxE-5y7ilnI9DGOwp8W02J169CbZG44SnOqCpTsPZGJzx-rp6sFQz7J/exec';
    final Uri uri = Uri.parse(url).replace(queryParameters: {
      'serialNumber': serialNumber,
      'status': status,
      'legajo': legajoConectado,
      'comment': comController.text,
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      printLog('Si llego');
      comController.clear();
      isRegister = false;
      setState(() {});
    } else {
      printLog('Unu');
    }
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            SizedBox(
                width: 300,
                child: TextField(
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  controller: snController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ingrese el número de serie',
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                  onChanged: (value) {
                    serialNumber = value;
                  },
                )),
            const SizedBox(height: 20),
            Text(
              '¿Listo para la venta? ${stateSell ? "SI" : "NO"}',
              style: const TextStyle(color: Color(0xfffbe4d8)),
            ),
            const SizedBox(height: 20),
            Switch(
                activeColor: const Color(0xfffbe4d8),
                activeTrackColor: const Color(0xff854f6c),
                inactiveThumbColor: const Color(0xff854f6c),
                inactiveTrackColor: const Color(0xfffbe4d8),
                value: stateSell,
                onChanged: (value) {
                  setState(() {
                    stateSell = value;
                  });
                }),
            const SizedBox(height: 20),
            SizedBox(
                width: 300,
                child: TextField(
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  controller: comController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Ingrese un comentario (opcional)',
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                )),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => updateGoogleSheet(),
                child: const Text('Subir')),
            const SizedBox(height: 10),
            if (isRegister) ...{
              const CircularProgressIndicator(),
            }
          ],
        ),
      ),
    );
  }
}

//REGBANK TAB //Regbank associates

class RegbankTab extends StatefulWidget {
  const RegbankTab({super.key});

  @override
  RegbankTabState createState() => RegbankTabState();
}

class RegbankTabState extends State<RegbankTab> {
  final TextEditingController loginController = TextEditingController();
  bool login = false;
  List<String> numbers = [];
  int step = 0;
  String header = '';
  String initialvalue = '';
  String finalvalue = '';
  final FocusNode registerFocusNode = FocusNode();
  final TextEditingController numbersController = TextEditingController();
  bool hearing = false;
  Stopwatch? stopwatch;
  Timer? timer;
  double _rp = 1.0;
  String temp = '';

  //// ---------------------------------------------------------------------------------- ////

  List<Map<String, List<int>>> mapasDatos = [];
  Map<String, List<int>> streamData = {};
  Map<String, List<int>> diagnosis = {};
  Map<String, List<int>> regDone = {};
  Map<String, List<int>> espUpdate = {};
  Map<String, List<int>> picUpdate = {};
  Map<String, List<int>> regPoint1 = {};
  Map<String, List<int>> regPoint2 = {};
  Map<String, List<int>> regPoint3 = {};
  Map<String, List<int>> regPoint4 = {};
  Map<String, List<int>> regPoint5 = {};
  Map<String, List<int>> regPoint6 = {};
  Map<String, List<int>> regPoint7 = {};
  Map<String, List<int>> regPoint8 = {};
  Map<String, List<int>> regPoint9 = {};
  Map<String, List<int>> regPoint10 = {};

  //// ---------------------------------------------------------------------------------- ////

  @override
  void initState() {
    super.initState();
    setupMqtt5773();
    var formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    printLog(formatter.format(DateTime.now()));
  }

//!Locuritas.

  void testFirestore() async {
    String url =
        'https://script.google.com/macros/s/AKfycbwwIHRUsVgeXTZ33-4lMOz8wYln95jgM4wPcnXmYDvKrFeLz-bH-tHgIPeGc2T-eREGlQ/exec';
    final Uri uri = Uri.parse(url).replace(
        queryParameters: {'deviceName': 'Detector23111633', 'alert': 'true'});
    var response = await http.post(uri);

    if (response.statusCode == 200) {
      printLog('Datos enviados correctamente');
    } else {
      printLog('Error al enviar datos: ${response.body}');
    }
  }

//!Locuritas

  String textData(int i) {
    switch (i) {
      case 0:
        return 'Stream Data';
      case 1:
        return 'Diagnosis';
      case 2:
        return 'Regulation Done';
      case 3:
        return 'Esp Update';
      case 4:
        return 'Pic Update';
      case 5:
        return 'Regulation Point 1';
      case 6:
        return 'Regulation Point 2';
      case 7:
        return 'Regulation Point 3';
      case 8:
        return 'Regulation Point 4';
      case 9:
        return 'Regulation Point 5';
      case 10:
        return 'Regulation Point 6';
      case 11:
        return 'Regulation Point 7';
      case 12:
        return 'Regulation Point 8';
      case 13:
        return 'Regulation Point 9';
      case 14:
        return 'Regulation Point 10';
      default:
        return '';
    }
  }

  Future<void> exportDataAndShare(List<Map<String, List<int>>> lista) async {
    final fileName = 'Data_${DateTime.now().toIso8601String()}.txt';
    final directory = await getExternalStorageDirectory();
    if (directory != null) {
      final file = File('${directory.path}/$fileName');
      final buffer = StringBuffer();
      for (int i = 0; i < lista.length; i++) {
        buffer.writeln('----------${textData(i)}----------');
        buffer.writeln(
            "N.Serie /-/ TimeStamp /-/ PPMCH4 /-/ PPMCO /-/ RSCH4 /-/ RSCO /-/ AD Gasout Estable /-/ AD Gasout Estable CO /-/ Temperatura /-/ AD Temp Estable /-/ VCC /-/ AD VCC Estable /-/ AD PWM Estable");
        lista[i].forEach((key, value) {
          var parts = key.split('/-/');
          int ppmch4 = value[0] + (value[1] << 8);
          int ppmco = value[2] + (value[3] << 8);
          int rsch4 = value[4] + (value[5] << 8);
          int rsco = value[6] + (value[7] << 8);
          int adgsEs = value[8] + (value[9] << 8);
          int adgsEsCO = value[10] + (value[11] << 8);
          int temp = value[12];
          int adTempEs = value[13] + (value[14] << 8);
          int vcc = value[15] + (value[16] << 8);
          int advccEst = value[17] + (value[18] << 8);
          int adpwmEst = value[19] + (value[20] << 8);
          buffer.writeln(
              "${parts[0]} /-/ ${parts[1]} /-/ $ppmch4 /-/ $ppmco /-/ $rsch4 /-/ $rsco /-/ $adgsEs /-/ $adgsEsCO /-/ $temp /-/ $adTempEs /-/ $vcc /-/ $advccEst /-/ $adpwmEst ");
        });
      }
      await file.writeAsString(buffer.toString());
      shareFile(file.path);
    } else {
      printLog('Failed to get external storage directory');
    }
  }

  void shareFile(String filePath) {
    Share.shareFiles([filePath]);
  }

  Future<void> exportDataToGoogleSheet(
      List<Map<String, List<int>>> lista) async {
    // Preparar los datos para Google Sheets
    List<List<String>> groupedBody = [];
    List<String> headers = [
      "N.Serie",
      "TimeStamp",
      "PPMCH4",
      "PPMCO",
      "RSCH4",
      "RSCO",
      "AD Gasout Estable",
      "AD Gasout Estable CO",
      "Temperatura",
      "AD Temp Estable",
      "VCC",
      "AD VCC Estable",
      "AD PWM Estable"
    ];

    for (int i = 0; i < lista.length; i++) {
      lista[i].forEach((key, value) {
        var parts = key.split('/-/');
        int ppmch4 = value[0] + (value[1] << 8);
        int ppmco = value[2] + (value[3] << 8);
        int rsch4 = value[4] + (value[5] << 8);
        int rsco = value[6] + (value[7] << 8);
        int adgsEs = value[8] + (value[9] << 8);
        int adgsEsCO = value[10] + (value[11] << 8);
        int temp = value[12];
        int adTempEs = value[13] + (value[14] << 8);
        int vcc = value[15] + (value[16] << 8);
        int advccEst = value[17] + (value[18] << 8);
        int adpwmEst = value[19] + (value[20] << 8);

        List<String> row = [
          parts[0],
          parts[1],
          ppmch4.toString(),
          ppmco.toString(),
          rsch4.toString(),
          rsco.toString(),
          adgsEs.toString(),
          adgsEsCO.toString(),
          temp.toString(),
          adTempEs.toString(),
          vcc.toString(),
          advccEst.toString(),
          adpwmEst.toString(),
        ];
        groupedBody.add(row);
      });

      printLog('¿Hay cosas? ${groupedBody.isNotEmpty}');
      // Ordenar por número de serie y luego por timestamp
      groupedBody.sort((a, b) {
        int serieCompare = a[0].compareTo(b[0]);
        if (serieCompare == 0) {
          // Si los números de serie son iguales, compara por timestamp
          return a[1]
              .compareTo(b[1]); // Suponiendo que parts[1] es el timestamp
        }
        return serieCompare;
      });

      // Aplanar la lista de listas para enviarla como una única lista
      List<String> flatBody = [];
      for (var group in groupedBody) {
        flatBody.addAll(group);
      }

      String title = textData(i);

      await sendToGoogleSheets(title, headers, flatBody).then((value) {
        if (!value) {
          sendToGoogleSheets(title, headers, flatBody);
        } else {
          flatBody.clear();
          groupedBody.clear();
        }
      });
    }
  }

  Future<bool> sendToGoogleSheets(
      String title, List<String> cabecera, List<String> body) async {
    printLog('Hay ${body.length} datos');
    var url =
        'https://script.google.com/macros/s/AKfycbx8sz7I8Tn6lKbG7QgsRgTyOi4ayGND5LSHtZl4JLG2OIFvsgTgyza2HIB1kVh_gXmj3Q/exec';

    // Construyendo el cuerpo de la solicitud
    var requestBody = jsonEncode({
      'title': title,
      'headers': cabecera,
      'body': body,
    });

    // Configurando los headers de la solicitud para enviar JSON
    var headers = {
      'Content-Type': 'application/json',
    };

    final Uri uri = Uri.parse(url);
    var response = await http.post(uri, headers: headers, body: requestBody);

    if (response.statusCode == 200) {
      printLog('Datos enviados correctamente');
      return true;
    } else {
      printLog('Error al enviar datos: ${response.bodyBytes.toString()}');
      return false;
    }
  }

  Future<void> wipeSheet() async {
    var url =
        'https://script.google.com/macros/s/AKfycbx8sz7I8Tn6lKbG7QgsRgTyOi4ayGND5LSHtZl4JLG2OIFvsgTgyza2HIB1kVh_gXmj3Q/exec';

    final Uri uri = Uri.parse(url);
    var response = await http.get(uri);

    if (response.statusCode == 200) {
      printLog('Wipe realizado correctamente');
    } else {
      printLog('Error al enviar datos: ${response.body}');
    }
  }

  void startTimer() {
    stopwatch = Stopwatch()..start();
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {});
    });
  }

  String elapsedTime() {
    final time = stopwatch!.elapsed;
    return '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void setupMqtt5773() async {
    try {
      printLog('Haciendo setup');
      String deviceId = 'FlutterApp/${generateRandomNumbers(32)}';
      String hostname = 'Cristian.local';

      mqttClient5773 = MqttServerClient.withPort(hostname, deviceId, 1883);

      mqttClient5773!.logging(on: true);
      mqttClient5773!.onDisconnected = mqttonDisconnected;

      // Configuración de las credenciales
      mqttClient5773!.setProtocolV311();
      mqttClient5773!.keepAlivePeriod = 3;
      await mqttClient5773!.connect();
      printLog('Usuario conectado a mqtt');
      setState(() {});
    } catch (e, s) {
      printLog('Error setup mqtt $e $s');
    }
  }

  void mqttonDisconnected() {
    printLog('Desconectado de mqtt');
    setupMqtt5773();
  }

  void sendMessagemqtt(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);

    mqttClient5773!
        .publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }

  void subToTopicMQTT(String topic) {
    mqttClient5773!.subscribe(topic, MqttQos.atLeastOnce);
  }

  void unSubToTopicMQTT(String topic) {
    mqttClient5773!.unsubscribe(topic);
  }

  void listenToTopics() {
    mqttClient5773!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String topic = c[0].topic;
      var serialNumerito = topic.split('/');
      final List<int> message = recMess.payload.message;
      var formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

      switch (message[0]) {
        case 0xF5: //Stream data
          streamData.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          // printLog(streamData);
          break;
        case 0xA1: //Diagnosis
          diagnosis.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xA2: //Reg Done
          regDone.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0XA3: //Esp Update
          espUpdate.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xA4: //Pic Update
          picUpdate.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB0: //RegPoint 1
          regPoint1.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB1: //RegPoint 2
          regPoint2.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB2: //RegPoint 3
          regPoint3.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB3: //RegPoint 4
          regPoint4.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB4: //RegPoint 5
          regPoint5.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB5: //RegPoint 6
          regPoint6.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB6: //RegPoint 7
          regPoint7.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB7: //RegPoint 8
          regPoint8.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB8: //RegPoint 9
          regPoint9.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
        case 0xB9: //RegPoint 10
          regPoint10.addAll({
            '${serialNumerito[1]}/-/${formatter.format(DateTime.now())}':
                message.sublist(1)
          });
          break;
      }

      printLog('Received message: ${message.toString()} from topic: $topic');
    });
  }

  List<String> generateSerialNumbers(
      String header, int initialValue, int finalValue) {
    printLog('Header: $header');
    printLog('Initial: $initialValue');
    printLog('Final: $finalValue');
    List<String> serialNumbers = [];
    for (int i = initialValue; i <= finalValue; i++) {
      if (i < 10) {
        serialNumbers.add("${header}0$i");
      } else {
        serialNumbers.add("$header$i");
      }
    }
    printLog('$serialNumbers');
    return serialNumbers;
  }

  String textToShow(int data) {
    switch (data) {
      case 0:
        return 'Agrega la cabecera del número de serie';
      case 1:
        return 'Desde...';
      case 2:
        return 'Hasta...';
      default:
        return "Error Desconocido";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: login
          ? SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 50,
                  ),
                  if (!hearing) ...[
                    Text(
                      textToShow(step),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFdfb6b2)),
                    ),
                    Center(
                      child: SizedBox(
                        width: 300,
                        child: TextField(
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xfffbe4d8)),
                          decoration: InputDecoration(
                              suffixIcon: IconButton(
                            onPressed: () {
                              showDialog(
                                context: navigatorKey.currentContext!,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Center(
                                        child: Text(
                                      'Borrar lista de números',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold),
                                    )),
                                    content: const Text(
                                        'Esta acción no puede revertirse'),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            setState(() {
                                              numbers.clear();
                                            });
                                            navigatorKey.currentState!.pop();
                                          },
                                          child: const Text('Borrar'))
                                    ],
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.delete_forever),
                          )),
                          focusNode: registerFocusNode,
                          controller: numbersController,
                          keyboardType: TextInputType.number,
                          onSubmitted: (value) {
                            if (step == 0) {
                              header = value;
                              step = step + 1;
                              numbersController.clear();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                registerFocusNode.requestFocus();
                              });
                            } else if (step == 1) {
                              initialvalue = value;
                              numbersController.clear();
                              step = step + 1;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                registerFocusNode.requestFocus();
                              });
                            } else if (step == 2) {
                              finalvalue = value;
                              numbers.addAll(generateSerialNumbers(
                                  header,
                                  int.parse(initialvalue),
                                  int.parse(finalvalue)));
                              printLog('Lista: $numbers');
                              numbersController.clear();
                              step = 0;
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                  ],
                  numbers.isNotEmpty &&
                          mqttClient5773!.connectionStatus!.state ==
                              MqttConnectionState.connected
                      ? ElevatedButton(
                          onPressed: () {
                            if (!hearing) {
                              try {
                                for (int i = 0; i < numbers.length; i++) {
                                  String topic = '015773_IOT/${numbers[i]}';
                                  subToTopicMQTT(topic);
                                }
                              } catch (e, s) {
                                printLog('Error al sub $e $s');
                              }
                              listenToTopics();
                              startTimer();
                              hearing = true;
                            } else {
                              try {
                                for (int i = 0; i < numbers.length; i++) {
                                  String topic = '015773_IOT/${numbers[i]}';
                                  unSubToTopicMQTT(topic);
                                }
                              } catch (e, s) {
                                printLog('Error al unsub $e $s');
                              }
                              hearing = false;
                              stopwatch!.stop();
                              timer!.cancel();

                              //Crear Sheet aca
                              mapasDatos.addAll([
                                streamData,
                                diagnosis,
                                regDone,
                                espUpdate,
                                picUpdate,
                                regPoint1,
                                regPoint2,
                                regPoint3,
                                regPoint4,
                                regPoint5,
                                regPoint6,
                                regPoint7,
                                regPoint8,
                                regPoint9,
                                regPoint10
                              ]);

                              try {
                                exportDataToGoogleSheet(mapasDatos);
                                exportDataAndShare(mapasDatos);
                              } catch (e, s) {
                                printLog('Lol $e $s');
                              }
                              setState(() {});
                            }
                          },
                          child: hearing
                              ? const Text(
                                  'Cancelar la escucha',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFFdfb6b2)),
                                )
                              : const Text(
                                  'Iniciar la escucha',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFFdfb6b2)),
                                ),
                        )
                      : Container(),
                  const SizedBox(
                    height: 30,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: navigatorKey.currentContext!,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Center(
                                child: Text(
                              'Borrar datos de la hoja de calculos',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                            )),
                            content: const Text(
                                'Esta acción no puede revertirse\nTodos los datos que había en la hoja de calculo se perderán.'),
                            actions: [
                              TextButton(
                                  onPressed: () {
                                    setState(() {
                                      wipeSheet();
                                    });
                                    navigatorKey.currentState!.pop();
                                  },
                                  child: const Text('Borrar'))
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Borrar datos de la hoja de calculo'),
                  ),
                  if (hearing) ...[
                    const SizedBox(
                      height: 30,
                    ),
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                            const Color(0xFF522B5B)),
                        foregroundColor: MaterialStateProperty.all<Color>(
                            const Color(0xFFdfb6b2)),
                      ),
                      onPressed: () {
                        sendMessagemqtt('015773_RB', 'DIAGNOSIS_OK');
                      },
                      child: const Text('Hacer Diagnosis OK'),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        String url =
                            'https://github.com/CrisDores/57_IOT_PUBLIC/raw/main/57_ota_factory_fw/firmware.bin';
                        sendMessagemqtt('015773_RB', 'ESP_UPDATE($url)');
                      },
                      child: const Text('OTA ESP'),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        String url =
                            'https://github.com/CrisDores/57_IOT_PUBLIC/raw/main/57_ota_factory_fw/firmware.bin';
                        sendMessagemqtt('015773_RB', 'PIC_UPDATE($url)');
                      },
                      child: const Text('OTA PIC'),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    Text(
                      'RP ${_rp.round()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFdfb6b2), fontSize: 30),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                          disabledActiveTrackColor: const Color(0xff2b124c),
                          disabledInactiveTrackColor: const Color(0xFF522b5b),
                          trackHeight: 20,
                          thumbShape: SliderComponentShape.noThumb),
                      child: Slider(
                        value: _rp,
                        divisions: 11,
                        min: 0,
                        max: 11,
                        onChanged: (value) {
                          if (0 < value && value < 11) {
                            setState(() {
                              _rp = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xfffbe4d8)),
                        decoration: const InputDecoration(
                            labelText: 'Temperatura (°C)',
                            labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                            hintText: 'Añadir temperatura',
                            hintStyle: TextStyle(
                                color: Color(0xfffbe4d8),
                                fontWeight: FontWeight.normal)),
                        onChanged: (value) {
                          temp = value;
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        sendMessagemqtt('015773_RB', 'REGPOINT_${_rp}_($temp)');
                      },
                      child: const Text('Enviar RegPoint'),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    Text(
                      'Tiempo transcurrido: ${elapsedTime()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xfffbe4d8)),
                    ),
                  ],
                ],
              ),
            )
          : Center(
              child: Column(
                children: [
                  const SizedBox(
                    height: 200,
                  ),
                  SizedBox(
                      width: 300,
                      child: TextField(
                        style: const TextStyle(color: Color(0xfffbe4d8)),
                        controller: loginController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ingresa la contraseña',
                          labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                          hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                        ),
                        onSubmitted: (value) {
                          if (loginController.text == '05112004') {
                            setState(() {
                              login = true;
                            });
                          } else {
                            showToast('Contraseña equivocada');
                          }
                        },
                      )),
                ],
              ),
            ),
    );
  }
}

//OTA TAB //Ota global

class Ota2Tab extends StatefulWidget {
  const Ota2Tab({super.key});

  @override
  Ota2TabState createState() => Ota2TabState();
}

class Ota2TabState extends State<Ota2Tab> {
  final TextEditingController verSoftController = TextEditingController();
  final TextEditingController verHardController = TextEditingController();
  final TextEditingController loginController = TextEditingController();
  bool login = false;
  bool versionSoftAdded = false;
  bool versionHardAdded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: Center(
        child: login
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                        width: 300,
                        child: TextField(
                          style: const TextStyle(color: Color(0xfffbe4d8)),
                          controller: verSoftController,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Ingrese la versión de software',
                            labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                            hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                          ),
                          onSubmitted: (value) {
                            versionSoftAdded = true;
                          },
                        )),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: 300,
                        child: TextField(
                          style: const TextStyle(color: Color(0xfffbe4d8)),
                          controller: verHardController,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Ingrese la versión de hardware',
                            labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                            hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                          ),
                          onSubmitted: (value) {
                            versionHardAdded = true;
                          },
                        )),
                    const SizedBox(
                      height: 30,
                    ),
                    ElevatedButton(
                        onPressed: () {
                          if (versionSoftAdded && versionHardAdded) {
                            showToast(
                                'Esta parte no esta implementada todavia');
                            versionSoftAdded = false;
                            versionHardAdded = false;
                            verHardController.clear();
                            verSoftController.clear();
                          } else {
                            showToast(
                                'Debes agregar las versiones\nAntes de enviar la OTA');
                          }
                        },
                        child: const Text('Hacer OTA global'))
                  ],
                ),
              )
            : Center(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 200,
                    ),
                    SizedBox(
                        width: 300,
                        child: TextField(
                          style: const TextStyle(color: Color(0xfffbe4d8)),
                          controller: loginController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ingresa la contraseña',
                            labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                            hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                          ),
                          onSubmitted: (value) {
                            if (loginController.text == '05112004') {
                              setState(() {
                                login = true;
                              });
                            } else {
                              showToast('Contraseña equivocada');
                            }
                          },
                        )),
                  ],
                ),
              ),
      ),
    );
  }
}

//*------------------------------------------SECONDARY SCREENS------------------------------------------*\\

//LOADING PAGE //Loading and precharge

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});
  @override
  LoadState createState() => LoadState();
}

class LoadState extends State<LoadingPage> {
  MyDevice myDevice = MyDevice();

  @override
  void initState() {
    super.initState();
    printLog('HOSTIAAAAAAAAAAAAAAAAAAAAAAAA');
    precharge().then((precharge) {
      if (precharge == true) {
        showToast('Dispositivo conectado exitosamente');
        if (deviceType == '022000' ||
            deviceType == '027000' ||
            deviceType == '041220') {
          navigatorKey.currentState?.pushReplacementNamed('/calefactor');
        } else if (deviceType == '015773') {
          navigatorKey.currentState?.pushReplacementNamed('/detector');
        }else if(deviceType == '020010'){
          navigatorKey.currentState?.pushReplacementNamed('/io');
        }
      } else {
        showToast('Error en el dispositivo, intente nuevamente');
        myDevice.device.disconnect();
      }
    });
  }

  Future<bool> precharge() async {
    try {
      printLog('Estoy precargando');
      await myDevice.device.requestMtu(255);
      toolsValues = await myDevice.toolsUuid.read();
      printLog('Valores tools: $toolsValues');
      printLog('Valores info: $infoValues');
      //Si es un calefactor
      if (deviceType == '022000' ||
          deviceType == '027000' ||
          deviceType == '041220') {
        varsValues = await myDevice.varsUuid.read();
        var parts2 = utf8.decode(varsValues).split(':');
        printLog('$parts2');
        turnOn = parts2[1] == '1';
        trueStatus = parts2[3] == '1';
        nightMode = parts2[4] == '1';
        printLog('Estado: $turnOn');
      } else if (deviceType == '015773') {
        //Si soy un detector

        if (factoryMode) {
          calibrationValues = await myDevice.calibrationUuid.read();
          regulationValues = await myDevice.regulationUuid.read();
          debugValues = await myDevice.debugUuid.read();
        }
        workValues = await myDevice.workUuid.read();
        printLog('Valores calibracion: $calibrationValues');
        printLog('Valores regulacion: $regulationValues');
        printLog('Valores debug: $debugValues');
        printLog('Valores trabajo: $workValues');
        printLog('Valores work: $workValues');
      }else if(deviceType == '020010'){
        ioValues = await myDevice.ioUuid.read();
        printLog('Valores IO: $ioValues');
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      printLog('Error en la precarga $e $stackTrace');
      showToast('Error en la precarga');
      // handleManualError(e, stackTrace);
      return Future.value(false);
    }
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: Center(
          child: Stack(
        children: <Widget>[
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xfffbe4d8),
              ),
              SizedBox(height: 20),
              Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Cargando...',
                    style: TextStyle(color: Color(0xfffbe4d8)),
                  )),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Versión $appVersionNumber',
                    style:
                        const TextStyle(color: Color(0xFFdfb6b2), fontSize: 12),
                  )),
              const SizedBox(height: 20),
            ],
          ),
        ],
      )),
    );
  }
}
