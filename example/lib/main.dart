import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:flutter_virtual_piano/flutter_virtual_piano.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<MidiPacket>? _rxSubscription;
  final MidiCommand midiCommand = MidiCommand();

  Uint8List? lastMidiMesg;

  @override
  void initState() {
    super.initState();
    _rxSubscription = midiCommand.onMidiDataReceived?.listen((packet) {
      debugPrint('received packet: ${packet.data}');
      setState(() {
        lastMidiMesg = packet.data;
      });
    });
  }

  @override
  void dispose() {
    _rxSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: FutureBuilder<List<MidiDevice>?>(
            future: midiCommand.devices,
            builder: (context, snapshot) {
              if (snapshot.data == null) {
                return const CircularProgressIndicator();
              }
              final devices = snapshot.data;
              if (devices == null) {
                return const Text('No Devices');
              }
              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          return MaterialButton(
                            child: Text(_deviceLabel(devices[index])),
                            onPressed: () {
                              setState(() {
                                midiCommand.connectToDevice(devices[index]);
                              });
                            },
                          );
                        }),
                  ),
                  Text('Last midi: $lastMidiMesg'),
                  SizedBox(
                    height: 80,
                    child: VirtualPiano(
                      noteRange: const RangeValues(48, 76),
                      onNotePressed: (note, vel) {
                        NoteOnMessage(note: note, velocity: 100).send();
                      },
                      onNoteReleased: (note) {
                        NoteOffMessage(note: note).send();
                      },
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _deviceLabel(MidiDevice device) {
    return device.connected
        ? '${device.name} CONNECTED'
        : 'connect: ${device.name}';
  }
}
