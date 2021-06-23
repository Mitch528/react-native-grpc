#!/bin/bash

mkdir -p ./src/_proto

OUT_DIR="./src/_proto"

echo "Compiling protobuf definitions"
npx protoc --ts_out $OUT_DIR --proto_path protos ./protos/*.proto
