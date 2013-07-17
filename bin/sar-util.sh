#!/bin/bash
# Usage $0 [[user@]target_host] [-p] [-P password]
LANG=C
set -ue

# ---------------
# Option parsing
# ---------------
option_description="[-s] [-p] [-P password] [[user@]target_host]"
usage(){
    echo "Usage: $0 $option_description
    If you don't specify a target_host, localhost is to be checked.
    You need to specify target_host when -p or -P options are used." >&2
    exit 1
}

# Init variables because "set -u" requires all variables are defined
silent=0
use_passwd=0
_arg_passwd=""
while getopts "spP:" OPT
do
    case $OPT in
        s) silent=1;;
        p) use_passwd=1;;
        P) _arg_passwd="$OPTARG"
            if [ "$_arg_passwd" = "" ]; then
                usage
            fi ;;
        *) usage ;;
    esac
done
# cut options from arguments
shift $(( $OPTIND - 1 ))

# Get $1
target_host=${1:-""}

# You need to specify target_host when -p or -P options are used.
if [[ "$use_passwd" = 1 && "$target_host" = "" ]]; then
    usage
elif [[ "$_arg_passwd" != "" && "$target_host" = "" ]]; then
    usage
fi

# -------------------
# Script env settings
# -------------------
# Get script path and filenames.
script_dir=$(cd $(dirname $0);pwd)
envfile=${envfile:-"$script_dir/../conf/sar-util-env.sh"}
sar_temp=`mktemp -u`

# sar general fixed options
_sar_interval=1
_sar_num=1

. $envfile

# Set env parameter when there are not the definitions in $envfile
SAR_BIN=${SAR_BIN:-"/usr/bin/sar"}
RM_BIN=${RM_BIN:-"/bin/rm -f"}
LOG_LEVEL=${LOG_LEVEL:-"debug"}
STDOUT_LOG=${STDOUT_LOG:-"/tmp/$0.out"}
STDERR_LOG=${STDERR_LOG:-"/tmp/$0.err"}

# Override env settings
if [ "$target_host" != "" ];then
    RESULT_LOG="/tmp/${target_host}.csv"
fi

# Set logger. Warning: Expect password will be displayed in "trace" log level.
. $script_dir/../lib/simple_logger.sh

# Read sar utils and error trap
. $script_dir/../lib/sar-util.sh

# silent mode implement
if [ "$silent" = 0 ]; then
    touch $STDOUT_LOG
    touch $STDERR_LOG
    tail -f $STDOUT_LOG &
    tail -f $STDERR_LOG &
fi
exec 1>$STDOUT_LOG
exec 2>$STDERR_LOG


# ----------------------------------------------
# Switch run mode and exec command (3 patterns)
# ----------------------------------------------
# 1. No option (local sar) exec command settings
exec_command=$SAR_BIN
rm_command="$RM_BIN $sar_temp"

# 2. No password ssh connection
## SSH and expect timeout
timeout=10

## No password ssh connection exec command settings
if [ "$target_host" != "" ]; then
    exec_command="ssh -o ConnectTimeout=$timeout $target_host $SAR_BIN"
    rm_command="ssh -o ConnectTimeout=$timeout $target_host $RM_BIN $sar_temp"
fi

# 3. SSH authentication using expect script
## Set password for expect
_passwd=""
if [ "$use_passwd" = 1 ]; then
    echo "Input password:"
    stty -echo
    read _passwd
    stty echo
elif [ "$_arg_passwd" != "" ]; then
    _passwd=$_arg_passwd
fi

## Expect ssh functions
exec_expect()
{
    expect -c "
    set timeout $timeout
    spawn /usr/bin/timeout $timeout ssh -o ConnectTimeout=$timeout $target_host $SAR_BIN $@
    expect {
        default {exit 1}
        \"Are you sure you want to continue connecting (yes/no)?\" {
            send \"yes\r\"
            expect \"password:\"
            send \"${_passwd}\r\"
        } \"password:\" {
            send \"${_passwd}\r\"
        }
    }
    interact
    catch wait result
    set STATUS [ lindex \$result 3 ]
    exit \$STATUS
    "
}
exec_expect_rm()
{
    expect -c "
    set timeout $timeout
    spawn /usr/bin/timeout $timeout ssh -o ConnectTimeout=$timeout $target_host $RM_BIN $sar_temp
    expect {
        default {exit 1}
        \"Are you sure you want to continue connecting (yes/no)?\" {
            send \"yes\r\"
            expect \"password:\"
            send \"${_passwd}\r\"
        } \"password:\" {
            send \"${_passwd}\r\"
        }
    }
    interact
    "
}
## Set exec command for expect
if [ "$_passwd" != "" ]; then
    exec_command=exec_expect
    rm_command=exec_expect_rm
fi


# Delete temp file and child processes when exit, by using rm_command function
trap 'logger_debug "Remove sar tempfile.";pkill -P $$ ; $rm_command > /dev/null' EXIT


# -----------------------
# Run stat collection
# -----------------------
# Output start settings to stdout log
logger_debug "Sar bin: $SAR_BIN"
logger_debug "Temporary file: $sar_temp"
logger_info "Execute command: $exec_command"
logger_trace "Password: $_passwd"

