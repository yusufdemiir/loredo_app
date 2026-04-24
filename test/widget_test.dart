import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loredo_app/main.dart';

void main() {
  testWidgets('renders injected home without Firebase runtime', (tester) async {
    await tester.pumpWidget(
      const MyApp(home: _TestHome()),
    );

    expect(find.text('Test Home'), findsOneWidget);
  });
}

class _TestHome extends StatelessWidget {
  const _TestHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Test Home')),
    );
  }
}
