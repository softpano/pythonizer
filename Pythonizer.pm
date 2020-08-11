package Pythonizer;
#
#:: ABSTRACT:  Supplementary subroutines for pythonizer
#:: Includes logging subroutine(logme), autocommit, banner, abend, out and helpme
#:: Copyright Nikolai Bezroukov, 2019.
#:: Licensed under Perl Artistic license
# Ver      Date        Who        Modification
# =====  ==========  ========  ==============================================================
# 00.00  2019/10/10  BEZROUN   Initial implementation. Limited by the rule "one statement-one line"
# 00.10  2019/11/19  BEZROUN   The prototype is able to process the minimal test (with  multiple errors) but still
# 00.11  2019/11/19  BEZROUN   autocommit now allow to save multiple modules in addition to the main program
# 00.12  2019/12/27  BEZROUN   Notions of ValCom was introduced in preparation of introduction of pre_processor.pl version 0.2
# 00.20  2020/02/03  BEZROUN   getline was moved from pythonyzer.
# 00.30  2020/08/05  BEZROUN   preprocess_line was folded into getline.

use v5.10;
   use warnings;
   use strict 'subs';
   use feature 'state';
   use Getopt::Std;
   use Softpano qw(autocommit helpme abend banner logme out);

require Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
@ISA = qw(Exporter);
#@EXPORT = qw(correct_nest getline output_open get_params prolog epilog output_line $IntactLine $::debug $::breakpoint $::TabSize $::TailComment);
@EXPORT = qw(preprocess_line correct_nest getline prolog epilog output_line);
our  ($IntactLine, $output_file, $NextNest,$CurNest, $line);
   $::TabSize=3;
   $::breakpoint=0;
   $NextNest=$CurNest=0;
   $MAXNESTING=9;
   $VERSION = '1.10';

#
# Decode parameter for the pythonizer. all parameters are exported
#
sub prolog
{
      getopts("fhrb:t:v:d:",\%options);
      if(  exists $options{'h'} ){
         helpme();
      }
      if(  exists $options{'d'}  ){
         if( $options{'d'} =~/^\d$/ ){
            $::debug=$options{'d'};
         }elsif( $options{'d'} eq '' ){
            $::debug=1;
         }else{
            die("Wrong value of option -d: $options('d')\n");
         }
      }
       if(  exists $options{'b'}  ){
         if( $options{'b'}>=0  && $options{'b'}<900 ){
            $::breakpoint=$options{'b'};
            ($::debug) && logme('W',"Breakpoint  set to $::breakpoint");
         }else{
            die("Wrong value of option -b (line for debugger breakpoint): $options('b')\n");
         }
      }
      if(  exists $options{'v'} ){
         if( $options{'v'} =~/\d/ && $options{'v'}<3  ){
            $::verbosity=$options{'v'};
         }else{
            logme('D',3,3); # add warnings
         }
      }
      if(  exists $options{'t'}  ){
         if( $options{'t'}>1  && $options{'2'}<10 ){
            $::TabSize=$options{'2'};
         }else{
            die("Range for options -t (tab size) is 1-10. You specified: $options('t')\n");
         }
      }

      if (scalar(@ARGV)==1) {
         $fname=$ARGV[0];
         unless( -f $fname) {
            abend("Input file $fname does not exist");
         }
         $output_file=substr($ARGV[0],0,rindex($ARGV[0],'.')).'.py';
         out("Results of transcription are written to the file  $output_file");
         open (STDIN, "<-",) || die("Can't open $fname for reading");
         open(SYSOUT,'>',$output_file) || die("Can't open $output_file for writing");
      }else{
         open(SYSOUT,'>-') || die("Can't open $STDOUT for writing");
      }
      if($debug){
          print STDERR "ATTENTION!!! Working in debugging mode debug=$debug\n";
      }
      out("=" x 90,"\n\n");
      #
      # Output the first line
      #

      $IntactLine='';

      return;
} # prolog

