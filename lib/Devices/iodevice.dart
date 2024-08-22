import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:http/http.dart' as http;

List<String> tipo = [];
List<String> estado = [];
List<bool> alertIO = [];
List<String> common = [];

class IODevicesTab extends StatefulWidget {
  const IODevicesTab({super.key});
  @override
  IODevicesTabState createState() => IODevicesTabState();
}

class IODevicesTabState extends State<IODevicesTab> {
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
          length: accesoTotal || accesoLabo ? 5 : 2,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, a)  {
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
                      const Tab(icon: Icon(Icons.settings_accessibility)),
                      const Tab(icon: Icon(Icons.pending_actions_rounded)),
                      const Tab(icon: Icon(Icons.perm_identity)),
                      const Tab(icon: Icon(Icons.send)),
                    ] else ...[
                      const Tab(icon: Icon(Icons.settings_accessibility)),
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
                    const InfoTab(),
                    const SetTab(),
                    const BurneoTab(),
                    const CredsTab(),
                    const OtaTab(),
                  ] else ...[
                    const SetTab(),
                    const OtaTab(),
                  ]
                ],
              ),
            ),
          ),
        ));
  }
}

//INFO Tab //Change Serial Number, Soft and Hard version

class InfoTab extends StatefulWidget {
  const InfoTab({super.key});
  @override
  InfoTabState createState() => InfoTabState();
}