# Get sar data by exec_command(local, no password ssh, expect)
$exec_command -A -o $sar_temp $_sar_interval $_sar_num >/dev/null || logger_fatal "Connection Error: $target_host" 

# -----------------------
# Read CPU load stats
# -----------------------
# CPU idle percent and use percent
usage=`$exec_command -q -f $sar_temp`

header=`get_sar_header "$usage"`
logger_debug "$header"
usage_avg=`get_sar_avg "$usage"`
logger_debug "$usage_avg"

# Header validation
column='$4'
expected='ldavg-1'
is_valid_header "$header" "$column" "$expected"

cpu_load=`echo "$usage_avg" | awk "{print $column}"`
logger_debug "CPU Load1: $cpu_load"

# Output result
echo "CpuLoad,$cpu_load" > $RESULT_LOG


# -----------------------
# Read CPU usage stats
# -----------------------
# CPU idle percent and use percent
usage=`$exec_command -u -f $sar_temp`

header=`get_sar_header "$usage"`
logger_debug "$header"
usage_avg=`get_sar_avg "$usage"`
logger_debug "$usage_avg"

# Header validation
column='$8'
expected='%idle'
is_valid_header "$header" "$column" "$expected" "$awk_option"

cpu_idle_percent=`echo "$usage_avg" | awk "{print $column}"`
logger_debug "CPU %idle: $cpu_idle_percent"

cpu_use_percent=`echo "100 - $cpu_idle_percent" | bc | sed -e "s/^\./0./"`
logger_debug "CPU real Usage: $cpu_use_percent"

# Output result
echo "CpuUsage,$cpu_use_percent" >> $RESULT_LOG


# -----------------------
# Read memory stats
# -----------------------
# memory usage percent
usage=`$exec_command -r -f $sar_temp`

header=`get_sar_header "$usage"`
logger_debug "$header"
usage_avg=`get_sar_avg "$usage"`
logger_debug "$usage_avg"

# Header validation
column='$2'
expected="kbmemfree"
is_valid_header "$header" "$column" "$expected"
column='$6'
expected="kbcached"
is_valid_header "$header" "$column" "$expected"

# Calc memory real usage
kbmemfree=`echo "$usage_avg" | awk '{print $2}'`
kbmemused=`echo "$usage_avg" | awk '{print $3}'`
logger_debug "kbmemfree: $kbmemfree; kbmemused: $kbmemused"
kbmemtotal=`echo "$kbmemfree + $kbmemused" | bc`
logger_debug "kbmemtotal: $kbmemtotal"

kbbuffers=`echo "$usage_avg" | awk '{print $5}'`
kbcached=`echo "$usage_avg" | awk '{print $6}'`
logger_debug "kbbuffers: $kbbuffers, kbcached: $kbcached"

logger_debug "$kbmemtotal - $kbmemfree - $kbbuffers - $kbcached"

mem_used_percent=`echo "scale=2; ($kbmemtotal - $kbmemfree - $kbbuffers - $kbcached) / $kbmemtotal * 100" \
    | bc | sed -e "s/^\./0./"`
logger_debug "Memory real usage: $mem_used_percent %"

# Output result
echo "MemUsage,$mem_used_percent" >> $RESULT_LOG


# -----------------------
# Read disk stats
# -----------------------
# Disk util
usage=`$exec_command -dp -f $sar_temp`

header=`get_sar_header "$usage"`
logger_debug "$header"
usage_avg=`get_sar_avg "$usage"`
logger_debug "$usage_avg"

# Header validation
column='$NF'
expected="%util"
is_valid_header "$header" "$column" "$expected"

device_list=`echo "$usage_avg" | grep -v -e DEV | awk '{print $2}'`
logger_debug "Disk devices:" $device_list
for i in $device_list
do
    device_usage=`echo "$usage_avg" | grep -e $i`
    logger_debug "$i: $device_usage"
    device_util="DiskUtil[$i],`echo "$device_usage" | awk '{print $NF}'`"
    logger_debug $device_util

    # Output result
    echo "$device_util" >> $RESULT_LOG
done


# -----------------------
# Read disk stats
# -----------------------
# Net util
usage=`$exec_command -n DEV -f $sar_temp`

header=`get_sar_header "$usage"`
logger_debug "$header"
usage_avg=`get_sar_avg "$usage"`
logger_debug "$usage_avg"

# Header validation
column='$5'
expected='rxkB/s'
is_valid_header "$header" "$column" "$expected"
column='$6'
expected='txkB/s'
is_valid_header "$header" "$column" "$expected"

device_list=`echo "$usage_avg" | grep -v -e IFACE | awk '{print $2}'`
logger_debug "Network interfaces:" $device_list
for i in $device_list
do
    device_usage=`echo "$usage_avg" | grep -e $i`
    logger_debug "$i: $device_usage"
    device_rx_util="NetRxkB[$i],`echo "$device_usage" | awk '{print $5}'`"
    device_tx_util="NetTxkB[$i],`echo "$device_usage" | awk '{print $6}'`"
    logger_debug "$device_rx_util; $device_tx_util"

    # Output result
    echo "$device_rx_util" >> $RESULT_LOG
    echo "$device_tx_util" >> $RESULT_LOG
done


# ----------------------------
# Output results to stdout log
# ----------------------------
logger_info "Output: $RESULT_LOG
`cat $RESULT_LOG`"

exit 0
