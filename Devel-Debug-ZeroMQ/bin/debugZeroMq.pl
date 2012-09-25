use strict;
use warnings;
use Devel::Debug::ZeroMQ;

my $commandToLaunch = join(' ',@ARGV);
Devel::Debug::ZeroMQ::loop($commandToLaunch);


