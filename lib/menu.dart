import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:biocaldensmartlifefabrica/aws/dynamo/dynamo.dart';
import 'package:biocaldensmartlifefabrica/aws/dynamo/dynamo_certificates.dart';
import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:biocaldensmartlifefabrica/aws/mqtt/mqtt.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:intl/intl.dart';
// import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => MenuPageState();
}

class MenuPageState extends State<MenuPage> {
  @override
  void initState() {
    super.initState();
    startBluetoothMonitoring();
    startLocationMonitoring();
    setupMqtt();
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
        length: 5,
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
                  icon: Icon(Icons.webhook_outlined),
                ),
                Tab(
                  icon: Icon(Icons.thermostat_auto),
                ),
                Tab(icon: Icon(Icons.send)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              ScanTab(),
              ControlTab(),
              ToolsAWS(),
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
              'Roll',
              'Patito',
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
            keyboardType: TextInputType.text,
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
  final TextEditingController pcController = TextEditingController();
  String serialNumber = '';
  String productCode = '';
  bool stateSell = false;
  bool isRegister = false;

  void updateGoogleSheet() async {
    printLog('mande alguito');

    setState(() {
      isRegister = true;
    });

    String status = stateSell ? 'Si' : 'No';
    const String url =
        'https://script.google.com/macros/s/AKfycbyJw-peLVNGfSwb9vi9YWTbYysBR4oc2_Bz8cReB1oMOLrRrE4kK9lIb0hhRzriAHWs/exec';

    final response = await dio.get(url, queryParameters: {
      'productCode': productCode,
      'serialNumber': serialNumber,
      'status': status,
      'legajo': legajoConectado,
      'comment': comController.text,
    });
    if (response.statusCode == 200) {
      printLog('Si llego');
      comController.clear();
      isRegister = false;
      showToast('Equipo cargado');
      snController.clear();
      pcController.clear();
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
      appBar: AppBar(
        title: const Align(
            alignment: Alignment.center,
            child: Text(
              'Registro de productos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            )),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xfffbe4d8),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              SizedBox(
                  width: 300,
                  child: TextField(
                    style: const TextStyle(color: Color(0xfffbe4d8)),
                    controller: pcController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ingrese el código de producto',
                      labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                      hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                    ),
                    onChanged: (value) {
                      productCode = '${value}_IOT';
                    },
                  )),
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
              isRegister
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        String accion =
                            'Se marco el equipo como ${stateSell ? 'listo para la venta' : 'no listo para la venta'}';
                        registerActivity(productCode, serialNumber, accion);
                        updateGoogleSheet();
                      },
                      child: const Text('Subir')),
            ],
          ),
        ),
      ),
    );
  }
}

//TOOLSAWS TAB//Technical Service (AWS Commands tools)

class ToolsAWS extends StatefulWidget {
  const ToolsAWS({super.key});

  @override
  ToolsAWSState createState() => ToolsAWSState();
}

class ToolsAWSState extends State<ToolsAWS> {
  final TextEditingController serialNumberController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  String productCode = '';
  String commandText = '';
  int key = 0;
  List<String> content = [];
  bool tools = false;
  bool config = false;

  String hintAWS(String cmd) {
    switch (cmd) {
      case '0':
        return '1 borrar NVS, 0 Conservar';
      case '2':
        return 'HardVer#SoftVer';
      case '4':
        return 'Nuevo SN';
      case '5':
        return '0 desactivar CPD';
      case '6':
        if (key == 0) {
          return 'Amazon CA';
        } else if (key == 1) {
          return 'Device Cert.';
        } else {
          return 'Private Key';
        }
      case '':
        return 'Aún no se agrega comando';
      default:
        return 'Este comando no existe...';
    }
  }

