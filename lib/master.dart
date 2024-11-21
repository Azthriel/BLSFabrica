import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:share_plus/share_plus.dart';

// VARIABLES //

late List<String> pikachu;
MyDevice myDevice = MyDevice();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final dio = Dio();
late bool factoryMode;
List<int> calibrationValues = [];
List<int> regulationValues = [];
List<int> toolsValues = [];
List<int> debugValues = [];
List<int> workValues = [];
List<int> infoValues = [];
List<int> varsValues = [];
List<int> ioValues = [];
String myDeviceid = '';
String deviceName = '';
String serialNumber = '';
String productCode = '';
bool bluetoothOn = true;
String wifiName = '';
String wifiPassword = '';
bool atemp = false;
String deviceType = '';
String softwareVersion = '';
String hardwareVersion = '';
String legajoConectado = '';
MqttServerClient? mqttClient5773;
String nameOfWifi = '';
var wifiIcon = Icons.wifi_off;
bool connectionFlag = false;
bool checkbleFlag = false;
bool checkubiFlag = false;
bool turnOn = false;
bool trueStatus = false;
bool nightMode = false;
bool isWifiConnected = false;
bool wifilogoConnected = false;
MaterialColor statusColor = Colors.grey;
String textState = '';
String errorMessage = '';
String errorSintax = '';
Timer? bluetoothTimer;
Timer? locationTimer;
String actualTemp = '';
bool awsInit = false;
bool tempMap = false;
double tempValue = 0.0;
bool distanceControlActive = false;

bool alreadySubReg = false;
bool alreadySubCal = false;
bool alreadySubOta = false;
bool alreadySubDebug = false;
bool alreadySubWork = false;
bool alreadySubIO = false;
bool alive = false;

String deviceResponseMqtt = '';

String rollerlength = '';
String rollerPolarity = '';
String rollerRPM = '';
String rollerMicroStep = '';
int actualPosition = 0;
int workingPosition = 0;
bool rollerMoving = false;
String rollerIMAX = '';
String rollerIRMSRUN = '';
String rollerIRMSHOLD = '';
bool rollerFreewheeling = false;
String rollerTPWMTHRS = '';
String rollerTCOOLTHRS = '';
String rollerSGTHRS = '';

String owner = '';
String distanceOn = '';
String distanceOff = '';
String secAdmDate = '';
String atDate = '';
List<String> secondaryAdmins = [];

bool accesoTotal = false;
bool accesoLabo = false;
bool accesoCS = false;

bool burneoDone = false;

bool roomTempSended = false;
String tempDate = '';

String energyTimer = '';

// Si esta en modo profile.
const bool xProfileMode = bool.fromEnvironment('dart.vm.profile');
// Si esta en modo release.
const bool xReleaseMode = bool.fromEnvironment('dart.vm.product');
// Determina si la app esta en debug.
const bool xDebugMode = !xProfileMode && !xReleaseMode;

//!------------------------------VERSION NUMBER---------------------------------------

String appVersionNumber = '24112102';

//!------------------------------VERSION NUMBER---------------------------------------

// FUNCIONES //

void printLog(var text) {
  if (xDebugMode) {
    // ignore: avoid_print
    print('PrintData: $text');
  }
}

void showToast(String message) {
  printLog('Toast: $message');
  Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: const Color(0xFFFFFFFF),
      textColor: const Color(0xFF000000),
      fontSize: 16.0);
}

Future<void> sendWifitoBle() async {
  MyDevice myDevice = MyDevice();
  String value = '$wifiName#$wifiPassword';
  String deviceCommand = command(deviceName);
  printLog(deviceCommand);
  String dataToSend = '$deviceCommand[1]($value)';
  printLog(dataToSend);
  try {
    await myDevice.toolsUuid.write(dataToSend.codeUnits);
    printLog('Se mando el wifi ANASHE');
  } catch (e) {
    printLog('Error al conectarse a Wifi $e');
  }
  atemp = true;
  wifiName = '';
  wifiPassword = '';
}

