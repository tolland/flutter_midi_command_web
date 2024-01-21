import 'dart:async';
import 'dart:js';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:flutter_midi_command_web/extensions.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:typings/core.dart' as html;

final List<html.MIDIInput> _webMidiInputs = [];
final List<html.MIDIOutput> _webMidiOutputs = [];
final List<MidiDevice> _connectedDevices = [];

/// A web implementation of the FlutterMidiCommandWeb plugin.
class FlutterMidiCommandWeb extends MidiCommandPlatform {
  final StreamController<MidiPacket> _rxStreamController =
      StreamController<MidiPacket>.broadcast();

  final StreamController<String> _setupStreamController =
      StreamController<String>.broadcast();

  late final Stream<String> _setupStream;
  late final Stream<MidiPacket> _rxStream;

  static void registerWith(Registrar registrar) {
    _log("register FlutterMidiCommandWeb");
    MidiCommandPlatform.instance = FlutterMidiCommandWeb();
  }

  FlutterMidiCommandWeb() {
    _setupStream = _setupStreamController.stream;
    _rxStream = _rxStreamController.stream;
  }

  Future<void> _initMidi() async {
    final access = await html.window.navigator
        .requestMIDIAccess(html.MIDIOptions(sysex: true, software: false));

    // deal with bug: https://github.com/dart-lang/sdk/issues/33248
    js_util.callMethod(access.inputs, 'forEach', [allowInterop(_getInputs)]);
    js_util.callMethod(access.outputs, 'forEach', [allowInterop(_getOutputs)]);
  }

  void _getInputs(dynamic a, dynamic b, dynamic c) {
    final inp = a as html.MIDIInput;
    _log('input id, name: ${inp.id} | ${inp.name}');
    _webMidiInputs.add(inp);
  }

  void _getOutputs(dynamic a, dynamic b, dynamic c) {
    final outp = a as html.MIDIOutput;
    _log('ouput id, name: ${outp.id} | ${outp.name}');
    _webMidiOutputs.add(outp);
  }

  @override
  Future<List<MidiDevice>> get devices async {
    await _initMidi();

    final deviceMap = <String, MidiDevice>{};
    int idCounter = 0;
    for (var input in _webMidiInputs) {
      final isConnected = _connectedDevices
              .firstWhereOrNull((device) => device.name == input.name) !=
          null;
      final device = MidiDevice(input.id, input.name ?? '', "web", isConnected);
      device.inputPorts.add(MidiPort(idCounter++, MidiPortType.IN));
      deviceMap[input.name ?? input.id] = device;
    }
    idCounter = 0;
    for (var output in _webMidiOutputs) {
      final isConnected = _connectedDevices
              .firstWhereOrNull((device) => device.name == output.name) !=
          null;
      final existingDevice = deviceMap[output.name];
      if (existingDevice != null) {
        existingDevice.outputPorts.add(MidiPort(idCounter++, MidiPortType.OUT));
      } else {
        final device =
            MidiDevice(output.id, output.name ?? '', "web", isConnected);
        device.outputPorts.add(MidiPort(idCounter++, MidiPortType.OUT));
        deviceMap[output.name ?? output.id] = device;
      }
    }
    return deviceMap.values.toList();
  }

  /// Connects to the device.
  @override
  Future<void> connectToDevice(MidiDevice device,
      {List<MidiPort>? ports}) async {
    // connect up incoming webmidi data to our rx stream of MidiPackets
    final inputPorts = _webMidiInputs.where((p) => p.name == device.name);
    for (var inport in inputPorts) {
      _log('connecting midi rx to: ${device.name}');
      inport.onmidimessage = allowInterop((midiMesg) {
        _rxStreamController.add(MidiPacket(
          (midiMesg as html.MIDIMessageEvent).data,
          midiMesg.timeStamp.toInt(),
          device,
        ));
      });
    }
    _connectedDevices.add(device);
    _setupStreamController.add("deviceConnected");
  }

  /// Disconnects from the device.
  @override
  void disconnectDevice(MidiDevice device, {bool remove = true}) {
    final inputPorts = _webMidiInputs.where((p) => p.name == device.name);
    for (var inport in inputPorts) {
      _log('connecting midi rx to: ${device.name}');
      inport.onmidimessage = allowInterop((midiMesg) {
        _rxStreamController.add(MidiPacket(
          (midiMesg as html.MIDIMessageEvent).data,
          midiMesg.timeStamp.toInt(),
          device,
        ));
      });
      _connectedDevices.remove(device);
      _setupStreamController.add("deviceDisconnected");
    }
  }

  @override
  void teardown() {
    //go through and call disconnect on all devics, then close rx stream
    for (MidiDevice device in _connectedDevices) {
      disconnectDevice(device);
    }
    _rxStreamController.close();
  }

  /// Sends data to the currently connected device.wmidi hardware driver name
  ///
  /// Data is an UInt8List of individual MIDI command bytes.
  @override
  void sendData(Uint8List data, {int? timestamp, String? deviceId}) {
    _webMidiOutputs.forEach((output) {
      double ts = timestamp == null ? 0.0 : timestamp.toDouble();

      if (deviceId != null) {
        if (deviceId == output.id) {
          output.send(data, ts);
        }
      } else {
        output.send(data, ts);
      }
    });
  }

  /// Stream firing events whenever a midi package is received.
  ///
  /// The event contains the raw bytes contained in the MIDI package.
  @override
  Stream<MidiPacket>? get onMidiDataReceived {
    return _rxStream;
  }

  /// Stream firing events whenever a change in the MIDI setup occurs.
  ///
  /// For example, when a new BLE devices is discovered.
  @override
  Stream<String>? get onMidiSetupChanged {
    return _setupStream;
  }
}

void _log(String mesg) {
  if (kDebugMode) {
    print(mesg);
  }
}
