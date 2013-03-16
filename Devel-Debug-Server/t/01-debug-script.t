use Test::More tests=> 31;

use strict;
use warnings;
no warnings 'once';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Proc::Background;
use Time::HiRes qw(usleep nanosleep);
use_ok("Devel::Debug::Server::Client");

#with option "-debugAgentProcess" another command window will open for the process to debug
my $cmdArg = $ARGV[0] || '';
my $cmdArgValue = $ARGV[1] ||undef;

my $processToDebugPID = undef;
my $processToDebugOption = 0;
if ( $cmdArg eq '-debugAgentProcess'){
    $processToDebugOption = 1;
}

my $debugServerCommand = "perl -I$FindBin::Bin/../lib $FindBin::Bin/../bin/debugServer.pl";
my $scriptPath = "$FindBin::Bin/bin/scriptToDebug.pl";
my $processCommand = "perl -I$FindBin::Bin/../lib $FindBin::Bin/../bin/debugZeroMq.pl $FindBin::Bin/bin/scriptToDebug.pl"; 
my $debugProcessCommand = $processToDebugOption ? "perl -d -I$FindBin::Bin/../lib $FindBin::Bin/../bin/debugZeroMq.pl $FindBin::Bin/bin/scriptToDebug.pl" : $processCommand; 


my $procServer = Proc::Background->new({'die_upon_destroy' => 1},$debugServerCommand);
my $processToDebug = Proc::Background->new({'die_upon_destroy' => 1},$debugProcessCommand);
my $processToDebug2 = undef;
my $processToDebug3 = undef;
if (!$processToDebugOption){
    $processToDebug2 = Proc::Background->new({'die_upon_destroy' => 1},$processCommand);
    $processToDebug3 = Proc::Background->new({'die_upon_destroy' => 1},$processCommand);
}

sleep 1; #wait for processes to start

ok($procServer->alive(), "debug server is running");
ok($processToDebug->alive(), "process to debug is running");


sleep 1; #wait for processes to register to debug server

my $debugData = Devel::Debug::Server::Client::refreshData();

my @processesIDs = keys %{$debugData->{processesInfo}};

if (!$processToDebugOption){
    is(scalar @processesIDs,3,"we have 3 processes to debug");
}

$processToDebugPID = $processesIDs[0];

my $processInfos = $debugData->{processesInfo}{$processToDebugPID};

is($processInfos->{fileName},"$FindBin::Bin/bin/scriptToDebug.pl",'we have the good fileName of the source file');
is($processInfos->{line},13,"we are on the good line of the script");
is($processInfos->{package},"main","debug process is in package main");
is($processInfos->{subroutine},"main","debug process is in subroutine main");
my $variables = $processInfos->{variables};
is(scalar %$variables,0, 'we have no variable defined at this line of the script');

#now time to do one step
$debugData = Devel::Debug::Server::Client::step($processToDebugPID);

#wait for debug command to be executed
$debugData = waitMilliSecondAndRefreshData(200);

$processInfos = $debugData->{processesInfo}{$processToDebugPID};
is($processInfos->{line},15,"we made a step in 200 ms");

$variables = $processInfos->{variables};
is($variables->{'$dummyVariable'},'dummy', 'we have one variable named $dummyVariable="dummy".');

#now set a breakpoint
$debugData = Devel::Debug::Server::Client::breakPoint($scriptPath,9);
$debugData = Devel::Debug::Server::Client::breakPoint($scriptPath,11); #invalid breakPoint

$debugData = waitMilliSecondAndRefreshData(100);

#check if we get the real line of the breapoints once they are set
my $requestedBreakpoints = $debugData->{requestedBreakpoints};
my $effectiveBreakpoints = $debugData->{effectiveBreakpoints};

is($effectiveBreakpoints->{$scriptPath}{9},9,"first breakpoint is effectively on the requested line (number9).");
is($effectiveBreakpoints->{$scriptPath}{11},13,"second breakpoint was set on line 13 instead of line 11 because is the the first that can be executed.");
is($effectiveBreakpoints->{$scriptPath}{13},13,"The breakpoint automatically set on line 13 is well registered.");
is($requestedBreakpoints->{$scriptPath}{13},1,"The breakpoint automatically set on line 13 is well registered on requested breakpoints.");


