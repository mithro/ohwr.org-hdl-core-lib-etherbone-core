#BUILD = lm32
#BUILD = win32
BUILD = unix

ifeq ($(BUILD), lm32)
TARGET	= lm32-elf-
endif
ifeq ($(BUILD), win32)
TARGET  = i586-mingw32msvc-
LIBS	= -lwsock32 -lws2_32
endif

ifeq ($(BUILD), lm32)
GOALS     =
CPLUSPLUS =
TRANSPORT = transport/lm32.c
else
GOALS     = tools/eb-read tools/eb-write tools/eb-load tools/eb-snoop tools/eb-tunnel test/sizes test/loopback
CPLUSPLUS = glue/cplusplus.cpp
TRANSPORT = transport/posix-ip.c		\
	    transport/posix-udp.c		\
	    transport/posix-tcp.c		\
	    transport/tunnel.c			\
	    transport/transports.c		\
	    transport/block.c
endif

ifeq ($(BUILD), win32)
LIBRARY = etherbone.dll
else
LIBRARY = etherbone.a
endif

FLAGS	= -Wall -Wmissing-declarations -O2
#FLAGS	:= $(FLAGS) -DEB_USE_DYNAMIC    # deterministic untill table overflow (default)
#FLAGS	:= $(FLAGS) -DEB_USE_STATIC=200 # fully deterministic
#FLAGS	:= $(FLAGS) -DEB_USE_MALLOC     # non-deterministic
#FLAGS	:= $(FLAGS) -DDISABLE_SLAVE
#FLAGS	:= $(FLAGS) -DDISABLE_MASTER

CFLAGS	= $(FLAGS) -Wmissing-prototypes
CXXFLAGS= $(FLAGS)
CC	= $(TARGET)gcc
CXX	= $(TARGET)g++

OBJECTS	= $(patsubst %.cpp,%.o,$(patsubst %.c,%.o,$(SOURCES)))
SOURCES	= memory/static.c		\
	  memory/dynamic.c		\
	  memory/array.c		\
	  memory/malloc.c		\
	  format/slave.c		\
	  format/master.c		\
	  glue/widths.c			\
	  glue/operation.c		\
	  glue/cycle.c			\
	  glue/device.c			\
	  glue/socket.c			\
	  glue/handler.c		\
	  glue/readwrite.c		\
	  glue/sdwb.c			\
	  $(CPLUSPLUS)			\
	  $(TRANSPORT)

all:	$(GOALS) $(LIBRARY)

etherbone.a:	$(OBJECTS)
	rm -f $@
	$(TARGET)ar rcs $@ $^
	$(TARGET)ranlib $@

etherbone.dll:	$(OBJECTS)
	$(TARGET)g++ $(CXXFLAGS) -shared -Wl,--out-implib=libetherbone.dll.a -Wl,--output-def,etherbone.def -o $@ $^ $(LIBS)

tools/%:	tools/%.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

test/%:	test/%.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

test/%:	test/%.cpp $(LIBRARY)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

clean:
	rm -f $(LIBRARY) $(OBJECTS) $(GOALS)

%.o:	%.c
	$(CC) $(CFLAGS) -o $@ -c $^

%.o:	%.cpp
	$(CXX) $(CXXFLAGS) -o $@ -c $^
