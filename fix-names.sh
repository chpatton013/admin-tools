IFS="\n"
for src in *; do
   dest=`echo "$src" | tr '[:upper:]' '[:lower:]' | tr ' ' '_'`
   if [ ! -f "$dest" ]; then
      mv "$src" "$dest"
   fi
done
