/*
 * piano.l: A Piano Score Scanner
 * Linus Yang
 */

%{

#include <cstdio>
#include <string>
#include "piano.tab.h"

#define YY_DECL extern "C" int yylex(YYSTYPE *yylval_param, YYLTYPE *yylloc_param)
#define YY_USER_ACTION do { \
    yylloc->first_column = yylloc->last_column; \
    yylloc->last_column = yylloc->first_column + yyleng; \
} while(0);
#define YY_NEW_LINE  do { \
    yylloc->first_column = yylloc->last_column = 1; \
    yylloc->first_line = ++yylloc->last_line; \
} while(0);

%}

%option bison-bridge bison-locations

space                [ \t]*
integer              [0-9]+
octave               [drmfslt]
variable             [A-Z]
comment              #.*\n

%%

{integer}            { yylval->ival = atoi(yytext); return INT; }
{octave}             { yylval->cval = yytext[0]; return OCTAVE; }
{variable}           { yylval->cval = yytext[0]; return VAR; }

"_"                  return(FLAT);
"^"                  return(SHARP);
"-"                  return(TWOBEATS);
"--"                 return(THREEBEATS);
"---"                return(FOURBEATS);
"("                  return(LPAREN);
")"                  return(RPAREN);
"["                  return(LBRACKET);
"]"                  return(RBRACKET);
"{"                  return(LBRACE);
"}"                  return(RBRACE);
"="                  return(ASSIGN);
"$"                  return(REF);
";"                  return(SEMICOLON);
\n                   { YY_NEW_LINE; return(NEWLINE); }

{space}              /* do nothing */
{comment}            { YY_NEW_LINE }
.                    { std::fprintf(stderr, "** ignore undefined token `%s' (line %d, col %d)\n",
                       yytext, yylloc->first_line, yylloc->first_column); }

%%
