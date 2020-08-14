#!/usr/bin/perl
## pythonizer Version 0.2 (Aug 5, 2020)
## Fuzzy prettyprint STDERR for Perl scripts
## Copyright Nikolai Bezroukov, 2019-2020.
## Licensed under Perl Artistic license
##
## The key idea is process specially preformatted Perl script in which the following is true
##     1. One statament per line
##     2  all block related curvy brackets on separate lines
##     3. Indentation already corresponds nesting     4.
## To be sucessful, this approach requres a certain (very resonable) layout of the script into which most Perl scripts can be converted via via preprocessing
## As most Perl statement are simple over 80% of them usually allow sucessful translation.  That's why we use the term "fuzzy".
## The result will contain some statement that need to be converted by hand and that in some cases requres change of logic.
## But there some notable exceptions. For example, Perl script that extensivly use references or OO.
##
## --- INVOCATION:
##
##   pythonizer [options] [file_to_process]
##
##--- OPTIONS:
##
##    -v -- verbosity (0 -none 3 max vebosity)
##    -h -- this help
##    -t -- size of tab ingenerated Python code (emulated with spaces). Default is 4
##    -d    level of debugging  default is 0 -- production mode
##          0 -- Production mode
##          1 -- Testing mode. Program is autosaved in Archive (primitive versioning mechanism)
##          2 -- Stop at the beginning of statement analysys (the statement can be selected via breakpoint option -b )
##          3 -- More debugging output.
##          4 -- Stop at lexical scanner with $DB::single = 1;
##          5 -- output stages of Python line generation
##--- PARAMETERS:
##
##    1st -- name of  file (only one argument accepted)

#--- Development History
#
# Ver      Date        Who        Modification
# =====  ==========  ========  ==============================================================
# 0.010  2019/10/09  BEZROUN   Initial implementation
# 0.020  2019/10/10  BEZROUN   Revised structure of globalk arrays, Now we have  foud TokenStr, ValClass ValPerl, ValPy
# 0.030  2019/10/11  BEZROUN   Resursion is used to expressions, but in certain cases when I need a lookahead, bracket counting is used instead
# 0.040  2019/10/12  BEZROUN   Better listing for debugging implemented
# 0.050  2019/11/06  BEZROUN   Forgot almost everything after a month; revised code just to refleash memoty. Tokenizer slightly improved
# 0.050  2019/11/07  BEZROUN   Assignment within logical expression is not allowed in Python. It is now tranlated correctly
# 0.060  2019/11/08  BEZROUN   post assignmen conditions like "next if( substr($line,0,1) eq '') " are processed correctly
# 0.070  2019/11/11  BEZROUN   x=(v>0) ? y :z is now translated into ugly Python ternary ooperator which exists since Python 2.5
# 0.071  2019/11/11  BEZROUN   program now correctly translated 80% codelines of pre_pythonizer.pl
# 0.080  2019/12/27  BEZROUN   Array ValCom is introduced for the preparetion of version 0.2 of pre-processor pre_pythonizer.pl
# 0.090  2020/02/03  BEZROUN   #\ means continuation of the statement.
# 0.091  2020/02/03  BEZROUN   Moved sub preprocess_line to Pythonizer
# 0.100  2020/03/16  BEZROUN   Reworked scanner
# 0.200  2020/08/05  BEZROUN   Abandoned hope to make it perfect.
# 0.210  2020/08/07  BEZROUN   Moved gen_output to Perlscan,  removed ValCom  from the exported list.
# 0.220  2020/08/07  BEZROUN   Diamond operator is processes as a special type of identifier.
# 0.230  2020/08/09  BEZROUN   gen_chunk moves to Perlscan module. Pythoncode array made local
# 0.230  2020/08/09  BEZROUN   more functions and statement eimplemnted
# 0.240  2020/08/10  BEZROUN   postfix conditional re-implemented differnetly then in expression via scanne buffer
# 0.250  2020/08/10  BEZROUN   split function is reimplemented and oprimized incase there is plain vanilla
# 0.251  2020/08/12  BEZROUN   Perl_default_var is renames into default_var
# 0.260  2020/08/14  BEZROUN   System variables in double quoted literals are compled correctly. Perlscan.pm improved.
# 0.261  2020/08/14  BEZROUN   for loop translation corrected
#!start ===============================================================================================================================

   use v5.10;
   use warnings;
   use strict 'subs';
   use feature 'state';

#
# Modules used ( from the current directory to make debugging more convinient; will change later)
#
   use lib '.';
   use Softpano qw(autocommit helpme abend banner logme out);
   use Perlscan qw(gen_statement  tokenize gen_chunk @ValClass  @ValPerl  @ValPy $TokenStr);
   use Pythonizer qw(correct_nest getline prolog epilog output_line);

   $VERSION='0.261';
   $breakpoint=9999; # line from which to debug code. See Pythonizer
   $debug=0;  # 0 production mode 1 - development/testing mode. 2-9 debugging modes
              # 4 -stop at Perlscan.pm
   $SCRIPT_NAME='pythonizer';
   $MYLIB='.';
   $OS=$^O; # $^O is built-in Perl Variable that contains OS name
   if( $OS eq 'cygwin' ){
      $HOME="/cygdrive/f/_Scripts";  # used for backups
   }elsif( $OS eq 'linux' ){
      $HOME=ENV{'HOME'}; # used for backups
   }
   $LOG_DIR='/tmp/'.ucfirst($SCRIPT_NAME);
   logme('D',3,3); # inital settings
   banner($LOG_DIR,$SCRIPT_NAME,'Fuzzy translator of Python to Perl $VERSION',30); # Opens SYSLOG and print STDERRs banner; parameter 4 is log retention period
   prolog(); # sets all options, including breakpoint
   if( $debug > 0 ){
      logme('D',3,3); # Max Verbosity
      autocommit("$HOME/Archive",$MYLIB,qw(Softpano.pm Perlscan.pm Pythonizer.pm));
   }

