# Makefile for Piano
# Linus Yang

APP = piano

CXX = g++
CXXFLAGS = -O2 -g
LDFLAGS = -lfl -L/opt/local/lib

FLEX = flex
BISON = bison

all: run

run: $(APP)
	./$(APP)

$(APP): $(APP).tab.o lex.yy.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

%.o: %.c
	cp $< $<c
	$(CXX) $(CXXFLAGS) $<c -c -o $@

lex.yy.c: $(APP).l
	$(FLEX) $<

$(APP).tab.c: $(APP).y
	$(BISON) -d -v $<

clean:
	rm -f $(APP) *.o lex.yy.c lex.yy.cc 
	rm -f $(APP).tab.c $(APP).tab.cc $(APP).tab.h $(APP).output
	rm -f $(APP).mid output.txt
	rm -Rf $(APP).dSYM

.PHONY: all clean run
