import 'package:flutter_test/flutter_test.dart';
import 'package:zero_one_form/main.dart';

void main() {
  testWidgets('Student Survey App launch test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const AcademySurveyApp(),
    );

    // Verify student survey welcome message is loaded
    expect(find.text('Zero One Academy'), findsWidgets);
  });
}
