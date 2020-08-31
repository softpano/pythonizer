package Pythonizer;
#
## ABSTRACT:  Supplementary subroutines for pythonizer
## Includes logging subroutine: logme,  abend, out, getopts  and helpme
## Copyright Nikolai Bezroukov, 2019-2020.
## Licensed under Perl Artistic license
# Ver      Date        Who        Modification
# =====  ==========  ========  ==============================================================
# 00.00  2019/10/10  BEZROUN   Initial implementation. Limited by the rule "one statement-one line"
# 00.10  2019/11/19  BEZROUN   The prototype is able to process the minimal test (with  multiple errors) but still
# 00.11  2019/11/19  BEZROUN   autocommit now allow to save multiple modules in addition to the main program
# 00.12  2019/12/27  BEZROUN   Notions of ValCom was introduced in preparation of introduction of pre_processor.pl version 0.2
# 00.20  2020/02/03  BEZROUN   getline was moved from pythonyzer.
# 00.30  2020/08/05  BEZROUN   preprocess_line was folded into getline.
# 00.40  2020/08/17  BEZROUN   getops is now implemented in Softpano.pm to allow the repretion of option letter to set the value of options ( -ddd)
# 00.50  2020/08/24  BEZROUN   Option -p added
# 00.60  2020/08/25  BEZROUN   __DATA__ and __END__ processing added
# 00.61  2020/08/25  BEZROUN   POD processing  added
# 00.70  2020/08/26  BEZROUN   Option - r (refactor) added

use v5.10;
   use warnings;
   use strict 'subs';
   use feature 'state';
   use Softpano qw(abend logme out getopts standard_options);

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
   $refactor=0;

#
#::prolog --  Decode parameter for the pythonizer. all parameters are exported
#
sub prolog
{
      getopts("hd:v:r:p:b:t:",\%options);
#
# Three standard otpiotn -h, -v and -d
#
      standard_options(\%options);
#
# Custom options specific for the application
#
      if(  exists $options{'r'}  ){
         if( $options{'r'} eq ''){
            $refactor='./prepythonizer.pl';
         }else{
            if ( -f $options{'r'} ){
              $refactor=$options{'r'};
            }else{
               logme('S',"file $options{'r'} does not exist (may be you need to specify path to the file)\n");
               exit 255;
            }
         }
         unless (-x $refactor) {
             logme('S',"File $options{'r'} specifed in option -r is not executable\n");
             exit 255;
         }
      }

      if(  exists $options{'p'}  ){
         if( $options{'p'}==2  || $options{'p'}==3 ){
            $::PyV=$options{'p'};
            ($::debug) && logme('W',"Python version set to $::PyV");
         }else{
            logme('S',"Wrong value of option -p. Only values 2 and 3 are valid. You provided the value : $options('b')\n");
            exit 255;
         }
      }

      if(  exists $options{'b'}  ){
        unless ($options{'b'}){
          logme('S',"Option -b should have a numberic value. There is no default.");
          exit 255;
        }
        if( $options{'b'}>=0  && $options{'b'}<9000 ){
           $::breakpoint=$options{'b'};
           ($::debug) && logme('W',"Breakpoint  set to line  $::breakpoint");
        }else{
           logme('S',"Wrong value of option -b (line for debugger breakpoint): $options('b')\n");
           exit 255;
        }
      }
      if(  exists $options{'t'}  ){
         $options{'t'}=1 if $options{'t'} eq '';
         if( $options{'t'}>1  && $options{'t'}<10 ){
            $::TabSize=$options{'t'};
         }else{
            logme('S',"Range for options -t (tab size) is 2-10. You specified: $options('t')\n");
            exit 255;
         }
      }
#
# Application arguments
#
      if (scalar(@ARGV)==1) {
         $fname=$ARGV[0];
         unless( -f $fname) {
            abend("Input file $fname does not exist");
         }
         $source_file=substr($ARGV[0],0,rindex($ARGV[0],'.'));
         $output_file=$source_file.'.py';
         out("Results of transcription are written to the file  $output_file");
         if ($refactor) {
             out("Option -r (refactor) was specified. file refactored using $refactor as the fist pass over the source code");
            `$refactor -v 0 $fname`;
         }
         open (STDIN, '<-',) || die("Can't open $fname for reading");
         open(SYSOUT,'>',$output_file) || die("Can't open $output_file for writing");
      }else{
         open(SYSOUT,'>-') || die("Can't open $STDOUT for writing");
      }
      if($debug){
          print STDERR "ATTENTION!!! Working in debugging mode debug=$debug\n";
      }
      out("=" x 90,"\n\n");
      return;
} # prolog

