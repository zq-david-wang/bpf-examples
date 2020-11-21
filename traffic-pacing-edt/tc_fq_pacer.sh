#!/bin/bash
#
# Loading FQ pacing qdisc in multi-queue MQ setup to avoid root qdisc lock.
#
# The FQ pacing qdisc is doing all the work of pacing packet out according to
# the EDT (Earliest Departure Time) future timestamps set by our BPF-prog that
# runs a TC-egress hook.
#
# Author: Jesper Dangaaard Brouer <netoptimizer@brouer.com>
# License: GPLv2
#
basedir=`dirname $0`
source ${basedir}/functions.sh

root_check_run_with_sudo "$@"

# Use common parameters
source ${basedir}/parameters.sh

export TC=tc

# Default verbose
VERBOSE=1

# Delete existing root qdisc
call_tc_allow_fail qdisc del dev "$DEV" root

if [[ -n $REMOVE ]]; then
    exit 0
fi

# MQ (Multi-Queue) as root qdisc
call_tc qdisc replace dev $DEV root handle 7FFF: mq

# Add FQ-pacer qdisc on each NIC avail TX-queue
i=0
for dir in /sys/class/net/$DEV/queues/tx-*; do
    # Details: cause-off-by-one, as tx-0 becomes handle 1:
    ((i++)) || true
    #call_tc qdisc add dev $DEV parent 7FFF:$i handle $i: fq
    #
    # The higher 'flow_limit' is needed for high-BW pacing
    call_tc qdisc add dev $DEV parent 7FFF:$i handle $i: fq \
       flow_limit 1000
    #
    #   quantum $((1514*4)) initial_quantum $((1514*20))
    # call_tc qdisc add dev $DEV parent 7FFF:$i handle $i: fq maxrate 930mbit
done
