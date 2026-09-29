import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/kupa_logo.dart';
import '../services/store_settings_provider.dart';
import 'package:provider/provider.dart';

class AboutGithubScreen extends StatelessWidget {
  const AboutGithubScreen({Key? key}) : super(key: key);

  static const String githubProfileUrl = 'https://github.com/israelxss';
  static const String githubRepoUrl = 'https://github.com/israelxss/kupa';
  static const String openDataUrl = 'https://www.over.org.il/projects/prices';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StoreSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('אודות וקוד פתוח 💚'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            const KupaLogo(size: 80),
            const SizedBox(height: 16),
            const Text(
              'קופה • Kupa',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text(
              'לפני שמשלמים בקופה – בודקים ב"קופה" 🛒',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Theme selector card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          settings.themeMode == AppThemeMode.system
                              ? Icons.brightness_auto
                              : (settings.themeMode == AppThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ערכת נושא (עיצוב)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              settings.themeMode == AppThemeMode.system
                                  ? 'אוטומטי לפי מצב הטלפון'
                                  : (settings.themeMode == AppThemeMode.dark ? 'מצב כהה תמיד' : 'מצב בהיר תמיד'),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => settings.cycleThemeMode(),
                      child: Text(
                        settings.themeMode == AppThemeMode.system
                            ? 'אוטומטי 📱'
                            : (settings.themeMode == AppThemeMode.dark ? 'כהה 🌙' : 'בהיר ☀️'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Open Source Mission Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.volunteer_activism, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text('קוד פתוח ושקיפות לצרכן', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'אפליקציית "קופה" פותחה כפרויקט קהילתי חופשי ופתוח לציבור על ידי israelxss.\n\n'
                      'המטרה פשוטה: לתת לכל צרכן בישראל כוח שקוף, נקי מאינטרסים מסחריים ומפרסומות. '
                      'האפליקציה מתממשקת בזמן אמת עם מאגרי חוק שקיפות המחירים הממשלתיים ופרויקט "גרסאות לעם" (over.org.il), '
                      'סורקת מעל 30 רשתות שיווק ומחשבת עבורכם את החלוקה הכי משתלמת לסל הקניות.',
                      style: TextStyle(fontSize: 13.5, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // GitHub Action Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF24292F) : Colors.black87,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.code, size: 22),
              label: const Text(
                'צפה בריפו של קופה ב-GitHub ⭐',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _launchUrl(githubRepoUrl),
            ),

            const SizedBox(height: 10),



            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.dataset_linked, size: 20),
              label: const Text('מאגר מחירי המזון (גרסאות לעם) 🔗'),
              onPressed: () => _launchUrl(openDataUrl),
            ),

            const SizedBox(height: 24),
            Text(
              'קופה • גרסה 1.0.0 • מופץ תחת רישיון MIT חופשי',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
