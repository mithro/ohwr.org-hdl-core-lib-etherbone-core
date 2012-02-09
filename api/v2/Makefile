FLAGS	= -Wall -Wmissing-declarations -O0 -g -m32
#FLAGS	:= $(FLAGS) -DEB_USE_DYNAMIC    # deterministic untill table overflow (default)
#FLAGS	:= $(FLAGS) -DEB_USE_STATIC=200 # fully deterministic
#FLAGS	:= $(FLAGS) -DEB_USE_MALLOC     # non-deterministic
#FLAGS	:= $(FLAGS) -DDISABLE_SLAVE
#FLAGS	:= $(FLAGS) -DDISABLE_MASTER

CFLAGS	= $(FLAGS) -Wmissing-prototypes
CXXFLAGS= $(FLAGS)
CC	= gcc
CXX	= g++

TARGETS	= demo/sizes demo/eb-read demo/eb-write demo/eb-snoop test/loopback
TARGET	= etherbone.a
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

all:	$(TARGETS) $(TARGET)

$(TARGET):	$(OBJECTS)
	rm -f $@
	ar rcs $@ $^
	ranlib $@

demo/%:	demo/%.c $(TARGET)
	$(CC) $(CFLAGS) -o $@ $^

test/%:	test/%.cpp $(TARGET)
	$(CXX) $(CXXFLAGS) -o $@ $^

clean:
	rm -f $(TARGET) $(OBJECTS) $(TARGETS)

%.o:	%.c
	$(CC) $(CFLAGS) -o $@ -c $^

%.o:	%.cpp
	$(CXX) $(CXXFLAGS) -o $@ -c $^
