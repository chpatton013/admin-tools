DIR=/home/chpatton013/admin-tools
COMMAND=$DIR/fix-names.sh
SELF=$DIR/r-fix-names.sh
$COMMAND
for d in *; do
   if [ -d "$d" ]; then
      cd "$d"
      $SELF
      cd -
   fi
done
