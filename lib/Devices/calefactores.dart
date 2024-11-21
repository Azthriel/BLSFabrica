import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:biocaldensmartlifefabrica/aws/dynamo/dynamo.dart';
import 'package:biocaldensmartlifefabrica/aws/dynamo/dynamo_certificates.dart';
import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

        if (int.tryParse(parts[1]) != null) {
          errorSintax = getWifiErrorSintax(int.parse(parts[1]));
        }
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
          length: accesoTotal || accesoLabo
              ? factoryMode
                  ? 5
                  : 4
              : accesoCS
                  ? 3
                  : 2,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, a) {
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
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                backgroundColor: const Color(0xFF522B5B),
                foregroundColor: const Color(0xfffbe4d8),
                title: Text(deviceName),
                bottom: TabBar(
                  labelColor: const Color(0xffdfb6b2),
                  unselectedLabelColor: const Color(0xff190019),
                  indicatorColor: const Color(0xffdfb6b2),
                  tabs: [
                    if (accesoTotal || accesoLabo) ...[
                      const Tab(icon: Icon(Icons.settings)),
                      const Tab(icon: Icon(Icons.star)),
                      const Tab(icon: Icon(Icons.thermostat)),
                      if (factoryMode) ...[
                        const Tab(icon: Icon(Icons.perm_identity))
                      ],
                      const Tab(icon: Icon(Icons.send)),
                    ] else if (accesoCS) ...[
                      const Tab(icon: Icon(Icons.thermostat)),
                      const Tab(icon: Icon(Icons.star)),
                      const Tab(icon: Icon(Icons.send)),
                    ] else ...[
                      const Tab(icon: Icon(Icons.thermostat)),
                      const Tab(icon: Icon(Icons.send)),
                    ]
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
                      wifiText(context);
                    },
                  ),
                ],
              ),
              body: TabBarView(
                children: [
                  if (accesoTotal || accesoLabo) ...[
                    const ToolsPage(),
                    const ParamsTab(),
                    const TempTab(),
                    if (factoryMode) ...[const CredsTab()],
                    const OtaTab(),
                  ] else if (accesoCS) ...[
                    const TempTab(),
                    const ParamsTab(),
                    const OtaTab(),
                  ] else ...[
                    const TempTab(),
                    const OtaTab(),
                  ]
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

  void sendDataToDevice() async {
    String dataToSend = textController.text;
    String data = '${command(deviceName)}[4]($dataToSend)';
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
              const SizedBox(height: 50),
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
                onPressed: () {
                  registerActivity(command(deviceName), textController.text,
                      'Se coloco el número de serie');
                  sendDataToDevice();
                },
                style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Text('Enviar'),
              ),
              const SizedBox(height: 20),
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
                      fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  registerActivity(command(deviceName), serialNumber,
                      'Se borró la NVS de este equipo...');
                  myDevice.toolsUuid
                      .write('${command(deviceName)}[0](1)'.codeUnits);
                },
                style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Text('Borrar NVS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//PARAMS TAB //Owner, secondary Admins and more

class ParamsTab extends StatefulWidget {
  const ParamsTab({super.key});
  @override
  State<ParamsTab> createState() => ParamsTabState();
}

class ParamsTabState extends State<ParamsTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text('Estado del control por\n distancia en el equipo:',
                  textAlign: TextAlign.center,
                  style: (TextStyle(
                      fontSize: 20.0,
                      color: Color(0xfffbe4d8),
                      fontWeight: FontWeight.bold))),
              Text.rich(
                TextSpan(
                  text: distanceControlActive ? 'Activado' : 'Desactivado',
                  style: (const TextStyle(
                      fontSize: 20.0,
                      color: Color(0xFFdfb6b2),
                      fontWeight: FontWeight.normal)),
                ),
              ),
              if (distanceControlActive) ...[
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  onPressed: () {
                    String mailData = '${command(deviceName)}[5](0)';
                    myDevice.toolsUuid.write(mailData.codeUnits);
                    registerActivity(command(deviceName), serialNumber,
                        'Se desactivo el control por distancia');
                    setState(() {
                      distanceControlActive = false;
                    });
                  },
                  child: const Text(
                    'Desacticar control por distancia',
                  ),
                ),
              ],
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Owner actual del equipo:',
                textAlign: TextAlign.center,
                style: (TextStyle(
                    fontSize: 20.0,
                    color: Color(0xfffbe4d8),
                    fontWeight: FontWeight.bold)),
              ),
              Text(
                owner == '' ? 'No hay owner registrado' : owner,
                textAlign: TextAlign.center,
                style: (const TextStyle(
                    fontSize: 20.0,
                    color: Color(0xFFdfb6b2),
                    fontWeight: FontWeight.bold)),
              ),
              if (owner != '') ...[
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  onPressed: () {
                    putOwner(service, command(deviceName), serialNumber, '');
                    registerActivity(command(deviceName), serialNumber,
                        'Se elimino el owner del equipo');
                    setState(() {
                      owner = '';
                    });
                  },
                  child: const Text(
                    'Eliminar Owner',
                  ),
                ),
              ],
              const SizedBox(
                height: 20,
              ),
              if (secondaryAdmins.isEmpty) ...[
                const Text(
                  'No hay administradores \nsecundarios para este equipo',
                  textAlign: TextAlign.center,
                  style: (TextStyle(
                      fontSize: 20.0,
                      color: Color(0xfffbe4d8),
                      fontWeight: FontWeight.bold)),
                )
              ] else ...[
                const Text(
                  'Administradores del equipo:',
                  textAlign: TextAlign.center,
                  style: (TextStyle(
                      fontSize: 20.0,
                      color: Color(0xfffbe4d8),
                      fontWeight: FontWeight.bold)),
                ),
                for (int i = 0; i < secondaryAdmins.length; i++) ...[
                  const Divider(),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () {
                              registerActivity(
                                  command(deviceName),
                                  serialNumber,
                                  'Se elimino el admin ${secondaryAdmins[i]} del equipo');
                              setState(() {
                                secondaryAdmins.remove(secondaryAdmins[i]);
                              });
                              putSecondaryAdmins(
                                  service,
                                  command(deviceName),
                                  extractSerialNumber(deviceName),
                                  secondaryAdmins);
                            },
                            icon: const Icon(Icons.delete, color: Colors.grey),
                          ),
                          Text(
                            secondaryAdmins[i],
                            style: (const TextStyle(
                                fontSize: 20.0,
                                color: Color(0xFFdfb6b2),
                                fontWeight: FontWeight.normal)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                ],
                const Divider(),
              ],
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Vencimiento beneficio\nAdministradores secundarios extra:',
                textAlign: TextAlign.center,
                style: (TextStyle(
                    fontSize: 20.0,
                    color: Color(0xfffbe4d8),
                    fontWeight: FontWeight.bold)),
              ),
              Text(
                secAdmDate,
                textAlign: TextAlign.center,
                style: (const TextStyle(
                    fontSize: 20.0,
                    color: Color(0xFFdfb6b2),
                    fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      final TextEditingController dateController =
                          TextEditingController();
                      return AlertDialog(
                        title: const Center(
                          child: Text(
                            'Especificar nueva fecha de vencimiento:',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 300,
                              child: TextField(
                                style: const TextStyle(color: Colors.black),
                                controller: dateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'aaaa/mm/dd',
                                  hintStyle: TextStyle(color: Colors.black),
                                ),
                                onChanged: (value) {
                                  if (value.length > 10) {
                                    dateController.text =
                                        value.substring(0, 10);
                                  } else if (value.length == 4) {
                                    dateController.text = '$value/';
                                  } else if (value.length == 7) {
                                    dateController.text = '$value/';
                                  }
                                },
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
                              registerActivity(
                                  command(deviceName),
                                  serialNumber,
                                  'Se modifico el vencimiento del beneficio "administradores secundarios extras"');
                              putDate(
                                  service,
                                  command(deviceName),
                                  extractSerialNumber(deviceName),
                                  dateController.text.trim(),
                                  false);
                              setState(() {
                                secAdmDate = dateController.text.trim();
                              });
                              navigatorKey.currentState!.pop();
                            },
                            child: const Text('Enviar fecha'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text(
                  'Modificar fecha',
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Vencimiento beneficio\nAlquiler temporario:',
                textAlign: TextAlign.center,
                style: (TextStyle(
                    fontSize: 20.0,
                    color: Color(0xfffbe4d8),
                    fontWeight: FontWeight.bold)),
              ),
              Text(
                atDate,
                textAlign: TextAlign.center,
                style: (const TextStyle(
                    fontSize: 20.0,
                    color: Color(0xFFdfb6b2),
                    fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      final TextEditingController dateController =
                          TextEditingController();
                      return AlertDialog(
                        title: const Center(
                          child: Text(
                            'Especificar nueva fecha de vencimiento:',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 300,
                              child: TextField(
                                style: const TextStyle(color: Colors.black),
                                controller: dateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'aaaa/mm/dd',
                                  hintStyle: TextStyle(color: Colors.black),
                                ),
                                onChanged: (value) {
                                  if (value.length > 10) {
                                    dateController.text =
                                        value.substring(0, 10);
                                  } else if (value.length == 4) {
                                    dateController.text = '$value/';
                                  } else if (value.length == 7) {
                                    dateController.text = '$value/';
                                  }
                                },
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
                              registerActivity(
                                  command(deviceName),
                                  serialNumber,
                                  'Se modifico el vencimiento del beneficio "alquiler temporario"');
                              putDate(
                                  service,
                                  command(deviceName),
                                  extractSerialNumber(deviceName),
                                  dateController.text.trim(),
                                  true);
                              setState(() {
                                atDate = dateController.text.trim();
                              });
                              navigatorKey.currentState!.pop();
                            },
                            child: const Text('Enviar fecha'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text(
                  'Modificar fecha',
                ),
              ),
              const SizedBox(
                height: 20,
              ),
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
  final TextEditingController distanceOnController =
      TextEditingController(text: distanceOn);
  final TextEditingController distanceOffController =
      TextEditingController(text: distanceOff);

  bool ignite = false;
  bool recording = false;
  List<List<dynamic>> recordedData = [];
  Timer? recordTimer;

  @override
  void initState() {
    super.initState();
    printLog('Valor temp: $tempValue');
    printLog('¿Encendido? $turnOn');
    subscribeTrueStatus();
  }

  void subscribeTrueStatus() async {
    printLog('Me subscribo a vars');
    await myDevice.varsUuid.setNotifyValue(true);

    final trueStatusSub =
        myDevice.varsUuid.onValueReceived.listen((List<int> status) {
      var parts = utf8.decode(status).split(':');
      // printLog(parts);
      setState(() {
        trueStatus = parts[0] == '1';
        actualTemp = parts[1];
      });
    });

    myDevice.device.cancelWhenDisconnected(trueStatusSub);
  }

  void sendTemperature(int temp) {
    String data = '${command(deviceName)}[7]($temp)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void turnDeviceOn(bool on) {
    int fun = on ? 1 : 0;
    String data = '${command(deviceName)}[11]($fun)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void sendRoomTemperature(String temp) {
    String data = '${command(deviceName)}[8]($temp)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void startTempMap() {
    String data = '${command(deviceName)}[12](0)';
    myDevice.toolsUuid.write(data.codeUnits);
  }

  void saveDataToCsv() async {
    List<List<dynamic>> rows = [
      [
        "Timestamp",
        "Temperatura",
      ]
    ];
    rows.addAll(recordedData);

    String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final pathOfTheFileToWrite = '${directory.path}/temp_data.csv';
    File file = File(pathOfTheFileToWrite);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: 'CSV TEMPERATURA');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: Center(
          child: SingleChildScrollView(
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
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Temperatura de corte: ',
                    style: TextStyle(
                      color: Color(0xfffbe4d8),
                      fontSize: 25,
                    ),
                  ),
                  TextSpan(
                    text: tempValue.round().toString(),
                    style: const TextStyle(
                      fontSize: 30,
                      color: Color(0xfffbe4d8),
                    ),
                  ),
                  const TextSpan(
                    text: '°C',
                    style: TextStyle(
                      fontSize: 30,
                      color: Color(0xfffbe4d8),
                    ),
                  ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                  trackHeight: 50.0,
                  thumbColor: const Color(0xfffbe4d8),
                  thumbShape: IconThumbSlider(
                      iconData: trueStatus
                          ? deviceType == '027000'
                              ? Icons.local_fire_department
                              : Icons.flash_on_rounded
                          : Icons.check,
                      thumbRadius: 25)),
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
            const SizedBox(height: 30),
            SizedBox(
                width: 300,
                child: !roomTempSended
                    ? TextField(
                        style: const TextStyle(color: Color(0xfffbe4d8)),
                        keyboardType: TextInputType.number,
                        controller: roomTempController,
                        decoration: const InputDecoration(
                          labelText: 'Introducir temperatura de la habitación',
                          labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                        ),
                        onSubmitted: (value) {
                          registerActivity(
                              command(deviceName),
                              extractSerialNumber(deviceName),
                              'Se cambio la temperatura ambiente de $actualTemp°C a $value°C');
                          sendRoomTemperature(value);
                          registerTemp(command(deviceName),
                              extractSerialNumber(deviceName));
                          showToast('Temperatura ambiente seteada');
                          setState(() {
                            roomTempSended = true;
                          });
                        },
                      )
                    : Text(
                        'La temperatura ambiente ya fue seteada\npor este legajo el dia \n$tempDate',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xfffbe4d8),
                          fontSize: 20,
                        ),
                      )),
            const SizedBox(height: 30),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Temperatura actual: ',
                    style: TextStyle(
                      color: Color(0xfffbe4d8),
                      fontSize: 20,
                    ),
                  ),
                  TextSpan(
                    text: actualTemp,
                    style: const TextStyle(
                      color: Color(0xFFdfb6b2),
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                  const TextSpan(
                    text: '°C ',
                    style: TextStyle(
                      color: Color(0xFFdfb6b2),
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IconButton(
              onPressed: () {
                setState(() {
                  recording = !recording;
                });
                if (!recording) {
                  recordTimer?.cancel();
                  saveDataToCsv();
                  recordedData.clear();
                } else {
                  recordTimer = Timer.periodic(
                    const Duration(seconds: 1),
                    (Timer t) {
                      if (recording) {
                        recordedData.add([DateTime.now(), actualTemp]);
                      }
                    },
                  );
                }
              },
              icon: recording
                  ? const Icon(
                      Icons.pause,
                      size: 35,
                      color: Color(0xffdfb6b2),
                    )
                  : const Icon(
                      Icons.play_arrow,
                      size: 35,
                      color: Color(0xffdfb6b2),
                    ),
            ),
            if (factoryMode) ...[
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Mapeo de temperatura:\n',
                      style: TextStyle(
                        color: Color(0xfffbe4d8),
                        fontSize: 20,
                      ),
                    ),
                    TextSpan(
                      text: tempMap ? 'REALIZADO' : 'NO REALIZADO',
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  registerActivity(
                      command(deviceName),
                      extractSerialNumber(deviceName),
                      'Se inicio el mapeo de temperatura en el equipo');
                  startTempMap();
                  showToast('Iniciando mapeo de temperatura');
                },
                style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Text('Iniciar mapeo temperatura'),
              ),
              const SizedBox(
                height: 10,
              ),
              ElevatedButton(
                  onPressed: () {
                    registerActivity(command(deviceName), serialNumber,
                        'Se mando el ciclado de la válvula de este equipo');
                    String data = '${command(deviceName)}[13](1000#5)';
                    myDevice.toolsUuid.write(data.codeUnits);
                  },
                  child: const Text('Ciclado fijo')),
              const SizedBox(
                height: 10,
              ),
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
                          ),
                        ),
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
                              registerActivity(
                                  command(deviceName),
                                  serialNumber,
                                  'Se mando el ciclado de la válvula de este equipo\nMilisegundos: ${timeController.text}\nIteraciones:$cicle');
                              String data =
                                  '${command(deviceName)}[13](${timeController.text}#$cicle)';
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
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                ),
                child: const Text('Configurar ciclado'),
              ),
              if (deviceType == '027000') ...[
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final TextEditingController timeController =
                            TextEditingController();
                        return AlertDialog(
                          title: const Center(
                            child: Text(
                              'Especificar parametros de la apertura temporizada:',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 300,
                                child: TextField(
                                  style: const TextStyle(color: Colors.black),
                                  controller: timeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Ingrese cantidad de milisegundos',
                                    labelStyle: TextStyle(color: Colors.black),
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
                                registerActivity(
                                    command(deviceName),
                                    serialNumber,
                                    'Se mando el temporizado de apertura');
                                String data =
                                    '${command(deviceName)}[14](${timeController.text.trim()})';
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
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                    ),
                  ),
                  child: const Text(
                    'Configurar Apertura\nTemporizada',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                GestureDetector(
                  onLongPressStart: (LongPressStartDetails a) async {
                    setState(() {
                      ignite = true;
                    });
                    while (ignite) {
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (!ignite) break;
                      String data = '027000_IOT[15](1)';
                      myDevice.toolsUuid.write(data.codeUnits);
                      printLog(data);
                    }
                  },
                  onLongPressEnd: (LongPressEndDetails a) {
                    setState(() {
                      ignite = false;
                    });
                    String data = '027000_IOT[15](0)';
                    myDevice.toolsUuid.write(data.codeUnits);
                    printLog(data);
                  },
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Chispero'),
                  ),
                ),
              ],
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Distancias de control: ',
                style: TextStyle(
                  color: Color(0xfffbe4d8),
                  fontSize: 20,
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  style: const TextStyle(
                    color: Color(0xFFdfb6b2),
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  controller: distanceOnController,
                  decoration: const InputDecoration(
                    labelText: 'Distancia de encendido:',
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    suffixText: 'Metros',
                    suffixStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                  onSubmitted: (value) {
                    if (int.parse(value) <= 5000 && int.parse(value) >= 3000) {
                      registerActivity(
                          command(deviceName),
                          extractSerialNumber(deviceName),
                          'Se modifico la distancia de encendido');
                      putDistanceOn(service, command(deviceName),
                          extractSerialNumber(deviceName), value);
                    } else {
                      showToast('Parametros no permitidos');
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
                  style: const TextStyle(
                    color: Color(0xFFdfb6b2),
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  controller: distanceOffController,
                  decoration: const InputDecoration(
                    labelText: 'Distancia de apagado:',
                    labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                    suffixText: 'Metros',
                    suffixStyle: TextStyle(color: Color(0xfffbe4d8)),
                  ),
                  onSubmitted: (value) {
                    if (int.parse(value) <= 300 && int.parse(value) >= 100) {
                      registerActivity(
                          command(deviceName),
                          extractSerialNumber(deviceName),
                          'Se modifico la distancia de apagado');
                      putDistanceOff(service, command(deviceName),
                          extractSerialNumber(deviceName), value);
                    } else {
                      showToast('Parametros no permitidos');
                    }
                  },
                ),
              ),
              const SizedBox(
                height: 30,
              ),
            ],
          ],
        ),
      )),
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
  bool sending = false;

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
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '¿Thing cargada? ',
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
                  decoration: InputDecoration(
                    label: const Text('Ingresa Amazon CA cert'),
                    labelStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    suffixIcon: IconButton(
                        onPressed: () {
                          amazonCAController.clear();
                        },
                        icon: const Icon(Icons.delete)),
                  ),
                  onChanged: (value) {
                    amazonCA = amazonCAController.text;
                    amazonCAController.text = 'Cargado';
                  },
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
                  decoration: InputDecoration(
                    label: const Text('Ingresa la private Key'),
                    labelStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    suffixIcon: IconButton(
                        onPressed: () {
                          privateKeyController.clear();
                        },
                        icon: const Icon(Icons.delete)),
                  ),
                  onChanged: (value) {
                    privateKey = privateKeyController.text;
                    privateKeyController.text = 'Cargado';
                  },
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
                  decoration: InputDecoration(
                    label: const Text('Ingresa device Cert'),
                    labelStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    suffixIcon: IconButton(
                        onPressed: () {
                          deviceCertController.clear();
                        },
                        icon: const Icon(Icons.delete)),
                  ),
                  onChanged: (value) {
                    deviceCert = deviceCertController.text;
                    deviceCertController.text = 'Cargado';
                  },
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              SizedBox(
                width: 300,
                child: sending
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          legajoConectado == '1860'
                              ? Image.asset('assets/Mecha.gif')
                              : Image.asset('assets/Vaca.webp'),
                          const LinearProgressIndicator(),
                        ],
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          printLog(amazonCA);
                          printLog(privateKey);
                          printLog(deviceCert);

                          if (amazonCA != null &&
                              privateKey != null &&
                              deviceCert != null) {
                            printLog('Estan todos anashe');
                            registerActivity(
                                command(deviceName),
                                extractSerialNumber(deviceName),
                                'Se asigno credenciales de AWS al equipo');
                            setState(() {
                              sending = true;
                            });
                            await writeLarge(amazonCA!, 0, deviceName);
                            await writeLarge(deviceCert!, 1, deviceName);
                            await writeLarge(privateKey!, 2, deviceName);
                            setState(() {
                              sending = false;
                            });
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

  void sendOTAWifi(bool factory) async {
    //0 work 1 factory
    String url = '';

    if (factory) {
      if (otaSVController.text.contains('_F')) {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/F/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
      } else {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/F/hv${hardwareVersion}sv${otaSVController.text.trim()}_F.bin';
      }
    } else {
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/W/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
    }

    printLog(url);
    try {
      String data = '${command(deviceName)}[2]($url)';
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
            showToast('HTTP CODE recibido: $valorEntreParentesis');
          }
        } else {
          switch (fun) {
            case 'OTA:START':
              showToast('Iniciando actualización');
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

  void sendOTABLE(bool factory) async {
    showToast("Enviando OTA...");

    String url = '';

    if (factory) {
      if (otaSVController.text.contains('_F')) {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
      } else {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}_F.bin';
      }
    } else {
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${command(deviceName)}/OTA_FW/W/hv${hardwareVersion}sv${otaSVController.text}.bin';
    }

    printLog(url);

    if (sizeWasSend == false) {
      try {
        String dir = (await getApplicationDocumentsDirectory()).path;
        File file = File('$dir/firmware.bin');

        if (await file.exists()) {
          await file.delete();
        }

        var req = await dio.get(url);
        var bytes = req.data.toString().codeUnits;

        await file.writeAsBytes(bytes);

        var firmware = await file.readAsBytes();
        firmwareGlobal = firmware;

        String data = '${command(deviceName)}[3](${bytes.length})';
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
              'El dispositio debe estar conectado a internet\npara poder realizar la OTA',
              textAlign: TextAlign.center,
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        registerActivity(
                            command(deviceName),
                            extractSerialNumber(deviceName),
                            'Se envio OTA Wifi a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                        sendOTAWifi(false);
                      },
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.build, size: 16),
                                SizedBox(width: 20),
                                Icon(Icons.wifi, size: 16),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Mandar OTA Work (WiFi)',
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        registerActivity(
                            command(deviceName),
                            extractSerialNumber(deviceName),
                            'Se envio OTA Wifi a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                        sendOTAWifi(true);
                      },
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                        ),
                      ),
                      child: const Center(
                        // Added to center elements
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.factory_outlined, size: 15),
                                  SizedBox(width: 20),
                                  Icon(Icons.wifi, size: 15),
                                ]),
                            SizedBox(height: 10),
                            Text(
                              'Mandar OTA fábrica (WiFi)',
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        registerActivity(
                            command(deviceName),
                            extractSerialNumber(deviceName),
                            'Se envio OTA ble a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                        sendOTABLE(false);
                      },
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                        ),
                      ),
                      child: const Center(
                        // Added to center elements
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.build, size: 16),
                                  SizedBox(width: 20),
                                  Icon(Icons.bluetooth, size: 16),
                                  SizedBox(height: 10),
                                ]),
                            SizedBox(height: 10),
                            Text(
                              'Mandar OTA Work (BLE)',
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        registerActivity(
                            command(deviceName),
                            extractSerialNumber(deviceName),
                            'Se envio OTA ble a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                        sendOTABLE(true);
                      },
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                        ),
                      ),
                      child: const Center(
                        // Added to center elements
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.factory_outlined, size: 15),
                                  SizedBox(width: 20),
                                  Icon(Icons.bluetooth, size: 15),
                                ]),
                            SizedBox(height: 10),
                            Text(
                              'Mandar OTA fábrica (BLE)',
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
          ],
        ),
      ),
    );
  }
}
