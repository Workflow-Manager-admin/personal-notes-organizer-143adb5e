import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Color scheme constants as per requirements.
const Color kPrimaryColor = Color(0xFF1976D2);
const Color kSecondaryColor = Color(0xFF424242);
const Color kAccentColor = Color(0xFFFFCA28);

void main() {
  runApp(const NotesApp());
}

// PUBLIC_INTERFACE
/// The root NotesApp widget which sets up [NotesProvider] and theming.
class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotesProvider()..loadNotes(),
      child: MaterialApp(
        title: 'Notes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.light(
            primary: kPrimaryColor,
            secondary: kSecondaryColor,
            surface: Colors.white,
            // Deprecated 'background': Use 'surface' for backgrounds in modern MaterialScheme.
            // background: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: kSecondaryColor,
            // onBackground: kSecondaryColor, // Omit deprecated
            error: Colors.red,
            onError: Colors.white,
            tertiary: kAccentColor,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            color: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: kPrimaryColor),
            titleTextStyle: TextStyle(
              color: kPrimaryColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusColor: kAccentColor,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: kPrimaryColor, width: 2),
            ),
          ),
          hintColor: kSecondaryColor,
        ),
        home: const NotesListScreen(),
      ),
    );
  }
}

// PUBLIC_INTERFACE
/// Note model representing a single note entity.
class Note {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert Note to Map for DB storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a Note from a DB map.
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

// PUBLIC_INTERFACE
/// Provider managing the state, logic, and local storage for notes.
class NotesProvider extends ChangeNotifier {
  final List<Note> _notes = [];
  late Database _db;
  bool _initialized = false;
  String _searchQuery = '';

  List<Note> get notes => _notes
    .where((n) =>
      n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      n.content.toLowerCase().contains(_searchQuery.toLowerCase())
    )
    .toList();

  bool get loading => !_initialized;
  String get searchQuery => _searchQuery;

  // PUBLIC_INTERFACE
  /// Loads notes from local DB. If DB not initialized, sets up DB.
  Future<void> loadNotes() async {
    _db = await _initDb();
    final List<Map<String, dynamic>> maps = await _db.query('notes', orderBy: 'updated_at DESC');
    _notes..clear()..addAll(maps.map(Note.fromMap));
    _initialized = true;
    notifyListeners();
  }

  // Initialize the database, creating table if not exists.
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notes_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // PUBLIC_INTERFACE
  /// Adds a new note.
  Future<void> addNote(String title, String content) async {
    final now = DateTime.now();
    final note = Note(
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _db.insert('notes', note.toMap());
    _notes.insert(0, note.copyWith(id: id)); // show newest on top
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  /// Updates an existing note by id.
  Future<void> updateNote(Note note, String newTitle, String newContent) async {
    final updated = Note(
      id: note.id,
      title: newTitle,
      content: newContent,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
    );
    await _db.update(
      'notes',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      _notes[idx] = updated;
      // bring to top
      final noteToBringTop = _notes.removeAt(idx);
      _notes.insert(0, noteToBringTop);
    }
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  /// Deletes a note by id.
  Future<void> deleteNote(Note note) async {
    await _db.delete('notes', where: 'id = ?', whereArgs: [note.id]);
    _notes.removeWhere((n) => n.id == note.id);
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  /// Sets the search query used to filter notes.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}

extension _NoteCopy on Note {
  // Helper to copy a Note with optional new id.
  Note copyWith({int? id, String? title, String? content, DateTime? createdAt, DateTime? updatedAt}) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// PUBLIC_INTERFACE
/// The main screen showing the notes list, search, and add button.
class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, model, _) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            title: Text('Notes', style: TextStyle(color: kPrimaryColor)),
            actions: [
              _SearchIconButton(),
            ],
          ),
          body: model.loading
              ? const Center(child: CircularProgressIndicator())
              : model.notes.isEmpty
                  ? _EmptyNotesWidget()
                  : _NotesListView(notes: model.notes),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const NoteEditScreen()),
            ),
            tooltip: 'Add Note',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

/// Floating search icon in AppBar opens search dialog.
class _SearchIconButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.search, color: kPrimaryColor),
      tooltip: 'Search',
      onPressed: () async {
        final model = Provider.of<NotesProvider>(context, listen: false);
        final result = await showSearch<String?>(
          context: context,
          delegate: NotesSearchDelegate(model),
        );
        if (result == null || result.isEmpty) {
          model.setSearchQuery('');
        }
      },
    );
  }
}

