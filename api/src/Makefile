CFLAGS = -std=c89 -Wall -O2

TARGETS = eb-snoop eb-write eb-read etherbone.dll

all:	$(TARGETS)

clean: 
	rm -f $(TARGETS) *.o

%:	%.c libetherbone.a
	$(CC) $(CFLAGS) -o $@ $^

libetherbone.a:	etherbone.o udp.o ring.o queue.o
	ar rcs $@ $^

etherbone.dll: etherbone.c udp.c ring.c queue.c
	i586-mingw32msvc-gcc $(CFLAGS) -shared -Wl,--out-implib=libetherbone.dll.a -o $@ $^ -lwsock32
