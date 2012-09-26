use strict;
use warnings;
package Devel::Debug::ZeroMQ::Client;

use Devel::Debug::ZeroMQ;

#Abstract the client module pour the GUI or CLI client

=head2  refreshData

return all data necessary to display screen

=cut
sub refreshData {

    my $req = { type => $Devel::Debug::ZeroMQ::DEBUG_GUI_TYPE
    };
    return sendCommand($req); #we just send a void command
}

=head2  sendCommand

send a command to the debug server to process whose pid is $pid. 
Returns the debug informations of the server.
The command is of the form:
    
            {
            command => $commandCode,
            arg1 => $firstArg, #if needed
            arg2 => $secondArg,#if needed
            arg3 => $thirdArg,#if needed
            };


=cut
sub sendCommand {
    my($pid,$command)= @_;
    
    Devel::Debug::ZeroMQ::initZeroMQ();

    my $req = { type => $Devel::Debug::ZeroMQ::DEBUG_GUI_TYPE,
                command => $command,
                pid=> $pid,
    };
    my $answer = Devel::Debug::ZeroMQ::send($req);

    return $answer;
   
}

1;
