import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'dart:async';

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
      home: BulbControlPage(),
    );
  }
}


class BulbControlPage extends StatefulWidget {
  const BulbControlPage({super.key});

  @override
  _BulbControlPageState createState() => _BulbControlPageState();
}

class _BulbControlPageState extends State<BulbControlPage> {
  void onDataReceived(Uint8List data) {
    String incoming = String.fromCharCodes(data);
    dataBuffer += incoming;
    if (dataBuffer.contains('\n')) {
      List<String> parts = dataBuffer.split('\n');
      for (int i = 0; i < parts.length - 1; i++) {
        String line = parts[i].trim();
        if (line.startsWith("Random Value: ")) {
          String valueStr = line.replaceAll("Random Value: ", "");
          int? parsed = int.tryParse(valueStr);
          if (parsed != null) {
            setState(() {
              latestValue = parsed;
            });
          }
        }
      }
      dataBuffer = parts.last; // Keep leftover
    }
  }

  void connectToBluetooth() async {
    List<BluetoothDevice> bondedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();

    BluetoothDevice? targetDevice;
    for (BluetoothDevice device in bondedDevices) {
      if (device.name == targetDeviceName) {
        targetDevice = device;
        break;
      }
    }

    if (targetDevice == null) {
      if (!_disposed) {
        setState(() {
          status = "HC-05 not found. Pair it first.";
          isConnecting = false;
        });
      }
      return;
    }

    try {
      BluetoothConnection toDevice =
          await BluetoothConnection.toAddress(targetDevice.address);
      if (!_disposed) {
        setState(() {
          connection = toDevice;
          status = "Connected to ${(targetDevice != null && targetDevice.name != null) ? targetDevice.name : "HC-05"}";
          isConnecting = false;
        });
      }

      connection!.input!.listen(onDataReceived).onDone(() {
        if (!_disposed) {
          setState(() {
            status = "Disconnected.";
          });
        }
      });
    } catch (e) {
      if (!_disposed) {
        setState(() {
          status = "Connection failed.";
          isConnecting = false;
        });
      }
    }
  }
  BluetoothConnection? connection;
  String dataBuffer = "";
  int latestValue = 0;
  bool isConnecting = true;
  String status = "Connecting...";
  final String targetDeviceName = "HC-05";
  bool bulbOn = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    connectToBluetooth();
  }

  Future<void> requestPermissionsAndScan() async {
    // ...existing code...
  }

  void scanAndConnect() async {
    setState(() {
      isConnecting = true;
      status = "Scanning...";
    });
    connectToBluetooth();
  }

  void toggleBulb() async {
    if (connection != null && connection!.isConnected) {
      try {
        String command = bulbOn ? "0" : "1";
        connection!.output.add(Uint8List.fromList(command.codeUnits));
        await connection!.output.allSent;
        setState(() {
          bulbOn = !bulbOn;
        });
      } catch (e) {
        setState(() {
          status = "Connection lost. Please reconnect.";
        });
        connection = null;
      }
    } else {
      setState(() {
        status = "Not connected.";
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    connection?.dispose();
    super.dispose();
  void onDataReceived(Uint8List data) {
    if (connection == null || !connection!.isConnected) return;
    String incoming = String.fromCharCodes(data);
    dataBuffer += incoming;
    if (dataBuffer.contains('\n')) {
      List<String> parts = dataBuffer.split('\n');
      for (int i = 0; i < parts.length - 1; i++) {
        String line = parts[i].trim();
        if (line.startsWith("Random Value: ")) {
          String valueStr = line.replaceAll("Random Value: ", "");
          int? parsed = int.tryParse(valueStr);
          if (parsed != null) {
            setState(() {
              latestValue = parsed;
            });
          }
        }
      }
      dataBuffer = parts.last; // Keep leftover
    }
  }

  void connectToBluetooth() async {
    List<BluetoothDevice> bondedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();

    BluetoothDevice? targetDevice;
    for (BluetoothDevice device in bondedDevices) {
      if (device.name == targetDeviceName) {
        targetDevice = device;
        break;
      }
    }

    if (targetDevice == null) {
      if (!_disposed) {
        setState(() {
          status = "HC-05 not found. Pair it first.";
          isConnecting = false;
        });
      }
      return;
    }

    try {
      BluetoothConnection toDevice =
          await BluetoothConnection.toAddress(targetDevice.address);
      if (!_disposed) {
        setState(() {
          connection = toDevice;
          status = "Connected to ${(targetDevice != null && targetDevice.name != null) ? targetDevice.name : "HC-05"}";
          isConnecting = false;
        });
      }

      connection!.input!.listen(onDataReceived).onDone(() {
        if (!_disposed) {
          setState(() {
            status = "Disconnected.";
          });
          connection = null;
        }
      });
    } catch (e) {
      if (!_disposed) {
        setState(() {
          status = "Connection failed.";
          isConnecting = false;
        });
        connection = null;
      }
    }
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bluetooth Bulb Controller')),
      body: Center(
        child: isConnecting
            ? ((status == "Device not found." || status == "Device not found. Please try again.")
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_disabled, color: Colors.red, size: 80),
                      SizedBox(height: 20),
                      Text(
                        status,
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            minimumSize: Size(160, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            scanAndConnect();
                          },
                          label: Text(
                            "Scan Again",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        status,
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      if (status == "Connection failed.")
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.refresh),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              minimumSize: Size(160, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              scanAndConnect();
                            },
                            label: Text(
                              "Scan Again",
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  )
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
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
                    SizedBox(height: 30),
                    // Arduino value round progress UI
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      color: Colors.blue[50],
                      child: Container(
                        width: 220,
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Arduino Value',
                              style: TextStyle(fontSize: 16, color: Colors.blue[800], fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    value: latestValue / 100.0,
                                    strokeWidth: 10,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                  ),
                                ),
                                Text(
                                  "$latestValue",
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text("Value Progress", style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      status,
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: Size(160, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          scanAndConnect();
                        },
                        label: Text(
                          "Scan Again",
                          style: TextStyle(fontSize: 18, color: Colors.white),
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
