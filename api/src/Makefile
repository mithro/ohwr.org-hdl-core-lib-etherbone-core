FLAGS = -Wall -O2
CFLAGS = $(FLAGS) -std=c89
CPPFLAGS = $(FLAGS)

TARGETS = eb-snoop eb-write eb-read

all:	$(TARGETS)

clean: 
	rm -f $(TARGETS) *.o

%:	%.c libetherbone.a
	$(CC) $(CFLAGS) -o $@ $^

libetherbone.a:	etherbone.o udp.o ring.o queue.o
	ar rcs $@ $^
