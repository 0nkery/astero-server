#!/usr/bin/env bash

(cd proto && git pull origin master)

protoc --elixir_out=./apps/proto/lib proto/*.proto
