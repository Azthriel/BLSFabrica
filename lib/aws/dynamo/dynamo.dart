import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:biocaldensmartlifefabrica/master.dart';

Future<void> queryItems(DynamoDB service, String pc, String sn) async {
  try {
    final response = await service.query(
      tableName: 'sime-domotica',
      keyConditionExpression: 'product_code = :pk AND device_id = :sk',
      expressionAttributeValues: {
        ':pk': AttributeValue(s: pc),
        ':sk': AttributeValue(s: sn),
      },
    );

    if (response.items != null) {
      printLog('Items encontrados');
      for (var item in response.items!) {
        owner = item['owner']?.s ?? '';
        distanceOn = item['distanceOn']?.n ?? '3000';
        distanceOff = item['distanceOff']?.n ?? '100';
        secAdmDate =
            item['DateSecAdm']?.s ?? 'No tiene activado este beneficio';
        atDate = item['DateAT']?.s ?? 'No tiene activado este beneficio';
        secondaryAdmins = item['secondary_admin']?.ss ?? [];
        if (secondaryAdmins.contains('') && secondaryAdmins.length == 1) {
          secondaryAdmins = [];
        }
      }
    } else {
      printLog('Dispositivo no encontrado');
    }
  } catch (e) {
    printLog('Error durante la consulta: $e');
  }
}

Future<void> putOwner(
    DynamoDB service, String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'owner': AttributeValueUpdate(value: AttributeValue(s: data)),
    });

    printLog('Item escrito perfectamente $response');
  } catch (e) {
    printLog('Error inserting item: $e');
  }
}

Future<void> putDistanceOn(
    DynamoDB service, String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'distanceOn': AttributeValueUpdate(value: AttributeValue(n: data)),
    });

    printLog('Item escrito perfectamente $response');
  } catch (e) {
    printLog('Error inserting item: $e');
  }
}

Future<void> putDistanceOff(
    DynamoDB service, String pc, String sn, String data) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'distanceOff': AttributeValueUpdate(value: AttributeValue(n: data)),
    });

    printLog('Item escrito perfectamente $response');
  } catch (e) {
    printLog('Error inserting item: $e');
  }
}

Future<void> putSecondaryAdmins(
    DynamoDB service, String pc, String sn, List<String> data) async {
  if (data.isEmpty) {
    data.add('');
  }
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      'secondary_admin': AttributeValueUpdate(value: AttributeValue(ss: data)),
    });

    printLog('Item escrito perfectamente $response');
  } catch (e) {
    printLog('Error inserting item: $e');
  }
}

Future<void> putDate(
    DynamoDB service, String pc, String sn, String data, bool at) async {
  try {
    final response = await service.updateItem(tableName: 'sime-domotica', key: {
      'product_code': AttributeValue(s: pc),
      'device_id': AttributeValue(s: sn),
    }, attributeUpdates: {
      at ? 'DateAT' : 'DateSecAdm':
          AttributeValueUpdate(value: AttributeValue(s: data)),
    });

    printLog('Item escrito perfectamente $response');
  } catch (e) {
    printLog('Error inserting item: $e');
  }
}
