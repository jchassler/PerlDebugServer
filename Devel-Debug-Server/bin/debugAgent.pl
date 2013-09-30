#!/usr/bin/env perl
use strict;
use warnings;
use Devel::Debug::Server::Agent;

# PODNAME: debugAgent.pl

# ABSTRACT: The devel::Debug agent

my $commandToLaunch = join(' ',@ARGV);
Devel::Debug::Server::Agent::loop($commandToLaunch);

__END__
 
 
=head1 synopsis

	#on command-line
	
	#... first launch the debug server (only once)
	
	tom@house:debugserver.pl 
	
	server is started...
	
	#now launch your script(s) to debug 
	
	tom@house:debugagent.pl path/to/scripttodebug.pl
	
	#in case you have arguments
	
	tom@house:debugagent.pl path/to/scripttodebug.pl arg1 arg2 ...
	
	#now you can send debug commands with the devel::debug::server::client module

=head1 description

to debug a perl script, simply start the server and launch the script with debugagent.pl.

See L<Devel::Debug::Server> for more informations.
