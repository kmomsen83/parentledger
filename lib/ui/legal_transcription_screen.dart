import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LegalTranscriptionScreen extends StatefulWidget {
final String? caseId;
const LegalTranscriptionScreen({super.key, this.caseId});

@override
State<LegalTranscriptionScreen> createState() =>
_LegalTranscriptionScreenState();
}

class _LegalTranscriptionScreenState
extends State<LegalTranscriptionScreen> {
final stt.SpeechToText _speech = stt.SpeechToText();

bool isListening = false;
bool isSaving = false;

String transcript = "";
DateTime? startTime;

/// ================================
/// INIT SPEECH
/// ================================
Future<void> initSpeech() async {
await Permission.microphone.request();

final available = await _speech.initialize();

if (!mounted) return;
if (!available) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text("Speech recognition unavailable")),
);
}
}

@override
void initState() {
super.initState();
initSpeech();
}

/// ================================
/// START RECORDING
/// ================================
void startListening() async {
transcript = "";
startTime = DateTime.now();

await _speech.listen(
onResult: (result) {
setState(() {
transcript = result.recognizedWords;
});
},
);

setState(() => isListening = true);
}

/// ================================
/// STOP RECORDING
/// ================================
void stopListening() async {
await _speech.stop();
setState(() => isListening = false);
}

/// ================================
/// SAVE TO FIRESTORE
/// ================================
Future<void> saveTranscription() async {
if (transcript.trim().isEmpty) return;

setState(() => isSaving = true);

try {
final user = FirebaseAuth.instance.currentUser;
if (user == null) throw Exception("Not logged in");

final db = FirebaseFirestore.instance;

final userDoc =
await db.collection("users").doc(user.uid).get();

final caseId = userDoc.data()?["caseId"];
if (caseId == null) throw Exception("Missing caseId");

await db
.collection("cases")
.doc(caseId)
.collection("events")
.add({
"type": "transcription",
"description": transcript,
"timestamp": Timestamp.now(),
"createdAt": Timestamp.now(),
});

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Saved to case")),
);

setState(() {
transcript = "";
});
} catch (_) {
      if (kDebugMode) {
        debugPrint("Save failed");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Save failed")),
      );
    }

if (!mounted) return;
setState(() => isSaving = false);
}

/// ================================
/// TIMER UI
/// ================================
String get elapsedTime {
if (startTime == null) return "00:00";

final diff = DateTime.now().difference(startTime!);
final mins = diff.inMinutes.toString().padLeft(2, '0');
final secs =
(diff.inSeconds % 60).toString().padLeft(2, '0');

return "$mins:$secs";
}

/// ================================
/// BUILD
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text("Legal Transcription"),
),
body: Padding(
padding: const EdgeInsets.all(16),
child: Column(
children: [

/// STATUS
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
isListening
? Icons.mic
: Icons.mic_none,
color: isListening
? Colors.red
: Colors.grey,
),
const SizedBox(width: 8),
Text(
isListening
? "Recording ($elapsedTime)"
: "Not Recording",
),
],
),

const SizedBox(height: 20),

/// RECORD BUTTON
GestureDetector(
onTap:
isListening ? stopListening : startListening,
child: Container(
width: 90,
height: 90,
decoration: BoxDecoration(
color: isListening
? Colors.red
: Colors.blue,
shape: BoxShape.circle,
),
child: Icon(
isListening ? Icons.stop : Icons.mic,
color: Colors.white,
size: 36,
),
),
),

const SizedBox(height: 30),

/// TRANSCRIPT
Expanded(
child: Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
border: Border.all(color: Colors.grey),
borderRadius: BorderRadius.circular(10),
),
child: SingleChildScrollView(
child: Text(
transcript.isEmpty
? "Transcript will appear here..."
: transcript,
style: const TextStyle(height: 1.4),
),
),
),
),

const SizedBox(height: 20),

/// ACTIONS
Row(
children: [
Expanded(
child: ElevatedButton(
onPressed:
isSaving ? null : saveTranscription,
child: isSaving
? const CircularProgressIndicator()
: const Text("Save to Case"),
),
),
const SizedBox(width: 10),
Expanded(
child: OutlinedButton(
onPressed: () {
setState(() {
transcript = "";
});
},
child: const Text("Discard"),
),
),
],
),
],
),
),
);
}
}