String command(String device) {
  if (device.contains('Eléctrico') || device.contains('Electrico')) {
    return '022000_IOT';
  } else if (device.contains('Gas')) {
    return '027000_IOT';
  } else if (device.contains('Detector')) {
    return '015773_IOT';
  } else if (device.contains('Radiador')) {
    return '041220_IOT';
  } else if (device.contains('Domótica') || device.contains('Domotica')) {
    return '020010_IOT';
  } else if (device.contains('Patito')) {
    return '027170_IOT';
  } else if (device.contains('Relé') || device.contains('Rele')) {
    return '027313_IOT';
  } else if (device.contains('Roll')) {
    return '024011_IOT';
  } else {
    return '';
  }
}

String generateErrorReport(FlutterErrorDetails details) {
  printLog('''
Error: ${details.exception}
Stacktrace: ${details.stack}
  ''');
  return '''
Error: ${details.exception}
Stacktrace: ${details.stack}
  ''';
}

void sendReportOnWhatsApp(String filePath) async {
  const text = 'Attached is the error report';
  final file = File(filePath);
  await Share.shareXFiles([XFile(file.path)], text: text);
}

Future<void> openQRScanner(BuildContext context) async {
  try {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var qrResult = await navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => const QRScanPage()));
      if (qrResult != null) {
        var wifiData = parseWifiQR(qrResult);
        wifiName = wifiData['SSID']!;
        wifiPassword = wifiData['password']!;
        sendWifitoBle();
      }
    });
  } catch (e) {
    printLog("Error during navigation: $e");
  }
}

Map<String, String> parseWifiQR(String qrContent) {
  printLog(qrContent);
  final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(qrContent);
  final passwordMatch = RegExp(r'P:([^;]+)').firstMatch(qrContent);

  final ssid = ssidMatch?.group(1) ?? '';
  final password = passwordMatch?.group(1) ?? '';
  return {"SSID": ssid, "password": password};
}

String extractSerialNumber(String productName) {
  RegExp regExp = RegExp(r'(\d{8})');

  Match? match = regExp.firstMatch(productName);

  return match?.group(0) ?? '';
}

String generateRandomNumbers(int length) {
  Random random = Random();
  String result = '';

  for (int i = 0; i < length; i++) {
    result += random.nextInt(10).toString();
  }

  return result;
}

