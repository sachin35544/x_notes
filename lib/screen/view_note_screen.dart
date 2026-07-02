import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:x_notes/screen/add_edit_screen.dart';
import 'package:x_notes/services/database_helper.dart';
import '../model/notes_model.dart';

class ViewNoteScreen extends StatefulWidget {
  final Note note;
  const ViewNoteScreen({super.key, required this.note});

  @override
  State<ViewNoteScreen> createState() => _ViewNoteScreenState();
}

class _ViewNoteScreenState extends State<ViewNoteScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late Note _currentNote;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
  }

  // --- FIXED: Added reminder field persistence ---
  Future<void> _handleCheckboxTap(int index, bool isChecked) async {
    String content = _currentNote.content;
    final regex = RegExp(r'\[(\s|x)\]');
    final matches = regex.allMatches(content).toList();
    if (index < matches.length) {
      final match = matches[index];
      String newTag = isChecked ? '[ ]' : '[x]';
      String newContent = content.replaceRange(match.start, match.end, newTag);

      final updatedNote = Note(
        id: _currentNote.id,
        title: _currentNote.title,
        content: newContent,
        color: _currentNote.color,
        dateTime: DateTime.now().toString(),
        imagePath: _currentNote.imagePath,
        reminder: _currentNote
            .reminder, // ✅ Ye line add ki hai taaki reminder delete na ho
      );

      await _databaseHelper.updateNote(updatedNote);
      setState(() => _currentNote = updatedNote);
    }
  }

  // --- NEW: Helper to format date ---
  // --- UPDATED: AM/PM Format ---
  String _formatReminderDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      final String month = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ][date.month - 1];

      String period = date.hour >= 12 ? 'PM' : 'AM';
      int hour = date.hour > 12 ? date.hour - 12 : date.hour;
      if (hour == 0) hour = 12;

      final String minute = date.minute.toString().padLeft(2, '0');

      return "$month ${date.day}, $hour:$minute $period";
    } catch (e) {
      return dateStr;
    }
  }

  bool _isReminderComplete(String dateStr) {
    return DateTime.parse(dateStr).isBefore(DateTime.now());
  }

  // --- STRIKETHROUGH LOGIC (Same as Home Screen) ---
  TextSpan _buildRichText(String fullText, Color textColor) {
    List<InlineSpan> spans = [];
    List<String> lines = fullText.split('\n');
    int checkboxCounter = 0;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      bool isLineChecked = line.startsWith('[x]');
      bool isLineUnchecked = line.startsWith('[ ]');

      if (i > 0) spans.add(const TextSpan(text: "\n"));

      if (isLineChecked || isLineUnchecked) {
        int currentIndex = checkboxCounter++;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _handleCheckboxTap(currentIndex, isLineChecked),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  isLineChecked
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: isLineChecked
                      ? Colors.blue
                      : textColor.withOpacity(0.6),
                  size: 20,
                ),
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
      style: TextStyle(
        fontSize: 18,
        height: 1.6,
        color: textColor.withOpacity(0.9),
      ),
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
  // -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    bool isDefaultColor = _currentNote.color == 'default';
    if (isDefaultColor) {
      bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    } else {
      bgColor = Color(int.parse(_currentNote.color));
    }
    Color textColor =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        flexibleSpace: isDefaultColor
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00004D),
                      Color(0xFF001A80),
                      Color(0xFF0040FF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              )
            : null,
        backgroundColor: isDefaultColor ? Colors.transparent : bgColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_outlined,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentNote.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Copied!"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditNoteScreen(note: _currentNote),
                ),
              );
              // Refresh note when returning from Edit screen
              // Note: Ideally you should reload from DB or pass updated note back
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
          IconButton(
            onPressed: () => _showDeleteDialog(context),
            icon: const Icon(Icons.delete, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentNote.imagePath != null)
                GestureDetector(
                  onTap: () => _showFullImage(context, _currentNote.imagePath!),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Image.file(
                      File(_currentNote.imagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _currentNote.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 28,
                      ),
                    ),

                    // --- UPDATED REMINDER DISPLAY FOR VIEW SCREEN ---
                    const SizedBox(height: 8),
                    if (_currentNote.reminder != null &&
                        _currentNote.reminder!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isReminderComplete(_currentNote.reminder!)
                                ? Colors.green.withOpacity(0.5)
                                : textColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isReminderComplete(_currentNote.reminder!)
                                  ? Icons.check_circle
                                  : Icons.alarm,
                              size: 16,
                              color: _isReminderComplete(_currentNote.reminder!)
                                  ? Colors.green
                                  : textColor.withOpacity(0.8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatReminderDate(_currentNote.reminder!),
                              style: TextStyle(
                                color:
                                    _isReminderComplete(_currentNote.reminder!)
                                    ? Colors.green
                                    : textColor.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ----------------------------------
                    const SizedBox(height: 16),
                    SelectionArea(
                      child: Text.rich(
                        _buildRichText(_currentNote.content, textColor),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Note"),
        content: const Text("Delete this note?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _databaseHelper.deleteNote(_currentNote.id!);
      if (mounted) Navigator.pop(context);
    }
  }
}
