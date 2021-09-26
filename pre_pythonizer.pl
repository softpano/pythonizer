#!/usr/bin/perl
#:: pre_pythonizer version 0.1
#:: Stage 1 of fuzzy translation of Perl to Python
#:: Nikolai Bezroukov, 2019-2020.
#:: Licensed under Perl Artistic license
#::
#:: This phase produced refactored Source PERL code and XREF table.
#:: XREF table is fuzzy, in a sense  that it is constructed using heuristic methods.
#:: Currently it is not used by pythonizer and just is created for reference
#::
#:: --- INVOCATION:
#::
#::   pre_pythonizer [options] [file_to_process]
#::
#::--- OPTIONS:
#::
#::    -v -- display version
#::    -h -- this help
#::    -t number -- size of tab (emulated with spaces)
#::
#::--- PARAMETERS:
#::    1st -- name of  file

#--- Development History
#
# Ver      Date        Who        Modification
# ====  ==========  ========  ==============================================================
# 0.10  2019/10/14  BEZROUN   Initial implementation
# 0.11  2019/11/20  BEZROUN   Minor changes in legend and help screen
# 0.20  2020/08/20  BEZROUN   The source reorganized into "subroutines-first" fashion
# 0.30  2020/09/01  BEZROUN   Several errors corrected. Integration with pythonizer via option -r (refator) of the latter.
# 0.40  2020/10/05  BEZROUN   Default changed to no main  sub. Option -m introduced (create_main_sub mode)
#=========================== START =========================================================
BEGIN {
    use File::Spec::Functions qw(rel2abs);
    use File::Basename qw(dirname);

    my $path   = rel2abs( $0 );
    our $myDir = dirname( $path );
    push @INC,$myDir;
}

   use v5.10;
#  use Modern::Perl;
   use warnings;
   use strict 'subs';
   use feature 'state';
   use Getopt::Std;

   $VERSION='0.4'; # alpha vestion
   $debug=1; # 0 production mode 1 - development/testing mode. 2-3 debugging modes

   #$debug=1;  # enable saving each source version without compile errors to GIT
   #$debug=2; # starting from debug=2 the results are not written to disk
   #$debug=3; # starting from Debug=3 only the first chunk processed
   $STOP_STRING=''; # In debug mode gives you an ability to switch trace on any type of error message for example S (via hook in logme).
   $use_git_repo='';

# You can switch on tracing from particular line of source ( -1 to disable)
   $breakpoint=-1;
   $CreateMainSub=0; # do not create main sub when refactring Perl source(now this is a defualt mode)

   $HOME=$ENV{'HOME'}; # the directory used for backups if debug>0
   if( $^O eq 'cygwin' ){
      # $^O is built-in Perl Variable that contains OS name
      $HOME="/cygdrive/f/_Scripts";  # CygWin development mode -- the directory used for backups
   }

   $SCRIPT_NAME='pre_pythonizer';

   $LOG_DIR='/tmp/'.ucfirst($SCRIPT_NAME);


   $tab=4;
   $nest_corrections=0;
   %keyword=('if'=>1,'while'=>1,'unless'=>1, 'until'=>1,'for'=>1,'foreach'=>1,'given'=>1,'when'=>1,'default'=>1);

   logme('D',1,2); # E and S to console, everything to the log.
   banner($LOG_DIR,$SCRIPT_NAME,'PREPYTHONIZER: Phase 1 of pythonizer',30); # Opens SYSLOG and print STDERRs banner; parameter 4 is log retention period
   get_params(); # At this point debug  flag can be reset
    if( $debug>0 ){
      logme('D',2,2); # Max verbosity
      print STDERR "ATTENTION!!! $SCRIPT_NAME is working in debugging mode $debug with autocommit of source to $HOME/Archive\n";
      autocommit("$HOME/Archive",$use_git_repo); # commit source archive directory (which can be controlled by GIT)
   }
   say "Log is written to $LOG_DIR, The original file will be saved as $fname.original unless this file already exists ";
   say STDERR  "=" x 80,"\n";
   if ($CreateMainSub) {
      @FormattedMain=("sub main\n","{\n");
   }else{
      @FormattedMain=();
   }
   @FormattedSource=@FormattedSub=@FormattedData=();
   $mainlineno=scalar( @FormattedMain); # we need to reserve one line for sub main
   $sourcelineno=$sublineno=$datalineno=0;