String getWifiErrorSintax(int errorCode) {
  switch (errorCode) {
    case 1:
      return "WIFI_REASON_UNSPECIFIED";
    case 2:
      return "WIFI_REASON_AUTH_EXPIRE";
    case 3:
      return "WIFI_REASON_AUTH_LEAVE";
    case 4:
      return "WIFI_REASON_ASSOC_EXPIRE";
    case 5:
      return "WIFI_REASON_ASSOC_TOOMANY";
    case 6:
      return "WIFI_REASON_NOT_AUTHED";
    case 7:
      return "WIFI_REASON_NOT_ASSOCED";
    case 8:
      return "WIFI_REASON_ASSOC_LEAVE";
    case 9:
      return "WIFI_REASON_ASSOC_NOT_AUTHED";
    case 10:
      return "WIFI_REASON_DISASSOC_PWRCAP_BAD";
    case 11:
      return "WIFI_REASON_DISASSOC_SUPCHAN_BAD";
    case 12:
      return "WIFI_REASON_BSS_TRANSITION_DISASSOC";
    case 13:
      return "WIFI_REASON_IE_INVALID";
    case 14:
      return "WIFI_REASON_MIC_FAILURE";
    case 15:
      return "WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT";
    case 16:
      return "WIFI_REASON_GROUP_KEY_UPDATE_TIMEOUT";
    case 17:
      return "WIFI_REASON_IE_IN_4WAY_DIFFERS";
    case 18:
      return "WIFI_REASON_GROUP_CIPHER_INVALID";
    case 19:
      return "WIFI_REASON_PAIRWISE_CIPHER_INVALID";
    case 20:
      return "WIFI_REASON_AKMP_INVALID";
    case 21:
      return "WIFI_REASON_UNSUPP_RSN_IE_VERSION";
    case 22:
      return "WIFI_REASON_INVALID_RSN_IE_CAP";
    case 23:
      return "WIFI_REASON_802_1X_AUTH_FAILED";
    case 24:
      return "WIFI_REASON_CIPHER_SUITE_REJECTED";
    case 25:
      return "WIFI_REASON_TDLS_PEER_UNREACHABLE";
    case 26:
      return "WIFI_REASON_TDLS_UNSPECIFIED";
    case 27:
      return "WIFI_REASON_SSP_REQUESTED_DISASSOC";
    case 28:
      return "WIFI_REASON_NO_SSP_ROAMING_AGREEMENT";
    case 29:
      return "WIFI_REASON_BAD_CIPHER_OR_AKM";
    case 30:
      return "WIFI_REASON_NOT_AUTHORIZED_THIS_LOCATION";
    case 31:
      return "WIFI_REASON_SERVICE_CHANGE_PERCLUDES_TS";
    case 32:
      return "WIFI_REASON_UNSPECIFIED_QOS";
    case 33:
      return "WIFI_REASON_NOT_ENOUGH_BANDWIDTH";
    case 34:
      return "WIFI_REASON_MISSING_ACKS";
    case 35:
      return "WIFI_REASON_EXCEEDED_TXOP";
    case 36:
      return "WIFI_REASON_STA_LEAVING";
    case 37:
      return "WIFI_REASON_END_BA";
    case 38:
      return "WIFI_REASON_UNKNOWN_BA";
    case 39:
      return "WIFI_REASON_TIMEOUT";
    case 46:
      return "WIFI_REASON_PEER_INITIATED";
    case 47:
      return "WIFI_REASON_AP_INITIATED";
    case 48:
      return "WIFI_REASON_INVALID_FT_ACTION_FRAME_COUNT";
    case 49:
      return "WIFI_REASON_INVALID_PMKID";
    case 50:
      return "WIFI_REASON_INVALID_MDE";
    case 51:
      return "WIFI_REASON_INVALID_FTE";
    case 67:
      return "WIFI_REASON_TRANSMISSION_LINK_ESTABLISH_FAILED";
    case 68:
      return "WIFI_REASON_ALTERATIVE_CHANNEL_OCCUPIED";
    case 200:
      return "WIFI_REASON_BEACON_TIMEOUT";
    case 201:
      return "WIFI_REASON_NO_AP_FOUND";
    case 202:
      return "WIFI_REASON_AUTH_FAIL";
    case 203:
      return "WIFI_REASON_ASSOC_FAIL";
    case 204:
      return "WIFI_REASON_HANDSHAKE_TIMEOUT";
    case 205:
      return "WIFI_REASON_CONNECTION_FAIL";
    case 206:
      return "WIFI_REASON_AP_TSF_RESET";
    case 207:
      return "WIFI_REASON_ROAMING";
    default:
      return "Error Desconocido";
  }
}

Future<void> writeLarge(String value, int thing, String device,
    {int timeout = 15}) async {
  List<String> sublist = value.split('\n');
  for (var line in sublist) {
    printLog('Mande chunk');
    String datatoSend = '${command(device)}[6]($thing#$line)';
    printLog(datatoSend);
    await myDevice.toolsUuid
        .write(datatoSend.codeUnits, withoutResponse: false);
  }
}

void startBluetoothMonitoring() {
  bluetoothTimer = Timer.periodic(
      const Duration(seconds: 1), (Timer t) => bluetoothStatus());
}

