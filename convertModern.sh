#!/bin/bash
inputfolder="input"
outputfolder="output"
tmpfolder="tmp"
echo "webp/webm/avif convert modern script v0.0.11"

filesConverted=0
filesLarger=0
totalsaved=0
totaloriginal=0
compressionlevel=75
pattern='[\-]{0,1}[0-9]{0,}\.[0-9]{0,2}'
patternMB='[\-]{0,1}[0-9]{0,}\.[0-9]{0,3}'
patternExtension='.[^\/]*'
encoding=""
outputextension=""
verboselevel=0
displayHelp=false
uselossless=false
deletelarger=false
checkexisting=false
reportunknown=false
convertTypes=("gif" "jpg" "jpeg" "png" "webm" "webp" "mp4", "avif" "bmp")
patternType='/(.[^\;]*)'

help=$'
    	-h 	displayHelp
	-e 	encoding		(webp/avif)
        -q 	compressionlevel 	(0-100)
        -v 	verboselevel		(0/1)
        -i 	inputfolder		path
        -o 	outputfolder		path
        -b	deletelarger
        -c	checkexisting
        -r	report unknown detected file types

	"webp" options:
	-l lossless encoding
    '

while getopts e:q:v:i:o:hlbcr flag
do
    case "${flag}" in
        e) encoding=${OPTARG};;
        q) compressionlevel=${OPTARG};;
        v) verboselevel=${OPTARG};;
        i) inputfolder=${OPTARG};;
        o) outputfolder=${OPTARG};;
        h) displayHelp=true;;
        l) uselossless=true;;
        b) deletelarger=true;;
		c) checkexisting=true;;
		r) reportunknown=true;;
    esac
done

if [ "$displayHelp" = true ]; then
	echo "$help"
	exit
fi

if [ ! -d "$inputfolder" ]; then
    echo "Inputfolder: '$inputfolder' does not exist. Create it or change the '-i yourFolderName' option."
    exit
fi

if [ ! -d "$outputfolder" ]; then
    echo "Outputfolder: '$outputfolder' does not exist. Create it or change the '-o yourFolderName' option."
    exit
fi

if [[ "$encoding" == "webp" ]]; then
	echo "Using webp with compression level '$compressionlevel'..."
	outputextension=".webp"
elif [[ "$encoding" == "avif" ]]; then
	echo "Using avif with quality level '$compressionlevel'..."
	outputextension=".avif"
else 
	echo "No encoding defined, use '-e webp' or '-e avif'."
	echo "$help"
	exit
fi

echo

SECONDS=0

