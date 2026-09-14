import 'package:flutter/material.dart';

enum PolicyKind { privacy, terms, licences }

/// In-app copy of the policy documents. Keep store/PRIVACY_POLICY.md in sync
/// with the privacy text here - Play Console requires it in the listing too.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.kind});

  final PolicyKind kind;

  static const _privacy = '''
Privacy Policy — Combo Universal

Last updated: 15 September 2026

1. What we collect
Combo Universal does not ask you to create an account and does not collect your name, phone number, email, contacts, photos, location or files.

2. Data stored on your device
Recent searches, saved lists, order-list notes, theme choice, text-size preference and the downloaded compatibility list are stored only on your device using local storage. Uninstalling the app or clearing app storage deletes this data. The app does not upload searches, saved lists, order-list notes or the catalog to us.

3. Network use and sharing
The app works fully offline by default. A build with list updates enabled downloads an updated compatibility list over HTTPS. The update request exposes the usual network metadata, such as your IP address, to the configured hosting provider; no account or app profile is sent. When you explicitly tap Share or Copy, the selected compatibility text is handed to the Android share target or clipboard you chose. Combo Universal does not collect that shared text.

4. Advertising and Google Mobile Ads
We use Google Mobile Ads to keep the app free. The SDK may automatically collect and share with Google: your IP address, which may be used to estimate general location; user product interactions such as app launches, taps and ad or video views; diagnostic information such as app launch time, hang rate and energy use; and device or account identifiers such as the Android Advertising ID and App Set ID. Google states that it uses these categories for advertising, analytics and fraud prevention, and encrypts them in transit. The app does not send your searches, saved lists or shop notes to Google.

Before the first ad SDK request, the app shows an in-app disclosure. In the European Economic Area, the UK and Switzerland, Google's User Messaging Platform may show a consent form. Your choices can limit or prevent ad requests and you can revisit required privacy options from Settings. You can also request non-personalised ads in Settings and reset or delete the Android Advertising ID in Android settings. Google's practices are described at https://policies.google.com/technologies/ads and https://developers.google.com/admob/android/privacy/play-data-disclosure.

5. Children
The app is intended for mobile repair professionals and shop owners and is not directed at children under 13. It is not enrolled in Google Play's Designed for Families programme.

6. Security and retention
We use HTTPS/TLS for network requests. No account is created and no personal data is retained on our servers. Google may retain advertising and diagnostic data under Google's policies. Local data remains until you clear it, clear app storage or uninstall the app.

7. Your choices
You can decline the initial ad disclosure for that session, change ad personalisation in Settings, use Google's required privacy-options entry point when shown, clear recent searches and saved data in the app, or uninstall the app to remove local data.

8. Changes
Any change to this policy will be published inside the app with an updated date.

9. Contact
Makund Mobile, Lathor, Bolangir, Odisha, India 767038
WhatsApp: +91 72057 02493
''';

  static const _terms = '''
Terms of Use & Disclaimer — Combo Universal
Last updated: 15 September 2026

1. Purpose
Combo Universal provides reference information about which mobile display, combo, battery, frame, power/volume flex, charging sub-board, display connector, back cover, tempered glass and Touch/OCA glass parts are commonly interchangeable between models.

2. Accuracy disclaimer
The compatibility data is community contributed and provided "as is" for guidance only. Manufacturers change panels, connectors and flex layouts within the same model name. Always physically verify connector pin count, pitch, latch, flex length, frame revision, panel type and touch calibration before fitting a part. Touch / OCA glass is a lamination part, not tempered screen-guard glass.

3. No liability
We are not liable for any loss, damaged part, damaged device or business loss arising from the use of this information. The final decision to fit a part is yours.

4. No affiliation
Brand names such as Samsung, Xiaomi, Redmi, Vivo, iQOO, Oppo, Realme, OnePlus, Apple, Motorola, Infinix, Tecno, Itel, Lava and Honor are trademarks of their respective owners. This app is an independent reference tool and is not endorsed by, affiliated with, or sponsored by any of them. Model names appear only to describe which spare part physically fits which handset, which is a factual statement of compatibility.

5. Where the data comes from
The compatibility list is curated by Makund Mobile from manually researched manufacturer and supplier references, our own parts records and workshop checks. The selection, organization and original notes are our work; we do not claim ownership of third-party source material and do not copy another app or database wholesale.

6. Acceptable use
Please do not scrape, resell or redistribute the app's compilation or original notes as your own product. You are free to use the compatibility information to run your repair business. If you believe a listing uses material without permission, report it so we can review it.

7. Reporting a problem
If you believe anything in this app infringes your rights, contact us on the WhatsApp number below and we will review and remove it promptly.

8. Ads
The app is free and supported by advertising. Ad content is served by Google and is not selected or endorsed by us. In the EEA, UK and Switzerland, Google's consent flow may offer personalised, non-personalised or limited ad choices; you can revisit required privacy options from Settings.

9. Contact
WhatsApp: +91 72057 02493
''';

  static const _titles = <PolicyKind, String>{
    PolicyKind.privacy: 'Privacy policy',
    PolicyKind.terms: 'Terms & disclaimer',
    PolicyKind.licences: 'Open source licences',
  };

  static const _bodies = <PolicyKind, String>{
    PolicyKind.privacy: _privacy,
    PolicyKind.terms: _terms,
    PolicyKind.licences: _licences,
  };

  static const _licences = '''
Open Source Licences — Combo Universal
Last updated: 15 September 2026

1. Typefaces
This app bundles the Sora, Inter and JetBrains Mono typefaces. All three are licensed under the SIL Open Font License, Version 1.1. The full licence text ships with the app in assets/google_fonts/OFL.txt. Sora is copyright The Sora Project Authors, Inter is copyright The Inter Project Authors, and JetBrains Mono is copyright The JetBrains Mono Project Authors.

2. Software libraries
The app is built with Flutter, which is copyright The Flutter Authors and licensed under the BSD 3-Clause License. Direct dependencies include google_mobile_ads, shared_preferences, http, share_plus, package_info_plus, connectivity_plus, google_fonts and cupertino_icons. Tap the button below for the complete, generated list of every direct and transitive package and its licence.

3. Icons
Interface icons are Material Symbols, copyright Google, licensed under the Apache License 2.0.

4. Compatibility data
The compatibility list is curated by Makund Mobile from manually researched manufacturer and supplier references, our own parts records and workshop checks. The selection, organization and original notes are our work; third-party source material is not claimed as owned or copied wholesale.

5. Trademarks
Manufacturer and model names are trademarks of their respective owners and are used here only to state which spare part fits which handset. No manufacturer logo or wordmark is used anywhere in this app.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[kind]!)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PolicyBody(text: _bodies[kind]!),
            if (kind == PolicyKind.licences) ...[
              const SizedBox(height: 12),
              // Flutter's built-in registry lists every package licence.
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('View full package licences'),
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Combo Universal',
                  applicationLegalese:
                      '\u00a9 2026 Makund Mobile. Brand names are trademarks of '
                      'their respective owners.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders the plain-text policy with real typographic hierarchy: the first
/// line becomes a heading, numbered clauses become bold subheadings, and the
/// rest flows as readable body copy.
class _PolicyBody extends StatelessWidget {
  const _PolicyBody({required this.text});

  final String text;

  static final _clause = RegExp(r'^\d+\.\s');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = text.trim().split('\n');
    final children = <Widget>[];

    for (var i = 0; i < blocks.length; i++) {
      final line = blocks[i].trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 12));
        continue;
      }
      if (i == 0) {
        children.add(SelectableText(line, style: theme.textTheme.headlineSmall));
        continue;
      }
      if (line.startsWith('Last updated')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(line, style: theme.textTheme.labelSmall),
        ));
        continue;
      }
      final isHeading = _clause.hasMatch(line);
      children.add(SelectableText(
        line,
        style: isHeading
            ? theme.textTheme.titleSmall
            : theme.textTheme.bodyMedium?.copyWith(height: 1.55),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
