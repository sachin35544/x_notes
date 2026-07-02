import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:x_notes/screen/add_edit_screen.dart';
import 'package:x_notes/screen/view_note_screen.dart';
import 'package:x_notes/services/database_helper.dart';
import '../model/notes_model.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Note> _notes = [];

  final Gradient _brandGradient = const LinearGradient(
    colors: [Color(0xFF00004D), Color(0xFF001A80), Color(0xFF0040FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final allNotes = await _databaseHelper.getNotes();
    setState(() {
      _notes = allNotes
          .where((note) => note.reminder != null && note.reminder!.isNotEmpty)
          .toList();
    });
  }

  TextSpan _buildRichText(String text, Color textColor) {
    List<InlineSpan> spans = [];
    final pattern = RegExp(
      r'(\[ \]|\[x\])|(\*\*(.*?)\*\*)|(_(.*?)_)|(<u>(.*?)</u>)',
    );
    int lastMatchEnd = 0;
    pattern.allMatches(text).forEach((match) {
      if (match.start > lastMatchEnd)
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      if (match.group(1) != null) {
        bool isChecked = match.group(1) == '[x]';
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Icon(
                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                color: textColor.withOpacity(0.7),
                size: 16,
              ),
            ),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(4) != null) {
        spans.add(
          TextSpan(
            text: match.group(5),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(6) != null) {
        spans.add(
          TextSpan(
            text: match.group(7),
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: textColor,
            ),
          ),
        );
      }
      lastMatchEnd = match.end;
    });
    if (lastMatchEnd < text.length)
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    return TextSpan(
      style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
      children: spans,
    );
  }

  String _formatDate(String dateStr) {
    DateTime dt = DateTime.parse(dateStr);
    return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reminders',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: _brandGradient),
        ),
      ),
      body: _notes.isEmpty
          ? const Center(
              child: Text(
                "No Reminders set!",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewNoteScreen(note: note),
                      ),
                    ); // Simple Push
                    _loadReminders();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: noteColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode ? Colors.white12 : Colors.black12,
                        width: 1,
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

                        // Display Reminder Date on Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          color: Colors.black.withOpacity(0.05),
                          child: Row(
                            children: [
                              Icon(
                                Icons.alarm,
                                size: 14,
                                color: textColor.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(note.reminder!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor.withOpacity(0.8),
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
                              if (note.title.isNotEmpty)
                                Text(
                                  note.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
      // STANDARD FAB
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: _brandGradient,
          shape: BoxShape.circle,
        ),
        child: FloatingActionButton(
          onPressed: () async {
            // Simple Navigation (No params)
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEditNoteScreen(),
              ),
            );
            _loadReminders();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
