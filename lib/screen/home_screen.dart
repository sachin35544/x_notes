import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:x_notes/screen/view_note_screen.dart';
import 'package:x_notes/services/database_helper.dart';

import '../model/notes_model.dart';
import 'add_edit_screen.dart';
import 'reminder_screen.dart';

// start app

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Note> _allNotes = [];
  List<Note> _filteredNotes = [];

  bool _isSelectionMode = false;
  List<int> _selectedIds = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final Gradient _brandGradient = const LinearGradient(
    colors: [Color(0xFF00004D), Color(0xFF001A80), Color(0xFF0040FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final List<Color> _colors = [
    Colors.white,
    Colors.amber,
    Color(0xFF50C878),
    Colors.redAccent,
    Colors.blueAccent,
    Colors.indigo,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.brown,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final notes = await _databaseHelper.getNotes();
    setState(() {
      _allNotes = notes;
      if (!_isSearching) {
        _filteredNotes = notes;
      } else {
        _onSearchChanged();
      }
    });
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = _allNotes;
      } else {
        _filteredNotes = _allNotes.where((note) {
          return note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredNotes = _allNotes;
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _pinSelectedNotes() async {
    for (var note in _allNotes) {
      if (_selectedIds.contains(note.id)) {
        final newStatus = note.isPinned == 1 ? 0 : 1;
        final updatedNote = Note(
          id: note.id,
          title: note.title,
          content: note.content,
          color: note.color,
          dateTime: note.dateTime,
          imagePath: note.imagePath,
          isBold: note.isBold,
          isItalic: note.isItalic,
          isUnderline: note.isUnderline,
          isPinned: newStatus,
          reminder: note.reminder, // Preserve reminder
        );
        await _databaseHelper.updateNote(updatedNote);
      }
    }
    _exitSelectionMode();
    _loadNotes();
  }

  Future<void> _deleteSelectedNotes() async {
    for (var id in _selectedIds) {
      await _databaseHelper.deleteNote(id);
    }
    _exitSelectionMode();
    _loadNotes();
  }

  void _showBulkColorPalette() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 80,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _colors.length,
            itemBuilder: (context, index) {
              final color = _colors[index];
              return GestureDetector(
                onTap: () async {
                  String colorString = index == 0
                      ? 'default'
                      : color.value.toString();
                  for (var note in _allNotes) {
                    if (_selectedIds.contains(note.id)) {
                      final updatedNote = Note(
                        id: note.id,
                        title: note.title,
                        content: note.content,
                        color: colorString,
                        dateTime: note.dateTime,
                        imagePath: note.imagePath,
                        isBold: note.isBold,
                        isItalic: note.isItalic,
                        isUnderline: note.isUnderline,
                        isPinned: note.isPinned,
                        reminder: note.reminder, // Preserve reminder
                      );
                      await _databaseHelper.updateNote(updatedNote);
                    }
                  }
                  Navigator.pop(context);
                  _exitSelectionMode();
                  _loadNotes();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.grey[300] : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 1),
                  ),
                  child: index == 0
                      ? const Icon(
                          Icons.format_color_reset,
                          size: 20,
                          color: Colors.black,
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- Helper to format Reminder Date ---
  // --- UPDATED: AM/PM Format Helper ---
  String _formatDate(String dateStr) {
    DateTime dt = DateTime.parse(dateStr);
    String period = dt.hour >= 12 ? 'PM' : 'AM';
    int hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    if (hour == 0) hour = 12; // 0 baje ko 12 banana
    return "${dt.day}/${dt.month} $hour:${dt.minute.toString().padLeft(2, '0')} $period";
  }

  // --- NEW: Helper to check if reminder is completed (Past time) ---
  bool _isReminderComplete(String dateStr) {
    DateTime dt = DateTime.parse(dateStr);
    return dt.isBefore(DateTime.now());
  }

  TextSpan _buildRichText(String fullText, Color textColor) {
    List<InlineSpan> spans = [];
    List<String> lines = fullText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      bool isLineChecked = line.startsWith('[x]');
      bool isLineUnchecked = line.startsWith('[ ]');

      if (i > 0) spans.add(const TextSpan(text: "\n"));

      if (isLineChecked || isLineUnchecked) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Icon(
                isLineChecked ? Icons.check_box : Icons.check_box_outline_blank,
                color: textColor.withOpacity(0.7),
                size: 16,
              ),
            ),
          ),
        );
        String content = line.length > 3 ? line.substring(4) : "";
        spans.addAll(_parseLineContent(content, textColor, isLineChecked));
      } else {
        spans.addAll(_parseLineContent(line, textColor, false));
      }
    }

    return TextSpan(
      style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
      children: spans,
    );
  }

  List<InlineSpan> _parseLineContent(
    String text,
    Color textColor,
    bool isStrikethrough,
  ) {
    List<InlineSpan> lineSpans = [];
    final pattern = RegExp(r'(\*\*(.*?)\*\*)|(_(.*?)_)|(<u>(.*?)</u>)');
    int lastMatchEnd = 0;

    TextStyle baseStyle = TextStyle(
      decoration: isStrikethrough ? TextDecoration.lineThrough : null,
      decorationColor: textColor,
    );

    pattern.allMatches(text).forEach((match) {
      if (match.start > lastMatchEnd) {
        lineSpans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ),
        );
      }
      if (match.group(1) != null) {
        lineSpans.add(
          TextSpan(
            text: match.group(2),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(3) != null) {
        lineSpans.add(
          TextSpan(
            text: match.group(4),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(5) != null) {
        lineSpans.add(
          TextSpan(
            text: match.group(6),
            style: baseStyle.copyWith(decoration: TextDecoration.underline),
          ),
        );
      }
      lastMatchEnd = match.end;
    });

    if (lastMatchEnd < text.length) {
      lineSpans.add(
        TextSpan(text: text.substring(lastMatchEnd), style: baseStyle),
      );
    }
    return lineSpans;
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        title: Text(
          "${_selectedIds.length} Selected",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: _brandGradient),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.push_pin),
            onPressed: _pinSelectedNotes,
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _showBulkColorPalette,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelectedNotes,
          ),
        ],
      );
    }

    if (_isSearching) {
      return AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: "Search notes...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: _brandGradient),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _searchController.clear(),
          ),
        ],
      );
    }

    return AppBar(
      title: const Text(
        'Notes',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: _brandGradient),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _startSearch,
          tooltip: "Search",
        ),
      ],
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Could not open link")));
    }
  }

  Widget _buildDrawer() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color iconColor = isDarkMode ? Colors.white70 : Colors.black54;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20),
            decoration: BoxDecoration(gradient: _brandGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 5,
                        color: Colors.black26,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo.png', // ✅ Logo Path
                    fit: BoxFit.contain,
                  ),
                ),

                // 👆👆👆 Update ends here 👆👆👆
                SizedBox(height: 12),
                Text(
                  "X Notes",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF0040FF),
                  ),
                  title: Text(
                    "Notes",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  tileColor: const Color(0xFF0040FF).withOpacity(0.1),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: Icon(Icons.notifications_none, color: iconColor),
                  title: Text("Reminders", style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReminderScreen(),
                      ),
                    );
                  },
                ),

                const Divider(thickness: 1, indent: 16, endIndent: 16),

                ListTile(
                  leading: Icon(Icons.share_outlined, color: iconColor),
                  title: Text("Share App", style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(
                      "Check out X Notes - Simple & Secure Notes App: https://play.google.com/store/apps/details?id=com.sktechstudio.x_notes",
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.star_rate_outlined, color: iconColor),
                  title: Text("Rate Us", style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _launchURL(
                      "https://play.google.com/store/apps/details?id=com.sktechstudio.x_notes",
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: iconColor),
                  title: Text(
                    "Privacy Policy",
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _launchURL(
                      "https://sktechstudio.blogspot.com/p/x-notes-privacy-policy.html",
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.gavel_outlined, color: iconColor),
                  title: Text(
                    "Terms & Conditions",
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _launchURL(
                      "https://sktechstudio.blogspot.com/p/x-notes-terms-conditions.html",
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.feedback_outlined, color: iconColor),
                  title: Text("Feedback", style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _launchURL(
                      "mailto:sktechstudio25@gmail.com?subject=X%20Notes%20Feedback",
                    );
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Version 1.0.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: _filteredNotes.isEmpty
          ? Center(
              child: Text(
                _isSearching ? "No matches found" : "No Notes yet!",
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) {
                final note = _filteredNotes[index];
                bool isSelected = _selectedIds.contains(note.id);

                Color noteColor;
                if (note.color == 'default') {
                  noteColor = isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF5F5F5);
                } else {
                  noteColor = Color(int.parse(note.color));
                }

                Color textColor =
                    ThemeData.estimateBrightnessForColor(noteColor) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black;

                return GestureDetector(
                  onLongPress: () {
                    _stopSearch();
                    setState(() {
                      _isSelectionMode = true;
                      _toggleSelection(note.id!);
                    });
                  },
                  onTap: () async {
                    if (_isSelectionMode) {
                      _toggleSelection(note.id!);
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewNoteScreen(note: note),
                        ),
                      );
                      _loadNotes();
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color.alphaBlend(
                              Colors.blue.withOpacity(0.2),
                              noteColor,
                            )
                          : noteColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blueAccent
                            : (isDarkMode ? Colors.white12 : Colors.black12),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.imagePath != null)
                          Image.file(
                            File(note.imagePath!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            height: 120,
                          ),

                        // --- REMINDER CHIP ADDED HERE ---
                        // --- UPDATED REMINDER CHIP FOR HOME SCREEN ---
                        if (note.reminder != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            color: Colors.black.withOpacity(0.05),
                            child: Row(
                              children: [
                                // Agar time complete ho gaya hai to Green Check, nahi to Alarm Icon
                                Icon(
                                  _isReminderComplete(note.reminder!)
                                      ? Icons.check_circle
                                      : Icons.alarm,
                                  size: 14,
                                  color: _isReminderComplete(note.reminder!)
                                      ? Colors.green
                                      : textColor.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(note.reminder!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    // Complete hone par text bhi green/grey kar sakte ho, abhi normal rakha hai
                                    color: _isReminderComplete(note.reminder!)
                                        ? Colors.green
                                        : textColor.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: note.title.isNotEmpty
                                        ? Text(
                                            note.title,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : Container(),
                                  ),
                                  if (note.isPinned == 1)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 4,
                                      ),
                                      child: Icon(
                                        Icons.push_pin,
                                        size: 16,
                                        color: textColor.withOpacity(0.7),
                                      ),
                                    ),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: const Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                    ),
                                ],
                              ),

                              if (note.title.isNotEmpty)
                                const SizedBox(height: 8),

                              if (note.content.isNotEmpty)
                                Text.rich(
                                  _buildRichText(note.content, textColor),
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _isSelectionMode || _isSearching
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: _brandGradient,
                shape: BoxShape.circle,
              ),
              child: FloatingActionButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditNoteScreen(),
                    ),
                  );
                  _loadNotes();
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
    );
  }
}
