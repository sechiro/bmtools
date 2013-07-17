#!/bin/sh
set -ue
LANG=C
usage(){
    echo "Usage: $0 sar_binary_log [output_dir(default:/tmp)] [start_time] [end_time]" 1>&2
}

sar_file=${1:-""}
output_dir=${2:-"/tmp"}
start_time=${3:-"00:00:00"}
end_time=${4:-"23:59:59"}

if [ "$sar_file" = "" ];then
    usage
    exit 1
fi

while read line
do
    class=$(echo $line | cut -d',' -f1)
    sar_option=$(echo $line | cut -d',' -f2)
    sar $sar_option -s $start_time -e $end_time -f $sar_file | sed -e '2,$s/\s\+/,/g' > $output_dir/sar-${class}.csv
done <<EOT
cpu_usage,-u
cpu_load,-q
mem,-r
disk,-dp
net,-n DEV
net_error,-n EDEV
EOT

echo "Output files:"
/bin/ls $output_dir/sar-*.csv