#launch again the process and wait for breakPoint to be reach
$debugData = Devel::Debug::Server::Client::run($processToDebugPID);

$debugData = waitMilliSecondAndRefreshData(100);

$processInfos = $debugData->{processesInfo}{$processToDebugPID};
is_deeply($processInfos->{stackTrace},['dummySubroutine(0)'],"we have the correct stackTrace");
$processInfos = $debugData->{processesInfo}{$processToDebugPID};
is($processInfos->{line},9,"We are on the good line of subroutine.");

my $processToDebugPID2 = $processesIDs[1];
#the breakpoint must be set on all processes
$debugData = Devel::Debug::Server::Client::run($processToDebugPID2);

$debugData = waitMilliSecondAndRefreshData(100);

$processInfos = $debugData->{processesInfo}{$processToDebugPID2};
is($processInfos->{line},9,"We are on the good line of subroutine in the second script ; breakpoints are set on all scripts.");


#return from current subroutine
$debugData = Devel::Debug::Server::Client::return($processToDebugPID);

$debugData = waitMilliSecondAndRefreshData(100);

$processInfos = $debugData->{processesInfo}{$processToDebugPID};
is($processInfos->{line},20,"We returned from subroutine.");
is($processInfos->{variables}->{'$infiniteLoop'},1,'$infinite is now 1');

#modify value of $infiniteLoop to alter script execution
$debugData = Devel::Debug::Server::Client::eval($processToDebugPID,'$infiniteLoop = 0');

$debugData = waitMilliSecondAndRefreshData(200);

$processInfos = $debugData->{processesInfo}{$processToDebugPID};
is($processInfos->{variables}->{'$infiniteLoop'},0,'$infinite is now 0');

is($processInfos->{finished},0, 'the script is not finished');
is($processInfos->{lastEvalCommand},'$infiniteLoop = 0', "the last eval command is '\$infiniteLoop = 0'");
is($processInfos->{lastEvalResult},'0', "the last eval result is '0'");


#modify value of $infiniteLoop to alter script execution
$debugData = Devel::Debug::Server::Client::run($processToDebugPID);

$debugData = waitMilliSecondAndRefreshData(300);

$processInfos = $debugData->{processesInfo}{$processToDebugPID};

is($processInfos->{finished},1, 'the script is finished because we changed the $infiniteLoop value.');
is($processInfos->{lastEvalCommand},'', "the last eval command is ''; it was cleaned when we sent the 'continue' command.");
is($processInfos->{lastEvalResult},'', "the last eval result was cleaned when we sent the 'continue' command.");

#now test if we can remove a breakpoint
$debugData = Devel::Debug::Server::Client::removeBreakPoint($scriptPath,9);
$debugData = Devel::Debug::Server::Client::breakPoint($scriptPath,20);

my $processToDebugPID3 = $processesIDs[2];
#the breakpoint must be set on all processes
$debugData = Devel::Debug::Server::Client::run($processToDebugPID3);

$debugData = waitMilliSecondAndRefreshData(100);

$processInfos = $debugData->{processesInfo}{$processToDebugPID3};
is($processInfos->{line},20, "Manage to remove a breakpoint, we halted on next breakpoint.");
is($processInfos->{halted},1, "process is halted.");

#launch again the process 
$debugData = Devel::Debug::Server::Client::removeBreakPoint($scriptPath,20);
$debugData = Devel::Debug::Server::Client::run($processToDebugPID3);

$debugData = waitMilliSecondAndRefreshData(100);

$processInfos = $debugData->{processesInfo}{$processToDebugPID3};
is($processInfos->{halted},0, "process is running.");
is($processInfos->{line},'??', "For a running process line number is '??'.");

#clean up processes
undef $procServer;
undef $processToDebug;

sub waitMilliSecondAndRefreshData{
    my ($timeToWaitMilliSec) = @_;

    usleep($timeToWaitMilliSec * 1000); #wait for breakPoint to be reach

    return Devel::Debug::Server::Client::refreshData();
}

1; #script completed !