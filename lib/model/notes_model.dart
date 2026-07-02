class Note {
  final int? id;
  final String title;
  final String content;
  final String color;
  final String dateTime;
  final String? imagePath;
  final int isBold;
  final int isItalic;
  final int isUnderline;
  final int isPinned;
  final String? reminder; // Naya Field

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.color,
    required this.dateTime,
    this.imagePath,
    this.isBold = 0,
    this.isItalic = 0,
    this.isUnderline = 0,
    this.isPinned = 0,
    this.reminder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'color': color,
      'dateTime': dateTime,
      'imagePath': imagePath,
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderline': isUnderline,
      'isPinned': isPinned,
      'reminder': reminder,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      color: map['color'],
      dateTime: map['dateTime'],
      imagePath: map['imagePath'],
      isBold: map['isBold'] ?? 0,
      isItalic: map['isItalic'] ?? 0,
      isUnderline: map['isUnderline'] ?? 0,
      isPinned: map['isPinned'] ?? 0,
      reminder: map['reminder'],
    );
  }
}