#::epilig -- close file and produce generated code, if in debug mode
sub epilog
{
   close STDIN;
   close SYSOUT;
   if( $::debug>2 ){
      say STDERR "==GENERATED OUTPUT FOR INPECTION==";
      print STDERR `cat -n $output_file`;
   }
} # epilog

#
#::get_here --  Extract here string with delimiter specified as the first argument
#
sub get_here
{
my $here_str;
   while (substr($line,0,length($_[0])) ne $_[0]) {
     $here_str.=$line;
     $line=getline();
   }
   return '""""'."\n".$here_str."\n".'"""""'."\n";
} # get_here

#
#::getline -- get input line. It has now ability to buffer line, which will be scanned by tokeniser next.
#
sub getline
{
state @buffer; # buffer to "postponed lines. Used for translation of postfix conditinals among other things.

   if( scalar(@_)>0 ){
       push(@buffer,@_); # buffer line for processing in the next call;
       return
   }
   while(1) {
      #
      # firs we perform debufferization
      #
      if( scalar(@buffer) ){
         $line=shift(@buffer);
      }else{
         $line=<>;
      }
      return $line unless (defined($line)); # End of file
      chomp($line);
      if (length($line)==0 || $line=~/^\s*$/ ){
         output_line(''); # blank line
         next;
      }elsif( $line =~ /^\s*(#.*$)/ ){
         # pure comment lines
         output_line('',$1);
         next;
      }elsif( $line =~ /^__DATA__/ || $line =~ /^__END__/){
         # data block
         open(SYSDATA,'>',"$source_file.data") || abend("Can't open file $source_file.data for writing. Check permissions" );
         logme('W',"Tail data after __DATA__ or __END__ line are detected in Perl Script. They are written to a separate file $source_file.data");
         while( $line=<> ){
            print SYSDATA $line;
         }
         close SYSDATA;
         return $line;
      }elsif( substr($line,0,1) eq '='){
         # POD block
         output_line('',q['''']);
         while($line=<>){
            last if($line eq '=cut');
            output_line('',$line);
         }
         output_line('',q['''']);
      }
      $IntactLine=$line;
      if( substr($line,-1,1) eq "\r" ){
         chop($line);
      }
      $line =~ s/\s+$//; # trim tailing blanks
      $line =~ s/^\s+//; # trim leading blanks
      return  $line;
   }
}

#::output_line -- Output line shifted properly to the current nesting level
# arg 1 -- actual PseudoPython generated line
# arg 2 -- tail comment (added Dec 28, 2019)
sub output_line
{
my $line=(scalar(@_)==0 ) ? $IntactLine : $_[0];
my $tailcomment=(scalar(@_)==2 ) ? $_[1] : '';
my $indent=' ' x $::TabSize x $CurNest;
my $flag=( $::TrStatus < 0 ) ? 'FAIL' : '    ';
my $len=length($line);
my $maxline=80;
my $prefix=sprintf('%4u',$.)." | $CurNest | $flag |";
my $com_zone=$maxline+length($prefix);
my $orig_tail_len=length($tailcomment);

   if ($tailcomment){
       $tailcomment=($tailcomment=~/^\s+(.*)$/ ) ? $indent.$1 : $indent.$tailcomment;
   }
   # Special case of empty line or "pure" comment that needs to be indented
   if( $len==0 ){
      if ($::TrStatus < 0) {
         out($prefix,join(' ',@::ValPy)." #FAIL $IntactLine");
         say SYSOUT join(' ',@::ValPy)." #FAIL $IntactLine";
      }else{
         out($prefix,$tailcomment);
         say SYSOUT $tailcomment;
      }
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
         if( length($IntactLine) > $maxline ){
            out($line);
            out((' ' x $com_zone),' #PL: ',substr($IntactLine,0,$maxline));
            out((' ' x $com_zone),' Cont:  ',substr($IntactLine,$maxline));
         }else{
            out($line,' #PL: ',$IntactLine);
         }
     }else{
         # short line
         out($line,(' ' x ($com_zone-$len)),' #PL: ',$IntactLine);
      }
   }else{
     #line with tail comment
     $IntactLine=substr($IntactLine,0,-$orig_tail_len);
     if ($tailcomment eq '#\\' ){
         out($line,' \ '); # continuation line
      }else{
         out($line,' ',$tailcomment); # output with tail comment instead of Perl comment
      }
      if( length($IntactLine)>90 ){
         #long line
         out((' ' x $com_zone),' #PL: ',substr($IntactLine,0,$maxline));
         out((' ' x $com_zone),' #Cont: ',substr($IntactLine,$maxline));
      }else{
         #short line
         out((' ' x $com_zone),' #PL: ',$IntactLine);
      }
   }

} # output_line

#::correct_nest -- ensure proper indenting of the lines. Accepts two arguments
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
