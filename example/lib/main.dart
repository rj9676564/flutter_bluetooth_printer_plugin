import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
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
  BluetoothDevice? bluetoothDevice;

  @override
  void initState() {
    printer.scanResults.listen((List<BluetoothDevice> event) {
      setState(() {
        _devices = event;
      });
      log(":==============");
      for (BluetoothDevice device in event) {
        log(device.name);
        if (device.name == "BLU58") {
          bluetoothDevice = device;
        }
      }
    });
    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> startScan() async {
    printer.startScan();
  }

  isEnable() async {
    var result = await printer.isEnabled();
    log("is enable $result");
  }

  BluetoothPrinter printer = BluetoothPrinter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Column(
            children: [
              TextButton(
                onPressed: () => isEnable,
                child: const Text('isEnable'),
              ),
              TextButton(
                  onPressed: () => startScan(), child: const Text('startScan')),
              TextButton(
                  onPressed: () => printer.stopScan(),
                  child: const Text('stopScan')),
              TextButton(
                  onPressed: () {
                    log("connect  ==== ${bluetoothDevice?.name}");
                    bluetoothDevice?.connect();
                  },
                  child: const Text('connect')),
              TextButton(
                  onPressed: () {
                    log("connect  ==== ${bluetoothDevice?.name}");
                    bluetoothDevice?.disconnect();
                  },
                  child: const Text('disconnect')),
              TextButton(
                  onPressed: () {
                    List<int> list = 'username=zwj\n\n\n'.codeUnits;
                    Uint8List bytes = Uint8List.fromList(list);
                    Uint8List bytes2 = Uint8List.fromList([0x1D, 0x21, 8]);
                    bluetoothDevice?.printBytes(
                        bytes: bytes2,
                        progress: (int total, int progress) {
                          log("progress2 = $progress  total  == $total");
                        });
                    log("connect  ==== ${bluetoothDevice?.name}");
                    bluetoothDevice?.printBytes(
                        bytes: bytes,
                        progress: (int total, int progress) {
                          log("progress = $progress  total  == $total");
                        });
                  },
                  child: const Text('print')),
              ..._devices.map((e) {
                return InkWell(
                    onTap: () => bluetoothDevice = e,
                    child: Container(
                      child: Text("${e.name}=="),
                      padding: const EdgeInsets.all(8),
                    ));
              })
            ],
          )),
    );
  }
}
