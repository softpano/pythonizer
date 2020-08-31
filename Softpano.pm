package Softpano;
## Simplified implementation of a subset of "defensive programming" toolkit stemming from my experience as a compiler writer.
## ABSTRACT:  Murphy principle states  "Anything that can go wrong will go wrong" but you better be informed if something happens ;-)
## Includes logging subroutine(logme), autocommit, banner, abend, out and helpme
## Copyright Nikolai Bezroukov, 2019-2020.
## Licensed under Perl Artistic license
# Ver      Date        Who        Modification
# =====  ==========  ========  ==============================================================
# 01.00  2019/10/09  BEZROUN   Initial implementation
# 01.10  2019/10/10  BEZROUN   autocommit now allow to save multiple modules in addition to the main program
# 01.20  2019/11/19  BEZROUN   mylib parameter added -- location of modules (usually during debugging this is '.'== the current working directory)
# 01.21  2020/08/04  BEZROUN   autocommit will works only if $::debug > 0
# 01.22  2020/08/05  BEZROUN   out now works with multiple arguments
# 01.30  2020/08/10  BEZROUN   tag "##" is not used as the comment prefix for help. Minor chages and corrections
# 01.40  2020/08/17  BEZROUN   getops is now implemented in Softpano.pm to allow the repetition of option letter to set the value of options ( -ddd)
use v5.10;
   use warnings;
   use strict 'subs';
   use feature 'state';

require Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
@ISA = qw(Exporter);
@EXPORT = qw(autocommit abend banner logme out getopts standard_options);
$VERSION = '1.10';
#
# NOTE: autocommit used only in debugging mode
# In debug mode it created backup and commit script to GIT repository, if there were changes from previous Version.
#
##autocommit - save script if it runs for subsequnt push into GIT or other versioning system
sub autocommit
{
# parameters
my $archive_dir=shift; # typically home or $HOME/bin
my $mylib=shift; # typically home or $HOME/bin
my @project=@_; # list of files in the project (maintained in the main script)
# local vars
my ($script_timestamp,$fqn);
#
#  commit each running Version to the repository to central GIT
#
  return if ($::debug==0);
  ( ! -d $archive_dir ) && `mkdir -p $archive_dir`;
  $script_name=substr($0,rindex($0,'/')+1);
  _compare_and_save($archive_dir,$0,$script_name);
  foreach my $script_name (@project) {
     $fqn=$mylib.'/'.$script_name;
     _compare_and_save($archive_dir,$fqn,$script_name);
  }
} # autocommit

##_compare_and_save -- save the script (internal sub called from autocommit)
sub _compare_and_save
{
my ($archive_dir,$fqn,$script_name)=@_;
my $script_delta=1;
  if(  -f "$archive_dir/$script_name"  ){
         if( (-s $fqn ) == (-s "$archive_dir/$script_name")   ){
            `diff $fqn $archive_dir/$script_name`;
            $script_delta=( $? == 0 )? 0: 1;
         }
         if( $script_delta ){
            chomp($script_timestamp=`date -r $archive_dir/$script_name +"%y%m%d_%H%M"`);
            `mv $archive_dir/$script_name $archive_dir/$script_name.$script_timestamp`;

         }
      }
      if( $script_delta ){
         `cp -p $fqn $archive_dir/$script_name`;
          # `cd $archive_dir && git commit $script_name`; # actual commit
      }
} #_compare_and_save

#
##helpme -- Read script and extract help from comments starting with ##
#
sub helpme
{
      open(SYSHELP,'<',$0);
      while($line=<SYSHELP> ){
         if(  substr($line,0,2) eq "##" ){
            print STDERR substr($line,2);
         }
      } # for
      close SYSHELP;
      exit;
}

#
## abend Terminate program (variant without mailing)
#
sub abend
{
my $message;
my ($package, $filename, $lineno) = caller;
      if( scalar(@_)==0 ){
         $message="$::SCRIPT_NAME-$lineno"."T  ABEND at $lineno. No message was provided. Exiting.";
      }else{
         $message="$::SCRIPT_NAME-$lineno"."T $_[0]. Exiting ";
      }
#  Syslog might not be availble
      out($message);
      #:banner('ABEND');
      die('Internal error');

} # abend

