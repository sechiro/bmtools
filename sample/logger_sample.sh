#!/bin/sh

# Set logger
# log_level must be set before include simple_logger.sh
# if you don't set it, "info" log_level will be used in your script.

log_level=${log_level:-"warn"}
. ./lib/simple_logger.sh

# Normal output.(Output to stdout)
logger_info "log test"
logger_warn "log test"
logger_fatal "log test"

# Redirect stdout to logfile. Logs are not displayed on your screen anymore.
log_file=/tmp/simple_logger.log
exec 1>$log_file

logger_info "log test"
logger_warn "log test"
logger_fatal "log test"
