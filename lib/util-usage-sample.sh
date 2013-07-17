#!/bin/bash

LOG_LEVEL="debug"
script_dir=$(cd $(dirname $0);pwd)
. $script_dir/simple_logger.sh
. $script_dir/sar-util.sh

# sar utils usage
usage=`sar -u 1 1`
header=`get_sar_header "$usage"`
logger_debug "$header"
usage_avg=`get_sar_avg "$usage"`
logger_debug "$usage_avg"
column='$8'

# success validation
expected='%idle'
is_valid_header "$header" "$column" "$expected"

# with awk option
# change delimiter
awk_option='-F,'
header=`echo "$header" | sed 's/ \+/,/g'`
is_valid_header "$header" "$column" "$expected" "$awk_option"

# fail validation
#expected='%idle1'
#is_valid_header "$header" "$column" "$expected"

is_include "$usage" "^Average"
