/*
 * piano.y: A Piano Score Parser
 * Linus Yang
 */

%{

#include <iostream>
#include <cstdio>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>
#include <iterator>
#include <utility>

#define VCOUNT 26
#define OCOUNT 7
#define GETV(c) (&vtable[(c) - 'A'])
#define SETV(c, s) (vtable[(c) - 'A'] = *(s))
#define CONCAT(s, t) (new string(*(s) + *(t)))
#define CONCAT_ELE(s, t) (new string(*(s) + " " + *(t)))
#define STR(s) (new string(s))
#define STRC(c) (new string(1, c))
#define PEMPTY (&empty)
#define WRITE_BYTES(f, b) (fwrite(b, 1, sizeof(b), f))

using namespace std;

extern "C" char *yytext;
extern "C" int yylex();
extern "C" FILE *yyin;

int octave_index(char c);
void yyerror(const char *s);
string map_all(string &s, const char map[OCOUNT]);
string append_all(string &s, const char *t);
string remove_space(string &s);

char orig_key(char c);
string sharp_key(string &s);
string flat_key(string &s);
string sharp_all(string &s);
string flat_all(string &s);
void write_to_midi(string &s);

string vtable[VCOUNT];
const char octaves[OCOUNT] = {'d', 'r', 'm', 'f', 's', 'l', 't'};
const char map_flat[OCOUNT] = {'8', '9', '0', 'q', 'w', 'e', 'r'};
const char map_normal[OCOUNT] = {'t', 'y', 'u', 'i', 'o', 'p', 'a'};
const char map_sharp[OCOUNT] = {'s', 'd', 'f', 'g', 'h', 'j', 'k'};
string empty = "";

const int midi_note[OCOUNT] = {60, 62, 64, 65, 67, 69, 71};
const unsigned char midi_header[] = {
    0x4d, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06,
    0x00, 0x00, // single-track format
    0x00, 0x01, // one track
    0x00, 0x10, // 16 ticks per quarter
    0x4d, 0x54, 0x72, 0x6B
};
const unsigned char midi_footer[] = { 0x01, 0xFF, 0x2F, 0x00 };
const unsigned char midi_tempoEvent[] = {
    0x00, 0xFF, 0x51, 0x03,
    0x0F, 0x42, 0x40 // Default 1 million usec per crotchet
};
const unsigned char midi_keySigEvent[] = {
    0x00, 0xFF, 0x59, 0x02,
    0x00, // C
    0x00  // major
};
const unsigned char midi_timeSigEvent[] = {
    0x00, 0xFF, 0x58, 0x04,
    0x04, // numerator
    0x02, // denominator (2==4, because it's a power of 2)
    0x30, // ticks per click (not used)
    0x08  // 32nd notes per crotchet 
};

%}

%union {
    int ival;
    char cval;
    std::string *sval;
}

%token <ival> INT
%token <cval> OCTAVE
%token <cval> VAR

%token FLAT
%token SHARP
%token TWOBEATS
%token THREEBEATS
%token FOURBEATS

%token LPAREN
%token RPAREN
%token LBRACKET
%token RBRACKET
%token LBRACE
%token RBRACE

%token ASSIGN
%token REF
%token SEMICOLON
%token NEWLINE

%left FLAT
%left SHARP
%right TWOBEATS
%right FOURBEATS

%type <sval> statments statment expression elements element

%start start

%%

start:
    statments { cout << *($1); write_to_midi(*($1)); }
    ;

statments:
    /* empty */ { $$ = PEMPTY; }
    | statment statments
    {
        $$ = CONCAT($1, $2);
    }
    ;

statment:
    VAR ASSIGN expression SEMICOLON
    {
        SETV($1, $3);
        $$ = PEMPTY;
    }
    | expression
    {
        $$ = $1;
    }
    ;

expression:
    INT LBRACE elements RBRACE
    {
        string t;
        for (int i = 0; i < $1; i++) {
            t += *($3);
        }
        $$ = STR(t);
    }
    | elements
    {
        $$ = $1;
    }
    ;

elements:
    element { $$ = $1; }
    | element elements { $$ = (*($1) == "\n") ? CONCAT($1, $2) : CONCAT_ELE($1, $2); }
    ;

element:
    REF VAR { $$ = GETV($2); }
    | NEWLINE { $$ = STRC('\n'); }
    | OCTAVE { $$ = STRC(orig_key($1)); }
    | element TWOBEATS { $$ = STR(append_all(*($1), "-")); }
    | element THREEBEATS { $$ = STR(append_all(*($1), "--")); }
    | element FOURBEATS { $$ = STR(append_all(*($1), "---")); }
    | SHARP element { $$ = STR(sharp_key(*($2))); }
    | FLAT element { $$ = STR(flat_key(*($2))); }
    | LPAREN elements RPAREN { $$ = $2; }
    | LBRACKET elements RBRACKET { $$ = STR(remove_space(*($2))); }
    ;

%%

