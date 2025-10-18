import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/custom_snackbar.dart';
import '../services/alert_dialog.dart';

class AddPhotos extends StatefulWidget {
  const AddPhotos({super.key});

  @override
  State<AddPhotos> createState() => _AddPhotosState();
}

class _AddPhotosState extends State<AddPhotos> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  final user = FirebaseAuth.instance.currentUser;

  /// 🔹 Pick image & upload
  Future<void> _pickAndUploadImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final file = File(pickedFile.path);
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos/${user!.uid}/$fileName.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('photos')
          .add({
        'url': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("📸 Photo uploaded: $downloadUrl");

      CustomSnackbar.show(context,"✅ Photo uploaded successfully!",
        backgroundColor: Colors.green);
    } catch (e) {
      CustomSnackbar.show(context,"❌ Failed to upload photo: $e",
        backgroundColor: Colors.redAccent,);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  ///🔹 Delete photo
  Future<void> _deletePhoto(String docId, String imageUrl) async {
    final confirm = await AlertDialogUtils.showConfirm(
      context: context,
      title: "Delete Photo?",
      content: const Text("Are you sure you want to delete this photo?"),
      confirmColor: Colors.redAccent,
    );

    if (confirm == true) {
      try {

        // 🔹 Delete from Storage
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        await ref.delete();

        // 🔹 Delete Firestore record
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('photos')
            .doc(docId)
            .delete();

        CustomSnackbar.show(context,"🗑️ Photo deleted successfully",
          backgroundColor: Colors.deepPurple);
      } catch (e) {
        CustomSnackbar.show(context,"❌ Failed to delete: $e",
          backgroundColor: Colors.redAccent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Gallery"),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: _isUploading ? null : _pickAndUploadImage,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('photos')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              print("📸 Photos loaded: ${snapshot.data?.docs.length}");
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final photos = snapshot.data!.docs;
              if (photos.isEmpty) {
                return const Center(
                  child: Text("📭 No photos uploaded yet."),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final imageUrl = photo['url'];

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                          ),
                        ),
                      ),
                      Positioned(top: 6,right: 6,
                        child: InkWell(
                          onTap: () => _deletePhoto(photo.id, imageUrl),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          // 🔹 Overlay spinner during upload
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
