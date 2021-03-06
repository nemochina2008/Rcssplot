##
## Functions part of Rcssplot package
##
## Lexer for Rcssplot.
## Use RcssLexer to read a file from disk and split into tokens
##  
##
## Author: Tomasz Konopka
##
##
## ################################################################
##
## The Lexer implements grammar (for guidance only)
## The lexer is implemented by hand, and the grammar written afterward)
##
##
## Input: Token MoreTokens
## Token: Terminals | Comment | Number | String
## MoreTokens: EMPTY | Token MoreTokens
## Terminals: one of ".:;{}="
##
## ################################################################
##


## Function for the Lexer that is called externally.
## f - input file, or vector of input files
## returns - a data frame with tokens
##
RcssLexer <- function(f) {
  
  ## obtain data from all input files
  fdata <- lapply(as.list(f), RcssFileCheckRead)
  fdata <- unlist(fdata)
  
  ## split the files into characters
  fdata <- unlist(strsplit(fdata, ""))
  
  ## process the characters and output the result
  return(RcssLexChars(fdata))
}





## Checks if a file exists 
##
## f - single file name
##
## returns - contents of file with " \n" at end of each line added
## (the space-newline is convenient for lexing)
RcssFileCheckRead <- function(f) {
  if (!file.exists(f)) {
    stopCF("RcssFileCheckRead: input file does not exist: ", f, "\n");
  }
  fcon <- file(f, open="r")
  fdata <- readLines(fcon)
  close(fcon)
  return(paste(fdata, "\n"))
}








## ################################################################
## Functions that handle organization of the Lexer


## The root of the actual lexer.
## Technically, this keeps track of the lexed tokens.
## Dispatches to other tokens to parse the next tokens.
##
## cc - a vector of characters
## position - current position in the character vector
## terminals - vector with characters for terminal characters
##
## returns - a data frame with pairs (token, tokentype)
RcssLexChars <- function(cc, pos = 1) {

  cclen <- length(cc)
  
  ## create a list with temporary values (placeholders)
  ## to avoid growing 
  ans <- list(rep(NA, cclen))

  ## bookkeeping
  nowpos <- pos  
  numtokens <- 0

  ## loop to fill list of tokens
  while(nowpos <= cclen) {
    ## obtain information about next token
    thistoken <- RcssLexNextToken(cc, nowpos)
    ## record token, but not if it is a space
    if (thistoken[3] != "SPACE" & thistoken[3] != "COMMENT") {
      ans[[numtokens+1]] <- thistoken[2:3]      
      numtokens <- numtokens + 1
    }
    ## progress along the cc array
    nowpos <- as.integer(thistoken[1])
  }

  ## trim the ans list to only those entries that actually have tokens
  ans <- ans[1:numtokens]
  ans <- data.frame(do.call(rbind, ans), stringsAsFactors = F)
  colnames(ans) <- c("token", "type")  
  return (ans)
}





## Helper function that concatenates a subset of characters in a vector
##
RcssGetToken <- function(cc, pos, newpos) {
  paste(cc[pos:(newpos - 1)], collapse = "")
}





## Function parses one token starting at position 'pos'
##
## cc - vector of characters
## pos - current position in the cc vector
## terminals, spacechars - vector of characters with special meaning 
##
## returns - a triple (NEWPOSITION, TOKEN, TOKENTYPE)
## 
RcssLexNextToken <- function(cc, pos,
                             terminals = unlist(strsplit(".,;:{}=","")),
                             spacechars = unlist(strsplit(" \t\r\n\f",""))) {
  
  nowchar <- cc[pos];
  
  if (nowchar %in% spacechars) {
    ## space character - in this state skip
    return(c(pos + 1, nowchar, "SPACE"))
    
  } else if (nowchar %in% terminals) {
    return(c(pos + 1, nowchar, "TERMINAL"));
    
  } else if (nowchar == "/" & cc[pos + 1] == "*") {
    ## This is the start of a comment
    newpos <- RcssParseComment(cc, pos)
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "COMMENT"))
    
  } else if (nowchar %in% c("\"", "\'")) {
      ## start of a string
    newpos <- RcssParseString(cc, pos, nowchar)
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "STRING"))
    
  } else if (nowchar == "#") {
    ## start of a hex color string    
    newpos <- RcssParseHexToken(cc, pos)
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "HEXCOLOR"))
    
  } else if (nowchar %in% c("-", "+", seq(0,9))) {
    ## start of a number
    newpos <- RcssParseNumber(cc, pos)
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "NUMBER"))
    
  } else {
    ## something else - generic token
    newpos <- RcssParseGeneric(cc, pos,
                               c(terminals, spacechars,
                                 "\"", "'", "/", "#", "-", "+"))
    token <- RcssGetToken(cc, pos, newpos)
    return(c(newpos, token, "IDENT"))
    
  }
  
}








## ################################################################
## Functions that handle individual token types



## parses a comment
## cc - vector of characters
## pos - current position (expects '/' followed by '*')
##
## returns - position of first non-comment
RcssParseComment <- function(cc, pos) {

  ## check one more time that this is a comment
  if (cc[pos] != "/" | cc[pos + 1] != "*") {
    stopCF("RcssParseComment: expecting /*, got ",
           paste(cc[pos:(pos + 1)], collapse=""),"\n");
  }
  
  ## cclen avoids reading beyond the vector length
  cclen <- length(cc)
  
  nowpos <- pos+2  
  while ((nowpos < cclen) & !(cc[nowpos] == "*" & cc[nowpos + 1] == "/")) {
    ## not end of comment yet
    ## check if perhaps nested comment
    if (cc[nowpos]=="/" & cc[nowpos + 1]=="*") {
      nowpos <- RcssParseComment(cc, nowpos);
    } else {
      nowpos <- nowpos + 1
    }
  }
  
  ## reached here, so either end of cc, or end of comment
  ## for the return value, either case is fine
  return(nowpos + 2)  
}





