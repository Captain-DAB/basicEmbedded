import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class HardwareInputPage extends StatefulWidget {
  @override
  _HardwareInputPageState createState() => _HardwareInputPageState();
}

class _HardwareInputPageState extends State<HardwareInputPage> {
  BluetoothConnection? connection;
  String dataBuffer = "";
  int latestValue = 0;
  bool isConnecting = true;
  String status = "Connecting...";
  final String targetDeviceName = "HC-05";

  @override
  void initState() {
    super.initState();
    connectToBluetooth();
  }

  bool _disposed = false;

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
          status = "Connected to ${targetDevice!.name}";
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

  @override
  void dispose() {
    _disposed = true;
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Live Arduino Data")),
      body: isConnecting
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    status,
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 30),
                  Text(
                    "$latestValue",
                    style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: latestValue / 100.0,
                    minHeight: 20,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                  SizedBox(height: 10),
                  Text("Value Progress", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
    );
  }
}
