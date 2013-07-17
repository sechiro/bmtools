#!/bin/bash
# Dependency: simple_logger.sh
# ---------------
# Error trap
# ---------------
on_error()
{
    errcode=$?
    logger_fatal "$0: error line $1: command exited with status $errcode."
}
trap 'on_error $LINENO' ERR

# -----------------------
# sar util functions
# -----------------------
get_sar_header()
{
    # "$1" is sar output text including LF.
    echo "$1" | grep -e ^Linux -A2| tail -n1 | tr -d '\r'
}
get_sar_avg_line(){
    echo "$1" | grep -e "^Average" | tr -d '\r'
}

# Header validation
is_valid_header()
{
    local _awk_option=${4:-""}
    local _checked=`echo $1 | awk $_awk_option "{print $2}"`
    if [ "$_checked" != "$3" ]; then
        logger_error "Unexpected sar data header. Expected: column $2 = $3. Actual: $_checked"
        exit 1
    else
        logger_info "Success validation: header column $2 = $_checked"
    fi
}

is_include()
{
    local _is_include=`echo "$1" | grep -e "$2" | wc -l`
    if [ $_is_include -ge 1 ]; then
        logger_info "$2 is found"
    else
        logger_error "$2 is not found"
        exit 1
    fi
}

get_sar_avg_value()
{
    local _header=`get_sar_header "$1"`
    local _target="$2"
    local OLDIFS=$IFS
    local _delim=${3:-""}

    IFS="${3:-${IFS}}"

    local _column_num=""
    local _loop_num=0
    for i in $_header
    do
        _loop_num=`expr $_loop_num + 1`
        if [ "$i" = "$_target" ]; then
            _column_num=$_loop_num
        fi
    done
    IFS=$OLDIFS

    local _awk_option=""
    if [  "$_delim" != "" ]; then
        _awk_option="-F${_delim}"
    fi

    get_sar_avg_line "$1" | awk $_awk_option "{print \"$_target[\"\$2\"],\"\$$_column_num}"
}
