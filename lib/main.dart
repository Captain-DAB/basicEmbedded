import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'dart:async';
import 'hardware_input_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Bulb Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bluetooth Demo Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BulbControlPage()),
                );
              },
              child: Text('Bulb Control', style: TextStyle(fontSize: 20)),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HardwareInputPage()),
                );
              },
              child: Text('Hardware Input', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

class BulbControlPage extends StatefulWidget {
  const BulbControlPage({super.key});

  @override
  _BulbControlPageState createState() => _BulbControlPageState();
}

class _BulbControlPageState extends State<BulbControlPage> {
  BluetoothConnection? connection;
  bool bulbOn = false;
  bool isConnecting = false;
  String status = "";
  final String targetDeviceName = "HC-05";
  BluetoothState bluetoothState = BluetoothState.UNKNOWN;
  StreamSubscription<BluetoothState>? bluetoothStateSubscription;

  @override
  void initState() {
    super.initState();
    bluetoothStateSubscription = FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((state) {
          setState(() {
            bluetoothState = state;
            if (state != BluetoothState.STATE_ON) {
              isConnecting = false;
              status = "Please turn on Bluetooth";
            } else {
              if (connection == null || status == "Please turn on Bluetooth") {
                status = "Device not found. Please try again.";
              }
            }
          });
        });
    requestPermissionsAndScan();
  }

  Future<void> requestPermissionsAndScan() async {
    // No additional permissions needed, handled by plugin
    // Ensure Bluetooth is enabled
    if (bluetoothState != BluetoothState.STATE_ON) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
    scanAndConnect();
  }

  void scanAndConnect() async {
    if (bluetoothState != BluetoothState.STATE_ON) {
      setState(() {
        isConnecting = false;
        status = "Please turn on Bluetooth";
      });
      return;
    }
    setState(() {
      isConnecting = true;
      status = "Scanning...";
    });
    List<BluetoothDevice> bondedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    BluetoothDevice? targetDevice;
    for (BluetoothDevice d in bondedDevices) {
      if (d.name == targetDeviceName) {
        targetDevice = d;
        break;
      }
    }
    if (targetDevice != null) {
      setState(() {
        status = "Connecting...";
      });
      try {
        connection = await BluetoothConnection.toAddress(targetDevice.address);
        setState(() {
          isConnecting = false;
          status = "Connected!";
        });
      } catch (e) {
        setState(() {
          isConnecting = false;
          status = "Connection failed.";
        });
        print("Connection failed: $e");
      }
    } else {
      setState(() {
        isConnecting = false;
        status = "Device not found.";
      });
    }
  }

  void toggleBulb() async {
    if (connection != null && connection!.isConnected) {
      String command = bulbOn ? "0" : "1";
      connection!.output.add(Uint8List.fromList(command.codeUnits));
      await connection!.output.allSent;
      setState(() {
        bulbOn = !bulbOn;
      });
    }
  }

  @override
  void dispose() {
    bluetoothStateSubscription?.cancel();
    connection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bluetooth Bulb Controller')),
      body: Center(
        child:
            isConnecting
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      status,
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      bulbOn ? Icons.lightbulb : Icons.lightbulb_outline,
                      color: bulbOn ? Colors.green : Colors.red,
                      size: 100,
                    ),
                    SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bulbOn ? Colors.green : Colors.red,
                        minimumSize: Size(200, 80),
                      ),
                      onPressed: toggleBulb,
                      child: Text(
                        bulbOn ? "Turn Bulb OFF" : "Turn Bulb ON",
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      status,
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    if (status == "Device not found. Please try again.")
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ElevatedButton(
                          onPressed: () {
                            scanAndConnect();
                          },
                          child: Text(
                            "Scan Again",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

// Arduino code
// #define BULB_PIN 8

// void setup() {
//   pinMode(BULB_PIN, OUTPUT);
//   digitalWrite(BULB_PIN, LOW); // Bulb OFF
//   Serial.begin(9600);
// }

// void loop() {
//   if (Serial.available()) {
//     char cmd = Serial.read();
//     if (cmd == '1') {
//       digitalWrite(BULB_PIN, HIGH); // Bulb ON
//     } else if (cmd == '0') {
//       digitalWrite(BULB_PIN, LOW); // Bulb OFF
//     }
//   }
// }
