
CXX ?= g++
# Accepts CXXSTD >= C++14
CXXFLAGS := $(shell pkg-config --cflags --libs gnome-keyring-1) -I ./lib -I . -std=c++14
EXTRA_FLAGS ?=

secret:
	mkdir -p ../bin/
	$(CXX)  unlock_keyrings.cc -o ../bin/unlock_keyrings $(CXXFLAGS) $(EXTRA_FLAGS)

