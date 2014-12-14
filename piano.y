/*
 * piano.y: A Piano Score Parser
 * Linus Yang
 */

%{

#include <iostream>
#include <fstream>
#include <cstdio>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>
#include <iterator>
#include <utility>
#include "piano.tab.h"

#define VCOUNT 26
#define OCOUNT 7
#define GETV(c) (&vtable[(c) - 'A'])
#define SETV(c, s) (vtable[(c) - 'A'] = *(s))
#define CONCAT(s, t) (str_concat(s, t))
#define CONCAT_ELE(s, t) (str_concat_ele(s, t))
#define STR(s) (str_copy(s))
#define PEMPTY (&empty)
#define PNEWLINE (&newline)
#define WRITE_BYTES(f, b) (fwrite(b, 1, sizeof(b), f))
#define BEAT_CHAR '-'
#define BEAT_STR "-"

using namespace std;

extern "C" char *yytext;
extern "C" int yylex();
extern "C" FILE *yyin;
void yyerror(const char *);

static char map_octave(char c);
static string *append_note(string *s, const char *t);
static string *reduce_note(string *s);
static string *sharp_note(string *s);
static string *flat_note(string *s);
static void output_note(string *s);

static vector<string *> str_pool;
static string *str_copy(string s);
static string *str_copy(char c);
static string *str_concat(string *s, string *t);
static string *str_concat_ele(string *s, string *t);

static string vtable[VCOUNT];
static const char octaves[OCOUNT] = {'d', 'r', 'm', 'f', 's', 'l', 't'};
static const char map_flat[OCOUNT] = {'8', '9', '0', 'q', 'w', 'e', 'r'};
static const char map_normal[OCOUNT] = {'t', 'y', 'u', 'i', 'o', 'p', 'a'};
static const char map_sharp[OCOUNT] = {'s', 'd', 'f', 'g', 'h', 'j', 'k'};
static string empty = "";
static string newline = "\n";

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
    0x0c, 0x35, 0x00 // 75 bpm
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

%locations
%error-verbose

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
%token BEAT

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

%right BEAT
%left FLAT SHARP

%type <sval> notes note

%start start

%%

start:
    notes
    {
        output_note($1);
    }
    ;

notes:
    note
    {
        $$ = $1;
    }
    | note notes
    {
        if (($1)->length() > 0) {
            $$ = (*($1) == newline) ? CONCAT(PNEWLINE, $2) : CONCAT_ELE($1, $2);
        } else {
            $$ = $2;
        }
    }
    ;

note:
    REF VAR { $$ = GETV($2); }
    | NEWLINE { $$ = PNEWLINE; }
    | OCTAVE { $$ = STR(map_octave($1)); }
    | note BEAT { $$ = append_note($1, BEAT_STR); }
    | SHARP note { $$ = sharp_note($2); }
    | FLAT note { $$ = flat_note($2); }
    | LPAREN notes RPAREN { $$ = $2; }
    | LBRACKET notes RBRACKET { $$ = reduce_note($2); }
    | VAR ASSIGN notes SEMICOLON { SETV($1, $3); $$ = PEMPTY; }
    | INT LBRACE notes RBRACE
    {
        string t;
        for (int i = 0; i < $1; i++) {
            t += *($3);
        }
        $$ = STR(t);
    }
    ;

%%

// String operations

static vector<string> split(string s)
{
    vector<string> tokens;
    istringstream iss(s);
    copy(istream_iterator<string>(iss), istream_iterator<string>(), back_inserter(tokens));
    return tokens;
}

static string merge(vector<string> &v)
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

static string *str_copy(string s)
{
    string *t = new string(s);
    str_pool.push_back(t);
    return t;
}

static string *str_copy(string *s)
{
    return str_copy(*s);
}

static string *str_copy(char c)
{
    return str_copy(string(1, c));
}

static string *str_concat(string *s, string *t)
{
    return str_copy(*s + *t);
}

static string *str_concat_ele(string *s, string *t)
{
    return str_copy(*s + " " + *t);
}

static void str_pool_clean()
{
    for (vector<string *>::iterator i = str_pool.begin(); i != str_pool.end(); i++) {
        string *s = *i;
        delete s;
    }
    str_pool.clear();
}

// Note transformation

static char map_octave(char c)
{
    for (int i = 0; i < OCOUNT; i++) {
        if (octaves[i] == c) {
            return map_normal[i];
        }
    }
    cerr << "** undefined octave: " << c << endl;
    exit(-1);
}

static string transform_note(string &s, bool flat)
{
    stringstream ss;
    for (int i = 0; i < s.length(); i++) {
        bool found = false;
        if (s[i] != BEAT_CHAR) {
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

static string *sharp_note(string *s)
{
    vector<string> input, output;
    input = split(*s);
    for (vector<string>::iterator i = input.begin(); i != input.end(); i++) {
        output.push_back(transform_note(*i, false));
    }
    string result(merge(output));
    return STR(result);
}

static string *flat_note(string *s)
{
    vector<string> input, output;
    input = split(*s);
    for (vector<string>::iterator i = input.begin(); i != input.end(); i++) {
        output.push_back(transform_note(*i, true));
    }
    string result(merge(output));
    return STR(result);
}

static string *append_note(string *s, const char *t)
{
    vector<string> input, output;
    input = split(*s);
    for (vector<string>::iterator i = input.begin(); i != input.end(); i++) {
        output.push_back(*i + string(t));
    }
    string result(merge(output));
    return STR(result);
}

static string *reduce_note(string *s)
{
    string str(*s);
    str.erase(remove(str.begin(), str.end(), ' '), str.end());
    return STR(str);
}

static int char_to_midi_note(char c)
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

static void output_note(string *s)
{
    vector<pair<int, int> > seq;
    vector<string> p = split(*s);
    int seq_size = sizeof(midi_tempoEvent) + 
        sizeof(midi_keySigEvent) + 
        sizeof(midi_timeSigEvent) + 
        sizeof(midi_footer);
    for (vector<string>::iterator i = p.begin(); i != p.end(); i++) {
        int length = 0;
        for (string::iterator j = i->begin(); j != i->end(); j++) {
            if (*j != BEAT_CHAR) {
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
            if (*j != BEAT_CHAR) {
                tone = char_to_midi_note(*j);
                int dash = 0;
                j++;
                while (j != i->end() && *j == BEAT_CHAR) {
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

    std::ofstream pout("output.txt");
    pout << *s;
    pout.close();

    cout << "** write to output.txt and piano.mid" << endl;
    cout << "** translated notes:" << endl;
    cout << *s;
}

void yyerror(const char *s)
{
    fprintf(stderr, "\n** line %d, col %d, token `%s': %s\n", 
        yylloc.first_line, yylloc.first_column, yytext, s);
    exit(-1);
}

int main(int argc, const char *argv[])
{
    const char *fname = "piano.txt";
    if (argc > 1) {
        fname = argv[1];
    }
    FILE *fin = fopen(fname, "r");
    if (!fin) {
        cerr << "** file not found: " << fname << endl;
        return -1;
    }

    yyin = fin;
    do {
        yyparse();
    } while (!feof(yyin));
    fclose(fin);
    str_pool_clean();

    return 0;
}
