package parse;

import error.ErrorHelper;

import java_cup.runtime.Symbol;
import java_cup.runtime.SymbolFactory;
import java_cup.runtime.ComplexSymbolFactory.Location;
import java_cup.runtime.ComplexSymbolFactory;

%%

%public
%final
%class Lexer
%implements Terminals
%cupsym Terminals
%cup
%line
%column
%char

%eofval{
    return tok(EOF);
%eofval}

%ctorarg String unitName

%init{
   this.unit = unitName;
%init}

%{
   private String unit;

   private ComplexSymbolFactory complexSymbolFactory = new ComplexSymbolFactory();

   public SymbolFactory getSymbolFactory() {
      return complexSymbolFactory;
   }

   // auxiliary methods to construct terminal symbols at current location

   private Location locLeft() {
      return new Location(unit, yyline + 1, yycolumn + 1, yychar);
   }

   private Location locRight() {
      return new Location(unit, yyline + 1, yycolumn + 1 + yylength(), yychar + yylength());
   }

   private java_cup.runtime.Symbol tok(int type, Object value, Location left, Location right) {
      return complexSymbolFactory.newSymbol(yytext(), type, left, right, value);
    }

   private Symbol tok(int type, String lexeme, Object value) {
      return complexSymbolFactory.newSymbol(lexeme, type, locLeft(), locRight(), value);
   }

   private Symbol tok(int type, Object value) {
      return tok(type, yytext(), value);
   }

   private Symbol tok(int type) {
      return tok(type, null);
   }

   // Error handling
   private void error(String format, Object... args) {
      throw ErrorHelper.error(
         Loc.loc(new Location(unit, yyline+1, yycolumn+1),
                 new Location(unit, yyline+1, yycolumn+1+yylength())),
         "lexical error: " + format,
         args);
   }

   // Auxiliary variables
   private int commentLevel;
   private StringBuilder str = new StringBuilder();
   private Location beginStr;
%}

%state LINE_COMMENT
%state BLOCK_COMMENT
%state STR

alpha = [a-zA-Z] | [a-zA-Z]_
dig   = [0-9]
id    = {alpha} ({alpha} | {dig})*
int   = {dig}+
ascii_char = \\{dig}{dig}{dig}
%%


// litint    = [0-9]+
// id        = [a-zA-Z][a-zA-Z0-9_]*


<YYINITIAL>{

[ \t\f\n\r]+   { /* skip */ }
[]*         { }

true | false   { return tok(LITBOOL, yytext().equals("true") ? new Boolean(true) : new Boolean(false)); }
{int}          { return tok(LITINT, yytext()); }

bool           { return tok(BOOL); }
int            { return tok(INT); }
float          { return tok(FLOAT); }
string         { return tok(STRING); }
if             { return tok(IF); }
then           { return tok(THEN); }
else           { return tok(ELSE); }
while          { return tok(WHILE); }
do             { return tok(DO); }
in             { return tok(IN); }

"="            { return tok(ASSIGN); }
"+"            { return tok(PLUS); }
"-"            { return tok(MINUS); }
"*"            { return tok(TIMES); }
"/"            { return tok(DIV); }
"%"            { return tok(MOD); }
"=="           { return tok(EQ); }
"<>"           { return tok(NE); }
"<"            { return tok(LT); }
"<="           { return tok(LE); }
">"            { return tok(GT); }
">="           { return tok(GE); }
"("            { return tok(LPAREN); }
")"            { return tok(RPAREN); }
"["            { return tok(LBR); }
"]"            { return tok(RBR); }
","            { return tok(COMMA); }

"or"           { return tok(OR); }
"and"          { return tok(AND); }

"#"            { yybegin(LINE_COMMENT); }
"~["           { commentLevel=1; yybegin(BLOCK_COMMENT); }
\"             { str.setLength(0); beginStr = locLeft(); yybegin(STR); }
<<EOF>>        { return tok(EOF); }

{id}           { return tok(ID, yytext().intern()); }

}

<LINE_COMMENT>{
\n             { yybegin(YYINITIAL); }
[^]            { }
<<EOF>>        { yybegin(YYINITIAL); }
}

<BLOCK_COMMENT>{
"~["           { commentLevel++; yybegin(BLOCK_COMMENT); }
"]~"           { if(commentLevel==1){ yybegin(YYINITIAL);} else{commentLevel--; yybegin(BLOCK_COMMENT);} }
[^]            { }
\n             { }
<<EOF>>        { yybegin(YYINITIAL); error("unclosed comment"); }
}

<STR>{
\"             { yybegin(YYINITIAL); return tok(LITSTRING, str.toString(), beginStr, locRight()); }
\\ b           { str.append('\b'); }
\\ t           { str.append('\t'); }
\\ n           { str.append('\n'); }
\\ r           { str.append('\r'); }
\\ f           { str.append('\f'); }
\\ \\          { str.append('\\'); }
\\ \"          { str.append('"'); }
{ascii_char}   { str.append((char) Integer.parseInt(yytext().replace('\\','0'))); }
\n             { error("invalid newline in string literal"); }
\\.            { error("invalid escape sequence in string literal"); }
[^\n\"\\]+     { str.append(yytext()); }
<<EOF>>        { yybegin(YYINITIAL); error("unclosed string literal"); }

}

.              { error("invalid character '%s'", yytext()); }
