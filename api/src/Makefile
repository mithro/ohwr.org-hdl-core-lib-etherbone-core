CC       = gcc
CXX      = g++
CFLAGS   = -std=c89 -Wall -O2
CXXFLAGS = -Wall -O2

TARGETS = eb-snoop eb-write eb-read etherbone.dll

all:	$(TARGETS)

clean: 
	rm -f $(TARGETS) *.o

libetherbone.a:	etherbone.o udp.o ring.o queue.o fec.o code.o
	ar rcs $@ $^

etherbone.dll: etherbone.c udp.c ring.c queue.c fec.cpp code.cpp
	i586-mingw32msvc-g++ $(CXXFLAGS) -shared -Wl,--out-implib=libetherbone.dll.a -Wl,--output-def,etherbone.def -o $@ $^ -lwsock32

%.o:	%.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o:	%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

eb-snoop:	eb-snoop.o libetherbone.a
	$(CXX) $(CXXFLAGS) -o $@ $^

eb-write:	eb-write.o libetherbone.a
	$(CXX) $(CXXFLAGS) -o $@ $^

eb-read:	eb-read.o libetherbone.a
	$(CXX) $(CXXFLAGS) -o $@ $^
