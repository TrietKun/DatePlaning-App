import 'package:datingplaningapp/firebase_options.dart';
import 'package:datingplaningapp/modules/welcome/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MaterialApp(
    home: WelcomeScreen(),
  ));
}
