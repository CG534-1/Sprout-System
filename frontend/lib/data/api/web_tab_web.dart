import 'package:web/web.dart';

const _tabKey = 'sprout.splash_tab';

bool webTabStillOpen() => window.sessionStorage.getItem(_tabKey) == '1';

void markWebTabOpen() {
  window.sessionStorage.setItem(_tabKey, '1');
}