void bluetoothStatus() async {
  FlutterBluePlus.adapterState.listen((state) {
    // print('Estado ble: $state');
    if (state != BluetoothAdapterState.on) {
      bluetoothOn = false;
      showBleText();
    } else if (state == BluetoothAdapterState.on) {
      bluetoothOn = true;
    }
  });
}

void showBleText() async {
  if (!checkbleFlag) {
    checkbleFlag = true;
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff522b5b),
          title: const Text(
            'Bluetooth apagado',
            style: TextStyle(color: Color(0xfffbe4d8)),
          ),
          content: const Text(
            'No se puede continuar sin Bluetooth',
            style: TextStyle(color: Color(0xfffbe4d8)),
          ),
          actions: [
            TextButton(
              style: const ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(Color(0xFFdfb6b2))),
              onPressed: () async {
                if (Platform.isAndroid) {
                  await FlutterBluePlus.turnOn();
                  checkbleFlag = false;
                  bluetoothOn = true;
                  navigatorKey.currentState?.pop();
                } else {
                  checkbleFlag = false;
                  navigatorKey.currentState?.pop();
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }
}

void registerActivity(
    String productCode, String serialNumber, String accion) async {
  try {
    FirebaseFirestore db = FirebaseFirestore.instance;

    String diaDeLaFecha =
        DateTime.now().toString().split(' ')[0].replaceAll('-', '');

    String documentPath = '$productCode:$serialNumber';

    String actionListName = '$diaDeLaFecha:$legajoConectado';

    DocumentReference docRef = db.collection('Registro').doc(documentPath);

    DocumentSnapshot doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        actionListName: FieldValue.arrayUnion([accion])
      }).then((_) {
        printLog("Documento creado exitosamente!");
      }).catchError((error) {
        printLog("Error creando el documento: $error");
      });
    } else {
      printLog("Documento ya existe.");
      await docRef.update({
        actionListName: FieldValue.arrayUnion([accion])
      }).catchError(
          (error) => printLog("Error al añadir item al array: $error"));
    }
  } catch (e, s) {
    printLog('Error al registrar actividad: $e');
    printLog(s);
  }
}

void wifiText(BuildContext context) {
  showDialog(
    barrierDismissible: true,
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text.rich(
                TextSpan(
                  text: 'Estado de conexión: ',
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
              Text.rich(
                TextSpan(
                  text: textState,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Error: $errorMessage',
                  style: const TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: 'Sintax: $errorSintax',
                  style: const TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  const Text.rich(
                    TextSpan(
                      text: 'Red actual: ',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    nameOfWifi,
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              const Text.rich(
                TextSpan(
                  text: 'Ingrese los datos de WiFi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.qr_code,
                ),
                iconSize: 50,
                onPressed: () async {
                  PermissionStatus permissionStatusC =
                      await Permission.camera.request();
                  if (!permissionStatusC.isGranted) {
                    await Permission.camera.request();
                  }
                  permissionStatusC = await Permission.camera.status;
                  if (permissionStatusC.isGranted) {
                    openQRScanner(navigatorKey.currentContext!);
                  }
                },
              ),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Nombre de la red',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(),
                  ),
                ),
                onChanged: (value) {
                  wifiName = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Contraseña',
                  hintStyle: TextStyle(),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(),
                  ),
                ),
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
            style: const ButtonStyle(),
            child: const Text(
              'Aceptar',
            ),
            onPressed: () {
              sendWifitoBle();
              navigatorKey.currentState?.pop();
            },
          ),
        ],
      );
    },
  );
}

void startLocationMonitoring() {
  locationTimer =
      Timer.periodic(const Duration(seconds: 1), (Timer t) => locationStatus());
}

void locationStatus() async {
  await LocationService.isLocationServiceEnabled();
}

