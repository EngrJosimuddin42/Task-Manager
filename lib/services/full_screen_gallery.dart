import 'package:flutter/material.dart';

class FullScreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  final Future<void> Function(String id, String url) onDelete;

  const FullScreenGallery({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black,iconTheme: const IconThemeData(color: Colors.white),
        title: Text("${currentIndex + 1} / ${widget.photos.length}",style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              final photo = widget.photos[currentIndex];
              await widget.onDelete(photo['id'], photo['url']);
              setState(() {
                widget.photos.removeAt(currentIndex);
                if (currentIndex >= widget.photos.length) {
                  currentIndex = widget.photos.length - 1;
                }
              });
              if (widget.photos.isEmpty) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return InteractiveViewer(
            panEnabled: true,
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Hero(
                tag: photo['url'],
                child: Image.network(photo['url'], fit: BoxFit.contain),
              ),
            ),
          );
        },
      ),
    );
  }
}
