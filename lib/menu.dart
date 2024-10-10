import 'dart:async';
import 'dart:convert';
import 'package:biocaldensmartlifefabrica/aws/dynamo/dynamo.dart';
import 'package:biocaldensmartlifefabrica/aws/dynamo/dynamo_certificates.dart';
import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:biocaldensmartlifefabrica/aws/mqtt/mqtt.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:http/http.dart' as http;

import 'package:provider/provider.dart';

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
        length: accesoTotal
            ? 4
            : accesoLabo
                ? 3
                : 2,
        child: Scaffold(
          backgroundColor: const Color(0xff190019),
          appBar: AppBar(
            backgroundColor: const Color(0xFF522B5B),
            foregroundColor: const Color(0xfffbe4d8),
            title: const Text('BSL Fábrica'),
            actions: <Widget>[
              if (legajoConectado == '1860') ...[
                GestureDetector(
                  onTap: () {
                    showDialog<void>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: Colors.transparent,
                            content: Image.asset('assets/puto.jpeg'),
                          );
                        });
                  },
                  child: Image.asset('assets/Mecha.gif'),
                ),
              ],
            ],
            bottom: TabBar(
              labelColor: const Color(0xffdfb6b2),
              unselectedLabelColor: const Color(0xff190019),
              indicatorColor: const Color(0xffdfb6b2),
              tabs: [
                if (accesoTotal) ...[
                  const Tab(
                    icon: Icon(Icons.bluetooth_searching),
                  ),
                  const Tab(
                    icon: Icon(Icons.assignment),
                  ),
                  const Tab(
                    icon: Icon(Icons.webhook_outlined),
                  ),
                  const Tab(icon: Icon(Icons.send)),
                ] else if (accesoLabo) ...[
                  const Tab(
                    icon: Icon(Icons.bluetooth_searching),
                  ),
                  const Tab(
                    icon: Icon(Icons.assignment),
                  ),
                  const Tab(
                    icon: Icon(Icons.webhook_outlined),
                  ),
                ] else if (accesoCS) ...[
                  const Tab(
                    icon: Icon(Icons.bluetooth_searching),
                  ),
                  const Tab(
                    icon: Icon(Icons.webhook_outlined),
                  ),
                ] else ...[
                  const Tab(
                    icon: Icon(Icons.bluetooth_searching),
                  ),
                  const Tab(
                    icon: Icon(Icons.assignment),
                  ),
                ]
              ],
            ),
          ),
          body: TabBarView(
            children: [
              if (accesoTotal) ...[
                const ScanTab(),
                const ControlTab(),
                const ToolsAWS(),
                const Ota2Tab(),
              ] else if (accesoLabo) ...[
                const ScanTab(),
                const ControlTab(),
                const ToolsAWS(),
              ] else if (accesoCS) ...[
                const ScanTab(),
                const ToolsAWS(),
              ] else ...[
                const ScanTab(),
                const ControlTab(),
              ]
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
              'Domótica',
              'Relé',
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
              registerActivity(
                  command(device.platformName),
                  extractSerialNumber(device.platformName),
                  'Se desconecto del equipo ${device.platformName}');
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
                          '015773_IOT',
                          '027313_IOT',
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
        registerActivity(command(deviceName), extractSerialNumber(deviceName),
            'Se conecto al equipo $deviceName');
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
        } else if (deviceType == '019000' || deviceType == '027170') {
          navigatorKey.currentState?.pushReplacementNamed('/patito');
        } else if (deviceType == '027313') {
          navigatorKey.currentState?.pushReplacementNamed('/rele');
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

        roomTempSended = await tempWasSended(
            command(deviceName), extractSerialNumber(deviceName));

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
        varsValues = await myDevice.varsUuid.read();
        printLog('Valores VARS: $varsValues || ${utf8.decode(varsValues)}');
        var parts2 = utf8.decode(varsValues).split(':');
        awsInit = parts2[0] == '1';
        burneoDone = parts2[5] == '1';
      } else if (deviceType == '024011') {
        varsValues = await myDevice.varsUuid.read();
        var parts2 = utf8.decode(varsValues).split(':');
        printLog('Valores vars: $parts2');

        distanceControlActive = parts2[0] == '1';
        rollerlength = parts2[1];
        rollerPolarity = parts2[2];
        rollerRPM = parts2[3];
        rollerMicroStep = parts2[4];
        actualPosition = int.parse(parts2[5]);
        workingPosition = int.parse(parts2[6]);
        rollerMoving = parts2[7] == '1';
        awsInit = parts2[8] == '1';
      } else if (deviceType == '027313') {
        varsValues = await myDevice.varsUuid.read();
        var parts2 = utf8.decode(varsValues).split(':');
        printLog('Valores vars: $parts2');
        distanceControlActive = parts2[0] == '1';
        turnOn = parts2[1] == '1';
        energyTimer = parts2[2];
        awsInit = parts2[3] == '1';
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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                legajoConectado == '1860'
                    ? Image.asset('assets/Mecha.gif')
                    : legajoConectado == '1799'
                        ? Image.asset('assets/puto.jpeg')
                        : const CircularProgressIndicator(
                            color: Color(0xfffbe4d8),
                          ),
                const SizedBox(height: 20),
                const Align(
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
                      style: const TextStyle(
                          color: Color(0xFFdfb6b2), fontSize: 12),
                    )),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
