import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// APP CONFIG & LINKS (FETCHED FROM GOOGLE SHEET - Native HttpClient)
// ---------------------------------------------------------------------------
class AppLinks {
  // Google Sheet CSV URL
  static const String csvUrl =
      "https://docs.google.com/spreadsheets/d/e/2PACX-1vTJx948x-lYMT9vg-ROQvIU8P6GmDjNF9Vvy6439HMYJpwfQCiazSFp1XlAC1MSJZU6-eJB0t97GfTj/pub?gid=0&single=true&output=csv";

  // Default Links
  static String rateUs =
      "https://play.google.com/store/apps/details?id=com.sktechstudio.qrscanner";
  static String privacyPolicy = "https://www.google.com";
  static String termsConditions = "https://www.google.com";
  static String disclaimer = "https://www.google.com";
  static String shareMessage =
      "Check out this amazing QR Scanner app: https://play.google.com/store/apps/details?id=com.sktechstudio.qrscanner";

  // Function to Fetch and Parse CSV
  static Future<void> fetchConfig() async {
    if (csvUrl.isEmpty) return;
    try {
      final HttpClient client = HttpClient();
      final Uri uri = Uri.parse(csvUrl);
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        final String content = await response.transform(utf8.decoder).join();
        final List<String> lines = content.split('\n');

        for (var line in lines) {
          final List<String> parts = line.split(',');
          if (parts.length >= 2) {
            final String key = parts[0].trim().toLowerCase();
            final String value = parts.sublist(1).join(',').trim();

            if (key.contains("rate"))
              rateUs = value;
            else if (key.contains("privacy"))
              privacyPolicy = value;
            else if (key.contains("terms"))
              termsConditions = value;
            else if (key.contains("disclaimer"))
              disclaimer = value;
            else if (key.contains("share"))
              shareMessage = value;
          }
        }
      }
    } catch (e) {
      // Fail silently
    }
  }
}
