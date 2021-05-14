import 'dart:async';

@JS('midi_command')
import 'package:js/js.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';

class FlutterMidiCommandWeb extends MidiCommandPlatform {
  late html.Window _window;

  html.MidiAccess? _access;

  StreamController<Uint8List> _rxStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> _rxStream = StreamController<Uint8List>.broadcast().stream;
  StreamController<String> _setupStreamController = StreamController<String>.broadcast();
  Stream<String>? _setupStream;

  /// A constructor that allows tests to override the window object used by the plugin.
  FlutterMidiCommandWeb({@visibleForTesting html.Window? window}) {
    _window = window ?? html.window;
    _requestMidiAccess();
  }

  /// Registers this class as the default instance of [UrlLauncherPlatform].
  static void registerWith(Registrar registrar) {
    print("register web impl");
    MidiCommandPlatform.instance = FlutterMidiCommandWeb();
  }

  _requestMidiAccess() async {
    print("request midi access");
    _window.navigator.requestMidiAccess({'sysex': true}).then((value) {
      print("succes $value");
      _access = value;
      print('inputs ${_access!.inputs}');
      print('outputs ${_access!.outputs}');

      _access!.on['statechange'].listen(_handleMIDIStateChange);
    });
  }

  void handler(html.MidiAccess access) {
    print("access $access");
  }

  @override
  Future<List<MidiDevice>?> get devices async {
    // var devs = await _methodChannel.invokeMethod('getDevices');
    // return devs.map<MidiDevice>((m) {
    //   var map = m.cast<String, Object>();
    //   return MidiDevice(map["id"], map["name"], map["type"], map["connected"] == "true");
    // }).toList();

    _access!.inputs!.forEach((key, value) {
      print("input key ${key} ${value}");
      // print("Input port [type:'${element.type}'] id:'${element.id}' manufacturer:'${element.manufacturer}' name:'${element.name}' version:'${element.version}'");
      // element.value.onMidiMessage.listen(_handleMidiIn);
      // html.MidiPort inPort = element as html.MidiPort;
      // value.on['midimessage'].listen(_handleMidiIn);
    });

    _access!.outputs!.forEach((key, value) {
      print("output ${key} ${value}");
    });

    return Future.value(null);
  }

  _handleMIDIStateChange(evt) {
    var connEvt = evt as html.MidiConnectionEvent;
    print("state ${connEvt.port}");
    _setupStreamController.sink.add(connEvt.type);
  }

  _handleMidiIn(html.MidiMessageEvent evt) {
    print("midi in $evt");
  }

  /// Starts scanning for BLE MIDI devices.
  ///
  /// Found devices will be included in the list returned by [devices].
  Future<void> startScanningForBluetoothDevices() async {}

  /// Stop scanning for BLE MIDI devices.
  void stopScanningForBluetoothDevices() {}

  /// Connects to the device.
  @override
  void connectToDevice(MidiDevice device) {
    // _methodChannel.invokeMethod('connectToDevice', device.toDictionary);
  }

  /// Disconnects from the device.
  @override
  void disconnectDevice(MidiDevice device) {
    // _methodChannel.invokeMethod('disconnectDevice', device.toDictionary);
  }

  @override
  void teardown() {
    // _methodChannel.invokeMethod('teardown');
  }

  /// Sends data to the currently connected device.
  ///
  /// Data is an UInt8List of individual MIDI command bytes.
  @override
  void sendData(Uint8List data) {
    print("send $data through method channel");
    // _methodChannel.invokeMethod('sendData', data);
  }

  /// Stream firing events whenever a midi package is received.
  ///
  /// The event contains the raw bytes contained in the MIDI package.
  @override
  Stream<Uint8List> get onMidiDataReceived {
    print("get on midi data");
    // _rxStream ??= _rxChannel.receiveBroadcastStream().map<Uint8List>((d) {
    //   return Uint8List.fromList(List<int>.from(d));
    // });
    _rxStream = _rxStreamController.stream;
    return _rxStream;
  }

  /// Stream firing events whenever a change in the MIDI setup occurs.
  ///
  /// For example, when a new BLE devices is discovered.
  @override
  Stream<String>? get onMidiSetupChanged {
    _setupStream = _setupStreamController.stream;
    return _setupStream;
  }
}