#
# Skip initial block of comments
#
   $line=<>; # we need to discard the first line with /usr/binperl as interpreter
   output_line('','#!/usr/bin/python2.7 -u'); # put a proper line
   $line=getline(); # get the first meaningful line,  initial block of comments will be copied to the output
   foreach $line ('import sys','import re','import os','import fileinput'){
       output_line('',$line); # to block repodocuting the first source line
   }
#
#Main loop
#
my $start;
   while(defined($line)){
      last unless(defined($line));
      if( $debug>1 ){
         say STDERR "\n\n === Line $. Perl source: |",$line,"| === \n";
         if( $.>=$breakpoint ){
            unless ( $DB::single ){
               logme('S', "Breakpoint was triggered at line $. in pythonizer.pl");
               $DB::single = 1;
            }
         }
      }
#
# You need to tokenize the statement first before translation
#
      tokenize($line);
      if( scalar(@ValClass)==0 ){
          $line=getline();
          next;
      }
      $FailedTrans=0;
      #
      # Statements
      #
      $RecursionLevel=-1;
      if( $ValClass[0] eq '}' ){
         # we treat curvy bracket as a separate dummy statement
          correct_nest(-1); # next line de-indented
      }elsif( $ValClass[0] eq '{' ){
         correct_nest(1); # next line indented
      }elsif( $ValClass[0] eq '(' ){
         if(index($TokenStr,')0')>-1) {
            #implicit if statement
            $rc=short_cut_if(0);
         }elsif(index($TokenStr,')=')>-1) {
            $rc=assignment(0);
            if( $rc<0 ){ $FailedTrans=1; }
         }
      }elsif( $ValPerl[0] eq 'use' || $ValPerl[0] eq 'goto' || $ValPerl[0] eq 'bless' || $ValPerl[0] eq 'package'  ){
         output_line('','#NOTRAN: '.$line);
         $line=getline();
         next;
      }elsif( $ValPerl[0] eq 'sub' ){
         correct_nest(0,0);
         gen_chunk($ValPy[0]); # def
         gen_chunk($ValPy[1]); # name
         gen_chunk('(perl_arg_array):'); # list of arguments
      }elsif(  $ValPerl[0] eq 'close' ){
         for( my $i=1; $i<@ValPy; $i++ ){
             if( $ValClass[$i] eq 'i' ){
                gen_chunk($ValPy[$i].'.f.close;');
             }
         }
      }elsif( $ValClass[0] eq 'h' ){
         if( substr($TokenStr,0,3) eq 'h=(' ){
            # hash initialization needs to be converted to dictionary initialization
            gen_chunk($ValPy[0].'={');
            for( my $i=3; $i<$#ValPy; $i++ ){
               gen_chunk( $ValPy[$i] );
            }
            gen_chunk('}');
         }else{
           gen_chunk(join(' ',@ValPy));
         }
      }elsif( $ValPerl[0] =~ /say|print/ ){
         gen_chunk($ValPy[0]);
         $start=1;
         if( $ValClass[$start] eq 'i' ){
            #printing to file handle
            gen_chunk(' >>'.$ValPy[1]); # this is Python 2.7 for 3.x   print('hello world', file=file_object)
            $start++;
         }
         $rc=expression($start,$#ValClass,0);
         if( $rc<0 ){ $FailedTrans=1; }
      }elsif( $ValClass[0] =~ /[shat]/ ){
          #scalar assignment or reg matching; Include my/own/state
          # expression is expected on the right side, but in Perl it can follow by condition a=2 if(b==0) => if( b==0  ){  a=2 }
          if( $#ValClass==1) {
             if( $ValClass[0] eq 't' ){
                #my $k;
                output_line("$ValPy[1]=None");
             }else{
                # $i++;
                gen_chunk($ValPy[0].$ValPy[1]);
              }
          }else{
            $rc=assignment(0);
            if( $rc<0 ){ $FailedTrans=1; }
          }
      }elsif( $ValClass[0] eq 'c' ){
           #normal control statement: if/while/for, etc -- next line is always nested.
           # in foreach loop "(" is absent )
           $rc=control(0);
           if( $rc<0 ){ $FailedTrans=1; }

      }elsif( $ValClass[0] eq 'C' ){
           #next last continue
          if( $ValPerl[0] eq 'elsif' ){
                gen_chunk('elif ');
                $end_pos=matching_br(1);
                $k=expression(2,$end_pos,0);
                if( $k<0 ){$rc=-255;}
                gen_chunk(':');
                gen_statement();

          }elsif( $ValPerl[0] eq 'else' ){
               gen_chunk('else:');
               gen_statement();
         }elsif( $ValPerl[0] eq 'return' ||  $ValPerl[0] eq 'exit' ){
               if(scalar(@ValClass)==1) {
                  # single statement without parameters
                  gen_chunk("$ValPy[0]()");
               }else{
                  gen_chunk("$ValPy[0](");
                  $rc=expression(1);
                  if( $rc<0 ){ $FailedTrans=1; }
                  gen_chunk(')');
               }
          }elsif( $#ValClass > 0 && $ValClass[1] eq 'c' ){
               # tail conditional for next and last
               $rc=control(1); # generate coditional statement as prefix
               if( $rc<0 ){ $FailedTrans=1; }
               gen_statement();
               correct_nest(1,1); # next line indented
               gen_chunk($ValPy[0]);
               gen_statement(); # output this isngle line
               correct_nest(-1,-1); # next line indented
           }else{
               # single keyword on the line like next;
               gen_chunk($ValPy[0]);
               if( $#ValClass>0 ){
                   $rc=expression(1,$#ValClass);
               }
           }
     }elsif( $ValClass[0] eq 'f' ){
         #this is a left hand function like is substr($line,0,1)='' or open or chomp;
         if( $ValPerl[0] eq 'substr' ){
            $rc=left_hand_substr(0);
            if( $rc<0 ){ $FailedTrans=1; }
         }elsif( $ValPerl[0] eq 'chomp' ){
            if( $#ValPerl==0) {
               gen_chunk(q[default_var=default_var.rstrip("\n")]); # chomp with no argumnets
            }elsif( $ValClass[1] eq '(' ){
               gen_chunk($ValPy[2].'='.$ValPy[2].$ValPy[0]);
            }elsif( $ValClass[1] eq 's' ){
               # function without paranthesys
               gen_chunk($ValPy[1].'='.$ValPy[1].$ValPy[0]);
            }else{
               $FailedTrans=1;
            }
         }elsif( $ValPerl[0] eq 'chop' ){
            if( $ValPerl[1] eq '(' ){
               if( $ValClass[2] eq 's' ){
                  gen_chunk($ValPy[2].'='.$ValPy[2].'[0:-1]');
               } else{
                  $FailedTrans=1;
               }
            }else{
               gen_chunk('default_var=default_var[0:-1]');
            }
         }else{
            $rc=function(0);
            if( $rc<0 ){ $FailedTrans=1; }
         }
      }elsif( $ValClass[0] eq 'q' ){
         # /abc/;
         gen_statement();
         $rc=expression(1);
      }elsif( $ValClass[0] eq 'd' ){
         if( length($TokenStr)==1 ){
             logme('W','line starts with digit');
         }else{
            $FailedTrans=1;
         }
      }elsif( $ValClass[0] eq '(' ){
         # (/abc/) && a=b; (a<b) || a=7
         $right_br=matching_br(0);
         if( $ValClass[$right_br+1] eq '0' ){
            gen_chunk('if ');
            $rc=expression(0); # this will scan till ')'
            if( $rc<0 ){ $FailedTrans=1; }
         }elsif( $ValClass[$right_br+1] eq '1' ){
            gen_token('if ! ');
            $rc=expression(0); # this will scan till ')'
            if( $rc<0 ){ $FailedTrans=1; }
         }elsif( $ValClass[$right_br+1] eq '=' ){
            #this is a list assignment like ($i,$k)=@_  or ($i,$k)=split(//,$text)
            $rc=expression(0,$right_br);
            gen_chunk($ValPy[$right_br+1]);
            $rc=expression($right_br+1,$#ValClass,0);
         }
      }elsif( $ValClass[0] eq 'k' ){
         # keyword for which we have no special treatment
         if( $ValClass[0] eq '(' ){
            $rc=expression(0,$#ValClass); # this will scan till ')'
            if( $rc<0 ){ $FailedTrans=1; }
          }else{
           $FailedTrans=1;
         }
      }elsif( $ValClass[0] eq 'i' ){
         # user defined functon
         if( $ValClass[1] eq '(' ){
            if( $ValClass[2] eq ')' ){
               # function with sero argumants
               gen_chunk($ValPy[0].'()');
            }else {
               gen_chunk($ValPy[0]);
               gen_chunk('([');
               $rc=expression(2,$#ValClass,0); # this will scan till ')'
               if( $rc<0 ){ $FailedTrans=1; }
               gen_chunk('])');
            }
         }else{
           $FailedTrans=1;
         }
      }else{
         $FailedTrans=1;
      }
      if( $FailedTrans ){
         push(@NoTrans,$line);
      }
      gen_statement();
      $line=getline(); # get new line
      correct_nest();
   } # while
#
# Epilog -- close  output file and  if you are in debugging mode display the content  on the screen
#
   say STDERR "The following lines were probably translated incorrectly:";
   say STDERR join("\n",@NoTrans);
   epilog();
   exit 0;


#
# Nov 11, 2019 Now assignment assepts not only the index of the first token, but also index of the last.
#
sub assignment
{
my $start=$_[0]; # start of analysys of assignment statement
   if( $start<0 || $FailedTrans  ){
      $FailedTrans=1;
      return -255;
   }
my $limit;
   if( scalar(@_)>1 ){
      $limit=$_[1];
   }else{
      $limit=$#ValClass;
   }
 my ($k,$split,$post_processing,$comma_pos,$from,$to);
 #
 # Assignment with post condition need to be transformed into regular control structure in Python
 #
   $k=$start;
   $post_processing=0;
   if( ($split=index($TokenStr,'c',$start))>-1 ){
      # process tail if/while/until/for
      control($split);
      gen_statement(); # output tail line
      $post_processing=1; # we need to restore the nesting after generating line
      $limit=$split-1; # we do not need to process condition agian.
   }
   #
   # Analysys of the left part
   #
   if( $ValClass[$k] eq 't' ){
       if( $TokenStr eq 'ts') {
         output_line('#NOTRANS '.$line);
         return $#ValClass;
       }elsif( $TokenStr=~/^t[sha]=/ || $TokenStr=~/^t\([sha]\s*(,[sha]\s*)*\s*\)\s*=/ ){
         #ignore my, etc just generate the assignment

         if( $ValPerl[$k] eq 'state'  || $ValPerl[$k] eq 'own'  ){
             gen_chunk('global ');
         }
       }
       $k++;

   }

   # Perl can have a list of the left side of the assignement



#
#  Check the type of assingment. If can be =, Conditional C-style or increament/decrement
#
   if( ($from=index($TokenStr,'=(',$k))>-1 &&  ($split=index($TokenStr,')?',$k))>-1 ){
      # this is C-style conditional assigment   x=(v>0):y:z;
      # Python: variable = something if condition else something_else
      $to=matching_br($from+1);
      ($to<0) && return -255;
      if( $k==$from-1 ){
         gen_chunk($ValPy[$k]);
      }else{
         $k=expression($k,$from-1,0); # generate variable
         ($k<0) && return -255;
      }
      gen_chunk('=');
      $comma_pos=index($TokenStr,':',$split+3);
      (($k=expression($split+2,$comma_pos-1,0))<0) && return -255;
      gen_chunk(' if ');
      $k=expression($from+1,$to); ($k<0) && return -255; # generate expression
      gen_chunk(' else ');
      $k=expression($comma_pos+1,$#ValPerl,0); # up to the very end
      ($k<0) && return -255;
      gen_statement(); # output if line
      return $#ValPerl+1;
   }
   #
   # C-style ++ and --
   #
   if( $ValClass[$k+1] eq '^' ){
       gen_chunk($ValPy[$k].$ValPy[$k+1]);
       return $#ValPerl+1;
   }
#
# Regular assignment with "="
#
   if( ($split=index($TokenStr,'=',$k))>-1 ){
       if( $ValPerl[$k] eq '(' ){
          # list on the left side
          gen_chunk($ValPy[$k]);
          $k++;
          gen_chunk($ValPy[$k]); # first in the cascading assignement
          $k++;
          while($k<$split ){
             # this was we skip delimiters
             if( substr($TokenStr,$k,1)=~/^[sha]/ ){
                gen_chunk(','.$ValPy[$k]);
             }
             $k++;
          }
          gen_chunk(')');
          $k++;
       }elsif( $split-$k==1 ){
         #scalar or array or hash but single variable -- regular assignment;
         gen_chunk($ValPy[$k]); # simple scalar assignment -- varible of left side
      }else{
         # possibly  array with complex subscripts or complex hash key expression
         $k=expression($k,$split-1,0); # on the left side it can be array index or something more complex
         ($k<0) && return -255;
      }
      gen_chunk($ValPy[$split]); # generate appropriate operation hidden under topn '=' (  +=, -=, etc)
      if( $limit - $split == 1 ){
         # only one token after '='
         $k=$split+1;
         gen_chunk($ValPy[$k]); # that includes diamond operator <> and <HANDLE> Aug 10,2020
         #$is_numeric{$ValPerl[$k]}='d'; # capture the type of variable.
      }elsif( $limit>$split ){
          # we have some kind of expression on  the right side
          $k=expression($split+1,$limit,0); # process expression without brackets -- last param is 0
          ($k<0) && return -255;
      }
   }elsif( ($split=index($TokenStr,'~',$k))>-1 ){
      #regular expression $string =~ /cat/ or $string =~m/cat/
      # re.search(r'cat', string): ...
      if( $split-$k==1 ){
         if( $ValClass[$split-1] eq 's' || $ValPerl[$split+1] eq 'tr'  ){
            gen_chunk($ValPy[$split-1]); # a
            gen_chunk('=');              # a=
            gen_chunk($ValPy[$split-1]); # a=areplicate variable
            if( $ValPerl[$split+1] eq 'tr' ){
               gen_chunk(".translate($ValPy[$split+1])");
            }else{
               gen_chunk($ValPy[$split+1]);
            }
            $k=$split+1;
        }else{
            $k=expression($start,$split-1,0); # can be array index or something  more problemtic ;-)
            ($k<0) && return -255;
            gen_chunk('=');
            $k=expression($start,$split-1,0); # do the same ;-)
            gen_chunk($ValPy[$split+1]); # add dot part generated by scanner
            $k=$split+1;
         }
      }
   }
   return $k+1;
} # assignment
#
# Arg1 - starting position for scan
# Arg2 - (optional) -- balance from whichto start (allows to skip opening brace)
sub matching_br
{
my $scan_start=$_[0];
my $balance=0;
   if( scalar(@_)>1 ){
      $balance=$_[1]; # case where opening bracket is missing for some reason or was skipped.
   }

   for( my $k=$scan_start; $k<length($TokenStr); $k++ ){
     $s=substr($TokenStr,$k,1);
     if( $s eq '(' ){
        $balance++;
     }elsif( $s eq ')' ){
        $balance--;
        if( $balance==0  ){
           $ValPy[$k]=''; # erase bracket just in  case
           return $k;
        }
     }
  } # for$
  return length($TokenStr)-1;
} # matching_br

#
# Extration of assignment statement from conditions and other places where Python prohibits them
# Added Nov 11, 2019
#
sub pre_assign
{
my  $assign_start=$_[0];
my  $assign_end;
my $balance=0;
   $assign_end=matching_br($assign_start);
   ($assign_end<0) && return -255;
   assignment($assign_start+1,$assign_end-1);
   gen_statement();
#
# remove everytnogh but variable name. we need to shink arrrays
#
my $from=index($TokenStr,'=',$assign_start+2); # "=" now is next to identifier; should be
my $howmany=$assign_end-$from+1;
      if( $howmany>0 ){
         splice(@ValClass,$from,$howmany);
         #splice(@ToSub,$from,$howmany);
         splice(@ValPerl,$from,$howmany);
         splice(@ValPy,$from,$howmany);
      }
# Remove opening bracket -- it is no longer needed

      splice(@ValClass,$assign_start,1);
      #splice(@ToSub,$assign_start,1);
      splice(@ValPerl,$assign_start,1);
      splice(@ValPy,$assign_start,1);
      $TokenStr=join('',@ValClass);
}
sub short_cut_if
{
   my $start=$_[0];
   $limit=matching_br($start);
   gen_chunk('if ');
   $k=expression($start+1,$limit,0);
   if( $k<0 ){
      $FailedTrans=1;
      return -255;
   }
   gen_chunk(':');
   gen_statement();
   correct_nest(1,1);
   $k=index($TokenStr,'0');
   if( $#ValClass==$k+1 ){
      gen_chunk($ValPy[$k+1]);
   }elsif( $ValClass[$k+1]=~/[ikf]/ && $ValClass[$k+2] eq '(' ){
      $k=function($k+1);
   }elsif( index($TokenStr,'=',$k)>-1 ){
      $k=assignment($k+1,$#ValClass);
   }
   gen_statement();
   if( $k<0){
      $FailedTrans=1;
      return -255;
   }
   correct_nest(-1,-1);
   return $#ValClass;

}
sub control
{
my $start=$_[0];
   if( $start<0 || $FailedTrans  ){
      $FailedTrans=1;
      return -255;
   }
my $limit;
   if( scalar(@_)>1 ){
      $limit=$_[1];
   }else{
      $limit=$#ValClass;
   }
my ($hashpos,$end_pos);
      if( $ValPerl[$start+1] eq '(' ){
            $ValPy[$start+1]='';
            $limit=matching_br($start+1);
            ($limit<0) && return -255;
            $ValPy[$limit]='';
      }

      if( $ValPerl[$start] eq 'if'  || $ValPerl[$start] eq 'unless' ){
         if( $TokenStr eq 'c(i)') {
             gen_chunk("$ValPy[$start] default_var=$ValPy[$start+2]:"); # gen initial keyword
             return($#ValClass);
         }
         if( $TokenStr=~/(^.*)\(s.*?=/ ){
            # assignment inside control statement is prohibited in Python (in 3.8 walrus operator fixes that )
            pre_assign(length($1));
            $limit=matching_br($start+1); # TokenStr changed because assigment was factored out
         } # if
         gen_chunk($ValPy[$start]); # gen initial keyword
         $k=expression($start+2,$limit,0);
         ($k<0) && return -255;
         gen_chunk(':');
          return($#ValClass);
      }elsif( $ValPerl[$start] eq 'while' || $ValPerl[$start] eq 'until' ){
         if( $TokenStr eq 'c(s=i)' && substr($ValPerl[4],0,1) eq '<' ) {
            gen_chunk("$ValPy[0] $ValPy[2] in $ValPy[4]:" );
         }elsif( $TokenStr eq 'c(i)' ){
            gen_chunk("$ValPy[0] default_var in $ValPy[2]:" );
         }elsif( $TokenStr eq 'c((cs=)' ){
            logme('S', "Translation of assignment in while loop requres Python 3.8+");
            return 255
         }else{
            $FailedTrans=1;
            return -255;
         }
         return($#ValClass);
      }elsif( $ValPerl[$start] eq 'for' && $ValPerl[$start+1] eq '(' ){
         # regular for loop but can be foreach loop too
         $end_pos=matching_br($start+1);
         if( $ValPerl[$end_pos-1] eq '++'){
            $increment='';
         }elsif( $ValPerl[$end_pos-1] eq '--'){
            $increment='-1';
         }else{
            $FailedTrans=1;
            return -255;
         }
         gen_chunk($ValPy[$start]);
         gen_chunk($ValPy[$start+2]); # index var
         gen_chunk('in range(');
         $start=index($TokenStr,'=',$start); # find initialization. BTW it can be expression
         if( $start == -1 ){$FailedTrans=1; return -255;}
         $start++;
         # find end of initialization
         $end=index($TokenStr,';',$start); # end of expression
         if( $end-$start==1 ){
             gen_chunk($ValPy[$start++]);
         }else{
            expression($start,$end-1,0); # gen expression
         }

         gen_chunk(',');
         #
         # Analize loop exit condition
         #
         $start=index($TokenStr,'>',$start);
         if( $start == -1 ){$FailedTrans=1; return -255; }
         $start++;
         # find end of loopexit condition
         $end=index($TokenStr,';',$start);
         if( $end == -1 ){$FailedTrans=1; return -255; }
         if( $end-$start==1 ){
             if( $ValClass[$start] eq 'a' ){
                gen_chunk('len('.$ValPy[$start].')');
             }else{
                gen_chunk($ValPy[$start]);
             }
         }else{
            expression($start,$end-1); # gen expression
         }
         if( $increment) {
            gen_chunk(",$increment):");
         }else{
           gen_chunk('):');
         }
         return($#ValClass);
      }elsif( $ValPerl[$start] eq 'for' || $ValPerl[$start] eq 'foreach' ){
         if( $TokenStr eq 'cs(a)') {
            # loop over an array
            gen_chunk("$ValPy[$start] $ValPy[$start+1] in $ValPy[$start+3]:" );
            return $#ValClass;
         }elsif( ($hashpos=index($TokenStr,'f(h)')) > -1 ){
            # for loop over a hash
            $end_pos=matching_br($start+1);
            if( $ValPerl[$hashpos] eq 'keys' || $ValPerl[$hashpos] eq 'values'  ){
               # foreach loop
               gen_chunk($ValPy[$start]);
               gen_chunk("$ValPy[$start+1] in $ValPy[$hashpos+2].$ValPerl[$hashpos]():"); # index var
               return $end_pos+1;
            }else{
               $FailedTrans=1;
               return -255;
            }
            return($#ValClass);
         }
      }else{
         $FailedTrans=1;
         return -255;
      }
} # control
sub next_comma
{
my $scan_start=$_[0];
my $balance=0;
    for( my $k=$scan_start; $k<length($TokenStr); $k++ ){
      $s=substr($TokenStr,$k,1);
      if( $s eq '(' ){
         $balance++;
      }elsif( $s eq ')' ){
         $balance--;
      }
      if( $s eq ',' && $balance==0  ){
          return $k;
      }

   } # for
   return -1;
} # next_comma

sub function
{
my $start=$_[0];
my ($end_pos,$k,$split,$split2);
   if( $start<0 || $FailedTrans ){
      $FailedTrans=1;
      return -255;
   }
   if( $ValPerl[$start] eq 'substr' ){
         #text[offset:len]
         $end_pos=matching_br($start+1);
         ($end_pos<0) && return -255;
         if( substr($TokenStr,5,1) eq ',' ){
            # Simplest case -- scalar varaible or constant is used
            gen_chunk($ValPy[$start+2]); #name of the variable
            gen_chunk('['); # opening  bracket
            $split=$start+3;
         }else{
            $split=next_comma($start+2);
            if( $split==-1 ){
               $FailedTrans=1;
               return -255
            }
            $k=expression($start+2,$split-1,0);
            ($k<0) && return -255;
            gen_chunk('['); # opening  bracket
         }
         $split2=next_comma($split+1);
         if( $split2>-1 ){
             # substr($line,$start,$end)
             $k=expression($split+1,$split2-1,0);
             ($k<0) && return -255;
             gen_chunk(':');
             $k=expression($split2+1,$end_pos-1,0);
             ($k<0) && return -255;
             gen_chunk(']');
         }else{
            # substr($line,$start)
            $k=expression($split+1,$end_pos-1,0);
            ($k<0) && return -255;
            gen_chunk(':]');
         }
         return $end_pos+1; # $end_pos signifies the end of function
      } #substr

      if( $ValPerl[$start] eq 'index' || $ValPerl[$start] eq 'rindex'){
         # string.find(text, substr, start)
         $end_pos=matching_br($start+1);
         ($end_pos<0) && return -255;
         if( substr($TokenStr,5,1) eq ',' ){
            # Simplest case -- scalar varaible is used
            gen_chunk("$ValPy[$start+2]$ValPy[$start]("); # line.find -- .find is now in scannet table Nov 15, 2019 --NNB
            $split=$start+3;
         }else{
            $split=next_comma($start+2);
            $k=expression($start+2,$split-1,0);
            ($k<0) && return -255;
            gen_chunk("$ValPy[$start]("); # opening  bracket
         }
         $split2=next_comma($split+1);
         if( $split2>-1 ){
             # index($line,$string,$start)
             if( $split+1==$split2 ){
                gen_chunk($ValPy[$split2]);
             }else{
                $k=expression($split+1,$split2,0);
                ($k<0) && return -255;
             }
             gen_chunk(',');
             $k=expression($split2+1,$end_pos-1,0);
             ($k<0) && return -255;
             gen_chunk(')');
         }else{
            # index($line,'xxx') -> line.find('xxx')
            $k=expression($split+1,$end_pos-1,0);
            ($k<0) && return -255;
            gen_chunk(')');
         }
         return $end_pos+1; # $end_pos signifies the end of function

      }elsif( $ValPerl[$start] eq 'open' ){
         $rc=open_fun($start);
         return -255 if( $rc < 0 );
         return($#ValClass); # this is a statement masqurading as function
      } elsif( $ValPerl[$start] eq 'exists' ){
         $incr=($ValPerl[$start+1] eq '(')?2:1;
         $k=$start+$incr;
         if( $ValClass[$k] eq 's') {
            $dict=$ValPy[$k];
            $k+=2;
            if( $ValClass[$k+1] eq ')' ) {
               #single token between {}
               if( $ValClass[$k] eq 's' || $ValClass[$k] eq '"' || $ValClass[$k] eq "'"){
                  gen_chunk("$ValPy[$k] in $dict");
                  return $k+2;
               }
               return -255
            }else{
               $limit=matching_br($k-1);
               $k=expression($k-1,$limit,1);
            }
         }else{
           return -255
         }
      }elsif(substr($ValPerl[$start],0,1) eq '-') {
         #file predicates
         if ($ValPerl[$start] eq '-s') {
            gen_chunk($ValPy[$start].'('.$ValPy[$start+1].').st_size');
         }else{
            gen_chunk($ValPy[$start].'('.$ValPy[$start+1].')');
         }
         return $start+2;
      }elsif( $ValPerl[$start] eq 'split' ){
         # you nees to exteact the second argument first
         if($ValClass[$start+2] eq "'" ){
            #this is text not pattern
            gen_chunk($ValPy[$start+4],'.split(',$ValPy[$start+2],')');
         }else{
            gen_chunk($ValPy[$start+4],'.',$ValPy[$start],'(',$ValPy[$start+2],')');

         }

         return $start+5;
      }
      #
      # Generic function
      #

      if( $ValClass[$start+1] ne '(' ){
           $FailedTrans=1;
           return -255
      }  # if
      $end_pos=matching_br($start+3,1);
      if( $end_pos<0 ){
         $FailedTrans=1;
         return -255;
      }
      if( substr($ValPy[$start],0,1) eq '.' ){
         #this is a method in Python
         $rc=expression($start+2,$end_pos,0);
         if( $rc<0 ){
            $FailedTrans=1;
            return -255;
         }
         gen_chunk($ValPy[$start]);
      }else{
         gen_chunk($ValPy[$start]);
         $rc=expression($start+1,$end_pos,1);
         if( $rc<0 ){
            $FailedTrans=1;
            return -255;
         }
      }
      return $end_pos+1;

} #function
sub open_fun
{
my $start=$_[0];
my($k,$myline, $target,$open_mode,$handle);
    #  open (SYSFORM,'>',$output_file ) || abend(__LINE__,"Cannot open file $output_file for");
   $k=($ValPerl[$start+1] eq '(') ? $start+2: $start+1;
   if( $ValClass[$k] eq 'i' ){
      $handle=$ValPy[$k];
   }else{
      return -255;
   }
   $k+=2 if(  $ValPerl[$k+1] eq ',');
   if( $ValClass[$k] eq "'" && $ValClass[$k+1] eq ',' ){
      # this is the second argument
      $open_mode=$ValPerl[$k];
      $k+=2;
      if( $ValClass[$k] eq "'" || $ValClass[$k] eq '"' || $ValClass[$k] eq 's' ){
         $target=$ValPy[$k];
      }
   }elsif( $ValClass[$k] eq "'" || $ValClass[$k] eq '"'  ){
      # ValPerl does not preserve quotes
      if( $ValPerl[$k]=~/^([<>])+/ ){
         $open_mode=$1;
         $target=$ValPy[$k];
         substr($target,1,length($1))='';
         if( substr($target,0,5) eq '"" + '){
            $target=substr($target,5);
         }
      }else{
         # implicit filemode
         $open_mode='>';
         $target=$ValPy[$k];
      }
   }elsif( $ValClass[$k] eq 's' ){
      # implicit filemode
      $open_mode='>';
      $target=$ValPy[$k];
   }
    if( $open_mode eq '>' ){
        $open_mode='r';
      }elsif( $open_mode eq '<' ){
        $open_mode='w';
      }elsif( $open_mode eq '>>'){
         $open_mode='a';
      }else{
          $open_mode='?';
      }
   $k+=2;
   if( $k<$#ValPerl &&  $ValPerl[$k] eq '||' ){
       output_line('try:');
       correct_nest(1,1);
   }
   #
   # Open statement generation from collected info -- $handle, $target and $open_mode
   #
   if(  $open_mode eq 'r' ||  $open_mode eq 'a' ){
      output_line("if os.path.isfile($target): $handle=open($target,'$open_mode')");
      output_line("else: os.exit()");
   }else{
      output_line("$handle=open($target,'$open_mode')");
   }
   if( $k<$#ValPerl &&  $ValPerl[$k] eq '||' ){
      correct_nest(-1,-1);
      output_line('except OSError:');
      correct_nest(1,1);
      $k++;
      if( $ValPerl[$k] eq 'die' ){
         $myline="print $ValPy[$k+1](";
         $k++ if( $ValClass[$k+1] eq '(');
         $myline.=$ValPy[$k].')';
         output_line($myline);
         output line('sys.exit()');
      }else{
         $myline="$ValPy[$k]$ValPy[$k+1]";
         for($k=$k+2;$k<@ValPy;$k++){
            $myline.=$ValPy[$k];
         }
         output_line($myline);
         output_line('sys.exit()');
      }
      correct_nest(-1,-1);
   } #if ValPerl
   return 0;
} # open_fun
#
# Anything in round brackets, including the list
# Arg1 == (obligatory) starting point
# Arg2 -- limit  -- the last token to scan.
# Arg3 -- mode of operation
#         0 - remove the inital round brackets
#         1 -preserve round brackets
# Arg 4 -- if given set recursion level to 0

sub expression
{
my $cur_pos=$_[0];
   if( $cur_pos<0 || $FailedTrans ){
       return -255
   }
my ($limit,$mode,$split,$start,$prev_k);

   $limit=(scalar(@_)>1) ? $_[1] : $#ValClass; # 0 - remove  round  brackets 1 -preserve round brackets
   $mode=(scalar(@_)>2) ? $_[2] : 0;  # 0 - remove  round  brackets 1 -preserve round brackets

#my $last_token=(scalar(@_) == 2)? $_[2] : undef;

  $RecursionLevel++; # we are starting from -1
   #
   # Do we need to add opening braket, which is missing because we put start as the next symbol
   #
   if( $mode==1 && $ValClass[$cur_pos] ne '(' ){
       gen_chunk('('); # generate artificial opening braket
   }
   if( $cur_pos==$limit ){
      # a single token in expression
      gen_chunk($ValPy[$cur_pos]);
      if( $mode && $ValClass[$cur_pos] ne ')' ){ gen_chunk(')') };
      $RecursionLevel--;
      return $cur_pos+1;
   }
   $prev_k=-1; # starting position of infinite loop preventor.
   while($cur_pos<=$limit ){
      if( $cur_pos < 0 || $FailedTrans ){
         $FailedTrans=1;
         return -255;
       }
       unless( defined($ValClass[$cur_pos]) ){
         say "Undefined ValClass $cur_pos";
         $DB::single = 1;
      }
      # return $cur_pos+1 if( defined($last_token) && $ValClass[$cur_pos] eq $last_token); # Nov 11, 2019 -- unlear if we need this functionality or not
      if( $ValClass[$cur_pos] eq '(' ){
         # generate brack if mode=1 or recursion level is above zero
         gen_chunk($ValPy[$cur_pos]);
         $cur_pos=expression($cur_pos+1,$limit,0); # preserve brackets
         ($cur_pos<0) && return -255;
      }elsif(  $ValClass[$cur_pos] eq '<' ){
         gen_chunk('readline()');
         $cur_pos++;
      }elsif( $ValClass[$cur_pos] eq 'f' ){
         $cur_pos=function($cur_pos);
         ($cur_pos<0) && return -255;
      }elsif( $ValClass[$cur_pos] eq ')' ){
         if( $RecursionLevel>0 ){
           $RecursionLevel--;
            gen_chunk($ValPy[$cur_pos]);
         }elsif( $mode==1 ){
            gen_chunk($ValPy[$cur_pos] ); # can be supressed on recursion level 0
         }
         return $cur_pos+1;
      }elsif( $ValClass[$cur_pos] eq 's' ){
            # march in Puthon is method .re.match
            # As the argument to =~ can be complex. currently we can transtalte only two simple case: a scalar and an element of array/hash
            if( $limit-$cur_pos>1 && ($split=index(substr($TokenStr,0,$limit),'~',$cur_pos))>-1){
               # REGEX processing
               if($ValClass[$split+1] eq 'q'){
                  if( $cur_pos+1==$split){
                      # Simple scalar variable of the left side
                      gen_chunk($ValPy[$split-1]); # replicate variable
                      gen_chunk($ValPy[$split+1]); # add dot part generated by scanner
                  }elsif( substr($TokenStr,$cur_pos,$split-$cur_pos)=~/s[^\[{][sdq'"][\[{]$/ ){
                        for( my $i=$cur_pos; $i<$split; $i++ ){
                           gen_chunk($ValPy[$i]);
                        }
                        gen_chunk($ValPy[$split+1]); # add dot part generated by scanner
                  }else{
                     $FailedTrans=1;
                     return -255;
                  }
               }elsif($ValClass[$split+1] eq 'f'){
                  # translate
                  gen_chunk($ValPy[$cur_pos].'.'.$ValPy[$split+1])
               }
               $cur_pos=$split+2;# split quotes regeg on the right side
           }else{
               gen_chunk($ValPy[$cur_pos]);
               $cur_pos++;
            }
      }else{
         gen_chunk($ValPy[$cur_pos]);
         $cur_pos++;
      }
      if( $cur_pos eq $prev_k ){
         logme("S","Internal error -- no progress in scanning expression from position $cur_pos");
         $cur_pos++;
         $FailedTrans=1;
         return -255;
      }
      $prev_k=$cur_pos
   }
   $RecursionLevel--;
   if( $mode==1 && $_[0] ne '(' ){
      gen_chunk(')');
   }
   return $cur_pos+1;
} #expression

sub left_hand_substr
#
# Perl
#    substr(s1, fron, len)=s2
# can be translated into Python:
#    text = text[:start] + replacement + text[(start+length):]
# or
#    s1 = s2.join(s1[0:from],s1[from+1:])
{
my  $equal_pos=index($TokenStr,'=');
my $comman_no=0;
state $temp_var=0;
my $var='';
my ($replacement,$k);

      if( $equal_pos == -1 ){
         return 255;
      }
      if( index(q(s'"qd),$ValClass[$equal_pos+1])>=1 && $#ValClass==$equal_pos+1 ){
         # $#ValClass==$equal_pos+1 means that we deal with =$str variant
         # substr($str,$from,$len)=$str2; -- no expression on the right part
         $replacement=$ValPy[$equal_pos+1]; # we can translate such subst in a single line
      }else{
         # we need a temp Variable to storethe replacement string
         $replacement="replacement$.";
         gen_chunk("$replacement.=");
         $k=expression($equal_pos+1); # parse the tail of te line  first starting from '='
         ($k<0) && return -255;
         gen_statement() # out the generated line
      }

      if( $ValClass[1] eq '(' && $ValClass[2] eq 's' ){
         # the first argument should be scalar
        $var=$ValPy[2];
        gen_chunk("$var=$var".'[:');
      }else{
         return 255;
      }
      for( $k=4; $k<@ValClass; $k++ ){
         if( $ValClass[$k] eq ')' ){
           last;
         }elsif( $ValClass[$k] eq ',' ){
           $comma_no++;
           if( $comma_no==1 ){
              gen_chunk("] + $replacement + $var".'[('.$ValPy[$k-1]);
           }elsif( $comma_no==2 ){
              gen_chunk("+$ValPy[$k-1]:]");
           }
         }elsif( $ValClass[$k] eq 'f' ){
            $k=function($k);
            ($k<0) && return -255;
          }elsif( $ValClass[$k] eq '(' ){
            $k=expression($k+1);
            ($k<0) && return -255;
         }else{
           gen_chunk($ValPy[$k]);
           $k++;
         }
      } #for
      return $k;
} #left_hand_substr