char orig_key(char c)
{
    for (int i = 0; i < OCOUNT; i++) {
        if (octaves[i] == c) {
            return map_normal[i];
        }
    }
    cerr << "ignore undefined octave: " << c << endl;
    return -1;
}

string change_key(string &s, bool flat)
{
    stringstream ss;
    for (int i = 0; i < s.length(); i++) {
        bool found = false;
        if (s[i] != '-') {
            for (int j = 0; j < OCOUNT; j++) {
                if (map_normal[j] == s[i]) {
                    ss << (flat ? map_flat[j] : map_sharp[j]);
                    found = true;
                    break;
                }
            }
        }
        if (!found) {
            ss << s[i];
        }
    }
    return ss.str();
}

string sharp_key(string &s)
{
    return change_key(s, false);
}

string flat_key(string &s)
{
    return change_key(s, true);
}

vector<string> split(string s)
{
    vector<string> tokens;
    istringstream iss(s);
    copy(istream_iterator<string>(iss), istream_iterator<string>(), back_inserter(tokens));
    return tokens;
}

string merge(vector<string> &v)
{
    stringstream ss;
    for (size_t i = 0; i < v.size(); ++i) {
        if (i != 0) {
            ss << " ";
        }
        ss << v[i];
    }
    return ss.str();
}

string sharp_all(string &s)
{
    vector<string> input, output;
    input = split(s);
    for (vector<string>::iterator i = input.begin(); i != input.end(); i++) {
        output.push_back(sharp_key(*i));
    }
    return merge(output);
}

string flat_all(string &s)
{
    vector<string> input, output;
    input = split(s);
    for (vector<string>::iterator i = input.begin(); i != input.end(); i++) {
        output.push_back(flat_key(*i));
    }
    return merge(output);
}

string append_all(string &s, const char *t)
{
    vector<string> input, output;
    input = split(s);
    for (vector<string>::iterator i = input.begin(); i != input.end(); i++) {
        output.push_back(*i + string(t));
    }
    return merge(output);
}

string remove_space(string &str)
{
    str.erase(remove(str.begin(), str.end(), ' '), str.end());
    return str;
}

void yyerror(const char *s)
{
    cerr << "parse error: " << s << endl;
    exit(-1);
}

int char_to_midi_note(char c)
{
    for (int i = 0; i < OCOUNT; i++) {
        if (c == map_flat[i]) {
            return midi_note[i] - 12;
        } else if (c == map_sharp[i]) {
            return midi_note[i] + 12;
        } else if (c == map_normal[i]) {
            return midi_note[i];
        }
    }
    cerr << "error convert midi note from: " << c << endl;
    return -1;
}

void write_to_midi(string &s)
{
    vector<pair<int, int> > seq;
    vector<string> p = split(s);
    int seq_size = sizeof(midi_tempoEvent) + 
        sizeof(midi_keySigEvent) + 
        sizeof(midi_timeSigEvent) + 
        sizeof(midi_footer);
    for (vector<string>::iterator i = p.begin(); i != p.end(); i++) {
        int length = 0;
        for (string::iterator j = i->begin(); j != i->end(); j++) {
            if (*j != '-') {
                length++;
            }
        }
        int beat = 8;
        if (length == 0) {
            continue;
        }
        beat /= length;
        for (string::iterator j = i->begin(); j != i->end(); j++) {
            int tone = 0;
            if (*j != '-') {
                tone = char_to_midi_note(*j);
                int dash = 0;
                j++;
                while (j != i->end() && *j == '-') {
                    j++;
                    dash++;
                }
                j--;
                seq.push_back(make_pair(beat * (dash + 1), tone));
                seq_size += 8;
            }
        }
    }

    FILE *fout = fopen("piano.mid", "wb");
    unsigned char midi_size[] = {0, 0, seq_size >> 8, seq_size & 0xff};
    unsigned char midi_body[] = {0, 0x90, 0, 127, 0, 0x80, 0, 0};

    WRITE_BYTES(fout, midi_header);
    WRITE_BYTES(fout, midi_size);
    WRITE_BYTES(fout, midi_tempoEvent);
    WRITE_BYTES(fout, midi_keySigEvent);
    WRITE_BYTES(fout, midi_timeSigEvent);
    for (vector<pair<int, int> >::iterator i = seq.begin(); i != seq.end(); i++) {
        midi_body[4] = i->first & 0xff;
        midi_body[2] = i->second & 0xff;
        midi_body[6] = i->second & 0xff;
        WRITE_BYTES(fout, midi_body);
    }
    WRITE_BYTES(fout, midi_footer);
    fclose(fout);
}

int main(int argc, const char *argv[])
{
    const char *fname = "piano.txt";
    if (argc > 1) {
        fname = argv[1];
    }
    FILE *fin = fopen(fname, "r");
    if (!fin) {
        cerr << "file not found: " << fname << endl;
        return -1;
    }

    yyin = fin;
    
    do {
        yyparse();
    } while (!feof(yyin));

    fclose(fin);

    return 0;
}
