import 'package:flutter/material.dart';

enum PolicyKind { privacy, terms, licences }

/// In-app copy of the policy documents. Keep store/PRIVACY_POLICY.md in sync
/// with the privacy text here - Play Console requires it in the listing too.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.kind});

  final PolicyKind kind;

  static const _privacy = '''
Privacy Policy — Combo Universal
Last updated: 7 September 2026

1. What we collect
Combo Universal does not ask you to create an account and does not collect your name, phone number, email, contacts, photos, location or files.

2. Data stored on your device
Recent searches, saved lists, theme choice and the downloaded compatibility list are stored only on your device using local storage. Uninstalling the app deletes them. This data is never uploaded to us.

3. Network use
The app works fully offline by default. A version built with list updates enabled downloads an updated compatibility list over HTTPS. This request contains no personal identifiers beyond the standard information every internet request includes (such as your IP address, handled by the hosting provider).

4. Advertising
We show ads from Google AdMob to keep the app free. Google may use a device advertising identifier to serve and measure ads. If you are in the European Economic Area, the UK or Switzerland, we ask for your consent through Google's official consent form before any ad is loaded, and no ad is requested if you decline. You can review or change that choice at any time from Settings, switch to non-personalised ads, and reset or delete the advertising ID in your Android settings. Google's practices are described at https://policies.google.com/technologies/ads

5. Children
The app is intended for mobile repair professionals and shop owners and is not directed at children under 13.

6. Security
We use HTTPS for all network requests. No personal data is transmitted to our servers.

7. Your choices
Clear recent searches and saved lists from within the app, disable personalised ads in Settings, or uninstall the app to remove all locally stored data.

8. Changes
Any change to this policy will be published inside the app with an updated date.

9. Contact
Makund Mobile, Lathor, Bolangir, Odisha, India 767038
WhatsApp: +91 72057 02493
''';

  static const _terms = '''
Terms of Use & Disclaimer — Combo Universal
Last updated: 7 September 2026

1. Purpose
Combo Universal provides reference information about which mobile display, combo, battery, tempered glass, sub-board and frame parts are commonly interchangeable between models.

2. Accuracy disclaimer
The compatibility data is community contributed and provided "as is" for guidance only. Manufacturers change panels, connectors and flex layouts within the same model name. Always physically verify the connector type, flex length, frame fit and touch calibration before fitting a part.

3. No liability
We are not liable for any loss, damaged part, damaged device or business loss arising from the use of this information. The final decision to fit a part is yours.

4. No affiliation
Brand names such as Samsung, Xiaomi, Redmi, Vivo, iQOO, Oppo, Realme, OnePlus, Apple, Motorola, Infinix, Tecno, Itel, Lava and Honor are trademarks of their respective owners. This app is an independent reference tool and is not endorsed by, affiliated with, or sponsored by any of them. Model names appear only to describe which spare part physically fits which handset, which is a factual statement of compatibility.

5. Where the data comes from
The compatibility list is compiled by Makund Mobile from its own parts listings and from parts physically tested in our own workshop. It is not copied from any other app or database.

6. Acceptable use
The compiled list is our own work. Please do not scrape, resell or redistribute it as your own product. You are of course free to use the information to run your repair business.

7. Reporting a problem
If you believe anything in this app infringes your rights, contact us on the WhatsApp number below and we will review and remove it promptly.

8. Ads
The app is free and supported by advertising. Ad content is served by Google and is not selected or endorsed by us. In the EEA and UK you are asked for consent before any ad loads, and you can change that choice at any time from Settings.

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
Last updated: 7 September 2026

1. Typefaces
This app bundles the Sora, Inter and JetBrains Mono typefaces. All three are licensed under the SIL Open Font License, Version 1.1. The full licence text ships with the app in assets/google_fonts/OFL.txt. Sora is copyright The Sora Project Authors, Inter is copyright The Inter Project Authors, and JetBrains Mono is copyright The JetBrains Mono Project Authors.

2. Software libraries
The app is built with Flutter, which is copyright The Flutter Authors and licensed under the BSD 3-Clause License. It also uses the google_mobile_ads, shared_preferences, http and url_launcher packages. Tap the button below for the complete, generated list of every package and its licence.

3. Icons
Interface icons are Material Symbols, copyright Google, licensed under the Apache License 2.0.

4. Compatibility data
The compatibility list is compiled by Makund Mobile from its own published listings and its own workshop testing. It is not derived from any third-party app or database.

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
