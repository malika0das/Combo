#!/usr/bin/env bash
# Downloads the three brand fonts into assets/google_fonts/ so the app renders
# them offline and never makes a network call at runtime.
#
#   bash tools/fetch_fonts.sh
#
# The `google_fonts` package looks in that asset folder first and only falls
# back to the network (or the platform font) if a file is missing, which keeps
# the Play Data Safety form free of any "downloads at runtime" caveat.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="assets/google_fonts"
mkdir -p "$DEST"

# family:weight:filename — filenames MUST match what google_fonts expects,
# i.e. "<Family>-<Weight>.ttf" with the family name exactly as on fonts.google.com.
FILES=(
  "Sora:400:Sora-Regular.ttf"
  "Sora:600:Sora-SemiBold.ttf"
  "Sora:700:Sora-Bold.ttf"
  "Inter:400:Inter-Regular.ttf"
  "Inter:500:Inter-Medium.ttf"
  "Inter:600:Inter-SemiBold.ttf"
  "Inter:700:Inter-Bold.ttf"
  "JetBrainsMono:400:JetBrainsMono-Regular.ttf"
  "JetBrainsMono:500:JetBrainsMono-Medium.ttf"
)

# Upstream google/fonts now ships these families as single variable TTFs —
# the old ofl/<family>/static/ directories are gone, so the per-weight URLs
# above would 404. Fetch each variable font once and copy it to every static
# filename google_fonts expects in asset mode (e.g. Sora-SemiBold.ttf).
declare -A VAR_URL=(
  [Sora]="https://raw.githubusercontent.com/google/fonts/main/ofl/sora/Sora%5Bwght%5D.ttf"
  [Inter]="https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf"
  [JetBrainsMono]="https://raw.githubusercontent.com/google/fonts/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf"
)

for family in Sora Inter JetBrainsMono; do
  var_file="$DEST/$family-Variable.ttf"
  if [[ ! -s "$var_file" ]]; then
    echo "fetch   $family variable font"
    curl -fsSL --globoff "${VAR_URL[$family]}" -o "$var_file" || {
      echo "WARNING: could not download $family — the app will fall back to" >&2
      echo "         the platform font for that family." >&2
      rm -f "$var_file"
      continue
    }
  fi
done

# Copy the variable font to every static filename google_fonts looks up.
for spec in "${FILES[@]}"; do
  family="${spec%%:*}"
  file="${spec##*:}"
  var_file="$DEST/$family-Variable.ttf"
  if [[ -s "$var_file" ]]; then
    cp -f "$var_file" "$DEST/$file"
    echo "have    $file (variable instance of $family)"
  else
    echo "missing $file"
  fi
done

# Licences must ship with the fonts. The OFL requires the FULL licence text to
# be distributed with the font files - a link is not sufficient.
cat > "$DEST/OFL.txt" <<'LICENSE'
Copyright (c) The Sora Project Authors (https://github.com/sora-xor/Sora-font)
Copyright (c) The Inter Project Authors (https://github.com/rsms/inter)
Copyright (c) The JetBrains Mono Project Authors (https://github.com/JetBrains/JetBrainsMono)

This Font Software is licensed under the SIL Open Font License, Version 1.1.

-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded,
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply to any
document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical writer or
other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining a
copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components, in
Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or in
the appropriate machine-readable metadata fields within text or binary
files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any Modified
Version, except to acknowledge the contribution(s) of the Copyright
Holder(s) and the Author(s) or with their explicit written permission.

5) The Font Software, modified or unmodified, in part or in whole, must be
distributed entirely under this license, and must not be distributed under
any other license. The requirement for fonts to remain under this license
does not apply to any document created using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are not
met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER
DEALINGS IN THE FONT SOFTWARE.
LICENSE

echo
echo "Done. Files in $DEST:"
ls -1 "$DEST"
echo
echo "Now run: flutter pub get && flutter run"
