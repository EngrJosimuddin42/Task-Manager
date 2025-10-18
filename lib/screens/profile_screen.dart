import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import 'login_screen.dart';
import '../services/custom_snackbar.dart';
import '../services/alert_dialog.dart';
import 'add_photos.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUploading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  /// 🔹 Load Profile
  Future<void> loadProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() {
          userData = null;
          isLoading = false;
        });
        CustomSnackbar.show(context, "⚠️ No profile data found!", backgroundColor: Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "❌ Error loading profile: $e";
        isLoading = false;
      });
      CustomSnackbar.show(context,"❌ Failed to load profile. Please try again later.",backgroundColor: Colors.red);
    }
  }

  /// 🔹 Upload Profile Image
  Future<void> uploadProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => isUploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('${user!.uid}.jpg');
      await ref.putFile(File(pickedFile.path));
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'photoUrl': imageUrl});

      setState(() {
        userData!['photoUrl'] = imageUrl;
        isUploading = false;
      });

      CustomSnackbar.show(context, "✅ Profile photo updated");
    } catch (e) {
      setState(() => isUploading = false);
      CustomSnackbar.show(context, "❌ Error: $e", backgroundColor: Colors.red);
    }
  }

  /// 🔹 Edit Profile Dialog
  Future<void> _showEditProfileDialog(BuildContext context, Map<String, dynamic>? userData, String userId, Function(Map<String, dynamic>) onProfileUpdated) async {
    final nameController = TextEditingController(text: userData?['name']);
    final phoneController = TextEditingController(text: userData?['phone']);

    final confirm = await AlertDialogUtils.showConfirm(
      context: context,
      title: "Edit Profile",
      confirmText: "Save",
      cancelText: "Cancel",
      confirmColor: Colors.deepPurple,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Name",
              prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: "Phone Number",
              prefixIcon: Icon(Icons.phone, color: Colors.deepPurple),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );

    // 🔹 If the user presses Save
    if (confirm == true) {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

      if (name.isEmpty || phone.isEmpty) {
        CustomSnackbar.show(context,"⚠️ Please fill all fields!",
          backgroundColor: Colors.orange);
        return;
      }
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'name': name,
          'phone': phone,
        });

        onProfileUpdated({
          'name': name,
          'phone': phone,
        });
        CustomSnackbar.show(context,"✅ Profile updated successfully!",
          backgroundColor: Colors.green);
      } catch (e) {
        CustomSnackbar.show(context,"❌ Error updating profile. Please try again later.",
          backgroundColor: Colors.red);
      }
    }
  }

  /// 🔹 Build Profile UI
  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage != null) return _buildErrorWidget();
    if (userData == null) return const Scaffold(body: Center(child: Text("No profile data found")));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      appBar: AppBar(
        title: const Text("👤 My Profile", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepPurple)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileAvatar(),
            const SizedBox(height: 20),
            Text(userData!['name'] ?? 'No Name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 6),
            Text(user!.email ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 20),
            if (userData!['phone'] != null) _buildPhoneRow(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed:  () async {
                await _showEditProfileDialog(context,
                  userData,
                  user!.uid,
                      (updatedData) {
                    setState(() {
                      userData!['name'] = updatedData['name'];
                      userData!['phone'] = updatedData['phone'];
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Divider(thickness: 1, color: Colors.black, indent: 20, endIndent: 20),
            _buildProfileDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: loadProfile, child: const Text("Retry"))
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 65,
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage: userData!['photoUrl'] != null ? NetworkImage(userData!['photoUrl']) : null,
            child: userData!['photoUrl'] == null
                ? Text(userData!['name'][0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.deepPurple, fontWeight: FontWeight.bold))
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: InkWell(
              onTap: uploadProfileImage,
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple))
                    : const Icon(Icons.camera_alt, color: Colors.deepPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.phone, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Text(userData!['phone'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    );
  }

  /// 🔹 Profile Details Card
  Widget _buildProfileDetails(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildProfileTile(icon: Icons.account_circle, color: Colors.deepPurple, title: "Account Type", subtitle: "Standard User"),
          _buildProfileTile(icon: Icons.language, color: Colors.orange, title: "Language", subtitle: "English"),

          ListTile(
            leading: const Icon(Icons.add_a_photo, color: Colors.deepPurple),
            title: const Text("My Gallery",style: TextStyle(fontWeight: FontWeight.bold),),
            onTap: () async {
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddPhotos()),
              );
            },
          ),


          _buildProfileTile(icon: Icons.location_on_outlined, color: Colors.red, title: "Location", subtitle: "Bangladesh"),
          _buildProfileTile(icon: Icons.settings, color: Colors.blueAccent, title: "Settings", subtitle: "Manage preferences"),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text("Delete All Tasks", style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () async {
              final confirm = await AlertDialogUtils.showConfirm(
                context: context,
                title: "Delete All Tasks",
                content: const Text("Are you sure you want to delete all tasks? This action cannot be undone."),
                confirmColor: Colors.redAccent,
              );
              if (confirm == true) {
                final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                await taskProvider.clearTasks();
                CustomSnackbar.show(context, "✅ All tasks deleted successfully", backgroundColor: Colors.green);
              }
            },
          ),
          _buildProfileTile(icon: Icons.help_outline, color: Colors.purple, title: "Help & Support", subtitle: "Get assistance"),
          _buildProfileTile(icon: Icons.feedback, color: Colors.brown, title: "Send Feedback", subtitle: "Share your experience"),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () async {
              final shouldLogout = await AlertDialogUtils.showConfirm(
                context: context,
                title: "Confirm Logout",
                content:const Text("Are you sure you want to log out?"),
                confirmColor: Colors.red);
              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Provider.of<TaskProvider>(context, listen: false).clearLocalOnly();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              }
            },
          ),
        ],
      ),
    );
  }

// 🔹 Creation ListTile Tool for Profile Page
  Widget _buildProfileTile({required IconData icon, required Color color, required String title, required String subtitle}) {
    return ListTile(
      leading: CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      onTap: () {},
    );
  }
}
