import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/entities/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:datingplaningapp/modules/home/main_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // final _auth = FirebaseAuth.instance;

  Future<void> login(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(cred.user!.uid)
          .get();

      currentUser = AppUser.fromMap(doc.id, doc.data()!);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainHome()),
      );
    } catch (e) {
      print("Login Error: $e");
    }
  }

  void _login() {
    login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Email
              TextField(
                controller: _emailController,
                style: const TextStyle(
                    color: Colors.white), // 👈 chữ nhập vào màu trắng
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  focusColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  labelText: 'Email',
                  labelStyle: const TextStyle(
                      color: Colors.white70), // 👈 màu chữ "Email"
                  prefixIcon: const Icon(Icons.email,
                      color: Colors.white), // 👈 icon trắng
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 20),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(
                    color: Colors.white), // 👈 chữ nhập vào màu trắng
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  labelText: 'Password',
                  labelStyle: const TextStyle(
                      color: Colors.white70), // 👈 màu chữ "Password"
                  prefixIcon: const Icon(Icons.lock,
                      color: Colors.white), // 👈 icon trắng
                ),
              ),
              const SizedBox(height: 30),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Login",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
