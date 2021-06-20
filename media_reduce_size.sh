#!/bin/bash
#
# This script reads from given directories (do not write) and
# writes generates commands to a temporary file (TMP_COMMAND_FILE).
#
# Usage:
#   $ bash media_reduce_size.sh <target direcotory> <destinition directory>
#
# Example:
#   $ bash media_reduce_size.sh /home/thorgeir/Dropbox /home/thorgeir/media/shrink
#    ... OR ....
#        if you are in the directory you want to reduce:
#   bash ~/microscripts/media_reduce_size.sh $(pwd) /tmp
#
# Help:
#   * ffmpeg easy explaination: https://superuser.com/a/933310
#
# Author: thorgeir <thorgeirsigurd@gmail.com>

# Exit after first error.
set -o errexit

ORIGINAL_DIR=${1}; shift
COPIED_DIR=${1}; shift

echo ${ORIGINAL_DIR}
echo ${COPIED_DIR}

# All commands will be available in this file.
TMP_COMMAND_FILE=/tmp/media_reduce_commands.sh


generate_cmd () {
    application=${1}; shift
    extension=${1}; shift
    options=${1}; shift

    pushd ${ORIGINAL_DIR}

    find * -iname "*.${extension}" -print0 | while read -r -d $'\0' media;
    do
        input=${ORIGINAL_DIR}/${media}
        output=${COPIED_DIR}/shrink/${media}
   
        # Skip reduce if the output already exists.
        if [ -f "${output}" ];
            then continue
        fi

        # Ignore stdout from ffmpeg command.
        if [ "${application}" = "ffmpeg" ];
            then application="${application} -loglevel error -i"
        fi

        echo mkdir -p ${COPIED_DIR}/shrink/$(dirname "${media}");
        
        echo "(set -x; ${application} \"${input}\" ${options} \"${output}\";);"
        echo "wc -c \"${input}\""
        echo "wc -c \"${output}\""
        echo "date --utc;"

    done >> $TMP_COMMAND_FILE
    popd
}


geneate_reduce_commands_jpg () {
    pushd ${ORIGINAL_DIR}

    find * -iname "*.jpg" -print0 | while read -r -d $'\0' media;
    do
        echo mkdir -p ${COPIED_DIR}/shrink/$(dirname "${media}");

        options="-resize 2048x2048 -quality 85"
        
        input=${ORIGINAL_DIR}/${media}
        output=${COPIED_DIR}/shrink/${media}

        echo "(set -x; convert \"${input}\" ${options} \"${output}\";);"
        echo "wc -c \"${input}\""
        echo "wc -c \"${output}\""
        echo "date --utc;"

    done >> $TMP_COMMAND_FILE
    popd
}


diff_old_and_new_dir () {
    # Compare the original 
    find_old_dir="pushd ${ORIGINAL_DIR}; find . | sort; popd"
    find_new_dir="pushd ${COPIED_DIR}/shrink; find . | sort; popd"

    echo "diff <(${find_old_dir}) <(${find_new_dir})" >> ${TMP_COMMAND_FILE}
}

begin () {
    echo "set -o errexit" > ${TMP_COMMAND_FILE}

    generate_cmd "ffmpeg" "mov" "-n -c:v libx264 -c:a copy -crf 20"
    generate_cmd "ffmpeg" "mp4" "-c:v libx264 -crf 28 -preset veryslow"
    generate_cmd "ffmpeg" "m4a" "-preset veryslow"
    generate_cmd "ffmpeg" "mp3" "-acodec libmp3lame -ac 2 -ab 64k -ar 44100"
    generate_cmd "convert" "jpg" "-resize 2048x2048 -quality 85"

    diff_old_and_new_dir
}

begin

echo "Now run:"
echo "$ bash ${TMP_COMMAND_FILE}"
