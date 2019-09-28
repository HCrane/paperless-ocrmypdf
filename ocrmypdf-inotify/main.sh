#/bin/bash
set -o pipefail

inotifywait -m -e close_write -e moved_to /in |
    while read -r path action file; do
        echo "Waiting for $file..."
        sleep 10
        echo "Processing $file..."

        out="${file%%.*}.pdf"
        
        ${OCRMYPDF_BINARY} ${OCRMYPDF_PARAMETERS} "$path/$file" "/work/$out" 2>&1 | tee /tmp/log
        rc=$?
        if [ $rc -ne 0 ] ; then
            echo "OCRmyPDF failed with code $rc"
            if [ -n "$(grep DpiError /tmp/log)" ] ; then
                echo "It was DpiError, retrying with img2pdf"
                img2pdf --pagesize A4 "$path/$file" | ${OCRMYPDF_BINARY} ${OCRMYPDF_PARAMETERS} - "/work/$out"
                rc=$?
                if [ $rc -ne 0 ] ; then
                    echo "img2pdf + OCRmyPDF failed with code $rc"
                fi
            fi
        fi

        if [ $rc -eq 0 -a -f "/work/$out" ] ; then
            mv -n "/work/$out" "/out/$out"
            mv -n "$path/$file" /archive
            echo "File $file processed and archived"
        else
            echo "Failed to process $file, leaving as is"
            [ -f "/work/$out" ] && rm "/work/$out"
        fi
    done