## helper function for string parsing
## return true if a position is preceded by an odd number of slashes
##
## cc - vector of characters
## nowpos - position of character to check escape for (e.g. a " in a string)
##
RcssIsEscaped <- function(cc, pos) {

  ## prepos will be the start of a series of slashes prior to pos
  prepos <- pos
  while (prepos > 1 & cc[prepos - 1] == "\\") {
    prepos <- prepos - 1
  }  
  ## count the number of slashes. Escaped if they are odd
  return ((pos-prepos) %% 2 == 1)  
}
  
  
  
  
  
## parses a number
## cc - vector of characters
## pos - current position (expects '-' or 0-9)
## exponent - set TRUE if parsing an exponent of a number
## decimal - set TRUE if parsing digits after a decimal point
##
## returns - position of first character outside the number
RcssParseNumber <- function(cc, pos, exponent = FALSE, decimal = FALSE) {

  digits = seq(0, 9)  
  
  nowpos <- pos
  ## skip a minus sign or plus sign if there is one
  if (cc[pos] == "-" | cc[pos] == "+") {
    nowpos <- nowpos + 1
  }

  ## a number must have at least one digit
  if (!(cc[nowpos] %in% digits)) {
    stopCF("RcssParseNumber: expecting number, got ", cc[pos], "\n");
  }
  
  ## loop to skip over the digits
  while (cc[nowpos] %in% digits) {
    nowpos <- nowpos + 1
  }
  
  ## after the first digits, can have a dot or an exponent
  if (cc[nowpos]==".") {
    ## do not allow multiple dots
    if (decimal) {
      return(-nowpos)
    } else {
      nowpos <- RcssParseNumber(cc, nowpos + 1,
                                exponent = exponent, decimal = TRUE)
    }
  } else if (cc[nowpos] %in% c("e", "E")) {
    ## do not allow exponents in exponents
    if (exponent) {
      return(-nowpos)
    } else {
      nowpos <- RcssParseNumber(cc, nowpos + 1,
                                exponent = TRUE, decimal = FALSE);
    }
  }
  
  ## check for possible parse errors (return(-nowpos) above)
  if (nowpos<0) {
    stopCF("RcssParseNumber: expecting number in format [-]X.XE[-]X\n",
         "   ", paste(cc[pos:-nowpos], collapse = ""), "\n")
  }

  return(nowpos)
}





## parses a string
## cc - vector of characters
## pos - current position (expects '/' followed by '*')
## delimiter - either " or ' (used to catch nested strings)
##
## returns - position of first character outside the string
RcssParseString <- function(cc, pos, delimiter="\"") {

  ## check one more time for string
  if (cc[pos] != "'" & cc[pos] != "\"") {
    stopCF("RcssParseString: expecting string, got ", cc[pos], "\n")
  }

  cclen <- length(cc)  
  nowpos <- pos + 1
  while ((nowpos < cclen) & !(cc[nowpos] == delimiter)) {
    nowpos <- nowpos + 1
  }

  ## at this stage, nowpos contains a string delimiter
  ## But, if it is "escaped" with slashes, need to continue
  ## By recursion, this will find the final (true) string delimiter
  if (RcssIsEscaped(cc, nowpos)) {
    nowpos <- RcssParseString(cc, nowpos, delimiter = delimiter)
  }

  ## at this stage, nowpos contains the final string delimiter
  ## move the position to the next non-string character
  return (nowpos + 1)
} 





## parses a hex color
## cc - vector of characters
## pos - current position (this function expects a hash sign)
##
## returns - position of the next non-hex character
RcssParseHexToken <- function(cc, pos) {

  ## check one more time start of a hex color
  if (cc[pos] != "#") {
    stopCF("parseHexToken: expecting #, got ", cc[pos], "\n")
  }
  
  ## find all subsequent characters that are consistent with a color
  nowpos <- pos + 1
  hexchars <- c(seq(0,9), letters[1:6])
  while ((cc[nowpos] %in% hexchars)) {
    nowpos <- nowpos + 1
  }
  
  ## check that the color has 6 or 8 characters
  hexlen <- nowpos - pos - 1
  if (hexlen != 6 & hexlen != 8) {
    stopCF("RcssParseHexToken:\n",
         "expecting hex color in #RRGGBB or #RRGGBBAA format\n",
         "   ",paste(cc[pos:(nowpos-1)], collapse = ""),"\n")
  }
  
  ## returns the position of the next non-hex character
  return(nowpos)  
}





## parser for a generic token
## cc - vector of characters
## pos - current position
## delimiters - a vector or delimiters that demarcate end of a token
##              (e.g. terminals not allowed in a variable name)
##
## returns - position of first character beyond the current token
RcssParseGeneric <- function(cc, pos, delimiters) {

  ## loop through characters, accepting everything except delimiters
  nowpos <- pos
  cclen <- length(cc)  
  while (nowpos <= cclen & !(cc[nowpos] %in% delimiters)) {
    nowpos <- nowpos + 1
  }
  
  return(nowpos)
}