class InfoTabState extends State<InfoTab> {
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
              const SizedBox(height: 50),
              const Text.rich(
                TextSpan(
                    text: 'Código de producto:',
                    style: (TextStyle(
                        fontSize: 20.0,
                        color: Color(0xfffbe4d8),
                        fontWeight: FontWeight.bold))),
              ),
              Text.rich(
                TextSpan(
                    text: productCode,
                    style: (const TextStyle(
                        fontSize: 20.0,
                        color: Color(0xFFdfb6b2),
                        fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 15),
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
                      fontWeight: FontWeight.bold)),
                ),
              ),
              Text.rich(
                TextSpan(
                    text: hardwareVersion,
                    style: (const TextStyle(
                        fontSize: 20.0,
                        color: Color(0xFFdfb6b2),
                        fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 50),
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

//SET Tab //Set input and output and test

class SetTab extends StatefulWidget {
  const SetTab({super.key});
  @override
  SetTabState createState() => SetTabState();
}

class SetTabState extends State<SetTab> {
  @override
  void initState() {
    super.initState();
    subToIO();
    processValues(ioValues);
  }

  void processValues(List<int> values) {
    ioValues = values;
    var parts = utf8.decode(values).split('/');
    printLog(parts);
    tipo.clear();
    estado.clear();
    common.clear();
    alertIO.clear();

    for (int i = 0; i < parts.length; i++) {
      var equipo = parts[i].split(':');
      tipo.add(equipo[0] == '0' ? 'Salida' : 'Entrada');
      estado.add(equipo[1]);
      common.add(equipo[2]);
      alertIO.add(estado[i] != common[i]);

      printLog(
          'En la posición $i el modo es ${tipo[i]} y su estado es ${estado[i]}');
      printLog('Su posición es ${common[i]}');
      printLog('¿Esta en alerta?: ${alertIO[i]}');
    }

    setState(() {});
  }

  void subToIO() async {
    if (!alreadySubIO) {
      await myDevice.ioUuid.setNotifyValue(true);
      printLog('Subscrito a IO');
      alreadySubIO = true;
    }

    var ioSub = myDevice.ioUuid.onValueReceived.listen((event) {
      printLog('Cambio en IO');
      processValues(event);
    });

    myDevice.device.cancelWhenDisconnected(ioSub);
  }

  @override
  Widget build(BuildContext context) {
    var parts = utf8.decode(ioValues).split('/');
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: ListView.builder(
        itemCount: parts.length,
        itemBuilder: (context, int index) {
          bool entrada = tipo[index] == 'Entrada';
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 10,
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xff2b124c),
                  borderRadius: BorderRadius.circular(20),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xff854f6c), width: 5),
                    right: BorderSide(color: Color(0xff854f6c), width: 5),
                    left: BorderSide(color: Color(0xff854f6c), width: 5),
                    top: BorderSide(color: Color(0xff854f6c), width: 5),
                  ),
                ),
                width: width - 50,
                height: entrada ? 275 : 250,
                child: Column(
                  children: [
                    Text(
                      tipo[index],
                      style: const TextStyle(
                          color: Color(0xFFdfb6b2),
                          fontWeight: FontWeight.bold,
                          fontSize: 50),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    entrada
                        ? alertIO[index]
                            ? const Icon(
                                Icons.new_releases,
                                color: Color(0xffcb3234),
                                size: 50,
                              )
                            : const Icon(
                                Icons.new_releases,
                                color: Color(0xff9b9b9b),
                                size: 50,
                              )
                        : Switch(
                            activeColor: const Color(0xfffbe4d8),
                            activeTrackColor: const Color(0xff854f6c),
                            inactiveThumbColor: const Color(0xff854f6c),
                            inactiveTrackColor: const Color(0xfffbe4d8),
                            value: estado[index] == '1',
                            onChanged: (value) async {
                              String fun = '$index#${value ? '1' : '0'}';
                              await myDevice.ioUuid.write(fun.codeUnits);
                            },
                          ),
                    const SizedBox(
                      height: 10,
                    ),
                    entrada
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 30,
                              ),
                              const Text(
                                'Estado común:',
                                style: TextStyle(
                                    color: Color(0xfffbe4d8), fontSize: 15),
                              ),
                              const Spacer(),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: ChoiceChip(
                                  label: const Text('0'),
                                  selected: common[index] == '0',
                                  shape: const OvalBorder(),
                                  pressElevation: 5,
                                  showCheckmark: false,
                                  selectedColor: const Color(0xfffbe4d8),
                                  onSelected: (value) {
                                    common[index] = '0';
                                    String data =
                                        '${command(deviceName)}[14]($index#${common[index]})';
                                    printLog(data);
                                    myDevice.toolsUuid.write(data.codeUnits);
                                  },
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: ChoiceChip(
                                  label: const Text('1'),
                                  labelStyle:
                                      const TextStyle(color: Color(0xff854f6c)),
                                  selected: common[index] == '1',
                                  shape: const OvalBorder(),
                                  pressElevation: 5,
                                  showCheckmark: false,
                                  selectedColor: const Color(0xfffbe4d8),
                                  onSelected: (value) {
                                    common[index] = '1';
                                    String data =
                                        '${command(deviceName)}[14]($index#${common[index]})';
                                    printLog(data);
                                    myDevice.toolsUuid.write(data.codeUnits);
                                  },
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          )
                        : const SizedBox(
                            height: 10,
                          ),
                    const SizedBox(
                      height: 5,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 30,
                        ),
                        const Text(
                          '¿Cambiar de modo?',
                          style:
                              TextStyle(color: Color(0xfffbe4d8), fontSize: 15),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  content: Text(
                                    '¿Cambiar de ${tipo[index]} a ${entrada ? 'Salida' : 'Entrada'}?',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        String fun =
                                            '${command(deviceName)}[13]($index#${entrada ? '0' : '1'})';
                                        printLog(fun);
                                        myDevice.toolsUuid.write(fun.codeUnits);
                                        Navigator.of(dialogContext).pop();
                                      },
                                      child: const Text('Cambiar'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: const Icon(
                            Icons.change_circle_outlined,
                            color: Color(0xFFdfb6b2),
                            size: 30,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          );
        },
      ),
    );
  }
}

//BURNEO Tab //Control pin and voltage

class BurneoTab extends StatefulWidget {
  const BurneoTab({super.key});
  @override
  State<BurneoTab> createState() => BurneoTabState();
}

class BurneoTabState extends State<BurneoTab> {
  bool testingIN = false;
  bool testingOUT = false;
  List<bool> stateIN = List<bool>.filled(4, false, growable: false);
  List<bool> stateOUT = List<bool>.filled(4, false, growable: false);

  void mandarBurneo() async {
    printLog('mande a la google sheet');

    const String url =
        'https://script.google.com/macros/s/AKfycbyESEF-o_iBAotpLi7gszSfelJVLlJbrgSVSiMYWYaHfC8io5fJ2tlAKkGpH7iJYK3p0Q/exec';

    final response = await dio.get(url, queryParameters: {
      'productCode': command(deviceName),
      'serialNumber': extractSerialNumber(deviceName),
      'Legajo': legajoConectado,
      'in0': stateIN[0],
      'in1': stateIN[1],
      'in2': stateIN[2],
      'in3': stateIN[3],
      'out0': stateOUT[0],
      'out1': stateOUT[1],
      'out2': stateOUT[2],
      'out3': stateOUT[3],
      'date': DateTime.now().toIso8601String()
    });
    if (response.statusCode == 200) {
      printLog('Anashe');
    } else {
      printLog('!=200 ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xff190019),
        body: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: '¿Burneo realizado? ',
                        style: TextStyle(
                          color: Color(0xfffbe4d8),
                          fontSize: 20,
                        ),
                      ),
                      TextSpan(
                        text: burneoDone ? 'SI' : 'NO',
                        style: TextStyle(
                          color: burneoDone
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
                    registerActivity(
                        command(deviceName),
                        extractSerialNumber(deviceName),
                        'Se envio el testeo de entradas');
                    for (int index = 0; index < 4; index++) {
                      String fun = '${command(deviceName)}[13]($index#1)';
                      myDevice.toolsUuid.write(fun.codeUnits);
                    }
                    printLog('Ya se cambiaron todos los pines a entrada');
                    setState(() {
                      testingIN = true;
                    });
                  },
                  child: const Text('Probar entradas'),
                ),
                if (testingIN) ...[
                  const SizedBox(
                    height: 10,
                  ),
                  for (int i = 0; i < 4; i++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Funcionamiento Entrada$i: ',
                            style: const TextStyle(
                                fontSize: 15.0,
                                color: Color(0xfffbe4d8),
                                fontWeight: FontWeight.normal)),
                        Switch(
                          activeColor: const Color(0xfffbe4d8),
                          activeTrackColor: const Color(0xff854f6c),
                          inactiveThumbColor: const Color(0xff854f6c),
                          inactiveTrackColor: const Color(0xfffbe4d8),
                          trackOutlineColor:
                              const WidgetStatePropertyAll(Color(0xff854f6c)),
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Icon(Icons.check,
                                    color: Color(0xff854f6c));
                              } else {
                                return const Icon(Icons.close,
                                    color: Color(0xfffbe4d8));
                              }
                            },
                          ),
                          value: stateIN[i],
                          onChanged: (value) {
                            setState(() {
                              stateIN[i] = value;
                            });
                            printLog(stateIN);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  onPressed: () {
                    if (testingIN) {
                      registerActivity(
                          command(deviceName),
                          extractSerialNumber(deviceName),
                          'Se envio el testeo de salidas');
                      for (int index = 0; index < 4; index++) {
                        String fun = '${command(deviceName)}[13]($index#0)';
                        myDevice.toolsUuid.write(fun.codeUnits);
                      }
                      printLog('Ya se cambiaron todos los pines a salida');
                      String fun1 = '${command(deviceName)}[15](0)';
                      myDevice.toolsUuid.write(fun1.codeUnits);
                      setState(() {
                        testingOUT = true;
                      });
                    } else {
                      showToast('Primero probar entradas');
                    }
                  },
                  child: const Text('Probar salidas'),
                ),
                if (testingOUT) ...[
                  const SizedBox(
                    height: 10,
                  ),
                  for (int i = 0; i < 4; i++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Funcionamiento Salida$i: ',
                            style: const TextStyle(
                                fontSize: 15.0,
                                color: Color(0xfffbe4d8),
                                fontWeight: FontWeight.normal)),
                        Switch(
                          activeColor: const Color(0xfffbe4d8),
                          activeTrackColor: const Color(0xff854f6c),
                          inactiveThumbColor: const Color(0xff854f6c),
                          inactiveTrackColor: const Color(0xfffbe4d8),
                          trackOutlineColor:
                              const WidgetStatePropertyAll(Color(0xff854f6c)),
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                            (Set<WidgetState> states) {
                              // ignore: deprecated_member_use
                              if (states.contains(MaterialState.selected)) {
                                return const Icon(Icons.check,
                                    color: Color(0xff854f6c));
                              } else {
                                return const Icon(Icons.close,
                                    color: Color(0xfffbe4d8));
                              }
                            },
                          ),
                          value: stateIN[i],
                          onChanged: (value) {
                            setState(() {
                              stateOUT[i] = value;
                            });
                            printLog(stateOUT);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
                ElevatedButton(
                  onPressed: () {
                    if (testingIN && testingOUT) {
                      registerActivity(
                          command(deviceName),
                          extractSerialNumber(deviceName),
                          'Se envio el burneo');
                      printLog('Se envío burneo');
                      mandarBurneo();
                      String fun2 = '${command(deviceName)}[15](1)';
                      myDevice.toolsUuid.write(fun2.codeUnits);
                    } else {
                      showToast('Primero probar entradas y salidas');
                    }
                  },
                  child: const Text('Enviar burneo'),
                ),
              ],
            ),
          ),
        ));
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
                          Image.asset('assets/Vaca.webp'),
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

  void sendOTAWifi() async {
    String url = '';
    if (otaSVController.text.contains('_F')) {
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
    } else {
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}_F.bin';
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
    if (!alreadySubOta) {
      await myDevice.otaUuid.setNotifyValue(true);
      alreadySubOta = true;
    }
    final otaSub = myDevice.otaUuid.onValueReceived.listen((event) {
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

    String url = '';
    if (otaSVController.text.contains('_F')) {
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
    } else {
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}_F.bin';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            const SizedBox(height: 40),
            SizedBox(
              height: 70,
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  registerActivity(
                      command(deviceName),
                      extractSerialNumber(deviceName),
                      'Se envio OTA Wifi a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                  sendOTAWifi();
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
            const SizedBox(height: 40),
            SizedBox(
              height: 70,
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  registerActivity(
                      command(deviceName),
                      extractSerialNumber(deviceName),
                      'Se envio OTA ble a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                  sendOTABLE();
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