sub epilog
{
   close STDIN;
   close SYSOUT;
   if( $::debug ){
      say STDERR "==GENERATED OUTPUT FOR INPECTION==";
      print STDERR `cat -n $output_file`;
   }
}
#
# Extract here string with delimiter specified as the first argument
#
sub get_here
{
my $here_str;
   while (substr($line,0,length($_[0])) ne $_[0]) {
     $here_str.=$line;
     $line=getline();
   }
   return '""""'."\n".$here_str."\n".'"""""'."\n";
}
#
# getline has now ability to buffer line, which will be scanned by tokeniser next.
#
sub getline
{
state @buffer;

   if( scalar(@_)>0 ){
       push(@buffer,@_); # buffer line for processing in the next call;
       return
   }
   while(1) {
      #
      # firs we perform debufferization
      #
      if (scalar(@buffer)) {
         $line=shift(@buffer);
      }else{
         $line=<>;
      }
      return $line unless (defined($line)); # End of file
      chomp($line);
      if (length($line)==0 || $line=~/^\s*$/ ){
         output_line('');
         next;
      }elsif( $line =~ /^\s*(#.*$)/ ){
           # pure comment lines
           output_line('',$1);
           next;
      }
      $IntactLine=$line;
      if( substr($line,-1,1) eq "\r" ){
         chop($line);
      }
      if( $line=~/(^.*\S)\s+$/ ){
        $line=$1;
      }
      if( $line=~/(^\s+)/ ){
         $line=substr($line,length($1));
      }
      return  $line;
   }

}

#
# Output line shifted properly to the current nesting level
# arg1 - actually PseudoPython gerenated line
# arg 2 -- tail comment (added Dec 28, 2019)
sub output_line
{
my $line=(scalar(@_)==0 ) ? $IntactLine : $_[0];
my $tailcomment=(scalar(@_)==2 ) ? $_[1] : '';
my $indent=' ' x $::TabSize x $CurNest;
my $flag=( $::FailedTrans && scalar(@_)==1 ) ? 'FAIL' : '    ';
my $len=length($line);
my $maxline=90;
my $prefix=sprintf('%4u',$.)." | $CurNest | $flag |";
my $com_zone=$maxline+length($prefix);

   if ($tailcomment){
       $tailcomment=($tailcomment=~/^\s+(.*)$/ ) ? $indent.$1 : $indent.$tailcomment;
   }
   # Special case of empty line or "pure" comment
   if( $len==0 ){
         out($prefix,$tailcomment);
         say SYSOUT $tailcomment;
         $IntactLine='';
         return;
   }
   $line=($line=~/^\s+(.*)$/ )? $indent.$1 : $indent.$line;
   say SYSOUT $line;
   $line=$prefix.$line;
   $len=length($line);
   if (scalar(@_)==1){
      # no tailcomment
      if ($IntactLine=~/^\s+(.*)$/) {
         $IntactLine=$1;
      }
      #remove tailcomment from original line
      if( $len > $maxline ){
         # long line
         if( length($IntactLine) > 90 ){
            out($line);
            out((' ' x $com_zone),' #PL: ',substr($IntactLine,0,90));
            out((' ' x $com_zone),' Cont:  ',substr($IntactLine,90));
         }else{
            out($line,' #PL: ',$IntactLine);
         }
     }else{
         # short line
         out($line,(' ' x ($com_zone-$len)),' #PL: ',$IntactLine);
      }
   }else{
     #line with tail comment
     $IntactLine=substr($IntactLine,0,-length($tailcomment));
     if ($tailcomment eq '#\\' ){
         out($line,' \ '); # continuation line
      }else{
         out($line, $tailcomment); # output with tail comment instead of Perl comment
      }
      if( length($IntactLine)>90 ){
         #long line
         out((' ' x $com_zone),' #PL: ',substr($IntactLine,0,90));
         out((' ' x $com_zone),' #Cont: ',substr($IntactLine,90));
      }else{
         #short line
         out((' ' x $com_zone),' #PL: ',$IntactLine);
      }
   }

} # output_line
#
# Correct nest -- ensure proper indenting of the lines. Accepts two arguments
#  if no arguments given it sets $CurNest=$NextNest;
#  If only 1 ARG given inrements/decreaments $NextNest;
#     NOTE: If zero is given sets NextNest to zero.
#  if two argumants given sets increments/decrements both NexNext and $CurNest
#     NOTE: Special case -- if 0,0 is passed both set to zero
# Each argiment checked against the min and max threholds befor processing
sub correct_nest
{
my $delta;
   if (scalar(@_)==0) {
      # if no arguments given  set NextNest equal to CurNest
      $CurNest=$NextNest;
      return;
   }
   $delta=$_[0];
   if ($delta==0 && scalar(@_)==1 ){
      $NextNest=0;
      return;
   }
   if( $NextNest+$delta > $MAXNESTING ){
      logme('E',"Attempt to set next nesting level above the treshold($MAXNESTING) ingnored");
   }elsif( $NextNest+$delta < 0 ){
      logme('S',"Attempt to set nesting level below zero ignored");
   }else{
     $NextNest+=$delta;
   }

   if(scalar(@_)==2){
       $delta=$_[1];
       if ($delta==0 && $_[0]==0){
          $CurNest=$NextNest=0;
          return;
       }
       if ($delta+$CurNest>$MAXNESTING) {
          logme('E',"Attempt to set current nesting level above the treshold($MAXNESTING) ignored");
       }elsif($delta+$CurNest<0){
          logme('S',"Attempt to set the curent nesting level below zero ignored");
       }else{
         $CurNest+=$delta;
       }
   }
}
1;
