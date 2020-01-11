package Pythonizer;
#
#:: ABSTRACT:  Supplementary subsroutnes for pythonizer
#:: Includes logging subroutine(logme), autocommit, banner, abend, out and helpme
#:: Copyright Nikolai Bezroukov, 2019.
#:: Licensed under Perl Artistic license
# Ver      Date        Who        Modification
# =====  ==========  ========  ==============================================================
# 00.00  2010/10/10  BEZROUN   Initial implementation. Limited by the rule "one statement-one line"
# 00.10  2010/11/19  BEZROUN   The prototype is able to process the amin test (with  multiple errors) but still
# 00.11  2010/11/19  BEZROUN   autocommit now allow to save multiple modules in addition to the main program
# 00.12  2010/12/27  BEZROUN   Notions of ValCom was introduced in preparation to pre_processeor version 0.1

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
@EXPORT = qw(correct_nest getline prolog epilog output_line);
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
         if( $options{'b'}>=0  && $options{'b'}<1000 ){
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
      out("=" x 80,"\n\n");
      #
      # Process the first line
      #
      $line=<>;
      if( length($line)>2 && $line =~/#\!/ ){
      }else{
         getline($line); # push back the first line
      }

   $old_tailcomment=$::TailComment;
   $old_original=$IntactLine;
   $IntactLine='NONE';
   foreach $line ( ('#!/usr/bin/python2.7 -u','import sys','import re','import os') ) {
      output_line($line,1);
   }
   $IntactLine=$old_original;
   $::TailComment=$old_tailcomment;
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
      if (scalar(@buffer)) {
         $line=shift(@buffer);
      }else{
         $line=<>;
      }
      return $line unless (defined($line));
      if (length($line)==0 || $line=~/^\s*#/ ){
         chomp($line);
         output_line($line,1);
         next;
      }
      $IntactLine=$line;
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
my $indent=' ' x $::TabSize x $CurNest;
my $flag=( $::FailedTrans && scalar(@_)==1 ) ? 'FAIL' : '    ';
my ($lineno,$len,$tail);

   if( $line=~/^\s+(.*)$/ ){
      $line=$indent.$1;
   }else{
      $line=$indent.$line;
   }
   if ($::TailComment) {
       $line.=' '.$::TailComment;
   }
   $len=length($line);
   say SYSOUT $line;
   $lineno=sprintf('%4u',$.);
   $line="$lineno | $CurNest | $flag |$line";
   if (scalar(@_)==1){
      if ($IntactLine=~/^\s+(.*)$/) {
         $IntactLine=$1;
      }
      if ($::TailComment) {
         $IntactLine=substr($IntactLine,0,-length($::TailComment));
      }
      if( $len > 72 ){
         if(length($IntactLine)>72){
            out($line);
            out((' ' x 89).' #Perl: '.substr($IntactLine,0,72));
            $tail=" #Cont: ".substr($IntactLine,72);
         }else{
            out($line.' #Perl: '.substr($IntactLine,0,72));
            $tail='';
         }
         ($tail) && out((' ' x 89).$tail);
      }elsif($line  || $IntactLine ){
         if ($IntactLine) {
            $tail=($IntactLine) ? (' ' x (72-$len))." #Perl: $IntactLine" : '';
            out($line.$tail);
         }else{
            out($line);
         }
      }
   }else{
      # gen line with  actual tail comment
      if ($_[1] eq '#\\' ){
         out($line,' \ '); # continuation line
      }else{
         out($line, $_[1]); # output with tail comment instead of Perl comment
      }

   }
   $IntactLine='';
}

sub correct_nest
{
my $delta;
   if (scalar(@_)==0) {
      $CurNest=$NextNest;
      return;
   }elsif(scalar(@_)>=1){
      $delta=$_[0];
      if($delta eq 0 && scalar(@_)==1 ){
         # single parameter was passed and it is zero
         $NextNest=0;
      }elsif($delta>0) {
         if ($NextNest>$MAXNESTING) {
             logme('E',"Nexting level exceeeded the  treshold: $MAXNESTING");
         }else{
             $NextNest++;
         }
      }elsif($delta<0) {
         if ($NextNest>0) {
            $NextNest--;
         }else{
            logme('S',"Attempt to set negative future nesting level");
         }
      }
   }
   if(scalar(@_)==2){
       if ($_[0]==0 && $_[0]==0 ) {
          # (0,0) has special meaning -- make both  zero.  Used for sub
          $CurtNest=$NextNest=0;
          return;
       }
       #  Correction of Curnest only
       $delta=$_[1];
       if( $delta == 0 ) {
         $CurtNest=0;
       }elsif($delta>0) {
         if ($CurNest>$MAXNESTING) {
             logme('E',"Nexting level exceeded the  treshold: $MAXNESTING");
         }else{
           $CurNest++;
         }
      }elsif($delta<0) {
         if ($CurNest>0) {
            $CurNest--;
         }else{
            logme('E',"Attempt to set negative current nesting level");
         }
      }
   }
}
1;
