FLAGS = -Wall -O2
CFLAGS = $(FLAGS) -std=c89
CPPFLAGS = $(FLAGS)

TARGETS = demo-slave

all:	$(TARGETS)

clean: 
	rm -f $(TARGETS) *.o

demo-slave:	demo-slave.o libetherbone.a
	$(CC) $(CFLAGS) -o $@ $^

libetherbone.a:	etherbone.o udp.o ring.o queue.o
	ar rcs $@ $^
