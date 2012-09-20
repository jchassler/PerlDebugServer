use strict;
use warnings;
package Devel::Debug::ZeroMQ::Client;

use Devel::Debug::ZeroMQ;

#Abstract the client module pour the GUI or CLI client

=head2  refreshData

return all data necessary to display screen

=cut
sub refreshData {
    my($command)= @_;
    
    Devel::Debug::ZeroMQ::initZeroMQ();

    my $req = { type => $Devel::Debug::ZeroMQ::DEBUG_GUI_TYPE
    };
    my $answer = Devel::Debug::ZeroMQ::send($req);

}


1;
