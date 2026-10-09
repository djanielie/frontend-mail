class MailCache {
  static Future<void> saveFolders(String email, List<Map<String, dynamic>> folders) async {}

  static Future<void> saveMessages(String email, String folder, Map<String, dynamic> payload) async {}

  static Future<void> saveDetail(String email, Map<String, dynamic> payload) async {}

  static Future<List<Map<String, dynamic>>?> loadFolders(String email) async => null;

  static Future<Map<String, dynamic>?> loadMessages(String email, String folder) async => null;

  static Future<Map<String, dynamic>?> loadDetail(String email) async => null;
}
