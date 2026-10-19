CXX      ?= g++
PLUGIN   := hyprwinwrap.so
SRC      := main.cpp bgrender.cpp

CXXFLAGS += -std=c++23 -shared -fPIC -O2 -Wall -Wno-unused-parameter
CXXFLAGS += $(shell pkg-config --cflags hyprland hyprutils hyprlang pixman-1 libdrm pangocairo libinput libudev wayland-server xkbcommon)
# Lua: try 5.5 then 5.4
LUA_CFLAGS := $(shell pkg-config --cflags lua55 2>/dev/null || pkg-config --cflags lua5.5 2>/dev/null || pkg-config --cflags lua 2>/dev/null)
LUA_LIBS   := $(shell pkg-config --libs lua55 2>/dev/null || pkg-config --libs lua5.5 2>/dev/null || pkg-config --libs lua 2>/dev/null)
CXXFLAGS += $(LUA_CFLAGS)
LDFLAGS  += -shared $(LUA_LIBS)

.PHONY: all clean

all: $(PLUGIN)

$(PLUGIN): $(SRC) bgrender.hpp globals.hpp
	$(CXX) $(CXXFLAGS) -o $@ $(SRC) $(LDFLAGS)

clean:
	rm -f $(PLUGIN)
