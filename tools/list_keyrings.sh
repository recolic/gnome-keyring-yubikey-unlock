#!/bin/bash
cd $(dirname $0)
eval g++ list_keyrings.cc -o list.out -Wno-deprecated-declarations $(pkg-config --cflags --libs gnome-keyring-1) &&
./list.out