/// The main scrollable list of notes.
class _NotesListView extends StatelessWidget {
  final List<Note> notes;
  const _NotesListView({required this.notes});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: notes.length,
      itemBuilder: (context, idx) =>
          _NoteCard(note: notes[idx], key: ValueKey(notes[idx].id)),
    );
  }
}

/// Widget displaying a single note in the list.
class _NoteCard extends StatelessWidget {
  final Note note;
  const _NoteCard({required this.note, super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    return Dismissible(
      key: ValueKey(note.id),
      background: _deleteBackground(),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await provider.deleteNote(note);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted.'),
            duration: Duration(milliseconds: 900),
            backgroundColor: kAccentColor,
          ),
        );
      },
      child: Card(
        elevation: 1,
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text(
            note.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kSecondaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          subtitle: Text(
            note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit, color: kPrimaryColor),
            tooltip: 'Edit note',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (ctx) => NoteEditScreen(note: note))),
          ),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => NoteEditScreen(note: note))),
        ),
      ),
    );
  }

  Widget _deleteBackground() => Container(
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.red, size: 28),
      );
}

/// Displays an empty state when there are no notes.
class _EmptyNotesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "No notes yet.\nTap '+' to create your first note!",
        textAlign: TextAlign.center,
        style: TextStyle(color: kSecondaryColor, fontSize: 18),
      ),
    );
  }
}

// PUBLIC_INTERFACE
/// Search delegate for searching notes by title/content.
class NotesSearchDelegate extends SearchDelegate<String?> {
  final NotesProvider model;
  NotesSearchDelegate(this.model)
      : super(
          searchFieldLabel: 'Search notes...',
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: kSecondaryColor),
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(color: kPrimaryColor, fontSize: 18),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: kPrimaryColor),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    model.setSearchQuery(query);
    final filtered = model.notes;
    return filtered.isEmpty
        ? const _EmptyNotesWidget()
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            children: filtered
                .map((n) => _NoteCard(note: n, key: ValueKey(n.id)))
                .toList(),
          );
  }

  @override
  Widget buildResults(BuildContext context) {
    model.setSearchQuery(query);
    final filtered = model.notes;
    return filtered.isEmpty
        ? const _EmptyNotesWidget()
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            children: filtered
                .map((n) => _NoteCard(note: n, key: ValueKey(n.id)))
                .toList(),
          );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: kPrimaryColor),
          onPressed: () {
            query = '';
            model.setSearchQuery('');
          },
        )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: kPrimaryColor),
      onPressed: () {
        model.setSearchQuery('');
        close(context, null);
      },
    );
  }
}

// PUBLIC_INTERFACE
/// The note editor/creation screen (for both editing and new note).
class NoteEditScreen extends StatefulWidget {
  final Note? note;
  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _content;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = widget.note?.title ?? '';
    _content = widget.note?.content ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Note' : 'New Note'),
        iconTheme: const IconThemeData(color: kPrimaryColor),
        actions: [
          if (!_saving)
            IconButton(
              icon: const Icon(Icons.check, color: kPrimaryColor),
              tooltip: 'Save',
              onPressed: _saveNote,
            ),
        ],
        backgroundColor: Colors.white,
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: _title,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter note title',
                        prefixIcon: Icon(Icons.title),
                      ),
                      maxLength: 60,
                      style: const TextStyle(fontSize: 18),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Title required' : null,
                      onSaved: (v) => _title = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _content,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        hintText: 'Enter note content',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      minLines: 6,
                      maxLines: null,
                      style: const TextStyle(fontSize: 16),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Content required'
                          : null,
                      onSaved: (v) => _content = v?.trim() ?? '',
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 22),
                      TextButton.icon(
                        onPressed: () async {
                          // Show dialog and then pop after operation to avoid issues with async context
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext ctx) => AlertDialog(
                              title: const Text('Delete Note?'),
                              content: const Text(
                                  'This note will be permanently deleted. Are you sure?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    )),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            // Move pop before async
                            Navigator.of(context).pop();
                            setState(() => _saving = true);
                            final provider = Provider.of<NotesProvider>(context, listen: false);
                            await provider.deleteNote(widget.note!);
                            setState(() => _saving = false);
                          }
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  void _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);

    final provider = Provider.of<NotesProvider>(context, listen: false);
    // Pop navigator *before* await to avoid context across async gap
    Navigator.of(context).pop();
    if (widget.note == null) {
      await provider.addNote(_title, _content);
    } else {
      await provider.updateNote(widget.note!, _title, _content);
    }
    // Remove pop from here to avoid context issues after await
    setState(() => _saving = false);
  }
}
