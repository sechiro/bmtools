#!/bin/bash
. ../lib/simple_logger.sh
. ../lib/sar-util.sh

text="Linux

00:00:00,a,b,c,d,f
Average:,a,b,success,d,f"

get_sar_avg_value "$text" c ,
is_include "$text" c