  TextInputType contentType(String cmd) {
    switch (cmd) {
      case '0':
        return TextInputType.number;
      case '2':
        return TextInputType.text;
      case '4':
        return TextInputType.number;
      case '5':
        return TextInputType.text;
      case '6':
        return TextInputType.multiline;
      case '':
        return TextInputType.none;
      default:
        return TextInputType.none;
    }
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
                'Customer service\nComandos a distancia',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              )),
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xfffbe4d8),
        ),
        body: Consumer<GlobalDataNotifier>(
          builder: (context, notifier, child) {
            String textToShow = notifier.getData();
            printLog(textToShow);

            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 335,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Ingrese el código de producto',
                          labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                          hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                          // fillColor: Color(0xfffbe4d8),
                        ),
                        dropdownColor: const Color(0xff190019),
                        items: <String>[
                          '022000_IOT',
                          '027000_IOT',
                          '020010_IOT',
                          '041220_IOT',
                          '015773_IOT'
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: const TextStyle(
                                  color: Color(0xfffbe4d8),
                                )),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            productCode = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 335,
                      child: TextField(
                        style: const TextStyle(color: Color(0xfffbe4d8)),
                        controller: serialNumberController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Ingrese el número de serie',
                          labelStyle: const TextStyle(color: Color(0xfffbe4d8)),
                          hintStyle: const TextStyle(color: Color(0xfffbe4d8)),
                          suffixIcon: IconButton(
                            onPressed: () {
                              String topic =
                                  'tools/$productCode/${serialNumberController.text.trim()}';
                              unSubToTopicMQTT(topic);
                              setState(() {
                                serialNumberController.clear();
                                notifier.updateData(
                                    'Esperando respuesta del esp...');
                              });
                              // printLog(
                              //     "',:v : ${serialNumberController.text.trim()}");
                            },
                            icon: const Icon(
                              Icons.delete_forever,
                              color: Color(0xfffbe4d8),
                            ),
                          ),
                        ),
                        onSubmitted: (value) {
                          setState(() {
                            queryItems(service, productCode,
                                serialNumberController.text.trim());
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () {
                          String topic =
                              'tools/$productCode/${serialNumberController.text.trim()}';
                          subToTopicMQTT(topic);
                          listenToTopics();
                          final data = {"alive": true};
                          String msg = jsonEncode(data);
                          registerActivity(
                              productCode,
                              serialNumberController.text.trim(),
                              'Se envio via mqtt: $msg');
                          sendMessagemqtt(topic, msg);
                        },
                        child: const Text('Verificar conexión equipo')),
                    const SizedBox(
                      height: 10,
                    ),
                    if (!tools && !config) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  config = true;
                                });
                              },
                              child: const Text('Parametros')),
                          ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  tools = true;
                                });
                              },
                              child: const Text('Comandos')),
                        ],
                      ),
                    ],
                    if (config) ...[
                      if (productCode != '' &&
                          serialNumberController.text != '') ...[
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
                              putOwner(service, productCode, serialNumber, '');
                              registerActivity(
                                  productCode,
                                  serialNumberController.text.trim(),
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
                                            productCode,
                                            serialNumberController.text.trim(),
                                            'Se elimino el admin ${secondaryAdmins[i]} del equipo');
                                        setState(() {
                                          secondaryAdmins
                                              .remove(secondaryAdmins[i]);
                                        });
                                        putSecondaryAdmins(
                                            service,
                                            productCode,
                                            serialNumberController.text.trim(),
                                            secondaryAdmins);
                                      },
                                      icon: const Icon(Icons.delete,
                                          color: Colors.grey),
                                    ),
                                    const SizedBox(
                                      width: 5,
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
                            )
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
                                          style: const TextStyle(
                                              color: Colors.black),
                                          controller: dateController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText: 'aaaa/mm/dd',
                                            hintStyle:
                                                TextStyle(color: Colors.black),
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
                                            productCode,
                                            serialNumber,
                                            'Se modifico el vencimiento del beneficio "administradores secundarios extras"');
                                        putDate(
                                            service,
                                            productCode,
                                            serialNumberController.text.trim(),
                                            dateController.text.trim(),
                                            false);
                                        setState(() {
                                          secAdmDate =
                                              dateController.text.trim();
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
                                          style: const TextStyle(
                                              color: Colors.black),
                                          controller: dateController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText: 'aaaa/mm/dd',
                                            hintStyle:
                                                TextStyle(color: Colors.black),
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
                                            productCode,
                                            serialNumber,
                                            'Se modifico el vencimiento del beneficio "alquiler temporario"');
                                        putDate(
                                            service,
                                            productCode,
                                            serialNumberController.text.trim(),
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
                      ] else ...[
                        const CircularProgressIndicator(),
                        const SizedBox(
                          height: 10,
                        ),
                        const Text(
                          'Esperando a que se\n seleccione un equipo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Color(0xfffbe4d8),
                          ),
                        )
                      ]
                    ],
                    if (tools) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 115,
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Comando:',
                                labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                                hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                                // fillColor: Color(0xfffbe4d8),
                              ),
                              dropdownColor: const Color(0xff190019),
                              items: <String>[
                                '0',
                                '2',
                                '4',
                                '5',
                                '6'
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value,
                                      style: const TextStyle(
                                        color: Color(0xfffbe4d8),
                                      )),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  commandText = value!;
                                  contentController.clear();
                                });
                                printLog(contentType(commandText));
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              style: const TextStyle(color: Color(0xfffbe4d8)),
                              controller: contentController,
                              maxLines: null,
                              keyboardType: contentType(commandText),
                              decoration: InputDecoration(
                                labelText: 'Contenido:',
                                hintText: hintAWS(commandText),
                                labelStyle:
                                    const TextStyle(color: Color(0xfffbe4d8)),
                                hintStyle:
                                    const TextStyle(color: Color(0xfffbe4d8)),
                                suffixIcon: commandText == '6'
                                    ? IconButton(
                                        onPressed: () {
                                          showDialog<void>(
                                            context: context,
                                            barrierDismissible: true,
                                            builder: (BuildContext context) {
                                              return SimpleDialog(
                                                title: const Text(
                                                    '¿Que vas a envíar?'),
                                                children: <Widget>[
                                                  SimpleDialogOption(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                      contentController.clear();
                                                      key = 0;
                                                      printLog(
                                                          'Amazon CA seleccionada');
                                                      setState(() {});
                                                    },
                                                    child:
                                                        const Text('Amazon CA'),
                                                  ),
                                                  SimpleDialogOption(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                      contentController.clear();
                                                      key = 1;
                                                      printLog(
                                                          'Device Cert. seleccionada');
                                                      setState(() {});
                                                    },
                                                    child: const Text(
                                                        'Device Cert.'),
                                                  ),
                                                  SimpleDialogOption(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                      contentController.clear();
                                                      key = 2;
                                                      printLog(
                                                          'Private key seleccionada');
                                                      setState(() {});
                                                    },
                                                    child: const Text(
                                                        'Private key'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.paste,
                                          color: Color(0xfffbe4d8),
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                if (commandText == '6') {
                                  content = contentController.text.split('\n');
                                  contentController.text = 'Cargado';
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      ElevatedButton(
                          onPressed: () {
                            String topic =
                                'tools/$productCode/${serialNumberController.text.trim()}';
                            subToTopicMQTT(topic);
                            listenToTopics();
                            if (commandText == '6') {
                              for (var line in content) {
                                String msg = jsonEncode({
                                  'cmd': commandText,
                                  'content': '$key#$line'
                                });
                                printLog(msg);

                                sendMessagemqtt(topic, msg);
                              }
                              String fun = key == 0
                                  ? 'Amazon CA'
                                  : key == 1
                                      ? 'Device cert.'
                                      : 'Private Key';
                              registerActivity(
                                  productCode,
                                  serialNumberController.text.trim(),
                                  'Se envio via mqtt un $fun');
                              contentController.clear();
                            } else {
                              String msg = jsonEncode({
                                'cmd': commandText,
                                'content': contentController.text.trim()
                              });
                              registerActivity(
                                  productCode,
                                  serialNumberController.text.trim(),
                                  'Se envio via mqtt: $msg');
                              sendMessagemqtt(topic, msg);
                              contentController.clear();
                            }
                          },
                          child: const Text('Enviar comando')),
                      const SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: const Color(0xff2b124c),
                          borderRadius: BorderRadius.circular(20),
                          border: const Border(
                            bottom:
                                BorderSide(color: Color(0xff854f6c), width: 5),
                            right:
                                BorderSide(color: Color(0xff854f6c), width: 5),
                            left:
                                BorderSide(color: Color(0xff854f6c), width: 5),
                            top: BorderSide(color: Color(0xff854f6c), width: 5),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Respuesta:',
                              style: TextStyle(
                                  color: Color(0xFFdfb6b2),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 30),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            Text(
                              textToShow,
                              style: const TextStyle(
                                  color: Color(0xFFdfb6b2), fontSize: 30),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    ],
                  ],
                ),
              ),
            );
          },
        ));
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
    var formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    printLog(formatter.format(DateTime.now()));
  }

