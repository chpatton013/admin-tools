echo $*
for d in *; do
   if [ -d "$d" ]; then
      echo cd "$d"
      echo `realpath $0` $*
      echo cd -
   fi
done
