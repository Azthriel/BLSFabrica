import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

late bool turnOn;
late double tempValue;

late bool tempMap;

class CalefactoresTab extends StatefulWidget {
  const CalefactoresTab({super.key});
  @override
  CalefactoresTabState createState() => CalefactoresTabState();
}

class CalefactoresTabState extends State<CalefactoresTab> {
  @override
  initState() {
    super.initState();
    updateWifiValues(toolsValues);
    subscribeToWifiStatus();
    var partes = utf8.decode(varsValues).split(':');
    tempValue = double.parse(partes[0]);
    turnOn = partes[1] == '1';

    tempMap = partes[6] == '1';
  }

  void updateWifiValues(List<int> data) {
    var fun =
        utf8.decode(data); //Wifi status | wifi ssid | ble status | nickname
    fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    printLog(fun);
    var parts = fun.split(':');
    if (parts[0] == 'WCS_CONNECTED') {
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog('sis $isWifiConnected');
      setState(() {
        textState = 'CONECTADO';
        statusColor = Colors.green;
        wifiIcon = Icons.wifi;
      });
    } else if (parts[0] == 'WCS_DISCONNECTED') {
      isWifiConnected = false;
      printLog('non $isWifiConnected');

      setState(() {
        textState = 'DESCONECTADO';
        statusColor = Colors.red;
        wifiIcon = Icons.wifi_off;
      });

      if (parts[0] == 'WCS_DISCONNECTED' && atemp == true) {
        //If comes from subscription, parts[1] = reason of error.
        setState(() {
          wifiIcon = Icons.warning_amber_rounded;
        });

        if (parts[1] == '202' || parts[1] == '15') {
          errorMessage = 'Contraseña incorrecta';
        } else if (parts[1] == '201') {
          errorMessage = 'La red especificada no existe';
        } else if (parts[1] == '1') {
          errorMessage = 'Error desconocido';
        } else {
          errorMessage = parts[1];
        }

        errorSintax = getWifiErrorSintax(int.parse(parts[1]));
      }
    }

    setState(() {});
  }

  void subscribeToWifiStatus() async {
    printLog('Se subscribio a wifi');
    await myDevice.toolsUuid.setNotifyValue(true);

    final wifiSub =
        myDevice.toolsUuid.onValueReceived.listen((List<int> status) {
      updateWifiValues(status);
    });

    myDevice.device.cancelWhenDisconnected(wifiSub);
  }

  //!Visual
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          primaryColor: const Color(0xFF2B124C),
          primaryColorLight: const Color(0xFF522B5B),
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Color(0xFFdfb6b2),
            selectionHandleColor: Color(0xFFdfb6b2),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2B124C),
          ),
          useMaterial3: true,
        ),
        home: DefaultTabController(
          length: 4,
          child: PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return AlertDialog(
                    content: Row(
                      children: [
                        const CircularProgressIndicator(),
                        Container(
                            margin: const EdgeInsets.only(left: 15),
                            child: const Text("Desconectando...")),
                      ],
                    ),
                  );
                },
              );
              Future.delayed(const Duration(seconds: 2), () async {
                printLog('aca estoy');
                await myDevice.device.disconnect();
                navigatorKey.currentState?.pop();
                navigatorKey.currentState?.pushReplacementNamed('/menu');
              });

              return; // Retorna según la lógica de tu app
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFF522B5B),
                foregroundColor: const Color(0xfffbe4d8),
                title: Text(deviceName),
                bottom: const TabBar(
                  labelColor: Color(0xffdfb6b2),
                  unselectedLabelColor: Color(0xff190019),
                  indicatorColor: Color(0xffdfb6b2),
                  tabs: [
                    Tab(icon: Icon(Icons.settings)),
                    Tab(icon: Icon(Icons.thermostat)),
                    Tab(icon: Icon(Icons.perm_identity)),
                    Tab(icon: Icon(Icons.send)),
                  ],
                ),
                actions: <Widget>[
                  IconButton(
                    icon: Icon(
                      wifiIcon,
                      size: 24.0,
                      semanticLabel: 'Icono de wifi',
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Row(children: [
                              const Text.rich(TextSpan(
                                  text: 'Estado de conexión: ',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ))),
                              Text.rich(TextSpan(
                                  text: textState,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)))
                            ]),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text.rich(TextSpan(
                                      text: 'Error: $errorMessage',
                                      style: const TextStyle(
                                        fontSize: 10,
                                      ))),
                                  const SizedBox(height: 10),
                                  Text.rich(TextSpan(
                                      text: 'Sintax: $errorSintax',
                                      style: const TextStyle(
                                        fontSize: 10,
                                      ))),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    const Text.rich(TextSpan(
                                        text: 'Red actual: ',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold))),
                                    Text.rich(TextSpan(
                                        text: nameOfWifi,
                                        style: const TextStyle(fontSize: 20))),
                                  ]),
                                  const SizedBox(height: 10),
                                  const Text.rich(TextSpan(
                                      text: 'Ingrese los datos de WiFi',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold))),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code),
                                    iconSize: 50,
                                    onPressed: () async {
                                      PermissionStatus permissionStatusC =
                                          await Permission.camera.request();
                                      if (!permissionStatusC.isGranted) {
                                        await Permission.camera.request();
                                      }
                                      permissionStatusC =
                                          await Permission.camera.status;
                                      if (permissionStatusC.isGranted) {
                                        openQRScanner(
                                            navigatorKey.currentContext!);
                                      }
                                    },
                                  ),
                                  TextField(
                                    decoration: const InputDecoration(
                                        hintText: 'Nombre de la red'),
                                    onChanged: (value) {
                                      wifiName = value;
                                    },
                                  ),
                                  TextField(
                                    decoration: const InputDecoration(
                                        hintText: 'Contraseña'),
                                    obscureText: true,
                                    onChanged: (value) {
                                      wifiPassword = value;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Cancelar'),
                                onPressed: () {
                                  navigatorKey.currentState?.pop();
                                },
                              ),
                              TextButton(
                                child: const Text('Aceptar'),
                                onPressed: () {
                                  sendWifitoBle();
                                  navigatorKey.currentState?.pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              body: const TabBarView(
                children: [
                  ToolsPage(),
                  TempTab(),
                  CredsTab(),
                  OtaTab(),
                ],
              ),
            ),
          ),
        ));
  }
}

