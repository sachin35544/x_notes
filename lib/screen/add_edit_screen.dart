import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:x_notes/services/database_helper.dart';
import 'package:x_notes/services/notification_service.dart';
import '../model/notes_model.dart';

class AddEditNoteScreen extends StatefulWidget {
  final Note? note;
  const AddEditNoteScreen({super.key, this.note});

  @override
  State<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends State<AddEditNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final UndoHistoryController _undoController = UndoHistoryController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Color _selectedColor = Colors.transparent;
  String? _imagePath;
  String? _reminderDateTime; // Reminder variable

  final ImagePicker _picker = ImagePicker();

  bool _isListMode = false;
  bool _showFormattingToolbar = false;

  final Gradient _brandGradient = const LinearGradient(
    colors: [Color(0xFF00004D), Color(0xFF001A80), Color(0xFF0040FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final List<Color> _colors = [
    Colors.transparent,
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
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _selectedColor = widget.note!.color == 'default'
          ? Colors.transparent
          : Color(int.parse(widget.note!.color));
      _imagePath = widget.note!.imagePath;
      _reminderDateTime = widget.note!.reminder; // Load reminder

      if (_contentController.text.contains('[ ]') ||
          _contentController.text.contains('[x]')) {
        _isListMode = true;
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imagePath = image.path);
  }

  // --- REMINDER PICKER ---
  Future<void> _pickReminder() async {
    final DateTime now = DateTime.now();
    DateTime initialDate = _reminderDateTime != null
        ? DateTime.parse(_reminderDateTime!)
        : now;

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final DateTime reminder = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _reminderDateTime = reminder.toString();
    });
  }

  String _formatDate(String dateStr) {
    DateTime dt = DateTime.parse(dateStr);
    String period = dt.hour >= 12 ? 'PM' : 'AM';
    int hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    if (hour == 0) hour = 12;
    return "${dt.day}/${dt.month} $hour:${dt.minute.toString().padLeft(2, '0')} $period";
  }

  void _toggleListMode() {
    setState(() {
      _isListMode = !_isListMode;
      String currentText = _contentController.text;
      List<String> lines = currentText.split('\n');
      if (_isListMode) {
        if (currentText.trim().isEmpty) {
          _contentController.text = "[ ] ";
        } else {
          for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            if (line.isNotEmpty &&
                !line.startsWith('[ ]') &&
                !line.startsWith('[x]')) {
              lines[i] = "[ ] $line";
            }
          }
          _contentController.text = lines.join('\n');
        }
      } else {
        for (int i = 0; i < lines.length; i++) {
          String line = lines[i];
          if (line.startsWith('[ ] '))
            lines[i] = line.substring(4);
          else if (line.startsWith('[x] '))
            lines[i] = line.substring(4);
          else if (line.startsWith('[ ]'))
            lines[i] = line.substring(3);
          else if (line.startsWith('[x]'))
            lines[i] = line.substring(3);
        }
        _contentController.text = lines.join('\n');
      }
    });
  }

  void _deleteLine(int index) {
    List<String> lines = _contentController.text.split('\n');
    if (index < lines.length) {
      lines.removeAt(index);
      _contentController.text = lines.join('\n');
      setState(() {});
    }
  }

  void _toggleCheckboxState(int index, bool currentVal) {
    List<String> lines = _contentController.text.split('\n');
    if (index < lines.length) {
      String line = lines[index];
      if (currentVal) {
        lines[index] = line.replaceFirst('[x]', '[ ]');
      } else {
        lines[index] = line.replaceFirst('[ ]', '[x]');
      }
      _contentController.text = lines.join('\n');
      setState(() {});
    }
  }

  void _addNewListItem() {
    String currentText = _contentController.text;
    if (currentText.isNotEmpty) {
      _contentController.text = "$currentText\n[ ] ";
    } else {
      _contentController.text = "[ ] ";
    }
    setState(() {});
  }