for filename in $inputfolder/*.*; do
	if [[ $(stat -c%s "$filename") == 0 ]]; then
		echo "'$filename' is zero bytes. Skipping."
		continue
	fi
	
    name=$(basename $filename)
    namebase=${name%.*}
	extension=$(file --brief --extension $filename)
	
	if [[ "$extension" == "???" ]]; then
		extension=$(file --brief -i $filename)
		if [[ "$extension" =~ $patternType ]]; then
			extension=${BASH_REMATCH[1]}
		fi
	fi
	
	if [[ $extension =~ $patternExtension ]]; then
		extension=${BASH_REMATCH[0]}
		extension="${extension,,}"
	fi
	
#	if [[ "$?" != 0 ]]; then
#		extension=${name##*.}
#		extension="${extension,,}"
#	fi

	extensionPattern="\<${extension}\>"	
	
	if [[ ! ${convertTypes[@]} =~ $extensionPattern ]]; then
		fileExtension=$extension
		extension=${fileExtension##*.}

		if [[ $extension == "plain" ]] || [[ $extension == "octet-stream" ]]; then
			extension="txt"
		elif [[ $extension == "python" ]]; then
			extension="py"
		else
			extension=${extension##*-}
			if [ "$reportunknown" = true ]; then
				echo "File extension unknown: Type '$fileExtension' converted to extension '$extension'"
			fi
		fi

		echo "'$filename' type is '$fileExtension', no conversion. Copying to '$outputfolder/$namebase.$extension'"	
		cp $filename $outputfolder/$namebase.$extension
	  	continue
	fi
	
    if [[ "$extension" == "webp" ]] && [[ "$encoding" != 'avif'  ]] || [[ "$extension" == "webm" ]] || [[ "$extension" == "mp4" ]]; then
    	if [ "$checkexisting" = true ] && [ -f "$outputfolder/$namebase.$extension" ]; then
    		echo "File '$outputfolder/$namebase.$extension' exists, skipping."
			continue
		fi
		
    	echo "Source is '$extension' - copying "$filename" directly to '$outputfolder/$namebase.$extension'."
		cp $filename $outputfolder/$namebase.$extension
        continue
    elif [[ ! ${convertTypes[@]} =~ $extensionPattern ]]; then
	    echo "Source is not converted, copying '$extension' - to '$outputfolder/$namebase.$extension'"
	    if [ "$checkexisting" = true ] && [ -f "$outputfolder/$namebase.$extension" ]; then
    		echo "File '$outputfolder/$namebase.$extension' exists, skipping."
			continue
		fi
		cp $filename $outputfolder/$namebase.$extension
        continue
    fi

    echo "Processing image $name..."
	if [[ "$extension" == "gif" ]]; then
		if [ "$checkexisting" = true ] && [ -f "$outputfolder/$namebase.webm" ]; then
    		echo "File '$outputfolder/$namebase.webm' exists, skipping."
			continue
		fi
		
		ffmpeg -y -i $filename -r 16 -c:v libvpx -quality good -b:v 2000K -crf 16 -pix_fmt yuv420p -movflags faststart $outputfolder/$namebase.webm &> /dev/null
	elif [[ "$encoding" == "avif" ]]; then
			pngType=' PNG24:'
		if [[ "$extension" != "png" ]]; then
			pngType=""
		fi
		
		if [ "$checkexisting" = true ] && [ -f "$outputfolder/$namebase$outputextension" ]; then
    		echo "File '$outputfolder/$namebase$outputextension' exists, skipping."
			continue
		fi
		
		magick $filename -quality $compressionlevel $pngType$outputfolder/$namebase$outputextension &> /dev/null
	else
		if [ "$checkexisting" = true ] && [ -f "$outputfolder/$namebase$outputextension" ]; then
    		echo "File '$outputfolder/$namebase$outputextension' exists, skipping."
			continue
		fi

		lossless=""
		if [ "$uselossless" = true ]; then
			lossless='-lossless'
		fi
		
		if [[ "$extension" == "bmp" ]]; then
			echo "File '$filename' is 'bmp', cross convert to 'png' and to 'webp'"
			magick $filename -quality 100 PNG24:$tmpfolder/$namebase.png &> /dev/null
			cwebp -q $compressionlevel -mt -m 6 $lossless -z 6 -sharp_yuv -metadata all -exact $tmpfolder/$namebase.png -o $outputfolder/$namebase$outputextension &> /dev/null
			rm $tmpfolder/$namebase.png
		else
			cwebp -q $compressionlevel -mt -m 6 -z 9 $lossless -sharp_yuv -metadata all -exact $filename -o $outputfolder/$namebase$outputextension &> /dev/null
		fi
		
		if [[ "$?" == 255 ]]; then
			echo "Could not convert image directly using 'webp' encoder, temporary converting to 'png' and afterwards to 'webp'."
		
			magick $filename -quality 100 PNG24:$tmpfolder/$namebase.png &> /dev/null
		
			if [[ "$?" == 0 ]]; then
				cwebp -q $compressionlevel -mt -m 6 $lossless -z 6 -sharp_yuv -metadata all -exact $tmpfolder/$namebase.png -o $outputfolder/$namebase$outputextension &> /dev/null
				rm $tmpfolder/$namebase.png
			else
				echo "Error coverting. Copying source '$filename' to '$outputfolder/$namebase.$extension'."
				cp $filename $outputfolder/$namebase.$extension
				continue
			fi
		fi
	fi
	
    ((filesConverted++))
done

ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

for filename in $inputfolder/*.*; do
	if [[ $(stat -c%s "$filename") == 0 ]]; then
		continue
	fi
	
    name=$(basename $filename)
    namebase=${name%.*}
    extension=$(file --brief --extension $filename)
    
    if [[ "$extension" == "???" ]]; then
		extension=$(file --brief -i $filename)
		if [[ "$extension" =~ $patternType ]]; then
			extension=${BASH_REMATCH[1]}
		fi
	fi

	if [[ $extension =~ $patternExtension ]]; then
		extension=${BASH_REMATCH[0]}
		extension="${extension,,}"
	fi
	
#	if [[ "$?" != 0 ]]; then
#		extension=${name##*.}
#		extension="${extension,,}"
#	fi

	if [[ "$extension" == "gif" ]]; then
		outputextension=".webm"
	elif [[ "$encoding" == "webp" ]]; then
		outputextension=".webp"
	elif [[ "$encoding" == "avif" ]]; then
		outputextension=".avif"
	fi
	
	if [[ "$extension" == "webm" ]] || [[ "$extension" == "mp4" ]]; then
		outputextension=.$extension
	fi
	
	if [[ "$encoding" == "webp" ]] && [[ "$extension" == "bmp" ]]; then
		outputextension=".webp"
	fi
	
	if [ ! -f "$outputfolder/$namebase$outputextension" ]; then
		continue
	fi

    originalsize=$(stat -c%s "$filename")	
    aftersize=$(stat -c%s "$outputfolder/$namebase$outputextension")

    originalkb=$(bc -l  <<< "$originalsize / 1024")
    aftersizekb=$(bc -l  <<< "$aftersize / 1024")

    ((totaloriginal+=originalsize))

    diff=$(bc -l  <<< "($originalsize-$aftersize) / 1024")

    if [[ "$verboselevel" != "0" ]]; then
        if [[ "$diff" =~ $pattern ]]; then
	        echo ""
            echo "File       : '$inputfolder/$name'"
            echo "Output     : '$outputfolder/$namebase$outputextension'"
            diffkb=${BASH_REMATCH[0]}

            if [[ "$originalkb" =~ $pattern ]]; then
                echo "Original   : ${BASH_REMATCH[0]} kb"
            fi

            if [[ "$aftersizekb" =~ $pattern ]]; then
                echo "After      : ${BASH_REMATCH[0]} kb"
            fi
            echo "Difference : $diffkb kb"
        fi
    fi

    if [[ $diff == -* ]]; then
	    ((filesLarger++))
    fi
    
	if [[ $diff == -* ]] && [[ $deletelarger = true ]]; then
		echo "Delete larger : '$outputfolder/$namebase$outputextension'"
		rm $outputfolder/$namebase$outputextension
		
		echo "Copying smaller file : '$filename' to '$outputfolder/$namebase$outputextension'"
		cp $filename $outputfolder/$namebase.$extension
	else
		((totalsaved+=originalsize-aftersize))
	fi
done

if (( $filesConverted > 0 )); then
    diff=$(bc -l  <<< "($totaloriginal - $totalsaved) / 1024")
    totaloriginal=$(bc -l  <<< "$totaloriginal / 1024")
    totalsaved=$(bc -l  <<< "$totalsaved / 1024")
    totalsavedmb=$(bc -l  <<< "$totalsaved / 1024")
	totalsavedgb=$(bc -l  <<< "$totalsavedmb / 1024")

    if [[ "$totaloriginal" =~ $pattern ]]; then
        totaloriginal=${BASH_REMATCH[0]}
    fi

    if [[ "$totalsaved" =~ $pattern ]]; then
        totalsaved=${BASH_REMATCH[0]}
    fi
    
    if [[ "$totalsavedmb" =~ $patternMB ]]; then
        totalsavedmb=${BASH_REMATCH[0]}
    fi

    if [[ "$totalsavedgb" =~ $patternMB ]]; then
        totalsavedgb=${BASH_REMATCH[0]}
    fi

    if [[ "$diff" =~ $pattern ]]; then
        diff=${BASH_REMATCH[0]}
    fi

	echo
	if (( $filesLarger > 0 )); then
	echo "Using '$encoding' encoding, covered $filesConverted file(s), reported larger $filesLarger file(s)."
	else
	    echo "Using '$encoding' encoding, covered $filesConverted file(s)."
	fi
    echo
    echo "$totaloriginal kb converted to $diff KB, saving $totalsaved KB ($totalsavedmb MB / $totalsavedgb GB)"
    echo "Runtime: $ELAPSED;"
    echo
    echo "Have a pleasent day."
else
    echo "'$encoding' converted no files. Did you forgot to copy any into '$inputfolder' ?"
fi
