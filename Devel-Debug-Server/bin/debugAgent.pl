use strict;
use warnings;
use Devel::Debug::Server::Agent;

my $commandToLaunch = join(' ',@ARGV);
Devel::Debug::Server::Agent::loop($commandToLaunch);