  void _applyStyle(String startTag, String endTag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (selection.start < 0) return;
    if (selection.start != selection.end) {
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        "$startTag${text.substring(selection.start, selection.end)}$endTag",
      );
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.end + startTag.length + endTag.length,
        ),
      );
    } else {
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        "$startTag$endTag",
      );
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + startTag.length,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = _selectedColor == Colors.transparent
        ? (isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5))
        : _selectedColor;
    Color textColor =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
        ? Colors.white
        : Colors.black;
    Color iconColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: _brandGradient),
        ),
        actions: [
          // Alarm Icon Here
          IconButton(
            onPressed: _pickReminder,
            icon: Icon(
              Icons.alarm_add,
              color: _reminderDateTime != null ? Colors.amber : Colors.white,
            ),
            tooltip: "Set Reminder",
          ),
          TextButton(
            onPressed: _saveNote,
            child: const Text(
              "Save",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_reminderDateTime != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 16,
                        right: 16,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey[800]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.alarm,
                              size: 18,
                              color: textColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_reminderDateTime!),
                              style: TextStyle(
                                color: textColor.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () =>
                                  setState(() => _reminderDateTime = null),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_imagePath != null)
                    Stack(
                      children: [
                        Image.file(
                          File(_imagePath!),
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  setState(() => _imagePath = null),
                            ),
                          ),
                        ),
                      ],
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: "Title",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _isListMode
                        ? _buildChecklistEditor(textColor)
                        : _buildStandardEditor(textColor),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2E33) : Colors.grey[200],
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.black : Colors.grey[300]!,
                ),
              ),
            ),
            child: _showFormattingToolbar
                ? _buildFormattingToolbar(iconColor)
                : _buildMainToolbar(iconColor, context),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardEditor(Color textColor) {
    return TextField(
      controller: _contentController,
      undoController: _undoController,
      maxLines: null,
      minLines: 15,
      style: TextStyle(fontSize: 18, color: textColor),
      decoration: InputDecoration(
        hintText: "Note something down...",
        border: InputBorder.none,
        hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
      ),
    );
  }

  Widget _buildChecklistEditor(Color textColor) {
    List<String> lines = _contentController.text.split('\n');
    if (lines.isEmpty) return Container();
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            String line = lines[index];
            bool isChecked = line.startsWith('[x]');
            bool isUnchecked = line.startsWith('[ ]');
            bool isListItem = isChecked || isUnchecked;
            if (!isListItem) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: TextEditingController(text: line),
                  onChanged: (val) {
                    lines[index] = val;
                    _contentController.text = lines.join('\n');
                  },
                  style: TextStyle(fontSize: 18, color: textColor),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              );
            }
            String pureText = line.length > 3 ? line.substring(4) : "";
            return Row(
              children: [
                IconButton(
                  icon: Icon(
                    isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isChecked ? Colors.blue : textColor.withOpacity(0.5),
                  ),
                  onPressed: () => _toggleCheckboxState(index, isChecked),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: pureText,
                    onChanged: (val) {
                      String prefix = isChecked ? '[x] ' : '[ ] ';
                      lines[index] = prefix + val;
                      _contentController.text = lines.join('\n');
                    },
                    style: TextStyle(
                      fontSize: 18,
                      color: textColor,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "List item",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => _deleteLine(index),
                ),
              ],
            );
          },
        ),
        InkWell(
          onTap: _addNewListItem,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                const Icon(Icons.add, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  "List item",
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Clean Toolbar
  Widget _buildMainToolbar(Color iconColor, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: _pickImage,
          icon: Icon(Icons.image_outlined, color: iconColor),
        ),
        IconButton(
          onPressed: () => _showColorPalette(context),
          icon: Icon(Icons.palette_outlined, color: iconColor),
        ),
        IconButton(
          onPressed: _toggleListMode,
          icon: Icon(
            _isListMode ? Icons.check_box : Icons.check_box_outline_blank,
            color: _isListMode ? Colors.blue : iconColor,
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _showFormattingToolbar = true),
          icon: Icon(Icons.text_format, color: iconColor),
        ),
        ValueListenableBuilder(
          valueListenable: _undoController,
          builder: (context, value, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.undo,
                  color: value.canUndo ? iconColor : iconColor.withOpacity(0.3),
                ),
                onPressed: value.canUndo ? () => _undoController.undo() : null,
              ),
              IconButton(
                icon: Icon(
                  Icons.redo,
                  color: value.canRedo ? iconColor : iconColor.withOpacity(0.3),
                ),
                onPressed: value.canRedo ? () => _undoController.redo() : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormattingToolbar(Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: () => _applyStyle('**', '**'),
          icon: Icon(Icons.format_bold, color: iconColor),
        ),
        IconButton(
          onPressed: () => _applyStyle('_', '_'),
          icon: Icon(Icons.format_italic, color: iconColor),
        ),
        IconButton(
          onPressed: () => _applyStyle('<u>', '</u>'),
          icon: Icon(Icons.format_underline, color: iconColor),
        ),
        IconButton(
          onPressed: () => setState(() => _showFormattingToolbar = false),
          icon: const Icon(Icons.close, color: Colors.redAccent),
        ),
      ],
    );
  }

  void _showColorPalette(BuildContext context) {
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
                onTap: () {
                  setState(() => _selectedColor = color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.grey[300] : color,
                    shape: BoxShape.circle,
                    border: _selectedColor == color
                        ? Border.all(color: Colors.blue, width: 3)
                        : null,
                  ),
                  child: index == 0
                      ? const Icon(Icons.format_color_reset, size: 20)
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty &&
        _contentController.text.isEmpty &&
        _imagePath == null) {
      Navigator.pop(context);
      return;
    }
    String colorToSave = _selectedColor == Colors.transparent
        ? 'default'
        : _selectedColor.value.toString();

    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: _contentController.text,
      color: colorToSave,
      dateTime: DateTime.now().toString(),
      imagePath: _imagePath,
      isBold: 0,
      isItalic: 0,
      isUnderline: 0,
      reminder: _reminderDateTime,
    );

    int id = 0;
    if (widget.note == null) {
      id = await _databaseHelper.insertNote(note);
    } else {
      id = widget.note!.id!;
      await _databaseHelper.updateNote(note);
    }

    // --- 👇👇 NOTIFICATION LOGIC UPDATED 👇👇 ---
    if (_reminderDateTime != null) {
      DateTime scheduleTime = DateTime.parse(_reminderDateTime!);

      if (scheduleTime.isAfter(DateTime.now())) {
        // 1. Title decide karo (Agar title khali hai to 'Untitled Note' likho)
        String notifTitle = _titleController.text.trim();
        if (notifTitle.isEmpty) notifTitle = "Untitled Note";

        // 2. Body decide karo (Agar content khali hai to 'Check your note' likho)
        String notifBody = _contentController.text.trim();
        if (notifBody.isEmpty) notifBody = "Check your note details";

        // 3. Asli Data Bhejo
        await NotificationService.scheduleNotification(
          id,
          notifTitle, // ✅ Ab ye Note ka Title hoga
          notifBody, // ✅ Ab ye Note ka Pura Content hoga
          scheduleTime,
        );
      }
    } else {
      await NotificationService.cancelNotification(id);
    }
    // ---------------------------------------------

    if (mounted) Navigator.pop(context);
  }
}
