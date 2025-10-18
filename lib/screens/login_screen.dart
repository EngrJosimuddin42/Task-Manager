import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'email_verify_screen.dart';
import '../services/custom_snackbar.dart';
import '../services/password_reset_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  // ✅ Dispose Controllers to Prevent Memory Leak
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 🔹 Login Function
  Future<void> login() async {
    setState(() => isLoading = true);

    //  ✅ Input Check
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // 🔹 Empty field check
    if (email.isEmpty || password.isEmpty) {
      CustomSnackbar.show(context,"⚠️ Please fill up all fields before login!",backgroundColor: Colors.red);
      setState(() => isLoading = false
      );
      return;
    }

    try {
      // ✅ Firebase Login
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user == null) {
        CustomSnackbar.show(context,"⚠️ User not found.",backgroundColor: Colors.red);
        setState(() => isLoading = false
        );
        return;
      }

      // ✅ Email verification check
      if (!user.emailVerified) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const EmailVerifyScreen()));
        setState(() => isLoading = false
        );
        return;
      }

      //  ✅ Successful login
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const HomeScreen()));
    }

    // 🔥 Firebase Authentication Error Handling
    on FirebaseAuthException catch (e) {
      print("FirebaseAuth error code: ${e.code}");
      String message = "⚠️ Login failed! Please try again.";
      Color color = Colors.red;

      // 🔹 user-not-found OR wrong password
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-login-credentials') {
        message = "⚠️ No account found for this email.\nPlease create one first.";}

      // 🔹 invalid email format
      else if (e.code == 'invalid-email') {
        message = "⚠️ Invalid email format!";}

      // 🔹 too many failed attempts
      else if (e.code == 'too-many-requests') {
        message = "🚫 Too many failed attempts. Please try again later.";
        color = Colors.orange;}

      // 🔹 default (unexpected)
      else {
        message = "⚠️ Unexpected error: ${e.code}";}

      // ✅ Show Custom Snackbar
      if (!mounted) return;
      CustomSnackbar.show(context,message,backgroundColor: color);}

    // 🔴 EXCEPTION HANDLING SECTION
    // ✅ This block catches and handles all non-Firebase errors
    catch (e) {
      print('⚠️ Non-Firebase error: $e');
      String message = "⚠️ Something went wrong. Please try again later.";
      Color color = Colors.red;

      // 🔹 Internet not available
      if (e.toString().contains("SocketException")) {
        message = "🌐 No Internet Connection! Please check your network.";
        color = Colors.orange;}

      // 🔹 Firebase not initialized properly
      else if (e.toString().contains("no-app") || e.toString().contains("FirebaseApp")) {
        message = "⚠️ Firebase not initialized properly. Please restart the app.";}

      // 🔹 setState after dispose issue (rare UI error)
      else if (e.toString().contains("setState() called after dispose()")) {
        message = "⚠️ App state error. Please reopen this page.";}

      // ✅ Show Custom Snackbar
      if (!mounted) return;
      CustomSnackbar.show(context, message,backgroundColor: color,);
    }
    finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Center(
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.task_alt, size: 70, color: Colors.deepPurple),
                  const SizedBox(height: 10),
                  const Text('Welcome Back!',style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold,color: Colors.deepPurple)),
                  const SizedBox(height: 5),
                  const Text('Sign in to continue managing your tasks',textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,color: Colors.black54)),
                  const SizedBox(height: 30),

                  // 🔹 Email Input
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 🔹 Password Input
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // 🔹 "Forgot Password?" Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {PasswordResetDialog.show(context);},
                      child: const Text("Forgot Password?",style: TextStyle(color: Colors.deepPurple,fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 🔹 Login Button
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.deepPurple)
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding:const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Login',style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🔹 Signup link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don’t have an account? "),
                      TextButton(
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SignupScreen())),
                        child: const Text('Create Account',style: TextStyle(fontWeight: FontWeight.bold,color: Colors.deepPurple)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
