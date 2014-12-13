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

$(APP): lex.yy.cc $(APP).tab.cc
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

%.cc: %.c
	mv $^ $@

lex.yy.c: $(APP).l
	$(FLEX) $^

$(APP).tab.c: $(APP).y
	$(BISON) -d -v $^

clean:
	rm -f $(APP) lex.yy.c lex.yy.cc 
	rm -f $(APP).tab.c $(APP).tab.cc $(APP).tab.h $(APP).output
	rm -f $(APP).mid
	rm -Rf $(APP).dSYM

.PHONY: all clean run
