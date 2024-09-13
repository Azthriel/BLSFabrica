import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:http/http.dart' as http;

class DetectorTabs extends StatefulWidget {
  const DetectorTabs({super.key});
  @override
  DetectorTabsState createState() => DetectorTabsState();
}

class DetectorTabsState extends State<DetectorTabs> {
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
    if (parts[0] == 'WCS_CONNECTED' || parts[0] == '1') {
      nameOfWifi = parts[1];
      isWifiConnected = true;
      printLog('sis $isWifiConnected');
      setState(() {
        textState = 'CONECTADO';
        statusColor = Colors.green;
        wifiIcon = Icons.wifi;
      });
    } else if (parts[0] == 'WCS_DISCONNECTED' || parts[0] == '0') {
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
    return PopScope(
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

        return;
      },
      child: MaterialApp(
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
          length: accesoTotal
              ? factoryMode
                  ? 7
                  : 3
              : accesoLabo
                  ? factoryMode
                      ? 5
                      : 3
                  : 2,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
                backgroundColor: const Color(0xff522b5b),
                foregroundColor: const Color(0xfffbe4d8),
                title: Text(deviceName),
                bottom: TabBar(
                  labelColor: const Color(0xffdfb6b2),
                  unselectedLabelColor: const Color(0xff190019),
                  indicatorColor: const Color(0xffdfb6b2),
                  tabs: [
                    if (accesoTotal) ...[
                      const Tab(icon: Icon(Icons.numbers)),
                      if (factoryMode) ...[
                        const Tab(icon: Icon(Icons.settings)),
                        const Tab(icon: Icon(Icons.tune)),
                        const Tab(icon: Icon(Icons.catching_pokemon)),
                      ],
                      const Tab(icon: Icon(Icons.lightbulb_sharp)),
                      if (factoryMode) ...[
                        const Tab(icon: Icon(Icons.perm_identity)),
                      ],
                      const Tab(icon: Icon(Icons.send)),
                    ] else if (accesoLabo) ...[
                      const Tab(icon: Icon(Icons.numbers)),
                      if (factoryMode) ...[
                        const Tab(icon: Icon(Icons.settings)),
                      ],
                      const Tab(icon: Icon(Icons.lightbulb_sharp)),
                      if (factoryMode) ...[
                        const Tab(icon: Icon(Icons.perm_identity)),
                      ],
                      const Tab(icon: Icon(Icons.send)),
                    ] else ...[
                      const Tab(icon: Icon(Icons.lightbulb_sharp)),
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
                leading: IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                                content: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                    onPressed: () {
                                      var data = '015773_IOT[0](1)';
                                      try {
                                        registerActivity(
                                            command(deviceName),
                                            extractSerialNumber(deviceName),
                                            'Se borró la NVS de este equipo...');
                                        myDevice.toolsUuid.write(data.codeUnits,
                                            withoutResponse: false);
                                        printLog('a');
                                      } catch (e, stackTrace) {
                                        printLog(
                                            'Fatal error 1 $e $stackTrace');
                                        showToast('Error al borrar NVS');
                                      }
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Borrar NVS ESP')),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                    onPressed: () {
                                      pikachu.contains('Pika');
                                    },
                                    child: const Text('Crashear app')),
                              ],
                            ));
                          });
                    })),
            body: TabBarView(
              children: [
                if (accesoTotal) ...[
                  const CharPage(),
                  if (factoryMode) ...[
                    const CalibrationPage(),
                    const RegulationPage(),
                    const DebugPage(),
                  ],
                  const LightPage(),
                  if (factoryMode) ...[
                    const CredsTab(),
                  ],
                  const OTAPage(),
                ] else if (accesoLabo) ...[
                  const CharPage(),
                  if (factoryMode) ...[
                    const CalibrationPage(),
                  ],
                  const LightPage(),
                  if (factoryMode) ...[
                    const CredsTab(),
                  ],
                  const OTAPage(),
                ] else ...[
                  const LightPage(),
                  const OTAPage(),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// CARACTERISTICAS //ANOTHER PAGE

class CharPage extends StatefulWidget {
  const CharPage({super.key});
  @override
  CharState createState() => CharState();
}

class CharState extends State<CharPage> {
  String dataToshow = '';
  var parts = utf8.decode(infoValues).split(':');
  late String serialNumber;
  TextEditingController textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    serialNumber = parts[1]; // Serial Number
  }

  void sendDataToDevice() async {
    String dataToSend = textController.text;
    try {
      String data = '015773_IOT[4]($dataToSend)';
      await myDevice.toolsUuid.write(data.codeUnits);
    } catch (e, stackTrace) {
      printLog('Error al enviar el numero de serie $e $stackTrace');
      showToast('Error al cambiar el número de serie');
      // handleManualError(e, stackTrace);
    }
    navigatorKey.currentState?.pushReplacementNamed('/menu');
  }

//! Visual
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
            if (factoryMode) ...[
              SizedBox(
                  width: 300,
                  child: TextField(
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
            ],
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
            const SizedBox(height: 30),
            if (factoryMode) ...{
              const Text.rich(
                TextSpan(
                    text: 'Seleccionar el tipo de gas:',
                    style: (TextStyle(
                        fontSize: 20.0,
                        color: Color(0xfffbe4d8),
                        fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildButton(
                    onPressed: () => showToast('En un futuro lo agregaremos'),
                    text: 'Dual Gas',
                  ),
                  const SizedBox(width: 16),
                  buildButton(
                    onPressed: () => showToast('En un futuro lo agregaremos'),
                    text: 'CH4',
                  ),
                  const SizedBox(width: 16),
                  buildButton(
                    onPressed: () => showToast('En un futuro lo agregaremos'),
                    text: 'CO',
                  )
                ],
              )
            }
          ],
        ),
      )),
    );
  }

  Widget buildButton({required VoidCallback onPressed, required String text}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
      ),
      child: Text(text),
    );
  }
}