Future<void> verificarAccesos(String legajo) async {
  try {
    DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
        .collection('Legajos')
        .doc('Accesos')
        .get();
    if (documentSnapshot.exists) {
      Map<String, dynamic> data =
          documentSnapshot.data() as Map<String, dynamic>;
      List<dynamic> fun0 = data['Total'] ?? [];
      List<dynamic> fun1 = data['Laboratorio'] ?? [];
      List<dynamic> fun2 = data['Customer Service'] ?? [];
      accesoTotal = fun0.contains(legajo);
      accesoLabo = fun1.contains(legajo);
      accesoCS = fun2.contains(legajo);

      printLog('Total: $accesoTotal');
      printLog('Labo: $accesoLabo');
      printLog('CS: $accesoCS');
    }
  } catch (e) {
    printLog('Error verificando accesos $e');
  }
}

Future<bool> tempWasSended(String productCode, String serialNumber) async {
  printLog('Ta bacano');
  try {
    String docPath = '$legajoConectado:$productCode:$serialNumber';
    DocumentSnapshot documentSnapshot =
        await FirebaseFirestore.instance.collection('Data').doc(docPath).get();
    if (documentSnapshot.exists) {
      Map<String, dynamic> data =
          documentSnapshot.data() as Map<String, dynamic>;

      printLog('TempSend: ${data['temp']}');
      data['temp'] == true
          ? tempDate = data['tempDate']
          : tempDate =
              '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
      return data['temp'] ?? false;
    } else {
      printLog('No existe');
      return false;
    }
  } catch (error) {
    printLog('Error al realizar la consulta: $error');
    return false;
  }
}

void registerTemp(String productCode, String serialNumber) async {
  try {
    FirebaseFirestore db = FirebaseFirestore.instance;

    String date =
        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    String documentPath = '$legajoConectado:$productCode:$serialNumber';

    DocumentReference docRef = db.collection('Data').doc(documentPath);

    docRef.set({'temp': true, 'tempDate': date});
  } catch (e, s) {
    printLog('Error al registrar actividad: $e');
    printLog(s);
  }
}

// CLASES //

//*BLUETOOTH*//

class MyDevice {
  static final MyDevice _singleton = MyDevice._internal();

  factory MyDevice() {
    return _singleton;
  }

  MyDevice._internal();

  late BluetoothDevice device;
  late BluetoothCharacteristic infoUuid;
  late BluetoothCharacteristic toolsUuid;
  late BluetoothCharacteristic varsUuid;
  late BluetoothCharacteristic workUuid;
  late BluetoothCharacteristic lightUuid;
  late BluetoothCharacteristic calibrationUuid;
  late BluetoothCharacteristic regulationUuid;
  late BluetoothCharacteristic otaUuid;
  late BluetoothCharacteristic debugUuid;
  late BluetoothCharacteristic ioUuid;
  late BluetoothCharacteristic patitoUuid;

