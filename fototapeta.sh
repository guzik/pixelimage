#!/usr/bin/bash

# N=`date +%s%N`
# export PS4='+[$(((`date +%s%N`-$N)/1000000))ms][${BASH_SOURCE}:${LINENO}]: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'; set -x;

TMPDIR=`mktemp -d`
INPUTFILE=${@: -1}
PATTERNDIR="pattern"
COLS=30

trap 'rm -rf -- "$TMPDIR"' EXIT

while getopts p:c:i: FLAG; do
	case $FLAG in
		p)
			PATTERNDIR=$OPTARG
			;;
		c)
			COLS=$OPTARG
			;;
		i)
			INPUTFILE=$OPTARG
			;;
	esac
done

shift $(($OPTIND -1))

declare -A CARDS
declare -A PIECES
for file in $PATTERNDIR/*; do
	CARDS[${file}]+=`convert $file -scale 1x1\! -format '%[pixel:s]' info:-`
	PIECES[${file}]=0
	# TODO
	# sprawdzic czy wszystkie maja ten sam rozmiar
	PATTERNWIDTH=`identify -format "%[fx:w]" $file`
	PATTERNHEIGHT=`identify -format "%[fx:h]" $file`
done

# for key in "${!PIECES[@]}"; do echo "$key => ${PIECES[$key]}"; done

WIDTH=`identify -format "%[fx:w]" $INPUTFILE`
echo $WIDTH
echo $COLS
echo $(( $WIDTH%$COLS ))
echo $(( $WIDTH/$COLS ))
if [[ $WIDTH%$COLS > 0 ]]; then
	WIDTH=$(( (($WIDTH/$COLS)+1)*$COLS ))
	convert $INPUTFILE -resize $WIDTH^x74 $TMPDIR/tmp.png
	INPUTFILE=$TMPDIR/tmp.png
else
	WIDTH=$(( $WIDTH/$COLS ))
fi
HEIGHT=`identify -format "%[fx:h]" $INPUTFILE`
FRAMEWIDTH=$(($WIDTH/$COLS))
FRAMEHEIGHT=$(($FRAMEWIDTH*$PATTERNHEIGHT/$PATTERNWIDTH))

echo $TMPDIR

echo "Input image:"
echo $WIDTH
echo $HEIGHT
# echo "Output image:"
# echo $((($WIDTH+$FRAMEWIDTH-1)/$FRAMEWIDTH*8))" mm"
# echo $((($HEIGHT+$FRAMEHEIGHT-1)/$FRAMEHEIGHT*8))" mm"

x=0
y=0
ROW=0
COL=0

while [ $y -lt $HEIGHT ]; do
	echo $ROW
	while [ $x -lt $WIDTH ]; do
		echo -n $COL" "
		convert $INPUTFILE -crop ${FRAMEWIDTH}x${FRAMEHEIGHT}+${x}+${y} +repage $TMPDIR/out-cropped-${ROW}-${COL}.png
		SCOLOUR=`convert $TMPDIR/out-cropped-${ROW}-${COL}.png -scale 1x1\! -format '%[pixel:s]' info:-`
		MINDISTANCE=100
		for key in "${!CARDS[@]}"; do
			DISTANCE=`compare -metric FUZZ xc:${SCOLOUR} xc:"${CARDS[$key]}" -format "%[distortion]" null: 2>/dev/null`
			DISTANCE=`echo "$DISTANCE*100/1"|bc`
			if [[ $DISTANCE -lt $MINDISTANCE ]]; then
				MINDISTANCE=$DISTANCE
				LASTCOLOUR=$key
			fi
		done
		cp $LASTCOLOUR $TMPDIR/f-$(printf "%03d" $COL).png
		((PIECES[$LASTCOLOUR]=PIECES[$LASTCOLOUR]+1))
		x=$(($x+$FRAMEWIDTH))
		COL=$(($COL+1))
	done
	echo " "
	convert +append $TMPDIR/f-???.png $TMPDIR/r-$(printf "%03d" $ROW).png
	x=0
	COL=0
	y=$(($y+$FRAMEHEIGHT))
	ROW=$(($ROW+1))
done
convert -append $TMPDIR/r-???.png out.png

rm -rf $TMPDIR
for key in "${!PIECES[@]}"; do
	if [ ${PIECES[$key]} -gt 0 ]; then
		echo "$key => ${PIECES[$key]}";
	fi
done