//CALIBRACION //ANOTHER PAGE

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});
  @override
  CalibrationState createState() => CalibrationState();
}

class CalibrationState extends State<CalibrationPage> {
  final TextEditingController _setVccInputController = TextEditingController();
  final TextEditingController _setVrmsInputController = TextEditingController();
  final TextEditingController _setVrms02InputController =
      TextEditingController();

  Color _vrmsColor = const Color(0xFFdfb6b2);
  Color _vccColor = const Color(0xFFdfb6b2);
  Color rsColor = const Color(0xFFdfb6b2);
  Color rrcoColor = const Color(0xFFdfb6b2);

  List<int> _calValues = List<int>.filled(11, 0);
  int _vrms = 0;
  int _vcc = 0;
  int _vrmsOffset = 0;
  int _vrms02Offset = 0;
  int _vccOffset = 0;
  int tempMicro = 0;
  String rs = '';
  String rrco = '';
  int rsValue = 0;
  int rrcoValue = 0;
  bool rsInvalid = false;
  bool rrcoInvalid = false;
  bool rsOver35k = false;
  int ppmCO = 0;
  int ppmCH4 = 0;

  @override
  void initState() {
    super.initState();
    _calValues = calibrationValues;
    ppmCO = workValues[5] + workValues[6] << 8;
    ppmCH4 = workValues[7] + workValues[8] << 8;
    updateValues(_calValues);
    _subscribeToCalCharacteristic();
    _subscribeToWorkCharacteristic();
  }

  @override
  void dispose() {
    _setVccInputController.dispose();
    _setVrmsInputController.dispose();
    _setVrms02InputController.dispose();
    super.dispose();
  }

  void _setVcc(String newValue) {
    if (newValue.isEmpty) {
      printLog('STRING EMPTY');
      return;
    }

    printLog('changing VCC!');

    List<int> vccNewOffset = List<int>.filled(3, 0);
    vccNewOffset[0] = int.parse(newValue);
    vccNewOffset[1] = 0; // only 8 bytes value
    vccNewOffset[2] = 0; // calibration point: vcc

    try {
      myDevice.calibrationUuid.write(vccNewOffset);
    } catch (e, stackTrace) {
      printLog('Error al escribir vcc offset $e $stackTrace');
      showToast('Error al escribir vcc offset');
      // handleManualError(e, stackTrace);
    }

    setState(() {});
  }

  void _setVrms(String newValue) {
    if (newValue.isEmpty) {
      return;
    }

    List<int> vrmsNewOffset = List<int>.filled(3, 0);
    vrmsNewOffset[0] = int.parse(newValue);
    vrmsNewOffset[1] = 0; // only 8 bytes value
    vrmsNewOffset[2] = 1; // calibration point: vrms

    try {
      myDevice.calibrationUuid.write(vrmsNewOffset);
    } catch (e, stackTrace) {
      printLog('Error al setear vrms offset $e $stackTrace');
      showToast('Error al setear vrms offset');
      // handleManualError(e, stackTrace);
    }

    setState(() {});
  }

