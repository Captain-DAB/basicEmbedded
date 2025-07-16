import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  bool bulbOn = false;
  bool isConnecting = false;
  String status = "";

  final String targetDeviceName = "HC-05";

  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? scanSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for Bluetooth state changes
    adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        adapterState = state;
        if (state != BluetoothAdapterState.on) {
          isConnecting = false;
          status = "Please turn on Bluetooth";
        } else {
          // Bluetooth is ON, allow scan again
          if (device == null || status == "Please turn on Bluetooth") {
            status = "Device not found. Please try again.";
          }
        }
      });
    });
    requestPermissionsAndScan();
  }

  Future<void> requestPermissionsAndScan() async {
    // Request Bluetooth and location permissions
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    // Turn on Bluetooth (no await needed)
    FlutterBluePlus.turnOn();

    // Wait until the adapter is ON
    await FlutterBluePlus.adapterState.firstWhere(
      (state) => state == BluetoothAdapterState.on,
    );

    scanAndConnect();
  }

  void scanAndConnect() async {
    if (adapterState != BluetoothAdapterState.on) {
      setState(() {
        isConnecting = false;
        status = "Please turn on Bluetooth";
      });
      return;
    }
    setState(() {
      isConnecting = true;
      status = "Scanning for device...";
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
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
                if (c.properties.write) {
                  characteristic = c;
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
        // If scan finished and device not found, show message and stop
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
      },
    );
  }

  void toggleBulb() async {
    if (characteristic != null) {
      String command = bulbOn ? "0" : "1";
      await characteristic!.write(command.codeUnits);
      setState(() {
        bulbOn = !bulbOn;
      });
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    adapterStateSubscription?.cancel();
    device?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Bulb Controller'),
      ),
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
