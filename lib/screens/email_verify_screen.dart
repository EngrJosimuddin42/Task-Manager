import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/custom_snackbar.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    // 🔹 Listen for user state changes (auto redirect if verified)
    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null && user.emailVerified) {
        _navigateToHome();
      }
    });
  }

// 🔹 Navigate helpers
  void _navigateToHome() {
    Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // 🔹 Check email verification
  Future<void> checkVerification() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.reload();

      if (user.emailVerified) {
        _navigateToHome();
      } else {
        CustomSnackbar.show(context,"📩 Email not verified yet.\nPlease check your inbox or spam folder.",
            backgroundColor: Colors.red);
      }
    } catch (e) {
      CustomSnackbar.show (context,"⚠️ Error checking verification: $e",
          backgroundColor: Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 🔹 Resend verification email
  Future<void> resendEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.sendEmailVerification();
      CustomSnackbar.show(context,"✅ Verification email sent again! Check your inbox.",
        backgroundColor: Colors.green,
      );
    } catch (e) {
      CustomSnackbar.show(context,"⚠️ Failed to send verification email: $e",
          backgroundColor: Colors.red);
    }
  }

  // 🔹 Handle back button press
  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const LoginScreen()));
    return false; // prevent default pop
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // 🔹 back press handle
      child:Scaffold(
        appBar: AppBar(
          title: const Text("Verify Your Email"),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 6,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_unread,size: 80, color: Colors.deepPurple),
                  const SizedBox(height: 20),

                  // 🔹 Notice Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.shade100)),
                    child: const Text("💡 If you registered before, please check your inbox or spam folder and verify your email.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.deepPurple,fontWeight: FontWeight.w600,fontSize: 13))),

                  const SizedBox(height: 20),
                  const Text("Please verify your email address to continue.",textAlign: TextAlign.center,style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 25),

                  // 🔹 "I've Verified" Button
                  isLoading
                      ? const CircularProgressIndicator(
                      color: Colors.deepPurple)
                      : ElevatedButton.icon(
                    onPressed: checkVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.verified_user,color: Colors.white),
                    label: const Text("I've Verified",style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white))),

                  const SizedBox(height: 12),

                  // 🔹 Resend Button
                  TextButton(
                    onPressed: resendEmail,
                    child: const Text("Resend Verification Email",style: TextStyle(color: Colors.deepPurple,fontWeight: FontWeight.w600)),
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