  void _setVrms02(String newValue) {
    if (newValue.isEmpty) {
      return;
    }

    List<int> vrms02NewOffset = List<int>.filled(3, 0);
    vrms02NewOffset[0] = int.parse(newValue);
    vrms02NewOffset[1] = 0; // only 8 bytes value
    vrms02NewOffset[2] = 2; // calibration point: vrms02

    try {
      myDevice.calibrationUuid.write(vrms02NewOffset);
    } catch (e, stackTrace) {
      printLog('Error al setear vrms offset $e $stackTrace');
      showToast('Error al setear vrms02 offset');
      // handleManualError(e, stackTrace);
    }

    setState(() {});
  }

  void updateValues(List<int> newValues) async {
    _calValues = newValues;
    printLog('Valores actualizados: $_calValues');

    if (_calValues.isNotEmpty) {
      _vccOffset = _calValues[0];
      _vrmsOffset = _calValues[1];
      _vrms02Offset = _calValues[2];

      _vcc = _calValues[3];
      _vcc += _calValues[4] << 8;
      printLog(_vcc);

      double adcPwm = _calValues[5].toDouble();
      adcPwm += _calValues[6] << 8;
      adcPwm *= 2.001955034213099;
      _vrms = adcPwm.toInt();
      printLog(_vrms);

      //

      if (_vcc >= 8000 || _vrms >= 2000) {
        _vcc = 0;
        _vrms = 0;
      }

      //

      if (_vcc > 5000) {
        _vccColor = Colors.red;
      } else {
        _vccColor = const Color(0xFFdfb6b2);
      }

      if (_vrms > 900) {
        _vrmsColor = Colors.red;
      } else {
        _vrmsColor = const Color(0xFFdfb6b2);
      }

      tempMicro = _calValues[7];
      rsValue = _calValues[8];
      rsValue += _calValues[9] << 8;

      rrcoValue = _calValues[10];
      rrcoValue = _calValues[11] << 8;

      if (rsValue >= 35000) {
        rsInvalid = true;
        rsOver35k = true;
        rsValue = 35000;
      } else {
        rsInvalid = false;
      }
      if (rsValue < 3500) {
        rsInvalid = true;
      } else {
        rsInvalid = false;
      }
      if (rrcoValue > 28000) {
        rrcoInvalid = false;
      } else {
        rrcoValue = 0;
        rrcoInvalid = true;
      }

      if (rsInvalid == true) {
        if (rsOver35k == true) {
          rs = '>35kΩ';
          rsColor = Colors.red;
        } else {
          rs = '<3.5kΩ';
          rsColor = Colors.red;
        }
      } else {
        var fun = rsValue / 1000;
        rs = '${fun}KΩ';
      }
      if (rrcoInvalid == true) {
        rrco = '<28kΩ';
        rrcoColor = Colors.red;
      } else {
        var fun = rrcoValue / 1000;
        rrco = '${fun}KΩ';
      }
    }

    setState(() {}); //reload the screen in each notification
  }

  void _subscribeToCalCharacteristic() async {
    if (!alreadySubCal) {
      await myDevice.calibrationUuid.setNotifyValue(true);
      alreadySubCal = true;
    }
    final calSub =
        myDevice.calibrationUuid.onValueReceived.listen((List<int> status) {
      updateValues(status);
    });

    myDevice.device.cancelWhenDisconnected(calSub);
  }

