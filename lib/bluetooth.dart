// For performing some operations asynchronously
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

// For using PlatformException
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  // Initializing the Bluetooth connection state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  // Initializing a global key, as it would help us in showing a SnackBar later
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  // Get the instance of the Bluetooth
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  // Track the Bluetooth connection with the remote device
  BluetoothConnection? connection;

  late int _deviceState;

  bool isDisconnecting = false;

  Map<String, Color> colors = {
    'onBorderColor': Colors.green,
    'offBorderColor': Colors.red,
    'neutralBorderColor': Colors.transparent,
    'onTextColor': Colors.green.shade700,
    'offTextColor': Colors.red.shade200,
    'neutralTextColor': Colors.blue,
  };

  // To track whether the device is still connected to Bluetooth
  bool get isConnected => connection != null && connection!.isConnected;

  // Define some variables, which will be required later
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _device = null;
  bool _connected = false;
  bool _isButtonUnavailable = false;
  List<double> fData = List<double>.filled(11, 0.0); // formatted data

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    _deviceState = 0; // neutral

    // If the bluetooth of the device is not enabled,
    // then request permission to turn on bluetooth
    // as the app starts up
    enableBluetooth();

    // Listen for further state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (_bluetoothState == BluetoothState.STATE_OFF) {
          _isButtonUnavailable = true;
        }
        getPairedDevices();
      });
    });
  }

  @override
  void dispose() {
    // Avoid memory leak and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection!.dispose();
      //connection = null;
    }

    super.dispose();
  }

  // Request Bluetooth permission from the user
  Future<bool?> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  // For retrieving and storing the paired devices
  // in a list.
  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // To get the list of paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  // Now, its time to build the UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("Flutter Bluetooth"),
          backgroundColor: Colors.deepPurple,
          actions: <Widget>[
            TextButton.icon(
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                "Refresh",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              // shape: RoundedRectangleBorder(
              //   borderRadius: BorderRadius.circular(30),
              // ),
              // splashColor: Colors.deepPurple,
              onPressed: () async {
                // So, that when new devices are paired
                // while the app is running, user can refresh
                // the paired devices list.
                await getPairedDevices().then((_) {
                  show('Device list refreshed');
                });
              },
            ),
          ],
        ),
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Visibility(
                visible: _isButtonUnavailable &&
                    _bluetoothState == BluetoothState.STATE_ON,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.yellow,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Enable Bluetooth',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Switch(
                      value: _bluetoothState.isEnabled,
                      onChanged: (bool value) {
                        future() async {
                          if (value) {
                            await FlutterBluetoothSerial.instance
                                .requestEnable();
                          } else {
                            await FlutterBluetoothSerial.instance
                                .requestDisable();
                          }

                          await getPairedDevices();
                          _isButtonUnavailable = false;

                          if (_connected) {
                            _disconnect();
                          }
                        }

                        future().then((_) {
                          setState(() {});
                        });
                      },
                    )
                  ],
                ),
              ),
              Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      // Padding(
                      //   padding: const EdgeInsets.only(top: 10),
                      //   child: Text(
                      //     "PAIRED DEVICES",
                      //     style: TextStyle(fontSize: 24, color: Colors.blue),
                      //     textAlign: TextAlign.center,
                      //   ),
                      // ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              // Text(
                              //   'Device:',
                              //   style: TextStyle(
                              //     fontWeight: FontWeight.bold,
                              //   ),
                              // ),
                              DropdownButton<BluetoothDevice>(
                                items: _getDeviceItems(),
                                onChanged: (value) =>
                                    setState(() => _device = value!),
                                value: _devicesList.isNotEmpty ? _device : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isButtonUnavailable
                            ? null
                            : _connected
                                ? _disconnect
                                : _connect,
                        child: Text(_connected ? 'Disconnect' : 'Connect'),
                      ),
                      Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text('x:'),
                                  ),
                                  Container(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(fData[0].toStringAsFixed(2)),
                                  ),
                                  Container(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text('y:'),
                                  ),
                                  Container(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(fData[1].toStringAsFixed(2)),
                                  ),
                                  Container(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text('z:'),
                                  ),
                                  Container(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(fData[2].toStringAsFixed(2)),
                                  ),
                                  // Text('x: ${fData[0].toStringAsFixed(2)}'),
                                  // Text('y: ${fData[1].toStringAsFixed(2)}'),
                                  // Text('z: ${fData[2].toStringAsFixed(2)}'),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text('xa: ${fData[3].toStringAsFixed(2)}'),
                                  Text('ya: ${fData[4].toStringAsFixed(2)}'),
                                  Text('za: ${fData[5].toStringAsFixed(2)}'),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text('xr: ${fData[5].toStringAsFixed(2)}'),
                                  Text('yr: ${fData[6].toStringAsFixed(2)}'),
                                  Text('zr: ${fData[7].toStringAsFixed(2)}'),
                                ],
                              ),
                            ],
                          )),
                      // Padding(
                      //   padding: const EdgeInsets.all(16.0),
                      //   child: Card(
                      //     shape: RoundedRectangleBorder(
                      //       side: new BorderSide(
                      //         color: _deviceState == 0
                      //             ? colors['neutralBorderColor']!
                      //             : _deviceState == 1
                      //                 ? colors['onBorderColor']!
                      //                 : colors['offBorderColor']!,
                      //         width: 3,
                      //       ),
                      //       borderRadius: BorderRadius.circular(4.0),
                      //     ),
                      //     elevation: _deviceState == 0 ? 4 : 0,
                      //     child: Padding(
                      //       padding: const EdgeInsets.all(8.0),
                      //       child: Row(
                      //         children: <Widget>[
                      //           Expanded(
                      //             child: Text(
                      //               "DEVICE 1",
                      //               style: TextStyle(
                      //                 fontSize: 20,
                      //                 color: _deviceState == 0
                      //                     ? colors['neutralTextColor']
                      //                     : _deviceState == 1
                      //                         ? colors['onTextColor']
                      //                         : colors['offTextColor'],
                      //               ),
                      //             ),
                      //           ),
                      //           // TextButton(
                      //           //   onPressed: _connected
                      //           //       ? _sendOnMessageToBluetooth
                      //           //       : null,
                      //           //   child: Text("ON"),
                      //           // ),
                      //           // TextButton(
                      //           //   onPressed: _connected
                      //           //       ? _sendOffMessageToBluetooth
                      //           //       : null,
                      //           //   child: Text("OFF"),
                      //           // ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                  Container(
                    color: Colors.blue,
                  ),
                ],
              ),
              // Expanded(
              //   child: Padding(
              //     padding: const EdgeInsets.all(20),
              //     child: Center(
              //       child: Column(
              //         mainAxisAlignment: MainAxisAlignment.center,
              //         children: <Widget>[
              //           Text(
              //             "NOTE: If you cannot find the device in the list, please pair the device by going to the bluetooth settings",
              //             style: TextStyle(
              //               fontSize: 15,
              //               fontWeight: FontWeight.bold,
              //               color: Colors.red,
              //             ),
              //           ),
              //           SizedBox(height: 15),
              //           ElevatedButton(
              //             //elevation: 2,
              //             child: Text("Bluetooth Settings"),
              //             onPressed: () {
              //               FlutterBluetoothSerial.instance.openSettings();
              //             },
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
              // )
            ],
          ),
        ),
      ),
    );
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name!),
          value: device,
        ));
      });
    }
    return items;
  }

  // Method to connect to bluetooth
  void _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('No device selected');
    } else {
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device!.address)
            .then((_connection) {
          print('Connected to the device');
          connection = _connection;
          setState(() {
            _connected = true;
          });

          connection!.input!.listen(_onDataReceived).onDone(() {
            if (isDisconnecting) {
              print('Disconnecting locally!');
            } else {
              print('Disconnected remotely!');
            }
            if (this.mounted) {
              setState(() {});
            }
          });
        }).catchError((error) {
          print('Cannot connect, exception occurred');
          print(error);
        });
        show('Device connected');

        setState(() => _isButtonUnavailable = false);
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    //print(data);
    List<int> queuBuffer = List.empty(growable: true);
    if (data.length > 0) {
      for (int i = 0; i < data.length; i++) {
        if (data[i] > 127) {
          int temp = data[i] - 256;
          queuBuffer.add(temp);
        } else {
          queuBuffer.add(data[i]);
        }
      }
    }
    //print(queuBuffer);
    int sHead;
    List<int> packeBuffer = List<int>.filled(9, 0);

    while (queuBuffer.length >= 11) {
      var temp = queuBuffer.first;
      queuBuffer.removeAt(0);
      //print('temp: $temp');
      if (temp == 85) {
        sHead = queuBuffer.first;
        //print('sHead: $sHead');
        queuBuffer.removeAt(0);
        for (int i = 0; i <= 8; i++) {
          packeBuffer[i] = queuBuffer.first;
          //packeBuffer.add(queuBuffer.first);
          queuBuffer.removeAt(0);
        }
        switch (sHead) {
          case 81:
            fData[0] = (packeBuffer[1].abs().toInt() << 8 |
                    (packeBuffer[0].abs().toInt() & 0xff)) /
                32768.0 *
                16;

            fData[1] = (packeBuffer[3].abs().toInt() << 8 |
                    (packeBuffer[2].abs().toInt() & 0xff)) /
                32768.0 *
                16;
            fData[2] = (packeBuffer[5].abs().toInt() << 8 |
                    (packeBuffer[4].abs().toInt() & 0xff)) /
                32768.0 *
                16;
            if (packeBuffer[1] < 0 && packeBuffer[0] < 0) {
              fData[0] = fData[0] * -1;
            }
            if (packeBuffer[3] < 0 && packeBuffer[2] < 0) {
              fData[1] = fData[0] * -1;
            }
            if (packeBuffer[5] < 0 && packeBuffer[4] < 0) {
              fData[2] = fData[0] * -1;
            }
            //print('${fData[0]}, ${fData[1]}, ${fData[2]}');
            break;
          case 82:
            fData[3] = (packeBuffer[1].abs().toInt() << 8 |
                    (packeBuffer[0].abs().toInt() & 0xff)) /
                32768.0 *
                2000;

            fData[4] = (packeBuffer[3].abs().toInt() << 8 |
                    (packeBuffer[2].abs().toInt() & 0xff)) /
                32768.0 *
                2000;
            fData[5] = (packeBuffer[5].abs().toInt() << 8 |
                    (packeBuffer[4].abs().toInt() & 0xff)) /
                32768.0 *
                2000;
            if (packeBuffer[1] < 0 && packeBuffer[0] < 0) {
              fData[3] = fData[3] * -1;
            }
            if (packeBuffer[3] < 0 && packeBuffer[2] < 0) {
              fData[4] = fData[4] * -1;
            }
            if (packeBuffer[5] < 0 && packeBuffer[4] < 0) {
              fData[5] = fData[5] * -1;
            }
            //print('${fData[3]}, ${fData[4]}, ${fData[5]}');
            break;
          case 83:
            fData[6] = (packeBuffer[1].abs().toInt() << 8 |
                    (packeBuffer[0].abs().toInt() & 0xff)) /
                32768.0 *
                180;

            fData[7] = (packeBuffer[3].abs().toInt() << 8 |
                    (packeBuffer[2].abs().toInt() & 0xff)) /
                32768.0 *
                180;
            fData[8] = (packeBuffer[5].abs().toInt() << 8 |
                    (packeBuffer[4].abs().toInt() & 0xff)) /
                32768.0 *
                180;
            if (packeBuffer[1] < 0 && packeBuffer[0] < 0) {
              fData[6] = fData[6] * -1;
            }
            if (packeBuffer[3] < 0 && packeBuffer[2] < 0) {
              fData[7] = fData[7] * -1;
            }
            if (packeBuffer[5] < 0 && packeBuffer[4] < 0) {
              fData[8] = fData[8] * -1;
            }
            //print('${fData[3]}, ${fData[4]}, ${fData[5]}');
            break;
        }
      }
    }
    setState(() {});
  }

  // Method to disconnect bluetooth
  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
      _deviceState = 0;
    });

    await connection!.close();
    show('Device disconnected');
    if (!connection!.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  // // Method to send message,
  // // for turning the Bluetooth device on
  // void _sendOnMessageToBluetooth() async {
  //   connection.output.add(utf8.encode("1" + "\r\n"));
  //   await connection.output.allSent;
  //   show('Device Turned On');
  //   setState(() {
  //     _deviceState = 1; // device on
  //   });
  // }

  // // Method to send message,
  // // for turning the Bluetooth device off
  // void _sendOffMessageToBluetooth() async {
  //   connection.output.add(utf8.encode("0" + "\r\n"));
  //   await connection.output.allSent;
  //   show('Device Turned Off');
  //   setState(() {
  //     _deviceState = -1; // device off
  //   });
  // }

  // Method to show a Snackbar,
  // taking message as the text
  Future show(
    String message, {
    Duration duration: const Duration(seconds: 3),
  }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    _scaffoldKey.currentState!.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }
}