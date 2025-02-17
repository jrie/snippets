CURRENTPLAYLIST=$(xmms2 playlist list | grep '*' | cut -d" " -f2)
CURRENT="$CURRENTPLAYLIST -- $(xmms2 current -f '${playtime} of ${duration} | ${title}')"
echo "$CURRENT"
