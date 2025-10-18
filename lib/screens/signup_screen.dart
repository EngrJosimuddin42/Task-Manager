import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_verify_screen.dart';
import '../services/custom_snackbar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  // 🔹 Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  // 🔹 State Variables
  bool isLoading = false;
  bool _obscurePassword = true;
  String? emailError;
  String? passwordError;

  // 🔹 Email validation (live)
  void _validateEmail(String value) {
    if (value.contains(RegExp(r'[A-Z]'))) {setState(() => emailError = "❌ Email must be lowercase (no capital letters allowed)");}
    else if (!RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$')
        .hasMatch(value)) {setState(() => emailError = "❌ Invalid email format (e.g. example@gmail.com)");}
    else {setState(() => emailError = null);
    }
  }

  // 🔹 Password validation (live)
  void _validatePassword(String value) {
    if (value.isEmpty) {setState(() => passwordError = "❌ Password is required");}
    else if (value.length < 6) {setState(() => passwordError = "🔒 Must be at least 6 characters long");}
    else if (!RegExp(r'[0-9]').hasMatch(value)) {setState(() => passwordError = "🔢 Must contain at least one number");}
    else if (!RegExp(r'[A-Za-z]').hasMatch(value)) {setState(() => passwordError = "🅰️ Must contain at least one letter");}
    else {setState(() => passwordError = null);
    }
  }

  // 🔹 Sign Up function with email verification
  Future<void> signup() async {
    setState(() => isLoading = true);

    final emailInput = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final email = emailInput.toLowerCase();

    // 🔹  ❌ Stop signup if email or password error exists
    if (emailError != null || passwordError != null) {
      CustomSnackbar.show(context,emailError ?? passwordError!,backgroundColor: Colors.red);
      setState(() => isLoading = false
      );
      return;
    }

    try {
      // 🔹 Create user
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,password: password );

      // 🔹 Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': name.isEmpty ? email.split('@')[0] : name,
        'email': email,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔹 Send email verification
      await userCredential.user!.sendEmailVerification();

      //  ✅ Success Snackbar
      CustomSnackbar.show(context,"📩 Verification email sent! Please verify your email before logging in.",
        backgroundColor: Colors.green);

      // 🔹 Go to email verify screen
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => EmailVerifyScreen()));

      // 🔹 Error Snackbar
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'email-already-in-use') {message = "⚠️ This email is already registered. Try logging in instead!";}
      else if (e.code == 'invalid-email') {message = "❌ Invalid email address format!";}
      else if (e.code == 'weak-password') {message = "🔒 Password too weak! Use at least 6 characters.";}
      else {message = "⚠️ Please fill up all fields before signing up!";}
      CustomSnackbar.show(context,message,backgroundColor: Colors.red);
    } catch (e) {
      CustomSnackbar.show(context,"❌ Unexpected error occurred: $e",backgroundColor: Colors.red);

    } finally {
      setState(() => isLoading = false);
    }
  }
                    // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 8,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text("Create Your Account",style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold,color: Colors.deepPurple)),
                const SizedBox(height: 25),

                // 🔹 Name Field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 🔹 Email Field
                TextField(
                  controller: emailController,
                  onChanged: _validateEmail,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: emailError,
                  ),
                ),
                const SizedBox(height: 15),

                // 🔹 Password Field
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  onChanged: _validatePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: passwordError,
                  ),
                ),
                const SizedBox(height: 25),

                // 🔹 Sign Up Button
                isLoading
                    ? const CircularProgressIndicator(color: Colors.deepPurple)
                    : ElevatedButton(
                  onPressed: signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign Up',style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const SizedBox(height: 15),

                // 🔹 Login Navigation
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Already have an account? Log In",style: TextStyle(color: Colors.deepPurple,fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
