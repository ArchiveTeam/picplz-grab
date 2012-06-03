#!/bin/bash
# Script for downloading the data of one Picplz.com user.
#
# Usage:   dld-picplz-user.sh ${USER_ID}
#
# Example user IDs: 1908 (large)
#                   216385 (smaller)
#                   454713 (smallest)
#

VERSION="20120602.01"

# this script needs wget-warc-lua

USER_AGENT="Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27"

if [ -z $DATA_DIR ]
then
  DATA_DIR=data
fi

user_id=$1
user_id_8=$( printf "%08d" ${user_id} )

prefix_dir="$DATA_DIR/${user_id_8:7:1}/${user_id_8:6:2}/${user_id_8:5:3}"
user_dir="$prefix_dir/$user_id_8"

if [ -d "$prefix_dir" ] && [ ! -z "$( find "$prefix_dir/" -maxdepth 1 -type f -name "picplz-$user_id_8-*.warc.gz" )" ]
then
  echo "Already downloaded ${user_id}"
  exit 0
fi

rm -rf "${user_dir}"
mkdir -p "${user_dir}/files"

echo "Downloading user ${user_id}..."

t=$( date -u +'%Y%m%d-%H%M%S' )
warc_file_base="picplz-$user_id_8-$t"
picplz_lua_json="$user_dir/picplz-$user_id_8.json"

picplz_lua_json=$picplz_lua_json \
./wget-warc-lua \
  -U "$USER_AGENT" \
  -nv \
  -o "${user_dir}/wget.log" \
  --lua-script="picplz-user.lua" \
  --directory-prefix="${user_dir}/files" \
  --force-directories \
  -e "robots=off" \
  --page-requisites --span-hosts \
  --warc-file="${user_dir}/${warc_file_base}" \
  --warc-header="operator: Archive Team" \
  --warc-header="picplz-dld-script-version: ${VERSION}" \
  --warc-header="picplz-user-id: ${user_id}" \
  "http://api.picplz.com/api/v2/user.json?id=${user_id}&include_detail=1&include_pics=1&pic_page_size=1000"

result=$?

if [ $result -ne 0 ] && [ $result -ne 6 ] && [ $result -ne 8 ]
then
  echo " - User ${user_id}: ERROR ($result)."
  exit 1
fi

echo -n " - User ${user_id} done: "

# TODO remove files
# mv "$user_dir/$warc_file_base.warc.gz" "$prefix_dir/$warc_file_base.warc.gz"
# rm -rf "$user_dir"

# du -hs "$prefix_dir/$warc_file_base.warc.gz"

exit 0

