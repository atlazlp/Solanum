# Build against the installed Hyprland headers (must match running compositor ABI).
CXX      ?= g++
PLUGIN   := groupbar-current.so
SRC      := main.cpp

CXXFLAGS += -std=c++23 -shared -fPIC -O2 -Wall -Wno-unused-parameter
CXXFLAGS += $(shell pkg-config --cflags hyprland hyprutils hyprlang pixman-1 libdrm)
LDFLAGS  += -shared

.PHONY: all clean

all: $(PLUGIN)

$(PLUGIN): $(SRC)
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(PLUGIN)
