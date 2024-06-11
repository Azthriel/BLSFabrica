import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

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
              resizeToAvoidBottomInset: false,
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
                    Tab(icon: Icon(Icons.settings_accessibility)),
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
                      wifiText(context);
                    },
                  ),
                ],
              ),
              body: const TabBarView(
                children: [
                  InfoTab(),
                  SetTab(),
                  CredsTab(),
                  OtaTab(),
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
                onPressed: () {
                  registerActivity(command(deviceType), textController.text,
                      'Se coloco el número de serie');
                  sendDataToDevice();
                },
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
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  registerActivity(command(deviceType), serialNumber,
                      'Se borró la NVS de este equipo...');
                  myDevice.toolsUuid
                      .write('${command(deviceType)}[0](1)'.codeUnits);
                },
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
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
                                        '${command(deviceType)}[14]($index#${common[index]})';
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
                                        '${command(deviceType)}[14]($index#${common[index]})';
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
                                            '${command(deviceType)}[13]($index#${entrada ? '0' : '1'})';
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
              // Text.rich(
              //   TextSpan(
              //     children: [
              //       const TextSpan(
              //         text: '¿Thing cargada? ',
              //         style: TextStyle(
              //           color: Color(0xfffbe4d8),
              //           fontSize: 20,
              //         ),
              //       ),
              //       TextSpan(
              //         text: awsInit ? 'SI' : 'NO',
              //         style: TextStyle(
              //           color: awsInit
              //               ? const Color(0xff854f6c)
              //               : const Color(0xffFF0000),
              //           fontSize: 20,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              // const SizedBox(height: 30),
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
                    ? const LinearProgressIndicator()
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
                                command(deviceType),
                                extractSerialNumber(deviceName),
                                'Se asigno credenciales de AWS al equipo');
                            setState(() {
                              sending = true;
                            });

                            await writeLarge(amazonCA!, 0, deviceType);
                            await writeLarge(deviceCert!, 1, deviceType);
                            await writeLarge(privateKey!, 2, deviceType);

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
                      command(deviceType),
                      extractSerialNumber(deviceName),
                      'Se envio OTA Wifi a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                  sendOTAWifi();
                },
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
            const SizedBox(height: 40),
            SizedBox(
              height: 70,
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  registerActivity(
                      command(deviceType),
                      extractSerialNumber(deviceName),
                      'Se envio OTA ble a el equipo. Sv: ${otaSVController.text}. Hv $hardwareVersion');
                  sendOTABLE();
                },
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
