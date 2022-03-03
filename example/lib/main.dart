import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<BluetoothDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    scan();
    if (!mounted) return;
  }

  BluetoothDevice? bluetoothDevice;
  BluetoothPrinter bluetoothPrint = BluetoothPrinter();

  scan() {
    bluetoothPrint.startScan();
    bluetoothPrint.scanResults.listen((List<BluetoothDevice> event) {
      log(":==============${event.length}");
      setState(() {
        _devices = event;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () {
                    scan();
                  },
                  child: Text('Scan'),
                ),
                InkWell(
                  onTap: () {
                    List<int> user = 'username1\n\n\n'.codeUnits;
                    Uint8List bytes = Uint8List.fromList([...user]);
                    bluetoothDevice?.printBytes(bytes: bytes);
                  },
                  child: Container(
                    child: Text('print'),
                    padding: EdgeInsets.all(8),
                    color: Colors.red,
                  ),
                ),
                InkWell(
                  onTap: () {

                    bluetoothDevice?.disconnect();
                  },
                  child: Container(
                    child: Text('disconnect'),
                    padding: EdgeInsets.all(8),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ..._devices.map((BluetoothDevice e) {
                      return InkWell(
                        onTap: () async {
                          await e.connect();
                          bluetoothDevice = e;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Text(e.name),
                          width: 200,
                          decoration: const BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: Colors.grey)),
                          ),
                        ),
                      );
                    }).toList()
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
