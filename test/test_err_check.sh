#!/bin/bash
LANG=C
set -eu

script_dir=$(cd $(dirname $0) && pwd)

. $script_dir/../lib/simple_logger.sh
. $script_dir/../lib/err_check.sh


test_file_exists()
{
    check_file=`file_exists /etc/hosts`
    echo $check_file
    file_exists /etc/ho
    echo $check_file
}
test_file_exists

echo 1
