package Softpano;
#:: Simplified implementation of a subset of "defensive programming" toolkit stemming from my experiense as a complier writer.
#:: ABSTRACT:  Murphy principle states  "Anything that can go wrong will go wrong" but you better be imformed if something happens ;-)
#:: Includes logging subroutine(logme), autocommit, banner, abend, out and helpme
#:: Copyright Nikolai Bezroukov, 2019.
#:: Licensed under Perl Artistic license
# Ver      Date        Who        Modification
# =====  ==========  ========  ==============================================================
# 01.00  2010/10/09  BEZROUN   Initial implementation
# 01.10  2010/10/10  BEZROUN   autocommit now allow to save multiple modules in addtion to the main program
# 01.20  2010/11/19  BEZROUN   mylib parameter added -- location of modules (ususally during debugging this is '.'== the current workiong directory)

use v5.10;
   use warnings;
   use strict 'subs';
   use feature 'state';

require Exporter;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
@ISA = qw(Exporter);
@EXPORT = qw(autocommit helpme abend banner logme out);
$VERSION = '1.10';
#
# NOTE: autocommit used only in debugging mode
# In debug mode it created backup and commit script to GIT repository, if there were changes from previous Version.
#
sub autocommit
{
# parameters
my $archive_dir=shift; # typically home or $HOME/bin
my $mylib=shift; # typically home or $HOME/bin
my @project=@_;
my ($script_timestamp,$fqn);
#
#  commit each running Version to the repository to central GIT
#
  ( ! -d $archive_dir ) && `mkdir -p $archive_dir`;
  $script_name=substr($0,rindex($0,'/')+1);
  _compare_and_save($archive_dir,$0,$script_name);
  foreach my $script_name (@project) {
     $fqn=$mylib.'/'.$script_name;
     _compare_and_save($archive_dir,$fqn,$script_name);
  }
} # autocommit
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
          # `git commit $0`;
      }
}
#
#:: helpme -- Read script and extract help from comments starting with #::
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
#:: abend Terminate program (variant without mailing)
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
#:: banner -- Open log and output the banner; if additional arguments given treat them as subtitles
#::           Depends of two Variable from the main namespace: VERSION and debug
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
#:: logme -- Simple message generator: Record message in log and STDERR
# PARAMETERS:
#            lineno, severity, message
# Arg1 Error code (the first letter is severity, the second letter can be used -- T is timestamp -- put timestamp inthe message)
# Arg3 Text of the message
# NOTE: $top_severity, $Verbosity1, $Verbosity1 are state Variables that are initialized via special call to sp:: sp::logmes

sub logme
{
#our $top_severity; -- should be defined globally
my $error_code=substr($_[0],0,1);
my $error_suffix=(length($_[0])>1) ? substr($_[0],1,1):''; # suffix T means add timestamp
my $message=$_[1];
      chomp($message); # we will add \n ourselves
state ($msg_cutlevel1, $msg_cutlevel2, @ermessage_db, @ercounter); # remeber they are statically scoped

#
# special cases -- ercode "D" means set msglevel1 and msglevel2, ' ' means print STDERR in log and console -- essentially out with messsage header
#

      if( $error_code eq 'D' ){
         # NOTE You can dynamically change Verbosity within the script by issue D message.
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
      my $severity=index("west",lc($error_code));
      if( $severity == -1 ){
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
#:: Output message to both log and STDERR
#
sub out
{
      if( scalar(@_)==0 ){
         say STDERR;
         say SYSLOG;
         return;
      }
      say STDERR $_[0];
      say SYSLOG $_[0];
}
#
#:: Invokes the debugger with the message
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
1;
