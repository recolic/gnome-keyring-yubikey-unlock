
CXX ?= g++
CXXFLAGS := $(shell pkg-config --cflags --libs gnome-keyring-1) -I ./lib -I .
EXTRA_FLAGS ?=

secret: rlib
	$(CXX) $(CXXFLAGS) $(EXTRA_FLAGS) unlock_keyrings.cc ./lib/rlib/libr.a -o ../bin/unlock_keyrings

rlib:
	cd ./lib/rlib && make

