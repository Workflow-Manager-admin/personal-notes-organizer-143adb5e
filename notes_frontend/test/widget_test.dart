import 'package:flutter_test/flutter_test.dart';
import 'package:notes_frontend/main.dart';

void main() {
  testWidgets('App bar has correct title', (WidgetTester tester) async {
    await tester.pumpWidget(const NotesApp());
    expect(find.text('Notes'), findsOneWidget); // Matches main appbar
  });

  testWidgets('Can render empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const NotesApp());
    await tester.pump(const Duration(milliseconds: 500)); // Let consumer update
    expect(find.textContaining('No notes yet'), findsWidgets);
  });
}
