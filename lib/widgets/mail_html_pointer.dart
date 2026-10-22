import 'package:flutter/foundation.dart';

class MailHtmlPointer {
  static final enabled = ValueNotifier<bool>(true);

  static void pause() => enabled.value = false;

  static void resume() => enabled.value = true;
}
