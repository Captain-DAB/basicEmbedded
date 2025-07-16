import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class HardwareInputPage extends StatefulWidget {
  const HardwareInputPage({super.key});

  @override
  _HardwareInputPageState createState() => _HardwareInputPageState();
}

class _HardwareInputPageState extends State<HardwareInputPage> {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;
  List<String> values = ["-", "-", "-", "-"];
  bool isConnecting = false;
  String status = "";
  final String targetDeviceName = "HC-05";
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<List<int>>? dataSubscription;

  @override
  void initState() {
    super.initState();
    scanAndConnect();
  }

  void scanAndConnect() async {
    setState(() {
      isConnecting = true;
      status = "Scanning for device...";
    });
    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      bool found = false;
      for (ScanResult r in results) {
        if (r.device.name == targetDeviceName) {
          found = true;
          FlutterBluePlus.stopScan();
          device = r.device;
          setState(() { status = "Connecting to device..."; });
          await device!.connect();
          List<BluetoothService> services = await device!.discoverServices();
          for (BluetoothService service in services) {
            for (BluetoothCharacteristic c in service.characteristics) {
              if (c.properties.notify || c.properties.read) {
                characteristic = c;
                await c.setNotifyValue(true);
                dataSubscription = c.value.listen((data) {
                  setState(() {
                    String str = String.fromCharCodes(data);
                    values = str.split(",");
                    if (values.length < 4) {
                      values = List<String>.filled(4, "-");
                    }
                  });
                });
                break;
              }
            }
          }
          setState(() {
            isConnecting = false;
            status = "Connected!";
          });
          break;
        }
      }
      if (!found) {
        Future.delayed(const Duration(seconds: 5), () {
          if (!found && mounted && device == null) {
            setState(() {
              isConnecting = false;
              status = "Device not found. Please try again.";
            });
            scanSubscription?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    dataSubscription?.cancel();
    device?.disconnect();
    super.dispose();
  }

  Widget valueCard(String label, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 120,
        height: 120,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 18, color: color)),
            SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hardware Output via Bluetooth')),
      body: Center(
        child: isConnecting
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(status, style: TextStyle(fontSize: 18)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Live Hardware Values', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      valueCard('Value 1', values[0], Colors.blue),
                      SizedBox(width: 16),
                      valueCard('Value 2', values[1], Colors.green),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      valueCard('Value 3', values[2], Colors.orange),
                      SizedBox(width: 16),
                      valueCard('Value 4', values[3], Colors.purple),
                    ],
                  ),
                  SizedBox(height: 30),
                  Text(status, style: TextStyle(fontSize: 18)),
                  if (status == "Device not found. Please try again.")
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: ElevatedButton(
                        onPressed: () {
                          scanAndConnect();
                        },
                        child: Text("Scan Again", style: TextStyle(fontSize: 18)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
