CFLAGS	= -Wall -O2
#CFLAGS	:= $(CFLAGS) -DEB_USE_DYNAMIC    # deterministic untill table overflow (default)
#CFLAGS	:= $(CFLAGS) -DEB_USE_STATIC=100 # fully deterministic
#CFLAGS	:= $(CFLAGS) -DEB_USE_MALLOC     # non-deterministic
CC	= gcc

TARGET	= etherbone.a
OBJECTS	= $(patsubst %.c,%.o,$(SOURCES))
SOURCES	= memory/static.c \
	  memory/dynamic.c \
	  memory/malloc.c
	  
$(TARGET):	$(OBJECTS)

clean:
	rm -f $(TARGET) $(OBJECTS)

%.o:	%.c
	$(CC) $(CFLAGS) -o $@ -c $^
