#!/bin/sh

bin/axen -w perf/perf-test.json -u http://localhost:3000 --testnet -d perf/perf.sqlite3 --developer-fund=perf/dev_fund.yml --official-nodes=perf/my_nodes.yml --record-nonces=true