#!/bin/bash
sar_header="Linux
"
cpu_header="05:44:55        CPU     %user     %nice   %system   %iowait    %steal     %idle"
cpu_data="Average:        all      0.00      0.00      1.00      1.00      0.00     98.00"
mem_header="05:44:55    kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit"
mem_data="Average:        84320    932196     91.71     28616    199008    935144     30.35"
disk_header="05:44:55          DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util"
disk_data="Average:          sda      3.00      0.00    112.00     37.33      0.01      3.33      3.33      1.00"
net_header="05:44:55        IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s"
net_data="Average:         eth0      0.00      0.00      0.00      0.00      0.00      0.00      0.00"

if [ "$1" = "-u" ];then
    echo "$sar_header"
    echo "$cpu_header"
    echo "$cpu_data"
elif [ "$1" = "-r" ];then
    echo "$sar_header"
    echo "$mem_header"
    echo "$mem_data"
elif [ "$1" = "-dp" ];then
    echo "$sar_header"
    echo "$disk_header"
    echo "$disk_data"
elif [ "$1" = "-n" ];then
    echo "$sar_header"
    echo "$net_header"
    echo "$net_data"
fi