//!Locuritas.

  // void testFirestore() async {
  //   String url =
  //       'https://script.google.com/macros/s/AKfycbwwIHRUsVgeXTZ33-4lMOz8wYln95jgM4wPcnXmYDvKrFeLz-bH-tHgIPeGc2T-eREGlQ/exec';
  //   var response = await dio.post(url,
  //       queryParameters: {'deviceName': 'Detector23111633', 'alert': 'true'});

  //   if (response.statusCode == 200) {
  //     printLog('Datos enviados correctamente');
  //   } else {
  //     printLog('Error al enviar datos: ${response.data}');
  //   }
  // }

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

    // var headers = {
    //   'Content-Type': 'application/json',
    // };

    var response = await dio.post(url, data: requestBody);

    if (response.statusCode == 200) {
      printLog('Datos enviados correctamente');
      return true;
    } else {
      printLog('Error al enviar datos: ${response.data.toString()}');
      return false;
    }
  }

  Future<void> wipeSheet() async {
    var url =
        'https://script.google.com/macros/s/AKfycbx8sz7I8Tn6lKbG7QgsRgTyOi4ayGND5LSHtZl4JLG2OIFvsgTgyza2HIB1kVh_gXmj3Q/exec';

    var response = await dio.get(url);

    if (response.statusCode == 200) {
      printLog('Wipe realizado correctamente');
    } else {
      printLog('Error al enviar datos: ${response.data.toString()}');
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

  Future<bool> setupMqtt5773() async {
    try {
      printLog('Haciendo setup');
      String deviceId = 'FlutterApp/${generateRandomNumbers(32)}';
      String hostname = 'Cristian.local';

      mqttClient5773 = MqttServerClient.withPort(hostname, deviceId, 1883);

      mqttClient5773!.logging(on: true);
      mqttClient5773!.onDisconnected = mqttonDisconnected5773;

      // Configuración de las credenciales
      mqttClient5773!.setProtocolV311();
      mqttClient5773!.keepAlivePeriod = 3;
      await mqttClient5773!.connect();
      printLog('Usuario conectado a mqtt mosquito');
      setState(() {});

      return true;
    } catch (e, s) {
      printLog('Error setup mqtt $e $s');
      return false;
    }
  }

  void mqttonDisconnected5773() {
    printLog('Desconectado de mqtt mosquito');
    reconnectMqtt5773();
  }

  void reconnectMqtt5773() async {
    await setupMqtt5773().then((value) {
      if (value) {
        listenToTopics5773();
      } else {
        reconnectMqtt5773();
      }
    });
  }

  void sendMessagemqtt5773(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);

    mqttClient5773!
        .publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }

  void subToTopicMQTT5773(String topic) {
    mqttClient5773!.subscribe(topic, MqttQos.atLeastOnce);
  }

  void unSubToTopicMQTT5773(String topic) {
    mqttClient5773!.unsubscribe(topic);
  }

  void listenToTopics5773() {
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
        appBar: AppBar(
          title: const Align(
              alignment: Alignment.center,
              child: Text(
                'Regulación',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              )),
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xfffbe4d8),
        ),
        body: SingleChildScrollView(
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
                          numbers.addAll(generateSerialNumbers(header,
                              int.parse(initialvalue), int.parse(finalvalue)));
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
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text(
                                  '¿Estas seguro que quieres hacer esto?',
                                  style: TextStyle(fontSize: 30),
                                ),
                                content: const Text(
                                  'Estas por empezar el proceso de regulación\nDe realizarse mal este proceso puede afectar al funcionamiento de los equipos',
                                  style: TextStyle(fontSize: 20),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      registerActivity('Global', 'Regbank',
                                          'Se inicio regbank para ${numbers.length} equipos');
                                      try {
                                        await setupMqtt5773();
                                        for (int i = 0;
                                            i < numbers.length;
                                            i++) {
                                          String topic =
                                              '015773_IOT/${numbers[i]}';
                                          subToTopicMQTT5773(topic);
                                        }
                                      } catch (e, s) {
                                        printLog('Error al sub $e $s');
                                      }
                                      listenToTopics5773();
                                      startTimer();
                                      hearing = true;
                                    },
                                    child: const Text('Iniciar escucha'),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          try {
                            for (int i = 0; i < numbers.length; i++) {
                              String topic = '015773_IOT/${numbers[i]}';
                              unSubToTopicMQTT5773(topic);
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
                              color: Colors.black, fontWeight: FontWeight.bold),
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
                    sendMessagemqtt5773('015773_RB', 'DIAGNOSIS_OK');
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
                    sendMessagemqtt5773('015773_RB', 'ESP_UPDATE($url)');
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
                    sendMessagemqtt5773('015773_RB', 'PIC_UPDATE($url)');
                  },
                  child: const Text('OTA PIC'),
                ),
                const SizedBox(
                  height: 30,
                ),
                Text(
                  'RP ${_rp.round()}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFFdfb6b2), fontSize: 30),
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
                    sendMessagemqtt5773('015773_RB', 'REGPOINT_${_rp}_($temp)');
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
        ));
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
  final TextEditingController productCodeController = TextEditingController();
  bool productCodeAdded = false;
  bool versionSoftAdded = false;
  bool versionHardAdded = false;
  String productCode = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      appBar: AppBar(
        title: const Align(
            alignment: Alignment.center,
            child: Text(
              'OTA Global',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            )),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xfffbe4d8),
      ),
      body: Center(
          child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
                width: 300,
                child: TextField(
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  controller: productCodeController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Ingrese el código de producto',
                    labelStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    suffixIcon: productCodeAdded
                        ? const Icon(
                            Icons.check_circle_outline_outlined,
                            color: Colors.green,
                          )
                        : const Icon(
                            Icons.cancel_rounded,
                            color: Colors.red,
                          ),
                  ),
                  onChanged: (value) {
                    productCodeAdded = true;
                    if (productCodeController.text.contains('_IOT')) {
                      productCode = productCodeController.text.trim();
                    } else {
                      productCode = '${productCodeController.text.trim()}_IOT';
                    }
                    setState(() {});
                  },
                )),
            const SizedBox(height: 20),
            SizedBox(
                width: 300,
                child: TextField(
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  controller: verSoftController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Ingrese la versión de software',
                    labelStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    suffixIcon: versionSoftAdded
                        ? const Icon(
                            Icons.check_circle_outline_outlined,
                            color: Colors.green,
                          )
                        : const Icon(
                            Icons.cancel_rounded,
                            color: Colors.red,
                          ),
                  ),
                  onChanged: (value) {
                    versionSoftAdded = true;
                    setState(() {});
                  },
                )),
            const SizedBox(height: 20),
            SizedBox(
                width: 300,
                child: TextField(
                  style: const TextStyle(color: Color(0xfffbe4d8)),
                  controller: verHardController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Ingrese la versión de hardware',
                    labelStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    hintStyle: const TextStyle(color: Color(0xfffbe4d8)),
                    suffixIcon: versionHardAdded
                        ? const Icon(
                            Icons.check_circle_outline_outlined,
                            color: Colors.green,
                          )
                        : const Icon(
                            Icons.cancel_rounded,
                            color: Colors.red,
                          ),
                  ),
                  onChanged: (value) {
                    versionHardAdded = true;
                    setState(() {});
                  },
                )),
            const SizedBox(
              height: 30,
            ),
            ElevatedButton(
              onPressed: () {
                if (versionSoftAdded && versionHardAdded && productCodeAdded) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text(
                          '¿Estas seguro de lo estas por hacer?',
                          style: TextStyle(fontSize: 30),
                        ),
                        content: const Text(
                          'Enviar ota sin estar seguro de lo que haces puede afectar el funcionamiento de todos los equipos.',
                          style: TextStyle(fontSize: 20),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              registerActivity('Global', 'OTA',
                                  'Se envio OTA global para los equipos $productCode. DATA: ${verHardController.text.trim()}#${verSoftController.text.trim()}');
                              String topic = 'tools/$productCode/global';
                              String msg = jsonEncode({
                                'cmd': '2',
                                'content':
                                    '${verHardController.text.trim()}#${verSoftController.text.trim()}'
                              });
                              sendMessagemqtt(topic, msg);

                              setState(() {
                                productCodeAdded = false;
                                versionSoftAdded = false;
                                versionHardAdded = false;
                                productCodeController.clear();
                                verHardController.clear();
                                verSoftController.clear();
                                productCode = '';
                              });
                              showToast('Ota realizada');
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Hacer OTA'),
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  showToast(
                      'Debes agregar las versiones\nAntes de enviar la OTA');
                }
              },
              child: const Text('Hacer OTA global'),
            ),
          ],
        ),
      )),
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
        } else if (deviceType == '020010') {
          navigatorKey.currentState?.pushReplacementNamed('/io');
        } else if (deviceType == '024011') {
          navigatorKey.currentState?.pushReplacementNamed('/roller');
        } else if (deviceType == '019000') {
          navigatorKey.currentState?.pushReplacementNamed('/patito');
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
      printLog('Valores tools: $toolsValues || ${utf8.decode(toolsValues)}');
      printLog('Valores info: $infoValues || ${utf8.decode(infoValues)}');

      await queryItems(
          service, command(deviceName), extractSerialNumber(deviceName));

      //Si es un calefactor
      if (deviceType == '022000' ||
          deviceType == '027000' ||
          deviceType == '041220') {
        varsValues = await myDevice.varsUuid.read();
        var parts2 = utf8.decode(varsValues).split(':');
        printLog('Valores vars: $parts2');
        distanceControlActive = parts2[0] == '1';
        tempValue = double.parse(parts2[1]);
        turnOn = parts2[2] == '1';
        trueStatus = parts2[4] == '1';
        nightMode = parts2[5] == '1';
        actualTemp = parts2[6];
        if (factoryMode) {
          awsInit = parts2[7] == '1';
          tempMap = parts2[8] == '1';
        }
        printLog('Estado: $turnOn');
      } else if (deviceType == '015773') {
        //Si soy un detector
        workValues = await myDevice.workUuid.read();
        if (factoryMode) {
          calibrationValues = await myDevice.calibrationUuid.read();
          regulationValues = await myDevice.regulationUuid.read();
          debugValues = await myDevice.debugUuid.read();
          awsInit = workValues[23] == 1;
        }

        printLog('Valores calibracion: $calibrationValues');
        printLog('Valores regulacion: $regulationValues');
        printLog('Valores debug: $debugValues');
        printLog('Valores trabajo: $workValues');
        printLog('Valores work: $workValues');
      } else if (deviceType == '020010') {
        ioValues = await myDevice.ioUuid.read();
        printLog('Valores IO: $ioValues || ${utf8.decode(ioValues)}');
      } else if (deviceType == '024011') {
        varsValues = await myDevice.varsUuid.read();
        var parts2 = utf8.decode(varsValues).split(':');
        printLog('Valores vars: $parts2');

        distanceControlActive = parts2[0] == '1';
        rollerlength = parts2[1];
        rollerPolarity = parts2[2];
        motorSpeedUp = parts2[3];
        motorSpeedDown = parts2[4];
        contrapulseTime = parts2[5];
        actualPosition = int.parse(parts2[6]);
        workingPosition = int.parse(parts2[7]);
        rollerMoving = parts2[8] == '1';
        awsInit = parts2[9] == '1';
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