  Future<bool> setup(BluetoothDevice connectedDevice) async {
    try {
      device = connectedDevice;

      List<BluetoothService> services =
          await device.discoverServices(timeout: 3);
      // printLog('Los servicios: $services');

      BluetoothService infoService = services.firstWhere(
          (s) => s.uuid == Guid('6a3253b4-48bc-4e97-bacd-325a1d142038'));
      infoUuid = infoService.characteristics.firstWhere((c) =>
          c.uuid ==
          Guid(
              'fc5c01f9-18de-4a75-848b-d99a198da9be')); //ProductType:SerialNumber:SoftVer:HardVer:Owner
      toolsUuid = infoService.characteristics.firstWhere((c) =>
          c.uuid ==
          Guid(
              '89925840-3d11-4676-bf9b-62961456b570')); //WifiStatus:WifiSSID/WifiError:BleStatus(users)

      infoValues = await infoUuid.read();
      String str = utf8.decode(infoValues);
      var partes = str.split(':');
      var fun = partes[0].split('_');
      factoryMode = partes[2].contains('_F');
      productCode = partes[0];
      deviceType = fun[0];
      serialNumber = partes[1];
      softwareVersion = partes[2];
      hardwareVersion = partes[3];
      printLog('Device: $deviceType');
      printLog('Product code: ${partes[0]}');
      printLog('Serial number: ${extractSerialNumber(device.platformName)}');

      switch (deviceType) {
        case '022000':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //DistanceControl:WorkingTemp:WorkingStatus:EnergyTimer:FlamingStatus:NightMode:actualTemp:Thing?:TempMap?:Offset
          otaUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          break;
        case '027000':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //DistanceControl:WorkingTemp:WorkingStatus:EnergyTimer:FlamingStatus:NightMode:actualTemp:Thing?:TempMap?:Offset
          otaUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          break;
        case '041220':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //DistanceControl:WorkingTemp:WorkingStatus:EnergyTimer:FlamingStatus:NightMode:actualTemp:Thing?:TempMap?:Offset
          otaUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          break;
        case '015773':
          BluetoothService service = services.firstWhere(
              (s) => s.uuid == Guid('dd249079-0ce8-4d11-8aa9-53de4040aec6'));

          if (factoryMode) {
            calibrationUuid = service.characteristics.firstWhere(
                (c) => c.uuid == Guid('0147ab2a-3987-4bb8-802b-315a664eadd6'));
            regulationUuid = service.characteristics.firstWhere(
                (c) => c.uuid == Guid('961d1cdd-028f-47d0-aa2a-e0095e387f55'));
            debugUuid = service.characteristics.firstWhere(
                (c) => c.uuid == Guid('838335a1-ff5a-4344-bfdf-38bf6730de26'));
            BluetoothService otaService = services.firstWhere(
                (s) => s.uuid == Guid('33e3a05a-c397-4bed-81b0-30deb11495c7'));
            otaUuid = otaService.characteristics.firstWhere((c) =>
                c.uuid ==
                Guid(
                    'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          }
          workUuid = service.characteristics.firstWhere(
              (c) => c.uuid == Guid('6869fe94-c4a2-422a-ac41-b2a7a82803e9'));
          lightUuid = service.characteristics.firstWhere(
              (c) => c.uuid == Guid('12d3c6a1-f86e-4d5b-89b5-22dc3f5c831f'));

          break;
        case '020010':
          BluetoothService service = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));
          ioUuid = service.characteristics.firstWhere(
              (c) => c.uuid == Guid('03b1c5d9-534a-4980-aed3-f59615205216'));
          otaUuid = service.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          varsUuid = service.characteristics.firstWhere(
              (c) => c.uuid == Guid('52a2f121-a8e3-468c-a5de-45dca9a2a207'));

          break;
        case '024011':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //DstCtrl:LargoRoller:InversionGiro:VelocidadMotor:PosicionActual:PosicionTrabajo:RollerMoving:AWSinit
          otaUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          break;
        case '019000' || '027170':
          BluetoothService service = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));
          patitoUuid = service.characteristics.firstWhere(
              (c) => c.uuid == Guid('03b1c5d9-534a-4980-aed3-f59615205216'));
          otaUuid = service.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          break;
        case '027313':
          BluetoothService espService = services.firstWhere(
              (s) => s.uuid == Guid('6f2fa024-d122-4fa3-a288-8eca1af30502'));

          varsUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  '52a2f121-a8e3-468c-a5de-45dca9a2a207')); //DistanceControl:WorkingTemp:WorkingStatus:EnergyTimer:FlamingStatus:NightMode:actualTemp:Thing?:TempMap?:Offset
          otaUuid = espService.characteristics.firstWhere((c) =>
              c.uuid ==
              Guid(
                  'ae995fcd-2c7a-4675-84f8-332caf784e9f')); //Ota comandos (Solo notify)
          break;
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      printLog(' $e $stackTrace');

      return Future.value(false);
    }
  }
}

//*-QRPAGE-*//solo scanQR

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});
  @override
  QRScanPageState createState() => QRScanPageState();
}

