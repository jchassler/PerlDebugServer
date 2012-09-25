use Test::More tests=> 8;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Proc::Background;
use_ok("Devel::Debug::ZeroMQ::Client");

my $debugServerCommand = "perl -I$FindBin::Bin/../lib $FindBin::Bin/../bin/debugServer.pl";
my $processCommand = "perl -I$FindBin::Bin/../lib $FindBin::Bin/../bin/debugZeroMq.pl $FindBin::Bin/bin/scriptToDebug.pl"; 

my $procServer = Proc::Background->new({'die_upon_destroy' => 1},$debugServerCommand);
my $processToDebug = Proc::Background->new({'die_upon_destroy' => 1},$processCommand);

sleep 1; #wait for processes to start

ok($procServer->alive(), "debug server is running");
ok($processToDebug->alive(), "process to debug is running");


sleep 1; #wait for processes to register to debug server

my $debugData = Devel::Debug::ZeroMQ::Client::refreshData();

my @processesIDs = keys %{$debugData->{processesInfo}};

is(scalar @processesIDs,1,"we have one process to debug");

my $processToDebugPID = $processesIDs[0];

my $processInfos = $debugData->{processesInfo}{$processToDebugPID};

is($processInfos->{fileName},"$FindBin::Bin/bin/scriptToDebug.pl",'we have the good fileName of the source file');
is($processInfos->{line},6,"we are on the good line of the script");
is($processInfos->{package},"main","debug process is in package main");
is($processInfos->{subroutine},"main","debug process is in subroutine main");



#clean up processes
undef $procServer;
undef $processToDebug;



