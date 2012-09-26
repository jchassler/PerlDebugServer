use Test::More tests=> 9;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Proc::Background;
use Time::HiRes qw(usleep nanosleep);
use_ok("Devel::Debug::ZeroMQ::Client");

my $debugServerCommand = "perl -I$FindBin::Bin/../lib $FindBin::Bin/../bin/debugServer.pl";
my $processCommand = "perl -I$FindBin::Bin/../lib $FindBin::Bin/../bin/debugZeroMq.pl $FindBin::Bin/bin/scriptToDebug.pl"; 

my $procServer = Proc::Background->new({'die_upon_destroy' => 1},$debugServerCommand);
my $processToDebug = Proc::Background->new({'die_upon_destroy' => 1},$processCommand);
my $processToDebug2 = Proc::Background->new({'die_upon_destroy' => 1},$processCommand);
my $processToDebug3 = Proc::Background->new({'die_upon_destroy' => 1},$processCommand);

sleep 1; #wait for processes to start

ok($procServer->alive(), "debug server is running");
ok($processToDebug->alive(), "process to debug is running");


sleep 1; #wait for processes to register to debug server

my $debugData = Devel::Debug::ZeroMQ::Client::refreshData();

my @processesIDs = keys %{$debugData->{processesInfo}};

is(scalar @processesIDs,3,"we have 3 processes to debug");

my $processToDebugPID = $processesIDs[0];

my $processInfos = $debugData->{processesInfo}{$processToDebugPID};

is($processInfos->{fileName},"$FindBin::Bin/bin/scriptToDebug.pl",'we have the good fileName of the source file');
is($processInfos->{line},13,"we are on the good line of the script");
is($processInfos->{package},"main","debug process is in package main");
is($processInfos->{subroutine},"main","debug process is in subroutine main");

#now time to do one step
$debugData = Devel::Debug::ZeroMQ::Client::sendCommand($processToDebugPID,
            {
            command => $Devel::Debug::ZeroMQ::STEP_COMMAND,
    });

sleep(1);#wait for debug command to be executed

$debugData = Devel::Debug::ZeroMQ::Client::refreshData();
$processInfos = $debugData->{processesInfo}{$processToDebugPID};
is($processInfos->{line},15,"we made a step");

#clean up processes
undef $procServer;
undef $processToDebug;


1; #script completed !
