
CXX ?= g++
CXXFLAGS := -I ./lib -I . -std=c++17 -DKEYRING_IMPL_$(KEYRING_IMPL)

ifeq ($(KEYRING_IMPL),lib)
    CXXFLAGS += $(shell pkg-config --cflags --libs gnome-keyring-1)
else ifneq ($(KEYRING_IMPL),standalone)
$(error "KEYRING_IMPL must be set to 'lib' or 'standalone'. Example: 'make KEYRING_IMPL=standalone'")
endif

secret:
	mkdir -p ../bin/
	$(CXX) unlock_keyrings.cc -o ../bin/unlock_keyrings $(CXXFLAGS)

