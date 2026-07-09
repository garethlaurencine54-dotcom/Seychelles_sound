import 'package:flutter_test/flutter_test.dart';
import 'package:seychelles_app/main.dart';

void main() {
  testWidgets('App basic compilation check', (WidgetTester tester) async {
    await tester.pumpWidget(const SeychellesSoundApp());
    expect(find.byType(MainNavigationWrapper), findsOneWidget);
  });
}