//TOOLS TAB // Serial number, versión number

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});
  @override
  ToolsPageState createState() => ToolsPageState();
}

class ToolsPageState extends State<ToolsPage> {
  TextEditingController textController = TextEditingController();
  var parts = utf8.decode(infoValues).split(':');
  late String serialNumber;

  @override
  void initState() {
    super.initState();
    serialNumber = parts[1]; // Serial number
  }

  void sendDataToDevice() async {
    String dataToSend = textController.text;
    String data = '${command(deviceType)}[4]($dataToSend)';
    try {
      await myDevice.toolsUuid.write(data.codeUnits);
    } catch (e) {
      printLog(e);
    }
  }

  //!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              const Text.rich(
                TextSpan(
                    text: 'Número de serie:',
                    style: (TextStyle(
                        fontSize: 20.0,
                        color: Color(0xFFdfb6b2),
                        fontWeight: FontWeight.bold))),
              ),
              Text.rich(
                TextSpan(
                    text: serialNumber,
                    style: (const TextStyle(
                        fontSize: 30.0,
                        color: Color(0xFF854f6c),
                        fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 100),
              SizedBox(
                  width: 300,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xfffbe4d8)),
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Introducir nuevo numero de serie',
                      labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    ),
                  )),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => sendDataToDevice(),
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Text('Enviar'),
              ),
              const SizedBox(height: 50),
              const Text.rich(
                TextSpan(
                    text: 'Version de software del modulo IOT:',
                    style: (TextStyle(
                        fontSize: 20.0,
                        color: Color(0xfffbe4d8),
                        fontWeight: FontWeight.bold))),
              ),
              Text.rich(
                TextSpan(
                    text: softwareVersion,
                    style: (const TextStyle(
                        fontSize: 20.0,
                        color: Color(0xFFdfb6b2),
                        fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 15),
              const Text.rich(
                TextSpan(
                    text: 'Version de hardware del modulo IOT:',
                    style: (TextStyle(
                        fontSize: 20.0,
                        color: Color(0xfffbe4d8),
                        fontWeight: FontWeight.bold))),
              ),
              Text.rich(
                TextSpan(
                    text: hardwareVersion,
                    style: (const TextStyle(
                        fontSize: 20.0,
                        color: Color(0xFFdfb6b2),
                        fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => myDevice.toolsUuid
                    .write('${command(deviceType)}[0](1)'.codeUnits),
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Text('Borrar NVS'),
              ),
              const SizedBox(
                height: 10,
              ),
              if (deviceType == '027000') ...[
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final TextEditingController cicleController =
                            TextEditingController();
                        final TextEditingController timeController =
                            TextEditingController();
                        return AlertDialog(
                          title: const Center(
                              child: Text(
                            'Especificar parametros del ciclador:',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          )),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 300,
                                child: TextField(
                                  style: const TextStyle(color: Colors.black),
                                  controller: cicleController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Ingrese cantidad de ciclos',
                                    hintText: 'Certificación: 1000',
                                    labelStyle: TextStyle(color: Colors.black),
                                    hintStyle: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              SizedBox(
                                width: 300,
                                child: TextField(
                                  style: const TextStyle(color: Colors.black),
                                  controller: timeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Ingrese duración de los ciclos',
                                    hintText: 'Recomendado: 1000',
                                    suffixText: '(mS)',
                                    suffixStyle: TextStyle(
                                      color: Colors.black,
                                    ),
                                    labelStyle: TextStyle(
                                      color: Colors.black,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                navigatorKey.currentState!.pop();
                              },
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                int cicle = int.parse(cicleController.text) * 2;
                                String data =
                                    '027000_IOT[13](${timeController.text}#$cicle)';
                                myDevice.toolsUuid.write(data.codeUnits);
                                navigatorKey.currentState!.pop();
                              },
                              child: const Text('Iniciar proceso'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                    ),
                  ),
                  child: const Text('Configurar ciclado'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

//CONTROL TAB // On Off y set temperatura

class TempTab extends StatefulWidget {
  const TempTab({super.key});
  @override
  TempTabState createState() => TempTabState();
}

class TempTabState extends State<TempTab> {
  final TextEditingController roomTempController = TextEditingController();

  @override
  void initState() {
    super.initState();
    printLog('Valor temp: $tempValue');
    printLog('¿Encendido? $turnOn');
    subscribeTrueStatus();
    updateChanges();
  }

  void updateChanges() async {}

  void subscribeTrueStatus() async {
    printLog('Me subscribo a vars');
    await myDevice.varsUuid.setNotifyValue(true);

    final trueStatusSub =
        myDevice.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      setState(() {
        if (parts[0] == '1') {
          trueStatus = true;
        } else {
          trueStatus = false;
        }
      });
    });

    myDevice.device.cancelWhenDisconnected(trueStatusSub);
  }

  void sendTemperature(int temp) {
    String data = '${command(deviceType)}[7]($temp)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void turnDeviceOn(bool on) {
    int fun = on ? 1 : 0;
    String data = '${command(deviceType)}[11]($fun)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void sendRoomTemperature(String temp) {
    String data = '${command(deviceType)}[8]($temp)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void startTempMap() {
    String data = '${command(deviceType)}[12](0)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                text: turnOn
                    ? trueStatus
                        ? 'Calentando'
                        : 'Encendido'
                    : 'Apagado',
                style: TextStyle(
                    color: turnOn
                        ? trueStatus
                            ? Colors.amber[600]
                            : Colors.green
                        : Colors.red,
                    fontSize: 30),
              ),
            ),
            const SizedBox(height: 30),
            Transform.scale(
              scale: 3.0,
              child: Switch(
                activeColor: const Color(0xfffbe4d8),
                activeTrackColor: const Color(0xff854f6c),
                inactiveThumbColor: const Color(0xff854f6c),
                inactiveTrackColor: const Color(0xfffbe4d8),
                value: turnOn,
                onChanged: (value) {
                  turnDeviceOn(value);
                  setState(() {
                    turnOn = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(TextSpan(
                    text: tempValue.round().toString(),
                    style: const TextStyle(
                        fontSize: 30, color: Color(0xfffbe4d8)))),
                const Text.rich(TextSpan(
                    text: '°C',
                    style: TextStyle(fontSize: 30, color: Color(0xfffbe4d8)))),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 50.0,
                thumbColor: const Color(0xfffbe4d8),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 0.0,
                ),
              ),
              child: Slider(
                value: tempValue,
                onChanged: (value) {
                  setState(() {
                    tempValue = value;
                  });
                },
                onChangeEnd: (value) {
                  printLog(value);
                  sendTemperature(value.round());
                },
                min: 10,
                max: 40,
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 300,
              child: TextField(
                style: const TextStyle(color: Color(0xfffbe4d8)),
                keyboardType: TextInputType.number,
                controller: roomTempController,
                decoration: const InputDecoration(
                  labelText: 'Introducir temperatura de la habitación',
                  labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                ),
                onSubmitted: (value) {
                  sendRoomTemperature(value);
                },
              ),
            ),
            const SizedBox(height: 30),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '¿Mapeo de temperatura realizado? ',
                    style: TextStyle(
                      color: Color(0xfffbe4d8),
                      fontSize: 20,
                    ),
                  ),
                  TextSpan(
                    text: tempMap ? 'SI' : 'NO',
                    style: TextStyle(
                      color: tempMap
                          ? const Color(0xff854f6c)
                          : const Color(0xffFF0000),
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                if (!tempMap) {
                  startTempMap();
                  showToast('Iniciando mapeo de temperatura');
                } else {
                  showToast('Mapeo de temperatura ya realizado');
                }
              },
              style: ButtonStyle(
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                ),
              ),
              child: const Text('Iniciar mapeo temperatura'),
            ),
          ],
        ),
      ),
    );
  }
}

//CREDENTIAL Tab //Add thing certificates

class CredsTab extends StatefulWidget {
  const CredsTab({super.key});
  @override
  CredsTabState createState() => CredsTabState();
}

class CredsTabState extends State<CredsTab> {
  TextEditingController amazonCAController = TextEditingController();
  TextEditingController privateKeyController = TextEditingController();
  TextEditingController deviceCertController = TextEditingController();
  String? amazonCA;
  String? privateKey;
  String? deviceCert;
  late bool awsInit;

  @override
  void initState() {
    super.initState();
    var parts = utf8.decode(varsValues).split(':');
    awsInit = parts[5] == '1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // const SizedBox(height: 30),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '¿El equipo tiene una Thing cargada? ',
                      style: TextStyle(
                        color: Color(0xfffbe4d8),
                        fontSize: 20,
                      ),
                    ),
                    TextSpan(
                      text: awsInit ? 'SI' : 'NO',
                      style: TextStyle(
                        color: awsInit
                            ? const Color(0xff854f6c)
                            : const Color(0xffFF0000),
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: amazonCAController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  decoration: const InputDecoration(
                    label: Text('Ingresa Amazon CA cert'),
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                  onChanged: (value) => amazonCA = amazonCAController.text,
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: privateKeyController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  decoration: const InputDecoration(
                    label: Text('Ingresa la private Key'),
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                  onChanged: (value) => privateKey = privateKeyController.text,
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: deviceCertController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  decoration: const InputDecoration(
                    label: Text('Ingresa device Cert'),
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                  onChanged: (value) => deviceCert = deviceCertController.text,
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () {
                    printLog(amazonCA);
                    printLog(privateKey);
                    printLog(deviceCert);

                    if (amazonCA != null &&
                        privateKey != null &&
                        deviceCert != null) {
                      printLog('Estan todos anashe');
                      writeLarge(amazonCA!, 0, deviceType);
                      writeLarge(deviceCert!, 1, deviceType);
                      writeLarge(privateKey!, 2, deviceType);
                    }
                  },
                  child: const Center(
                    child: Column(
                      children: [
                        SizedBox(height: 10),
                        Icon(
                          Icons.perm_identity,
                          size: 16,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Enviar certificados',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//OTA Tab // Update micro

class OtaTab extends StatefulWidget {
  const OtaTab({super.key});
  @override
  OtaTabState createState() => OtaTabState();
}

class OtaTabState extends State<OtaTab> {
  var dataReceive = [];
  var dataToShow = 0;
  var progressValue = 0.0;
  TextEditingController otaSVController = TextEditingController();
  late Uint8List firmwareGlobal;
  bool sizeWasSend = false;

  @override
  void initState() {
    super.initState();
    subToProgress();
  }

  void sendOTAWifi() async {
    String url =
        'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/W/hv${hardwareVersion}sv${otaSVController.text}.bin';
    printLog(url);
    try {
      String data = '${command(deviceType)}[2]($url)';
      await myDevice.toolsUuid.write(data.codeUnits);
      printLog('Si mandé ota');
    } catch (e, stackTrace) {
      printLog('Error al enviar la OTA $e $stackTrace');
      showToast('Error al enviar OTA');
    }
    showToast('Enviando OTA...');
  }

  void subToProgress() async {
    printLog('Entre aquis mismito');

    printLog('Hice cosas');
    await myDevice.otaUuid.setNotifyValue(true);
    printLog('Notif activated');

    final otaSub = myDevice.otaUuid.onValueReceived.listen((List<int> event) {
      try {
        var fun = utf8.decode(event);
        fun = fun.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
        printLog(fun);
        var parts = fun.split(':');
        if (parts[0] == 'OTAPR') {
          printLog('Se recibio');
          setState(() {
            progressValue = int.parse(parts[1]) / 100;
          });
          printLog('Progreso: ${parts[1]}');
        } else if (fun.contains('OTA:HTTP_CODE')) {
          RegExp exp = RegExp(r'\(([^)]+)\)');
          final Iterable<RegExpMatch> matches = exp.allMatches(fun);

          for (final RegExpMatch match in matches) {
            String valorEntreParentesis = match.group(1)!;
            printLog('HTTP CODE recibido: $valorEntreParentesis');
            if (valorEntreParentesis == '200') {
              showToast('Iniciando actualización');
            } else {
              showToast('HTTP CODE recibido: $valorEntreParentesis');
            }
          }
        } else {
          switch (fun) {
            case 'OTA:START':
              printLog('Header se recibio correctamente');
              break;
            case 'OTA:SUCCESS':
              printLog('Estreptococo');
              navigatorKey.currentState?.pushReplacementNamed('/menu');
              showToast("OTA completada exitosamente");
              break;
            case 'OTA:FAIL':
              showToast("Fallo al enviar OTA");
              break;
            case 'OTA:OVERSIZE':
              showToast("El archivo es mayor al espacio reservado");
              break;
            case 'OTA:WIFI_LOST':
              showToast("Se perdió la conexión wifi");
              break;
            case 'OTA:HTTP_LOST':
              showToast("Se perdió la conexión HTTP durante la actualización");
              break;
            case 'OTA:STREAM_LOST':
              showToast("Excepción de stream durante la actualización");
              break;
            case 'OTA:NO_WIFI':
              showToast("Dispositivo no conectado a una red Wifi");
              break;
            case 'OTA:HTTP_FAIL':
              showToast("No se pudo iniciar una peticion HTTP");
              break;
            case 'OTA:NO_ROLLBACK':
              showToast("Imposible realizar un rollback");
              break;
            default:
              break;
          }
        }
      } catch (e, stackTrace) {
        printLog('Error malevolo: $e $stackTrace');
        // handleManualError(e, stackTrace);
        // showToast('Error al actualizar progreso');
      }
    });
    myDevice.device.cancelWhenDisconnected(otaSub);
  }

  void sendOTABLE() async {
    showToast("Enviando OTA...");

    String url =
        'https://github.com/barberop/sime-domotica/raw/main/${command(deviceType)}/OTA_FW/W/hv${hardwareVersion}sv${otaSVController.text}.bin';

    printLog(url);

    if (sizeWasSend == false) {
      try {
        String dir = (await getApplicationDocumentsDirectory()).path;
        File file = File('$dir/firmware.bin');

        if (await file.exists()) {
          await file.delete();
        }

        var req = await http.get(Uri.parse(url));
        var bytes = req.body.codeUnits;

        await file.writeAsBytes(bytes);

        var firmware = await file.readAsBytes();
        firmwareGlobal = firmware;

        String data = '${command(deviceType)}[3](${bytes.length})';
        printLog(data);
        await myDevice.toolsUuid.write(data.codeUnits);
        sizeWasSend = true;

        sendchunk();
      } catch (e, stackTrace) {
        printLog('Error al enviar la OTA $e $stackTrace');
        // handleManualError(e, stackTrace);
        showToast("Error al enviar OTA");
      }
    }
  }

  void sendchunk() async {
    try {
      int mtuSize = 255;
      await writeChunk(firmwareGlobal, mtuSize);
    } catch (e, stackTrace) {
      printLog('El error es: $e $stackTrace');
      showToast('Error al enviar chunk');
      // handleManualError(e, stackTrace);
    }
  }

  Future<void> writeChunk(List<int> value, int mtu, {int timeout = 15}) async {
    int chunk = mtu - 3;
    for (int i = 0; i < value.length; i += chunk) {
      printLog('Mande chunk');
      List<int> subvalue = value.sublist(i, min(i + chunk, value.length));
      await myDevice.infoUuid.write(subvalue, withoutResponse: false);
    }
    printLog('Acabe');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xff190019),
      appBar: AppBar(
        title: const Align(
            alignment: Alignment.center,
            child: Text(
              'El dispositio debe estar conectado a internet\n                para poder realizar la OTA',
              style: TextStyle(fontSize: 18),
            )),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xfffbe4d8),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 40,
                  width: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xff854f6c),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                Text(
                  'Progreso descarga OTA: ${(progressValue * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xfffbe4d8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
                width: 300,
                child: TextField(
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  controller: otaSVController,
                  decoration: const InputDecoration(
                    labelText: 'Introducir última versión de Software',
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                )),
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              width: 300,
              child: ElevatedButton(
                onPressed: () => sendOTAWifi(),
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      Icon(
                        Icons.memory,
                        size: 16,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Actualizar equipo',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              width: 300,
              child: ElevatedButton(
                onPressed: () => sendOTABLE(),
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      Icon(
                        Icons.bluetooth,
                        size: 16,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Actualizar equipo (BLE)',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
