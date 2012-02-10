TARGET  = i586-mingw32msvc-
FLAGS	= -Wall -Wmissing-declarations -O0 -g -m32

#FLAGS	:= $(FLAGS) -DEB_USE_DYNAMIC    # deterministic untill table overflow (default)
#FLAGS	:= $(FLAGS) -DEB_USE_STATIC=200 # fully deterministic
#FLAGS	:= $(FLAGS) -DEB_USE_MALLOC     # non-deterministic
#FLAGS	:= $(FLAGS) -DDISABLE_SLAVE
#FLAGS	:= $(FLAGS) -DDISABLE_MASTER

CFLAGS	= $(FLAGS) -Wmissing-prototypes
CXXFLAGS= $(FLAGS)
CC	= $(TARGET)gcc
CXX	= $(TARGET)g++

LIBS	= -lwsock32 -lws2_32

GOALS	= demo/sizes demo/eb-read demo/eb-write demo/eb-snoop test/loopback
LIBRARY	= etherbone.a
OBJECTS	= $(patsubst %.cpp,%.o,$(patsubst %.c,%.o,$(SOURCES)))
SOURCES	= memory/static.c		\
	  memory/dynamic.c		\
	  memory/array.c		\
	  memory/malloc.c		\
	  glue/widths.c			\
	  glue/operation.c		\
	  glue/cycle.c			\
	  glue/device.c			\
	  glue/socket.c			\
	  glue/handler.c		\
	  glue/readwrite.c		\
	  glue/cplusplus.cpp		\
	  transport/posix-ip.c		\
	  transport/posix-udp.c		\
	  transport/posix-tcp.c		\
	  transport/ssh.c		\
	  transport/transports.c	\
	  transport/block.c		\
	  format/slave.c		\
	  format/master.c

all:	$(GOALS) $(LIBRARY)

$(LIBRARY):	$(OBJECTS)
	rm -f $@
	i586-mingw32msvc-g++ $(CXXFLAGS) -shared -Wl,--out-implib=libetherbone.dll.a -Wl,--output-def,etherbone.def -o $@ $^ $(LIBS)
#	$(TARGET)ar rcs $@ $^
#	$(TARGET)ranlib $@

demo/%:	demo/%.c $(LIBRARY)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

test/%:	test/%.cpp $(LIBRARY)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

clean:
	rm -f $(LIBRARY) $(OBJECTS) $(GOALS)

%.o:	%.c
	$(CC) $(CFLAGS) -o $@ -c $^

%.o:	%.cpp
	$(CXX) $(CXXFLAGS) -o $@ -c $^
