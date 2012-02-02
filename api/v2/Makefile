CFLAGS	= -Wall -O2 -m32
#CFLAGS	:= $(CFLAGS) -DEB_USE_DYNAMIC    # deterministic untill table overflow (default)
#CFLAGS	:= $(CFLAGS) -DEB_USE_STATIC=200 # fully deterministic
#CFLAGS	:= $(CFLAGS) -DEB_USE_MALLOC     # non-deterministic
#CFLAGS := $(CFLAGS) -DDISABLE_SLAVE
#CFLAGS := $(CFLAGS) -DDISABLE_MASTER
CC	= gcc

TARGETS	= demo/sizes demo/eb-read demo/eb-write demo/eb-snoop
TARGET	= etherbone.a
OBJECTS	= $(patsubst %.c,%.o,$(SOURCES))
SOURCES	= memory/static.c		\
	  memory/dynamic.c		\
	  memory/array.c		\
	  memory/malloc.c		\
	  glue/widths.c			\
	  glue/operation.c		\
	  glue/cycle.c			\
	  glue/device.c			\
	  glue/socket.c			\
	  transport/posix-ip.c		\
	  transport/posix-udp.c		\
	  transport/posix-tcp.c		\
	  transport/ssh.c		\
	  transport/transports.c	\
	  transport/block.c		\
	  format/poll.c			\
	  format/flush.c

all:	$(TARGETS) $(TARGET)

$(TARGET):	$(OBJECTS)
	rm -f $@
	ar rcs $@ $^
	ranlib $@

demo/%:	demo/%.c $(TARGET)
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -f $(TARGET) $(OBJECTS) $(TARGETS)

%.o:	%.c
	$(CC) $(CFLAGS) -o $@ -c $^