  void _subscribeToWorkCharacteristic() async {
    if (!alreadySubWork) {
      await myDevice.workUuid.setNotifyValue(true);
      alreadySubWork = true;
    }
    final workSub =
        myDevice.workUuid.onValueReceived.listen((List<int> status) {
      setState(() {
        ppmCO = status[5] + (status[6] << 8);
        ppmCH4 = status[7] + (status[8] << 8);
      });
    });

    myDevice.device.cancelWhenDisconnected(workSub);
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff190019),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          Text('Valores de calibracion: $_calValues',
              textScaler: const TextScaler.linear(1.2),
              style: const TextStyle(color: Color(0xFFdfb6b2))),
          const SizedBox(height: 40),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '(C21) VCC:                          ',
                  style: TextStyle(
                    fontSize: 22.0,
                    color: Color(0xfffbe4d8),
                  ),
                ),
                TextSpan(
                  text: '$_vcc',
                  style: TextStyle(
                    fontSize: 24.0,
                    color: _vccColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' mV',
                  style: TextStyle(
                    fontSize: 22.0,
                    color: _vccColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                disabledActiveTrackColor: _vccColor,
                disabledInactiveTrackColor: const Color(0xff854f6c),
                trackHeight: 12,
                thumbShape: SliderComponentShape.noThumb),
            child: Slider(
              value: _vcc.toDouble(),
              min: 0,
              max: 8000,
              onChanged: null,
              onChangeStart: null,
            ),
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '(C21) VRMS:                          ',
                  style: TextStyle(
                    fontSize: 22.0,
                    color: Color(0xfffbe4d8),
                  ),
                ),
                TextSpan(
                  text: '$_vrms',
                  style: TextStyle(
                    fontSize: 24.0,
                    color: _vrmsColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' mV',
                  style: TextStyle(
                    fontSize: 22.0,
                    color: _vrmsColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                disabledActiveTrackColor: _vrmsColor,
                disabledInactiveTrackColor: const Color(0xff854f6c),
                trackHeight: 12,
                thumbShape: SliderComponentShape.noThumb),
            child: Slider(
              value: _vrms.toDouble(),
              min: 0,
              max: 2000,
              onChanged: null,
              onChangeStart: null,
            ),
          ),
          const SizedBox(height: 50),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '(C20) VCC Offset:                  ',
                  style: TextStyle(fontSize: 22.0, color: Color(0xfffbe4d8)),
                ),
                TextSpan(
                  text: '$_vccOffset ',
                  style: const TextStyle(
                      fontSize: 22.0,
                      color: Color(0xFFdfb6b2),
                      fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: 'ADCU',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Color(0xFFdfb6b2),
                  ),
                ),
              ],
            ),
          ),
          FractionallySizedBox(
            widthFactor: 0.550,
            alignment: Alignment.bottomLeft,
            child: TextField(
              style: const TextStyle(color: Color(0xfffbe4d8)),
              keyboardType: TextInputType.number,
              controller: _setVccInputController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(10.0),
                prefixText: '(0 - 255)  ',
                prefixStyle: TextStyle(
                  color: Color(0xfffbe4d8),
                ),
                hintText: 'Modificar VCC',
                hintStyle: TextStyle(
                  color: Color(0xfffbe4d8),
                ),
              ),
              onSubmitted: (value) {
                if (int.parse(value) <= 255 && int.parse(value) >= 0) {
                  _setVcc(value);
                } else {
                  showToast('Valor ingresado invalido');
                }
                _setVccInputController.clear();
              },
            ),
          ),
          const SizedBox(height: 40),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '(C21) VRMS Offset:            ',
                  style: TextStyle(fontSize: 22.0, color: Color(0xfffbe4d8)),
                ),
                TextSpan(
                  text: '$_vrmsOffset ',
                  style: const TextStyle(
                      fontSize: 22.0,
                      color: Color(0xFFdfb6b2),
                      fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: 'ADCU',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Color(0xFFdfb6b2),
                  ),
                ),
              ],
            ),
          ),
          FractionallySizedBox(
            widthFactor: 0.550,
            alignment: Alignment.bottomLeft,
            child: TextField(
              style: const TextStyle(
                color: Color(0xfffbe4d8),
              ),
              keyboardType: TextInputType.number,
              controller: _setVrmsInputController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(10.0),
                prefixText: '(0 - 255)  ',
                prefixStyle: TextStyle(
                  color: Color(0xfffbe4d8),
                ),
                hintText: 'Modificar VRMS',
                hintStyle: TextStyle(
                  color: Color(0xfffbe4d8),
                ),
              ),
              onSubmitted: (value) {
                if (int.parse(value) <= 255 && int.parse(value) >= 0) {
                  _setVrms(value);
                } else {
                  showToast('Valor ingresado invalido');
                }
                _setVrmsInputController.clear();
              },
            ),
          ),
          const SizedBox(height: 40),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '(C97) VRMS02 Offset:            ',
                  style: TextStyle(fontSize: 22.0, color: Color(0xfffbe4d8)),
                ),
                TextSpan(
                  text: '$_vrms02Offset ',
                  style: const TextStyle(
                      fontSize: 22.0,
                      color: Color(0xFFdfb6b2),
                      fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: 'ADCU',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Color(0xFFdfb6b2),
                  ),
                ),
              ],
            ),
          ),
          FractionallySizedBox(
            widthFactor: 0.550,
            alignment: Alignment.bottomLeft,
            child: TextField(
              style: const TextStyle(
                color: Color(0xfffbe4d8),
              ),
              keyboardType: TextInputType.number,
              controller: _setVrms02InputController,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(10.0),
                prefixText: '(0 - 255)  ',
                prefixStyle: TextStyle(
                  color: Color(0xfffbe4d8),
                ),
                hintText: 'Modificar VRMS',
                hintStyle: TextStyle(
                  color: Color(0xfffbe4d8),
                ),
              ),
              onSubmitted: (value) {
                if (int.parse(value) <= 255 && int.parse(value) >= 0) {
                  _setVrms02(value);
                } else {
                  showToast('Valor ingresado invalido');
                }
                _setVrms02InputController.clear();
              },
            ),
          ),
          const SizedBox(height: 70),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Resistencia del sensor en GAS: ',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Color(0xfffbe4d8),
                  ),
                ),
                TextSpan(
                  text: rs,
                  style: TextStyle(
                    fontSize: 24.0,
                    color: rsColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                disabledActiveTrackColor: rsColor,
                disabledInactiveTrackColor: const Color(0xff854f6c),
                trackHeight: 12,
                thumbShape: SliderComponentShape.noThumb),
            child: Slider(
              value: rsValue.toDouble(),
              min: 0,
              max: 35000,
              onChanged: null,
              onChangeStart: null,
            ),
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Resistencia de sensor en monoxido: ',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Color(0xfffbe4d8),
                  ),
                ),
                TextSpan(
                  text: rrco,
                  style: TextStyle(
                    fontSize: 24.0,
                    color: rrcoColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                disabledActiveTrackColor: rrcoColor,
                disabledInactiveTrackColor: const Color(0xff854f6c),
                trackHeight: 12,
                thumbShape: SliderComponentShape.noThumb),
            child: Slider(
              value: rrcoValue.toDouble(),
              min: 0,
              max: 100000,
              onChanged: null,
              onChangeStart: null,
            ),
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Temperatura del micro: ',
                  style: TextStyle(
                    fontSize: 22.0,
                    color: Color(0xfffbe4d8),
                  ),
                ),
                TextSpan(
                  text: tempMicro.toString(),
                  style: const TextStyle(
                    fontSize: 24.0,
                    color: Color(0xffdfb6b2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(
                  text: '°C',
                  style: TextStyle(
                    fontSize: 24.0,
                    color: Color(0xffdfb6b2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text.rich(TextSpan(children: [
            const TextSpan(
              text: 'PPM CO: ',
              style: TextStyle(
                fontSize: 22.0,
                color: Color(0xfffbe4d8),
              ),
            ),
            TextSpan(
              text: '$ppmCO',
              style: const TextStyle(
                fontSize: 24.0,
                color: Color(0xffdfb6b2),
                fontWeight: FontWeight.bold,
              ),
            ),
          ])),
          const SizedBox(height: 20),
          Text.rich(TextSpan(children: [
            const TextSpan(
              text: 'PPM CH4: ',
              style: TextStyle(
                fontSize: 22.0,
                color: Color(0xfffbe4d8),
              ),
            ),
            TextSpan(
              text: '$ppmCH4',
              style: const TextStyle(
                fontSize: 24.0,
                color: Color(0xffdfb6b2),
                fontWeight: FontWeight.bold,
              ),
            ),
          ])),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

//REGULATION //ANOTHER PAGE

class RegulationPage extends StatefulWidget {
  const RegulationPage({super.key});
  @override
  RegulationState createState() => RegulationState();
}

class RegulationState extends State<RegulationPage> {
  List<String> valores = [];
  final ScrollController _scrollController = ScrollController();
  late List<int> value;
  bool regulationDone = false;

  @override
  void initState() {
    super.initState();
    value = regulationValues;
    _readValues();
    _subscribeValue();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _readValues() {
    setState(() {
      for (int i = 0; i < 10; i += 2) {
        printLog('i = $i');
        int datas = value[i] + (value[i + 1] << 8);
        valores.add(datas.toString());
      }
      for (int j = 10; j < 15; j++) {
        printLog('j = $j');
        valores.add(value[j].toString());
      }
      for (int k = 15; k < 29; k += 2) {
        printLog('k = $k');
        int dataj = value[k] + (value[k + 1] << 8);
        valores.add(dataj.toString());
      }

      if (value[29] == 0) {
        regulationDone = false;
      } else if (value[29] == 1) {
        regulationDone = true;
      }
    });
  }

  void _subscribeValue() async {
    if (!alreadySubReg) {
      await myDevice.regulationUuid.setNotifyValue(true);
      alreadySubReg = true;
    }
    printLog('Me turbosuscribi a regulacion');
    final regSub =
        myDevice.regulationUuid.onValueReceived.listen((List<int> status) {
      updateValues(status);
    });

    myDevice.device.cancelWhenDisconnected(regSub);
  }

  void updateValues(List<int> data) {
    valores.clear();
    printLog('Entro: $data');
    setState(() {
      for (int i = 0; i < 10; i += 2) {
        int datas = value[i] + (value[i + 1] << 8);
        valores.add(datas.toString());
      }
      for (int j = 10; j < 15; j++) {
        valores.add(value[j].toString());
      }
      for (int k = 15; k < 29; k += 2) {
        int dataj = value[k] + (value[k + 1] << 8);
        valores.add(dataj.toString());
      }

      if (value[29] == 0) {
        regulationDone = false;
      } else if (value[29] == 1) {
        regulationDone = true;
      }
    });
  }

  String textToShow(int index) {
    switch (index) {
      case 0:
        return 'Resistencia del sensor en gas a 20 grados';
      case 1:
        return 'Resistencia del sensor en gas a 30 grados';
      case 2:
        return 'Resistencia del sensor en gas a 40 grados';
      case 3:
        return 'Resistencia del sensor en gas a 50 grados';
      case 4:
        return 'Resistencia del sensor en gas a x grados';
      case 5:
        return 'Corrector de temperatura a 20 grados';
      case 6:
        return 'Corrector de temperatura a 30 grados';
      case 7:
        return 'Corrector de temperatura a 40 grados';
      case 8:
        return 'Corrector de temperatura a 50 grados';
      case 9:
        return 'Corrector de temperatura a x grados';
      case 10:
        return 'Resistencia de sensor en monoxido a 20 grados';
      case 11:
        return 'Resistencia de sensor en monoxido a 30 grados';
      case 12:
        return 'Resistencia de sensor en monoxido a 40 grados';
      case 13:
        return 'Resistencia de sensor en monoxido a 50 grados';
      case 14:
        return 'Resistencia de sensor en monoxido a x grados';
      case 15:
        return 'Resistencia del sensor de CH4 en aire limpio';
      case 16:
        return 'Resistencia del sensor de CO en aire limpio';
      default:
        return 'Error inesperado';
    }
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Scaffold(
          backgroundColor: const Color(0xff190019),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Row(children: [
                const SizedBox(width: 15),
                const Text('Regulación completada:',
                    style: TextStyle(color: Color(0xfffbe4d8), fontSize: 22.0)),
                const SizedBox(width: 40),
                regulationDone
                    ? const Text('SI',
                        style: TextStyle(
                            color: Color(0xFFdfb6b2),
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold))
                    : const Text('NO',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold))
              ]),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: valores.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(textToShow(index),
                          style: const TextStyle(
                              color: Color(0xfffbe4d8),
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      subtitle: Text(valores[index],
                          style: const TextStyle(
                              color: Color(0xFFdfb6b2), fontSize: 30)),
                    );
                  },
                ),
              )
            ],
          )),
    );
  }
}

//LIGHT //ANOTHER PAGE

class LightPage extends StatefulWidget {
  const LightPage({super.key});
  @override
  LightPageState createState() => LightPageState();
}

class LightPageState extends State<LightPage> {
  double _sliderValue = 100.0;

  void _sendValueToBle(int value) async {
    try {
      final data = [value];
      myDevice.lightUuid.write(data, withoutResponse: true);
    } catch (e, stackTrace) {
      printLog('Error al mandar el valor del brillo $e $stackTrace');
      // handleManualError(e, stackTrace);
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
              Icon(
                Icons.lightbulb,
                size: 200,
                color: Colors.yellow.withOpacity(_sliderValue / 100),
              ),
              const SizedBox(
                height: 30,
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                    trackHeight: 50.0,
                    thumbColor: const Color(0xfffbe4d8),
                    thumbShape: IconThumbSlider(
                        iconData: _sliderValue > 50
                            ? Icons.light_mode
                            : Icons.nightlight,
                        thumbRadius: 25)),
                child: Slider(
                  value: _sliderValue,
                  min: 0.0,
                  max: 100.0,
                  onChanged: (double value) {
                    setState(() {
                      _sliderValue = value;
                    });
                  },
                  onChangeEnd: (value) {
                    setState(() {
                      _sliderValue = value;
                    });
                    _sendValueToBle(_sliderValue.toInt());
                  },
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              Text(
                'Valor del brillo: ${_sliderValue.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 20.0, color: Color(0xFFdfb6b2)),
              ),
            ],
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

//OTA //ANOTHER PAGE

class OTAPage extends StatefulWidget {
  const OTAPage({super.key});
  @override
  OTAState createState() => OTAState();
}

class OTAState extends State<OTAPage> {
  var dataReceive = [];
  var dataToShow = 0;
  var progressValue = 0.0;
  var picprogressValue = 0.0;
  var writingprogressValue = 0.0;
  var picwritingprogressValue = 0.0;
  late Uint8List firmwareGlobal;
  bool sizeWasSend = false;
  bool otaPIC = false;
  TextEditingController otaSVController = TextEditingController();

  @override
  void initState() {
    super.initState();
    subToProgress();
  }

  void sendOTAWifi(int value) async {
    String url = '';
    if (value == 0) {
      //ota factory
      //https://github.com/barberop/sime-domotica/raw/main/015773_IOT/OTA_FW/F/hv240214Asv240524D_F.bin
      if (otaSVController.text.contains('_F')) {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${command(deviceName)}/OTA_FW/F/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
      } else {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${command(deviceName)}/OTA_FW/F/hv${hardwareVersion}sv${otaSVController.text.trim()}_F.bin';
      }
    } else if (value == 1) {
      //ota work
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${command(deviceName)}/OTA_FW/W/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
    } else if (value == 2) {
      //ota pic
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${command(deviceName)}/OTA_FW/F/hv${hardwareVersion}sv${otaSVController.text.trim()}.hex';
      otaPIC = true;
    }

    printLog(url);
    if (otaPIC == true) {
      try {
        String data = '015773_IOT[9]($url)';
        await myDevice.toolsUuid.write(data.codeUnits);
        printLog('Me puse corte re kawaii');
      } catch (e, stackTrace) {
        printLog('Error al enviar la OTA $e $stackTrace');
        // handleManualError(e, stackTrace);
        showToast('Error al enviar OTA');
      }
      showToast('Enviando OTA PIC...');
    } else {
      try {
        String data = '015773_IOT[2]($url)';
        await myDevice.toolsUuid.write(data.codeUnits);
        printLog('Si mandé ota');
      } catch (e, stackTrace) {
        printLog('Error al enviar la OTA $e $stackTrace');
        // handleManualError(e, stackTrace);
        showToast('Error al enviar OTA');
      }
      showToast('Enviando OTA WiFi...');
    }
  }

  void sendOTABLE(int value) async {
    showToast("Enviando OTA...");

    String url = '';
    if (value == 0) {
      if (otaSVController.text.contains('_F')) {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}.bin';
      } else {
        url =
            'https://github.com/barberop/sime-domotica/raw/main/${deviceType}_IOT/OTA_FW/hv${hardwareVersion}sv${otaSVController.text.trim()}_F.bin';
      }
    } else if (value == 1) {
      url =
          'https://github.com/barberop/sime-domotica/raw/main/${command(deviceName)}/OTA_FW/W/hv${hardwareVersion}sv${otaSVController.text}.bin';
    }

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

  @override
  void dispose() {
    otaPIC = false;
    atemp = false;
    super.dispose();
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xff190019),
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
                      value: picprogressValue,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xff2b124c)),
                    ),
                  ),
                ),
                Text(
                  'Progreso descarga OTA PIC: ${(picprogressValue * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xffdfb6b2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // const SizedBox(height: 10),
            // Stack(
            //   alignment: Alignment.center,
            //   children: [
            //     Container(
            //       height: 40,
            //       width: 300,
            //       decoration: BoxDecoration(
            //         borderRadius: BorderRadius.circular(20),
            //         color: const Color(0xff854f6c),
            //       ),
            //       child: ClipRRect(
            //         borderRadius: BorderRadius.circular(20),
            //         child: LinearProgressIndicator(
            //           value: picwritingprogressValue,
            //           backgroundColor: Colors.transparent,
            //           valueColor: const AlwaysStoppedAnimation<Color>(
            //               Color(0xff2b124c)),
            //         ),
            //       ),
            //     ),
            //     Text(
            //       'Progreso escritura OTA PIC: ${(picwritingprogressValue * 100).toInt()}%',
            //       style: const TextStyle(
            //         color: Color(0xffdfb6b2),
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 10),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xff2b124c)),
                    ),
                  ),
                ),
                Text(
                  'Progreso descarga OTA ESP: ${(progressValue * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xffdfb6b2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // const SizedBox(height: 10),
            // Stack(
            //   alignment: Alignment.center,
            //   children: [
            //     Container(
            //       height: 40,
            //       width: 300,
            //       decoration: BoxDecoration(
            //         borderRadius: BorderRadius.circular(20),
            //         color: const Color(0xff854f6c),
            //       ),
            //       child: ClipRRect(
            //         borderRadius: BorderRadius.circular(20),
            //         child: LinearProgressIndicator(
            //           value: writingprogressValue,
            //           backgroundColor: Colors.transparent,
            //           valueColor: const AlwaysStoppedAnimation<Color>(
            //               Color(0xff2b124c)),
            //         ),
            //       ),
            //     ),
            //     Text(
            //       'Progreso escritura OTA ESP: ${(writingprogressValue * 100).toInt()}%',
            //       style: const TextStyle(
            //         color: Color(0xffdfb6b2),
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 20),
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
                        sendOTAWifi(1);
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
                              'Mandar OTA trabajo(WiFi)',
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
                        sendOTAWifi(0);
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
                              'Mandar OTA fabrica (WiFi)',
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
                        sendOTABLE(1);
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
                              'Mandar OTA trabajo (BLE)',
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
                        sendOTABLE(0);
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
                              'Mandar OTA fabrica (BLE)',
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
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  registerActivity(
                      command(deviceName),
                      extractSerialNumber(deviceName),
                      'Se envio OTA PIC a el equipo.');
                  otaPIC = true;
                  sendOTAWifi(2);
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
                            Icon(Icons.memory, size: 15),
                            SizedBox(width: 20),
                            Icon(Icons.wifi, size: 15),
                          ]),
                      SizedBox(height: 10),
                      Text(
                        'Mandar OTA PIC',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

//DEBUG //ANOTHER PAGE

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});
  @override
  DebugState createState() => DebugState();
}