class QRScanPageState extends State<QRScanPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  AnimationController? animationController;
  bool flashOn = false;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    animation = Tween<double>(begin: 10, end: 350).animate(animationController!)
      ..addListener(() {
        setState(() {});
      });

    animationController!.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),
          // Arriba
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Text('Escanea el QR',
                      style:
                          TextStyle(color: Color.fromRGBO(178, 181, 174, 1))),
                )),
          ),
          // Abajo
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              color: Colors.black54,
            ),
          ),
          // Izquierda
          Positioned(
            top: 250,
            bottom: 250,
            left: 0,
            width: 50,
            child: Container(
              color: Colors.black54,
            ),
          ),
          // Derecha
          Positioned(
            top: 250,
            bottom: 250,
            right: 0,
            width: 50,
            child: Container(
              color: Colors.black54,
            ),
          ),
          // Área transparente con bordes redondeados
          Positioned(
            top: 250,
            left: 50,
            right: 50,
            bottom: 250,
            child: Stack(
              children: [
                Positioned(
                  top: animation.value,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    color: const Color(0xFF1E242B),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    color: const Color(0xFFB2B5AE),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    color: const Color(0xFFB2B5AE),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 3,
                    color: const Color(0xFFB2B5AE),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 3,
                    color: const Color(0xFFB2B5AE),
                  ),
                ),
              ],
            ),
          ),
          // Botón de Flash
          Positioned(
            bottom: 20,
            right: 20,
            child: IconButton(
              icon: Icon(
                flashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () {
                controller?.toggleFlash();
                setState(() {
                  flashOn = !flashOn;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      Future.delayed(const Duration(milliseconds: 800), () {
        try {
          if (navigatorKey.currentState != null &&
              navigatorKey.currentState!.canPop()) {
            navigatorKey.currentState!.pop(scanData.code);
          }
        } catch (e, stackTrace) {
          printLog("Error: $e $stackTrace");
          showToast('Error al leer QR');
        }
      });
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    animationController?.dispose();
    super.dispose();
  }
}

//*-Provider-*//Se actualizan cositas

class GlobalDataNotifier extends ChangeNotifier {
  String? _data;

  // Obtener datos por topic específico
  String getData() {
    return _data ?? 'Esperando respuesta del esp...';
  }

  // Actualizar datos para un topic específico y notificar a los oyentes
  void updateData(String newData) {
    if (_data != newData) {
      _data = newData;
      notifyListeners(); // Esto notifica a todos los oyentes que algo cambió
    }
  }
}

//*-Slider-*//Cositas

class IconThumbSlider extends SliderComponentShape {
  final IconData iconData;
  final double thumbRadius;

  const IconThumbSlider({required this.iconData, required this.thumbRadius});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Draw the thumb as a circle
    final paint = Paint()
      ..color = sliderTheme.thumbColor!
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, thumbRadius, paint);

    // Draw the icon on the thumb
    TextSpan span = TextSpan(
      style: TextStyle(
        fontSize: thumbRadius,
        fontFamily: iconData.fontFamily,
        color: sliderTheme.valueIndicatorColor,
      ),
      text: String.fromCharCode(iconData.codePoint),
    );
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    Offset iconOffset = Offset(
      center.dx - (tp.width / 2),
      center.dy - (tp.height / 2),
    );
    tp.paint(canvas, iconOffset);
  }
}

//*-Location-*//Servicio

class LocationService {
  static const platform =
      MethodChannel('com.sime.biocaldensmartlifefabrica/location');

  static Future<bool> isLocationServiceEnabled() async {
    try {
      final bool isEnabled =
          await platform.invokeMethod('isLocationServiceEnabled');
      return isEnabled;
    } on PlatformException catch (e) {
      // Maneja la excepción aquí si es necesario
      printLog('Error verificando ubi $e');
      return false;
    }
  }

  static Future<void> openLocationOptions() async {
    try {
      platform.invokeListMethod("openLocationSettings");
    } on PlatformException catch (e) {
      printLog('Error abriendo la ubicación $e');
    }
  }
}
