FLAGS = -Wall -O2
CFLAGS = $(FLAGS) -std=c89
CPPFLAGS = $(FLAGS)

libetherbone.a:	etherbone.o udp.o ring.o
	ar rcs $@ $^