#
## banner -- Open log and output the banner; if additional arguments given treat them as subtitles
##           Depends of two Variable from the main namespace: VERSION and debug
sub banner {
#
# Sanity check
#
state $logfile;
#
# If called from ABEND close SYSLOG and, optionally, mail the log file to the primary sysadmin
#
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

my $timestamp=`date "+%y/%m/%d %H:%M"`; chomp $timestamp;
my $day=`date '+%d'`; chomp $day;
my $logstamp=`date +"%y%m%d_%H%M"`; chomp $logstamp;
my $script_mod_stamp;
      chomp($script_mod_stamp=`date -r $0 +"%y%m%d_%H%M"`);
      if( -d $my_log_dir ){
         if( 1 == $day && $log_retention_period>0 ){
            #Note: in debugging script home dir is your home dir and the last thing you want is to clean it ;-)
            `find $my_log_dir -name "*.log" -type f -mtime +$log_retention_period -delete`; # monthly cleanup
         }
      }else{
         `mkdir -p $my_log_dir`;
      }

      $logfile="$my_log_dir/$script_name.$logstamp.log";
      open(SYSLOG, ">$logfile") || abend(__LINE__,"Fatal error: unable to open $logfile");
      $title="\n\n".uc($script_name).": $title (last modified $script_mod_stamp) Running at $timestamp\nLogs are at $logfile. Type -h for help.\n";
      out($title); # output the banner
      for( my $i=4; $i<@_; $i++) {
         out($_[$i]); # optional subtitles
      }
      out ("================================================================================\n\n");
} #banner

#
## logme -- Simple message generator: Record message in log and STDERR
# PARAMETERS:
#            lineno, severity, message
# Arg1 Error code (the first letter is severity, the second letter can be used -- T is timestamp -- put timestamp inthe message)
# Arg3 Text of the message
# NOTE: $top_severity, $Verbosity1, $Verbosity1 are state Variables that are initialized via special call to sp:: sp::logmes

sub logme
{
#our $top_severity; -- should be defined globally
my $error_code=uc(substr($_[0],0,1));
my $error_suffix=(length($_[0])>1) ? substr($_[0],1,1):''; # suffix T means add timestamp
my $message=$_[1];
      chomp($message); # we will add \n ourselves
state ($msg_cutlevel1, $msg_cutlevel2, @ermessage_db, @ercounter); # remember they are statically scoped

#
# special cases -- ercode "D" means set msglevel1 and msglevel2, ' ' means print STDERR in log and console -- essentially out with messsage header
#

      if( $error_code eq 'D' ){
         # NOTE You can dynamically change Verbosity within the script by issuing D message.
         # Set script name and message  prefix
         if ($_[1]>0) {
            $msg_cutlevel1=length("WEST")-$_[1]-1; # Verbosity 3 is max and means 4-3-1 =0 is index correcponfing to  ('W')
            $msg_cutlevel2=length("WEST")-$_[2]-1; # same for log only (like in MSGLEVEL mainframes ;-)
            return;
         }else{
            my $summary='ERROR STATISTICS: ';
            out("\n$message");
            for( my $counter=1; $counter<length('WEST'); $counter++ ){
               if( defined($ercounter[$counter]) ){
                  $summary.=" ".substr('WEST',$counter,1).": ".$ercounter[$counter];
               }else{
                  $ercounter[$counter]=0;
               }
            } # for
            ($summary) && out("\n$summary\n");
            if( $ercounter[1] + $ercounter[2] ){
               # print STDERR errors & severe errors
               for(  $severity=1;  $severity<=3; $severity++ ){
                   ( $ercounter[$severity] > 0 ) && out("$ermessage_db[$severity]\n\n");
               }
               ($ercounter[2]>0) && out("\n*** PLEASE CHECK $ercounter[2] SERIOUS MESSAGES ABOVE");
                return $ercounter[1] + $ercounter[2];
            }
            return 0;
         }
      }
      unless( $error_code ){
         # Blank error code is old equivalent of out: put obligatory message on console and into log
         out($message);
         return;
      }
#
# detect callere.
#
      my ($package, $filename, $lineno) = caller;
#
# Generate diagnostic message from error code, line number and message (optionally timestamp is suffix of error code is T)
#
      $message=" $filename [$lineno$error_code]: $message";
      my $severity=index("WEST",uc($error_code));
      if( $severity == -1 ){
         # all unknown codes.
         out($message);
         return;
      }
      $ercounter[$severity]++; #Increase messages counter  for given severity (supressed messages are counted too)
      $ermessage_db[$severity] .= "\n\n$message"; #Error history for the ercodes E and S
      ($severity >= $msg_cutlevel1 ) && print STDERR "$message\n";
      ($severity >= $msg_cutlevel2 ) && print SYSLOG "$message\n";
      return;
} # logme

