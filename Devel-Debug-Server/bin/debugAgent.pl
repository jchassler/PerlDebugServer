#!/usr/bin/env perl
use strict;
use warnings;
use Devel::Debug::Server::Agent;
# PODNAME: debugAgent.pl

# ABSTRACT: The devel::Debug agent

my $commandToLaunch = join(' ',@ARGV);
Devel::Debug::Server::Agent::loop($commandToLaunch);

__END__
 
# PODNAME: debugAgent.pl

# ABSTRACT: The devel::Debug agent
 
=head1 SYNOPSIS

#on command-line

#... first launch the debug server

tom@house:debugServer.pl 

server is started...

#now launch your script to debug

tom@house:debugAgent.pl path/to/scriptToDebug.pl

#in case you have arguments

tom@house:debugAgent.pl path/to/scriptToDebug.pl arg1 arg2 ...


=head1 DESCRIPTION

To debug a perl script, simply start the server and launch the script with debugAgent.pl.

