#!/usr/bin/bash

TMPDIR=`mktemp -d`
INPUTFILE=${@: -1}
PATTERNDIR="pattern"
COLS=30

trap 'rm -rf -- "$TMPDIR"' EXIT

while getopts p:c:i:o:v FLAG; do
	case $FLAG in
		p)
			PATTERNDIR=$OPTARG
			;;
		c)
			COLS=$OPTARG
			;;
		i)
			INPUTFILE=$OPTARG
			OUTPUTFILE="${INPUTFILE%.*}-outxx.png"
			;;
		o)
			OUTPUTFILE=$OPTARG
			;;
		v)
			N=`date +%s%N`
			export PS4='+[$(((`date +%s%N`-$N)/1000000))ms][${BASH_SOURCE}:${LINENO}]: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'; set -x;
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

WIDTH=`identify -format "%[fx:w]" $INPUTFILE`
if [[ $((WIDTH%COLS)) > 0 ]]; then
	# zmiana rozmiaru wejściowego obrazka do wielokrotności "kafelków"
	WIDTH=$(( ((WIDTH/COLS)+1)*COLS ))
	convert $INPUTFILE -resize $WIDTH $TMPDIR/tmp.png
	INPUTFILE=$TMPDIR/tmp.png
fi
HEIGHT=`identify -format "%[fx:h]" $INPUTFILE`
FRAMEWIDTH=$((WIDTH/COLS))
# TODO
# nie działa dla małych obrazów wejściowych!
FRAMEHEIGHT=$((FRAMEWIDTH*PATTERNHEIGHT/PATTERNWIDTH))

echo "Input image:"
echo $WIDTH
echo $HEIGHT

x=0
y=0
ROW=0
COL=0

while [ $y -lt $HEIGHT ]; do
	while [ $x -lt $WIDTH ]; do
		echo -ne "Row: "$ROW" "$((COL*100/COLS))"%\r"
		SCOLOUR=`convert $INPUTFILE -crop ${FRAMEWIDTH}x${FRAMEHEIGHT}+${x}+${y} +repage -scale 1x1\! -format '%[pixel:s]' info:-`
		MINDISTANCE=100
		for key in "${!CARDS[@]}"; do
			DISTANCE=`compare -metric FUZZ xc:${SCOLOUR} xc:"${CARDS[$key]}" -format "%[distortion]" null: 2>/dev/null`
			DISTANCE=`echo "$DISTANCE*100/1"|bc`
			if [[ $DISTANCE -lt $MINDISTANCE ]]; then
				MINDISTANCE=$DISTANCE
				LASTCOLOUR=$key
			fi
		done
		if [ $x -eq 0 ]; then
			cp $LASTCOLOUR $TMPDIR/r-$(printf "%03d" $ROW).png
		else
			convert +append $TMPDIR/r-$(printf "%03d" $ROW).png $LASTCOLOUR $TMPDIR/r-$(printf "%03d" $ROW)-$(printf "%03d" $COL).png
			mv $TMPDIR/r-$(printf "%03d" $ROW)-$(printf "%03d" $COL).png $TMPDIR/r-$(printf "%03d" $ROW).png
		fi
		PIECES[$LASTCOLOUR]=$((PIECES[$LASTCOLOUR]+1))
		x=$((x+FRAMEWIDTH))
		COL=$((COL+1))
	done
	x=0
	COL=0
	y=$((y+FRAMEHEIGHT))
	ROW=$((ROW+1))
done
convert -append $TMPDIR/r-???.png $OUTPUTFILE

rm -rf $TMPDIR

for key in "${!PIECES[@]}"; do
	if [ ${PIECES[$key]} -gt 0 ]; then
		echo "$key => ${PIECES[$key]}";
	fi
done
