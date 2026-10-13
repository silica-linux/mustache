#!/bin/sh
# Ogni file con estensione da asset deve avere una riga in ASSETS.md.
status=0
for file in $(git ls-files | grep -Ei '\.(png|jpe?g|svg|webp|gif|ttf|otf|wav|ogg|mp3)$'); do
  grep -q "\`$file\`" ASSETS.md || { echo "senza riga in ASSETS.md: $file"; status=1; }
done
exit $status