#
## Output message to both log and STDERR
#
sub out
{
      if( scalar(@_)==0 ){
         say STDERR;
         say SYSLOG;
      }else{
         say STDERR @_;
         say SYSLOG @_;
      }
}
#
## Invokes the debugger with the message
#
sub stepin
{
   if (scalar(@_)) {
      logme('S',$_[0]);
   }else{
      logme('S',"Attempt to activate interactive debugger stepping (works only if Perl is running with -d option) ");
   }
   return unless($::debug);
   $DB::single = 1;
}
sub getopts
{
my ($options_def,$options_hash)=@_;
my ($first,$rest,$pos,$cur_opt);
   while(@ARGV){
      $cur_opt=$ARGV[0];
      last if( substr($cur_opt,0,1) ne '-' );
      if ($cur_opt eq '--'){
          shift @ARGV;
          last;
      }
      $first=substr($cur_opt,1,1);
      $pos = index($options_def,$first);
      if( $pos==-1) {
         warn("Undefined option -$first skipped without processing\n");
         shift(@ARGV);
         next;
      }
      $rest=substr($cur_opt,2);
      if( $pos<length($options_def)-1 && substr($options_def,$pos+1,1) eq ':' ){
         # option with parameters
         if( $rest eq ''){
           shift(@ARGV); # get the value of option
           unless( @ARGV ){
              warn("End of line reached for option -$first which requires argument\n");
              $$options_hash{$first}='';
              last;
           }
           if ( $ARGV[0] =~/^-/ ) {
               warn("Option -$first requires argument\n");
               $$options_hash{$first} = '';
           }else{
               $$options_hash{$first}=$ARGV[0];
               shift(@ARGV); # get next chunk
           }
         } else {
            #value is concatenated with option like -ddd
            if( ($first x length($rest)) eq $rest ){
               $$options_hash{$first} = length($rest)+1;
            }else{
               $$options_hash{$first}=$rest;
            }
            shift(@ARGV);
         }
      }else {
         $$options_hash{$first} = 1; # set the option
         if ($rest eq '') {
            shift(@ARGV);
         } else {
            $ARGV[0] = "-$rest"; # there can be other options without arguments after the first
         }
      }
   }
}
sub standard_options
{
my $options_hash=$_[0];
   if(  exists $$options_hash{'h'} ){
      helpme();
   }
   if(  exists $$options_hash{'d'}  ){
      $$options_hash{'d'}=1 if $$options_hash{'d'} eq '';
      if( $$options_hash{'d'} =~/^\d$/ ){
         $::debug=$$options_hash{'d'};
      }else{
         logme('S',"Wrong value of option -d. If can be iether set of d letters like -ddd or an integer like -d 3 . You supplied the value  $$options_hash{'d'}\n");
         exit 255;
      }
      ($::debug) && logme('W',"Debug flag is set to $::debug ::PyV");
   }
   if(  exists $$options_hash{'v'} ){
      $$options_hash{'v'}=1 if $$options_hash{'v'} eq '';
      if( $$options_hash{'v'} =~/\d/ && $$options_hash{'v'}<3 && $$options_hash{'v'}>0 ){
         $::verbosity=$$options_hash{'v'};
      }else{
          logme('S',"Wrong value of option -v. Should be an interger from 1 to 3. The value given was: $$options_hash('v')\n");
          exit 255;
      }
   }
}
1;
