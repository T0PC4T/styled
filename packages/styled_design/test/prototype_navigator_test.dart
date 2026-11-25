import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styled_design/styled_design.dart';

const _routes = {
  'admin.dashboard': '/admin',
  'admin.automations': '/admin/automations',
  'admin.automationEditor': '/admin/automations/:id',
  'admin.settings': '/admin/settings',
};

DesignDestination _to(String screenId, [String? path]) =>
    DesignDestination(screenId, Uri.parse(path ?? _routes[screenId]!));

void main() {
  late BuildContext context;
  late PrototypeNavigator nav;
  late List<String> calls;

  Future<void> setUpNavigator(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    context = tester.element(find.byType(SizedBox));
    calls = [];
    nav = PrototypeNavigator(routeOf: (id) => _routes[id], onNavigate: calls.add);
    addTearDown(nav.dispose);
  }

  List<String> stack() => [for (final p in nav.pages) '${p.screenId} ${p.location}'];

  testWidgets('push stacks pages, reads params from the location, and completes when popped', (tester) async {
    await setUpNavigator(tester);
    nav.start(_to('admin.automations'), fixture: 'empty');
    expect(nav.top!.fixture, 'empty');
    var notified = 0;
    nav.addListener(() => notified++);

    Object? popped = 'pending';
    nav.push(context, _to('admin.automationEditor', '/admin/automations/auto_welcome')).then((v) => popped = v);
    expect(stack(), ['admin.automations /admin/automations', 'admin.automationEditor /admin/automations/auto_welcome']);
    expect(nav.top!.params, {'id': 'auto_welcome'});
    expect(nav.top!.fixture, isNull, reason: 'pages navigated to draw their default fixture');
    expect(nav.pages.first.key, isNot(nav.top!.key));

    expect(nav.pop('saved'), isTrue);
    await tester.pump();
    expect(popped, 'saved');
    expect(stack(), ['admin.automations /admin/automations']);
    expect(nav.pop(), isFalse, reason: 'the last page stays');
    expect(notified, 2);
    expect(calls, ['push /admin/automations/auto_welcome']);
  });

  testWidgets('back pops, or shows the fallback when nothing is below', (tester) async {
    await setUpNavigator(tester);
    nav.start(_to('admin.automations'));
    nav.push(context, _to('admin.automationEditor', '/admin/automations/a1'));
    nav.back(context, _to('admin.automations'));
    expect(stack(), ['admin.automations /admin/automations']);

    nav.start(_to('admin.automationEditor', '/admin/automations/a1'));
    nav.back(context, _to('admin.automations'));
    expect(stack(), ['admin.automations /admin/automations'], reason: 'the fallback replaces the only page');
  });

  testWidgets('backTo pops down to the ancestor on the stack, else shows it', (tester) async {
    await setUpNavigator(tester);
    nav.start(_to('admin.dashboard'));
    final below = nav.top!.key;
    Object? completed = 'pending';
    nav.push(context, _to('admin.automations'));
    nav.push(context, _to('admin.automationEditor', '/admin/automations/a1')).then((v) => completed = v);
    nav.backTo(context, _to('admin.dashboard'));
    await tester.pump();
    expect(stack(), ['admin.dashboard /admin']);
    expect(nav.top!.key, below, reason: 'the ancestor keeps its page, so its state survives');
    expect(completed, isNull);

    nav.replaceAll(context, _to('admin.automations'));
    nav.backTo(context, _to('admin.dashboard'));
    expect(stack(), ['admin.dashboard /admin'], reason: 'not on the stack: shown in place of it');
    expect(calls, [
      'push /admin/automations',
      'push /admin/automations/a1',
      'backTo /admin',
      'replaceAll /admin/automations',
      'backTo /admin',
    ]);
  });

  testWidgets('replaceAll leaves one page; replace swaps the top', (tester) async {
    await setUpNavigator(tester);
    nav.start(_to('admin.dashboard'));
    nav.push(context, _to('admin.automations'));
    nav.replace(context, _to('admin.settings'));
    expect(stack(), ['admin.dashboard /admin', 'admin.settings /admin/settings']);
    nav.replaceAll(context, _to('admin.automations'));
    expect(stack(), ['admin.automations /admin/automations']);
  });

  testWidgets('setQuery merges into the top page only; null or empty removes a key', (tester) async {
    await setUpNavigator(tester);
    nav.start(_to('admin.automations', '/admin/automations?tab=all'));
    nav.push(context, _to('admin.settings'));
    nav.setQuery(context, {'section': 'email'}, history: false);
    expect(nav.top!.query, {'section': 'email'});
    nav.pop();
    expect(nav.top!.query, {'tab': 'all'}, reason: 'each page keeps its own query');
    nav.setQuery(context, {'tab': 'paused', 'q': 'dbs'}, history: true);
    expect(nav.top!.location.toString(), '/admin/automations?tab=paused&q=dbs');
    nav.setQuery(context, {'tab': null, 'q': ''}, history: false);
    expect(nav.top!.location.toString(), '/admin/automations');
    expect(calls.where((c) => c.startsWith('setQuery')), [
      'setQuery section=email',
      'setQuery tab=paused&q=dbs',
      'setQuery tab&q',
    ]);
  });

  test('routeParams reads the params a route names', () {
    expect(PrototypeNavigator.routeParams('/admin/automations/:id', Uri.parse('/admin/automations/a%20b')), {
      'id': 'a b',
    });
    expect(PrototypeNavigator.routeParams('/admin/automations/:id', Uri.parse('/admin/users/x')), isEmpty);
    expect(PrototypeNavigator.routeParams(null, Uri.parse('/x')), isEmpty);
  });
}
