#!/bin/bash

# put in your .bash_profile like this
# source ~/path/to/SushiCoin/sushicoin_profile.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

alias sc="cd $DIR"
alias sc-unit="sc && crystal spec"
alias sc-e2e="sc && TRAVIS=true crystal spec"
