FLAGS = -Wall -O2
CFLAGS = $(FLAGS) -std=c89
CPPFLAGS = $(FLAGS)

all:	demo-slave

demo-slave:	demo-slave.o libetherbone.a
	$(CC) $(CFLAGS) -o $@ $^

libetherbone.a:	etherbone.o udp.o ring.o
	ar rcs $@ $^