class DebugState extends State<DebugPage> {
  List<String> debug = [];
  List<int> lastValue = [];
  int regIniIns = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    updateDebugValues(debugValues);
    _subscribeDebug();
  }

  void updateDebugValues(List<int> values) {
    debug.clear();
    lastValue.clear();
    printLog('Aqui esta esto: $values');
    printLog('Largo del valor: ${values.length}');

    setState(() {
      // Procesar valores de 16 bits y añadirlos a la lista debug
      for (int i = 0; i < values.length - 5; i += 2) {
        int datas = values[i] + (values[i + 1] << 8);
        debug.add(datas.toString());
      }

      // Actualizar lastValue para que contenga solo los últimos 4 elementos
      lastValue = values.sublist(values.length - 4);

      printLog('Largo del último valor: ${lastValue.length}');

      // Verificar que la lista tiene exactamente 4 elementos
      if (lastValue.length == 4) {
        regIniIns = (lastValue[3] << 24) |
            (lastValue[2] << 16) |
            (lastValue[1] << 8) |
            lastValue[0];
        printLog('Valor mistico: $regIniIns');
      } else {
        printLog('No hay suficientes valores para procesar regIniIns.');
      }
    });
  }

  void _subscribeDebug() async {
    if (!alreadySubDebug) {
      await myDevice.debugUuid.setNotifyValue(true);
      alreadySubDebug = true;
    }
    printLog('Me turbosuscribi a regulacion');
    final debugSub =
        myDevice.debugUuid.onValueReceived.listen((List<int> status) {
      updateDebugValues(status);
    });

    myDevice.device.cancelWhenDisconnected(debugSub);
  }

  String _textToShow(int num) {
    switch (num + 1) {
      case 1:
        return 'Gasout: ';
      case 2:
        return 'Gasout estable CH4: ';
      case 3:
        return 'Gasout estable CO: ';
      case 4:
        return 'VCC: ';
      case 5:
        return 'VCC estable: ';
      case 6:
        return 'Temperatura: ';
      case 7:
        return 'Temperatura estable: ';
      case 8:
        return 'PWM Rising point: ';
      case 9:
        return 'PWM Falling point: ';
      case 10:
        return 'PWM: ';
      case 11:
        return 'PWM estable: ';
      default:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Scaffold(
        backgroundColor: const Color(0xff190019),
        body: Column(
          children: [
            const Text('Valores del PIC ADC',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFFdfb6b2),
                    fontWeight: FontWeight.bold,
                    fontSize: 30)),
            const SizedBox(
              height: 20,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: debug.length + 1,
                itemBuilder: (context, index) {
                  return index == 0
                      ? ListBody(
                          children: [
                            Row(
                              children: [
                                const Text('RegIniIns: ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xfffbe4d8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)),
                                Text(regIniIns.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xFFdfb6b2),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                  disabledActiveTrackColor:
                                      const Color(0xff2b124c),
                                  disabledInactiveTrackColor:
                                      const Color(0xff854f6c),
                                  trackHeight: 12,
                                  thumbShape: SliderComponentShape.noThumb),
                              child: Slider(
                                value: regIniIns.toDouble(),
                                min: 0,
                                max: pow(2, 32).toDouble(),
                                onChanged: null,
                                onChangeStart: null,
                              ),
                            ),
                          ],
                        )
                      : ListBody(
                          children: [
                            Row(
                              children: [
                                Text(_textToShow(index - 1),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xfffbe4d8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)),
                                Text(debug[index - 1],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xFFdfb6b2),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                  disabledActiveTrackColor:
                                      const Color(0xff2b124c),
                                  disabledInactiveTrackColor:
                                      const Color(0xff854f6c),
                                  trackHeight: 12,
                                  thumbShape: SliderComponentShape.noThumb),
                              child: Slider(
                                value: double.parse(debug[index - 1]),
                                min: 0,
                                max: 1024,
                                onChanged: null,
                                onChangeStart: null,
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