#
# Main loop initialization variables
#
   $new_nest=$cur_nest=0;
   #$top=0; $stack[$top]='';
   $lineno=$noformat=$SubsNo=0;
   $here_delim="\n"; # impossible combination
   $InfoTags='';
   @SourceText=<STDIN>;

#
# Slurp the initial comment block and use statements
#
   $ChannelNo=$lineno=0;
   while(1){
      if( $lineno == $breakpoint ){
         $DB::single = 1
      }
      chomp($line=$SourceText[$lineno]);
      if( $line=~/^\s*$/ ){
         process_line("\n",-1000);
         $lineno++;
         next;
      }
      $intact_line=$line;
      if( substr($intact_line,0,1) eq '#' ){
          process_line($line,-1000);
          $lineno++;
          next;
      }
      $line=normalize_line($line);
      chomp($line);
      ($line)=split(' ',$line,1);
      if($line=~/^use\s+/){
         process_line($line,-1000);
      }else{
         last;
      }
      $lineno++;
   } #while
#
# MAIN LOOP
#
   $ChannelNo=1;
   for( ; $lineno<@SourceText; $lineno++  ){
      $line=$SourceText[$lineno];
      $offset=0;
      chomp($line);
      $intact_line=$line;
      if( $lineno == $breakpoint ){
         $DB::single = 1
      }
      $line=normalize_line($line);
      #
      # Check for HERE line
      #

      if($noformat){
         if( $line eq $here_delim ){
            $noformat=0;
            $InfoTags='';
         }
         process_line($line,-1000);
         next;
      }

      if( $line =~/<<['"](\w+)['"]$/ ){
         $here_delim=$1;
         $noformat=1;
         $InfoTags='HERE';
      }
      #
      # check for comment lines
      #
      if( substr($line,0,1) eq '#' ){
         if( $line eq '#%OFF' ){
            $noformat=1;
            $here_delim='#%ON';
            $InfoTags='OFF';
         }elsif( $line =~ /^#%ON/ ){
            $noformat=0;
         }elsif( substr($line,0,6) eq '#%NEST') {
            if( $line =~ /^#%NEST=(\d+)/) {
               if( $cur_nest != $1 ) {
                  $cur_nest=$new_nest=$1; # correct current nesting level
                  $InfoTags="=$cur_nest";
               }else{
                  $InfoTags="OK $cur_nest";
               }
            }elsif( $line =~ /^#%NEST++/) {
               $cur_nest=$new_nest=$1+1; # correct current nesting level
               $InfoTags='+1';
            }elsif( $line =~ /^#%NEST--/) {
               $cur_nest=$new_nest=$1+1; # correct current nesting level
               $InfoTags='-1';
            }elsif( $line =~ /^#%ZERO\?/) {
               if( $cur_nest == 0 ) {
                  $InfoTags="OK $cur_nest";
               }else{
                  $InfoTags="??";
                  logme('E',"Nest is $cur_nest instead of zero. Reset to zero");
                  $cur_nest=$new_nest=0;
                  $nest_corrections++;
               }
            }
         }
         process_line($line,-1000);
         next;
      }
      if( $line =~ /^sub\s+(\w+)/ ){
         $SubList{$1}=$lineno;
         $SubsNo++;
         $ChannelNo=2; # write to subroutine block
         $CommentBlock=0;
         #
         # Here is have problem with comment block on level zero -- it belongs to the sub that will follow
         #
         for( $backno=$#FormattedMain;$backno>0;$backno-- ){
            unless( defined($FormattedMain[$backno]) ){
               logme('E',"Line $backno in FormattedMain is undefined");
               $DB::single = 1;
               next;
            }
            $comment=$FormattedMain[$backno];
            if ($comment =~ /^\s*#/ || $comment =~ /^\s*$/){
               $CommentBlock++;
            }else{
               last;
            }
         }
         $backno++;
         for (; $backno<@FormattedMain; $backno++){
            $comment=$FormattedMain[$backno];
            process_line($comment,-1000); #copy comment block from @FormattedMain were it got by mistake
         }
         for ($backno=0; $backno<$CommentBlock; $backno++){
            pop(@FormattedMain); # then got to it by mistake
         }
         if( $cur_nest != 0 ) {
            logme('E',"Non zero nesting encounted for subroutine definition $1");
            if ($cur_nest>0) {
               $InfoTags='} ?';
            }else{
               $InfoTags='{ ?';
            }
            $nest_corrections++;
         }
         $cur_nest=$new_nest=0;
      }elsif( $line eq '__END__' || $line eq '__DATA__' ) {
         $ChannelNo=3;
         logme('E',"Non zero nesting encounted for $line");
         if ($cur_nest>0) {
            $InfoTags='} ?';
         }else{
            $InfoTags='{ ?';
         }
         $noformat=1;
         $here_delim='"'; # No valid here delimiter in this case !
         $InfoTags='DATA';
      }
      if( substr($line,0,1) eq '=' && $line ne '=cut' ){
         $noformat=1;
         $InfoTags='POD';
         $here_delim='=cut'
      }

      # blank lines should not be processed
      if( $line =~/^\s*$/ ){
         process_line('',-1000);
         next;
      }
      # trim leading blanks
      if( $line=~/^\s*(\S.*$)/){
         $line=$1;
      }
      # comments on the level of nesting 0 should be shifted according to nesting
      if( substr($line,0,1) eq '#' ){
         process_line($line,0);
         next;
      }

      # comments on the level of nesting 0 should start with the first position
      $first_sym=substr($line,0,1);
      $last_sym=substr($line,-1,1);
      if( $first_sym eq '{' && length($line)==1 ){
         process_line('{',0);
         $cur_nest=$new_nest+=1;
         next;
      } elsif( $first_sym eq '}' ){
         $cur_nest=$new_nest-=1;
          process_line('}',0); # shift "{" left, aligning with the keyword
         if( substr($line,0,1) eq '}' ){
            $line=substr($line,1);
         }
         while( substr($line,0,1) eq ' ' ){
            $line=substr($line,1);
         }
         # Case of }else{
         unless( $last_sym eq '{') {
             process_line($line,0);
             next;
         }
         if( $cur_nest==0 ){
            $ChannelNo=1; # write to main
         }
      }
      # Step 2: check the last symbol for "{" Note: comments are prohibited on such lines
      if( $last_sym eq '{' && length($line)>1 ){
         process_line(substr($line,0,-1),0);
         process_line('{',0);
         $cur_nest=$new_nest+=1;
         next;
      }# if
      #elsif( $last_sym eq '}' && length($line)==1  ){
      # NOTE: only standalone } on the line affects effective nesting; line that has other symbols is assumed to be like if (...) { )
      # $new_nest-- is not nessary as as it is also the first symbol and nesting was already corrected
      #}
      process_line($line,$offset);
   } # while
#
# Epilog
#
   write_formatted_code(); # write to the database.
   exit 0;

#
# Subroutines
#
sub normalize_line
{
my $line=$_[0];
   $line=~tr/\t/ /; # eliminate \t
      if( substr($line,-1,1) eq "\r" ){
         chop($line);
      }
      # strip trailing blanks, if any
      if( $line=~/(^.*\S)\s+$/ ){
         $line=$1;
      }
   return($line);
}
sub process_line
{
my $line=$_[0];
my $offset=$_[1];

      #if( length($line)>1 && substr($line,0,1) ne '#' ){
      #   $line=perl_optimizer($line);
      #}
      $prefix=sprintf('%4u %3d %4s',$lineno, $cur_nest, $InfoTags);
      if( ($cur_nest+$offset)<0 || $cur_nest<0 ){
         $spaces='';
      }else{
         $offset=( $ChannelNo==1 )? 1 : 0;
         $spaces= ' ' x (($cur_nest+$offset)*$tab);
      }
      $line="$spaces$line\n";
      print STDERR "$prefix | $line";
      if( $ChannelNo==0) {
         $FormattedSource[$sourcelineno++]=$line;
      }elsif($ChannelNo==1){
         unless( defined($line) ){
               logme('E',"Line $lineno is undefined");
               $DB::single = 1;
         }
         $FormattedMain[$mainlineno++]=$line;
      }elsif($ChannelNo==2){
         $FormattedSub[$sublineno++]=$line;
      }elsif($ChannelNo==3){
         $FormattedData[$datalineno++]=$line;
      }else{
         logme('S',"Internal error. Channel is outside rance or 0-2. The value is $ChannelNo. Exiting... ");
         exit 255;
      }
      $cur_nest=$new_nest;
      if( $noformat==0 ){ $InfoTags='' }
}
sub write_formatted_code
{
my $output_file=$fname;
my ($line,$i,$k,$var, %dict, %type, @xref_table);

   unless( -f "$fname.original" ){
      `cp $fname  $fname.original`;
   }
   push(@FormattedSource,@FormattedSub);
   push(@FormattedSource,@FormattedMain);
   if ($CreateMainSub){
      push(@FormattedSource,"}\nmain();\n");# close main and generate call to main
   }
   push(@FormattedSource,@FormattedData);
   open (SYSFORM,'>',$output_file ) || abend(__LINE__,"Cannot open file $output_file for writing");
   print SYSFORM @FormattedSource;
   close SYSFORM;
   print `perl -cw  $output_file`;
   if(  $? > 0 ){
      logme('E',"Checking reformatted source code via perl -cw produced some errors (RC=$?). Please correct them before proceeding");
   }
   $output_file="$LOG_DIR/fname.xref";
   open (SYSFORM,'>',$output_file ) || abend(__LINE__,"Cannot open file $output_file for writing");

   for( $i=0; $i<@SourceText; $i++ ){
      $line=$SourceText[$i];
      next if (substr($line,0,1) eq '#' || $line=~/(\s+)\#/ );
      chomp($line);
      while( ($k=index($line,'$'))>-1 ){
         $line=substr($line,$k+1);
         next unless( $line=~/^(\w+)/ );
         next if( $1 eq '_' || $1 =~/[1-9]/ );
         $k+=length($1)+1;
         $var='$'.$1;
         if($line=~/^\w+\s*[<>=+-]\s*[+-]?\d+/ ){
            unless(exists($type{$var})) {$type{$var}='int';}
         }elsif( $line=~/^\w+\s*=\s*\$\#\w+/ ){
            unless( exists($type{$var}) ) {$type{$var}='int';}
         }elsif( $line=~/^\w+\s*[+-=<>!]?=\s*(index|length|scalar)/ ){
            unless( exists($type{$var}) ) {$type{$var}='int';}
          }elsif( $line=~/^\w+\s*[+-=<>!]?=\s*[+-]?\d+/ ){
            unless( exists($type{$var}) ) {$type{$var}='int';}
         }elsif( $line=~/^\w+\s*\[.+?\]?\s*(\$\w+)/ && exists($type{$1}) && $type{$1} eq 'int' ) {
            unless( exists($type{$var}) ) {$type{$var}='int';};
         }elsif( $line=~/^\w+\s*\[.+?\]?\s*[+-=<>!]=\s*\d+/ ){
            #Array
            unless( exists($type{$var}) ) {$type{$var}='int';}
         }elsif( $line=~/^\w+\s*\{.+?\}\s*[+-=<>!]?=\s*\d+/ ){
            #Hash
            unless( exists($type{$var}) ) {$type{$var}='int';}
         }

         if( exists($dict{$var}) ){
            $dict{$var}.=', '.$i;
         }else{
           $dict{$var}.=$i;
         }

     }
   }
   write_line("\n\nCROSS REFERENCE TABLE\n");
   $i=0;
   foreach $var (keys(%dict)) {
      $prefix=( exists($type{$var}) ) ? $type{$var} : 'str';
      $xref_table[$i]="$prefix $var $dict{$var}\n";
      $i++;
   }
   @xref_table=sort(@xref_table);

   open (SYSFORM,'>',$output_file ) || abend(__LINE__,"Cannot open file $output_file for writing");
   for( $i=0; $i<@xref_table; $i++ ){
      write_line($xref_table[$i]);
   }
   write_line("\nSUBROUTINES\n");
   foreach $sub (keys(%SubList)){
     write_line("$sub: $SubList{$sub}");
   }
   close SYSFORM;
}
sub write_line
{
my $myline=$_[0];
  say STDERR $myline;
  say SYSFORM $myline;
}
#
# Try to normalise perl text whenever possible
#
sub perl_optimizer
{
my $line=$_[0];

   if( $line=~/^\s*print\b(.+)\\[n]"$/ ){
      $line=qw(say$1";);
   }
   return $line;

}
#
# process parameters and options
#
sub get_params
{
      getopts("hv:b:d:f:t:m",\%options);
      if(  exists $options{'v'} ){
         if( $options{'v'} =~/\d/ && $options{'v'}<3  ){
            logme('D',$options{'v'},);
         }else{
            logme('D',3,3); # add warnings
         }
      }
      if(  exists $options{'h'} ){
         helpme();
      }


      if(  exists $options{'f'}  ){
         $write_FormattedSource=1;
      }
      if(  exists $options{'m'}  ){
         $CreateMainSub=1;
      }

      if(  exists $options{'t'}  ){
         if( $options{'t'}>0  && $options{'t'}<10 ){
            $tab=$options{'t'};
         } else {
            die("Wrong value of option -t (tab size): $options('t')\n");
         }
      }

      if(  exists $options{'b'}  ){
         if( $options{'b'}>0  && $options{'t'}<1000 ){
            $breakpoint=$options{'b'};
         } else {
            die("Wrong value of option -b (line for debugger breakpoint): $options('b')\n");
         }
      }

      if(  exists $options{'d'}  ){
         if( $debug =~/\d/ ){
            $debug=$options{'d'};
         }elsif( $options{'d'} eq '' ){
            $debug=1;
         }else{
            die("Wrong value of option -d: $options('d')\n");
         }
      }

      if( scalar(@ARGV)==0 ){
         open (STDIN, ">-");
         $write_FormattedSource=0;
         return;
      }

      if( scalar(@ARGV)==1 ){
         $fname=$ARGV[0];
         unless( -f $fname ){
            die ("File $ARGV[0] does not exists");
         }
         open (STDIN, "<$fname");
      } else {
         $args=join(' ', @ARGV);
         die ("Too many arguments: $args")
      }

}
#
###================================================= NAMESPACE sp: My SP toolkit subroutines
#
#
# Create backup and commit script to GIT repository if there were changes from previous version.
#
#package sp;
sub autocommit
{
# parameters
my $archive_dir=$_[0]; # typically home or $HOME/bin
my $git_repo=$_[1]; # GIT dir
my $script_name=substr($0,rindex($0,'/')+1);

#
#  commit each running version to the repository to central GIT
#

my $script_timestamp;
my $script_delta=1;
my $host=`hostname -s`;
      chomp($host);
      ( ! -d $archive_dir ) && `mkdir -p $archive_dir`;
      if(  -f "$archive_dir/$script_name"  ){
         if( (-s $0 ) == (-s "$archive_dir/$script_name")   ){
            `diff $0 $archive_dir/$script_name`;
            $script_delta=( $? == 0 )? 0: 1;
         }

         if( $script_delta ){
            chomp($script_timestamp=`date -r $archive_dir/$script_name +"%y%m%d_%H%M"`);
            `mv $archive_dir/$script_name $archive_dir/$script_name.$script_timestamp`;

         }
      }
      ($script_delta) && `cp -p $0 $archive_dir/$script_name`;
      ($git_repo) && `cd $archive_dir && git commit $0`;
} # commit_source

# Read script and extract help from comments starting with #::
#
sub helpme
{
      open(SYSHELP,"<$0");
      while($line=<SYSHELP> ){
         if(  substr($line,0,3) eq "#::" ){
            print STDERR substr($line,3);
         }
      } # for
      close SYSHELP;
      exit;
}

#
# Terminate program (variant without mailing)
#
sub abend
{
my $message;
my ($package, $filename, $lineno) = caller;
      if( scalar(@_)==0 ){
         $message=$MessagePrefix.$lineno."T  ABEND at $lineno. No message was provided. Exiting.";
      }else{
         $message=$MessagePrefix.$lineno."T $_[0]. Exiting ";
      }
#  Syslog might not be available
      out($message);
      #[EMAIL] banner('ABEND');
      die('Internal error');

} # abend

#
# Open log and output the banner; if additional arguments given treat them as subtitles
#        depends of two variable from main namespace: VERSION and debug
sub banner {
#
# Sanity check
#
state $logfile;
      if( scalar(@_)<4 && $_[0] eq 'ABEND' ){
         close SYSLOG;
         #`cat $logfile | mail -s "[ABEND for $HOSTNAME/$SCRIPT_NAME] $_[0] $PrimaryAdmin`;
         return;
      }
#
# Decode obligatory arguments
#
state $my_log_dir=$_[0];
my $script_name=$_[1];
my $title=$_[2]; # this is an optional argumnet which is print STDERRed as subtitle after the title.
my $log_retention_period=$_[3];

my ($script_mod_stamp,$day);
      chomp($script_mod_stamp=`date -r $0 +"%y%m%d_%H%M"`);
      if( -d $my_log_dir ){
         chomp($day=`date '+%d'`);
         if( 1 == $day && $log_retention_period>0 ){
            #Note: in debugging script home dir is your home dir and the last thing you want is to clean it ;-)
            `find $my_log_dir -name "*.log" -type f -mtime +$log_retention_period -delete`; # monthly cleanup
         }
      }else{
         `mkdir -p $my_log_dir`;
      }
my $logstamp=`date +"%y%m%d_%H%M"`; chomp $logstamp;
      $logfile="$my_log_dir/$script_name.$logstamp.log";
my $timestamp=`date "+%y/%m/%d %H:%M"`; chomp $timestamp;
      open(SYSLOG, ">$logfile") || abend(__LINE__,"Fatal error: unable to open $logfile");
      $title="\n\n".uc($script_name).": $title (last modified $script_mod_stamp) Running at $timestamp\nLogs are at $logfile. Type -h for help.\n";
      out($title); # output the banner
      for( my $i=4; $i<@_; $i++) {
         out($_[$i]); # optional subtitles
      }
      out ("================================================================================\n\n");
} #banner

#
# Message generator: Record message in log and STDIN
# PARAMETERS:
#            lineno, severity, message
# ARG1 lineno, If it is negative skip this number of lines
# Arg2 Error code (the first letter is severity, the second letter can be used -- T is timestamp -- put timestamp inthe message)
# Arg3 Text of the message
# NOTE: $top_severity, $verbosity1, $verbosity1 are state variables that are initialized via special call to sp:: sp::logmes

sub logme
{
#our $top_severity; -- should be defined globally
my $error_code=substr($_[0],0,1);
my $error_suffix=(length($_[0])>1) ? substr($_[0],1,1):''; # suffix T means add timestamp
my $message=$_[1];
      chomp($message); # we will add \n ourselves

state $verbosity1; # $verbosity console
state $verbosity2; # $verbosity for log
state $msg_cutlevel1; # variable 6-$verbosity1
state $msg_cutlevel2; # variable 5-$verbosity2
state @ermessage_db; # accumulates messages for each caterory (warning, errors and severe errors)
state @ercounter;
state $delim='=' x 80;
state $MessagePrefix='';

#
# special cases -- ercode "D" means set msglevel1 and msglevel2, ' ' means print STDERR in log and console -- essentially out with messsage header
#

      if( $error_code eq 'D' ){
         # NOTE You can dynamically change verbosity within the script by issue D message.
         # Set script name and message  prefix
         if ( $MessagePrefix eq '') {
            $MessagePrefix=substr($0,rindex($0,'/')+1);
            $MessagePrefix=substr( $MessagePrefix,0,4);
         }
         $verbosity1=$_[1];
         $verbosity2=$_[2];

         $msg_cutlevel1=length("WEST")-$verbosity1-1; # verbosity 3 is max and means 4-3-1 =0  -- the index corresponding to code 'W'
         $msg_cutlevel2=length("WEST")-$verbosity2-1; # same for log only (like in MSGLEVEL mainframes ;-)

         return;
      }
      unless ( $error_code ){
         # Blank error code is old equivalent of out: put obligatory message on console and into log
         out($message);
         return;
      }
#
# detect caller lineno.
#
      my ($package, $filename, $lineno) = caller;
#
# Generate diagnostic message from error code, line number and message (optionally timestamp is suffix of error code is T)
#
      $message="$MessagePrefix\-$lineno$error_code: $message";
      my $severity=index("west",lc($error_code));
      if( $severity == -1 ){
         out($message);
         return;
      }

      $ercounter[$severity]++; #Increase messages counter  for given severity (supressed messages are counted too)
      $ermessage_db[$severity] .= "\n\n$message"; #Error history for the ercodes E and S
      return if(  $severity<$msg_cutlevel1 && $severity<$msg_cutlevel2 ); # no need to process if this is lower then both msglevels
#
# Stop processing if severity is less then current msglevel1 and msglevel2
#
      if( $severity < 3 ){
         if( $severity >= $msg_cutlevel2 ){
            # $msg_cutlevel2 defines writing to SYSLOG. 3 means Errors (Severe and terminal messages always whould be print STDERRed)
            if( $severity<4 ){
               print SYSLOG "$message\n";
            } else {
               # special treatment of serious messages
               print SYSLOG "$delim\n$message\n$delim\n";
            }
         }
         if( $severity >= $msg_cutlevel1 ){
            # $msg_cutlevel1 defines writing to STDIN. 3 means Errors (Severe and terminal messages always whould be print STDERRed)
            if( $severity<2 ){
               print STDERR "$message\n";
            } else {
               print STDERR "$delim\n$message\n$delim\n";
            }
         }
         if (length($::STOP_STRING)>0 && index($::STOP_STRING,$error_code) >-1 ){
            $DB::single = 1;
         }
         return;
      } # $severity<3

my $summary='';
      #
      # We will put the most severe errors at the end and make 15 sec pause before  read them
      #
      out("\n$message");
      for( my $counter=1; $counter<length('WES'); $counter++ ){
         if( defined($ercounter[$counter]) ){
            $summary.=" ".substr('WES',$counter,1).": ".$ercounter[$counter];
         }else{
            $ercounter[$counter]=0;
         }
      } # for
      ($summary) && out("\n=== SUMMARY OF ERRORS: $summary\n");
      if( $ercounter[1] + $ercounter[2] ){
         # print STDERR errors & severe errors
         for(  $severity=1;  $severity<3; $severity++ ){
            # $ermessage_db[$severity]
            if( $ercounter[$severity] > 0 ){
               out("$ermessage_db[$severity]\n\n");
            }
         }
         ($ercounter[2]>0) && out("\n*** PLEASE CHECK $ercounter[2] SERIOUS MESSAGES ABOVE");
      }
#
# Compute RC code: 10 or higher there are serious messages
#
      my $rc=0;
      if( $ercounter[2]>0 ){
         $rc=($ercounter[2]<9) ? 10*$ercounter[2] : 90;
      }
      if( $ercounter[1]>0 ){
         $rc=($ercounter[1]<9) ? $ercounter[2] : 9;
      }
      exit $rc;
} # logme


sub out
#
# Output message to both log and STDERR
#
{
      if( scalar(@_)==0 ){
         say STDERR;
         say SYSLOG;
         return;
      }
      say STDERR $_[0];
      say SYSLOG $_[0];
}

sub step
{
      $DB::single = 1;
}
