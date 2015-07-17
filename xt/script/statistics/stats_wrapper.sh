#!/bin/sh

"${XTDC_BASE_DIR}/script/statistics/stats_collecter.pl" --group=order_stats
"${XTDC_BASE_DIR}/script/statistics/graph_builder.pl"   --group=order_stats
