#!/bin/bash
eval g++ $(pkg-config --cflags --libs gnome-keyring-1) list_keyrings.cc -o list.out &&
./list.out

