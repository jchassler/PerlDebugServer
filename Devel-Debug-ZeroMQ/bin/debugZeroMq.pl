use strict;
use warnings;
use Devel::Debug::ZeroMQ::Agent;

my $commandToLaunch = join(' ',@ARGV);
Devel::Debug::ZeroMQ::Agent::loop($commandToLaunch);


