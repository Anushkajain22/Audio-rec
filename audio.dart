import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioRecorder extends StatefulWidget {
  @override
  _AudioRecorderState createState() => _AudioRecorderState();
}

class _AudioRecorderState extends State<AudioRecorder> {
  bool _isRecording = false;
  String _filePath = '';
  List<int> _audioData = [];
  StreamSubscription<bool>? _recorderStatusSubscription;
  List<String> _recordings = [];

  final FlutterAudioQuery _audioQuery = FlutterAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _recorderStatusSubscription?.cancel();
    _audioPlayer.stop();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    try {
      await _checkPermission();
    } catch (e) {
      print('Permission denied: $e');
      return;
    }

    try {
      bool isRecording = await Record().isRecording();
      setState(() {
        _isRecording = isRecording;
      });
    } catch (e) {
      print('Error checking recording status: $e');
    }

    List<SongInfo> songs = await _audioQuery.getSongs();
    setState(() {
      _recordings = songs
          .where((song) =>
              song.filePath != null && song.filePath!.endsWith('.m4a'))
          .map((song) => song.filePath!)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording)
              SpinKitRing(
                color: Colors.blue,
                size: 64.0,
                lineWidth: 4.0,
              )
            else
              Text('Tap to start recording'),
            SizedBox(height: 16),
            FloatingActionButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Icon(_isRecording ? Icons.stop : Icons.mic),
            ),
            SizedBox(height: 16),
            if (_recordings.isNotEmpty)
              Text('Recordings:', style: Theme.of(context).textTheme.headline6),
            Expanded(
              child: ListView.builder(
                itemCount: _recordings.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    title: Text(_recordings[index]),
                    onTap: () => _playRecording(_recordings[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      await _checkPermission();
      setState(() {
        _isRecording = true;
      });
      await Record().start();
    } on PlatformException catch (e) {
      print('Error starting recording: $e');
      setState(() {
        _isRecording = false;
      });
      _showErrorDialog('Could not start recording');
    }
  }

  Future<void> _stopRecording() async {
    try {
      setState(() {
        _isRecording = false;
      });
      String? path = await Record().stop();
      if (path != null) {
        setState(() {
          _filePath = path;
        });
        await _saveRecording();
        _audioPlayer.stop();
      } else {
        _showErrorDialog('Could not stop recording');
      }
    } on PlatformException catch (e) {
      print('Error stopping recording: $e');
      _showErrorDialog('Could not stop recording');
    }
  }

  Future<void> _saveRecording() async {
    String fileName = DateTime.now().toString() + '.m4a';
    File file = File(fileName);
    await file.writeAsBytes(_audioData);
    setState(() {
      _audioData.clear();
      _recordings.add(fileName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording saved to $fileName'),
      ),
    );
  }

  Future<void> _checkPermission() async {
    PermissionStatus status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throwPermissionException('Microphone permission not granted');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playRecording(String filePath) async {
    try {
      int result = await _audioPlayer.play(filePath, isLocal: true);
      if (result == 1) {
        print('Playing audio');
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }
}
