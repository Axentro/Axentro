#!/bin/sh

crystal tool format && crystal spec && ameba
