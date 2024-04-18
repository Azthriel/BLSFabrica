import 'package:biocaldensmartlifefabrica/master.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController legajoController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final FocusNode passNode = FocusNode();

  Future<void> verificarCredenciales() async {
    printLog('Entro aquís');
    try {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('Legajos')
          .doc(legajoController.text.trim())
          .get();
      if (documentSnapshot.exists) {
        Map<String, dynamic> data =
            documentSnapshot.data() as Map<String, dynamic>;
        if (data['pass'] == passController.text.trim()) {
          showToast('Inicio de sesión exitoso');
          legajoConectado = legajoController.text.trim();
          navigatorKey.currentState?.pushReplacementNamed('/menu');
          printLog('Inicio de sesión exitoso');
        } else {
          showToast('Contraseña incorrecta');
          printLog('Credenciales incorrectas');
        }
      } else {
        showToast('Legajo inexistente');
      }
    } catch (error) {
      printLog('Error al realizar la consulta: $error');
    }
  }

//!Visual
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xff190019),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 200,
                  child: Image.asset('assets/Fabrica/logo.png'),
                ),
                const SizedBox(height: 50),
                SizedBox(
                    width: 300,
                    child: TextField(
                      style: const TextStyle(color: Color(0xfffbe4d8)),
                      controller: legajoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ingrese su legajo',
                        labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                        hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                      ),
                      onSubmitted: (value) {
                        passNode.requestFocus();
                      },
                    )),
                const SizedBox(height: 20),
                SizedBox(
                    width: 300,
                    child: TextField(
                      style: const TextStyle(color: Color(0xfffbe4d8)),
                      focusNode: passNode,
                      controller: passController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ingrese su contraseña',
                        labelStyle: TextStyle(color: Color(0xfffbe4d8)),
                        hintStyle: TextStyle(color: Color(0xfffbe4d8)),
                      ),
                      onSubmitted: (value) {
                        verificarCredenciales();
                      },
                    )),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => verificarCredenciales(),
                  child: const Text('Ingresar'),
                ),
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
