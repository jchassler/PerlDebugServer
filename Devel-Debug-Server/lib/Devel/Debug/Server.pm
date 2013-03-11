use strict;
use warnings;
package Devel::Debug::Server;

use ZeroMQ qw/:all/;
use Time::HiRes qw(usleep nanosleep);
use Storable;

my $NO_COMMAND = 'no_command';
our $READY_COMMAND = 'ready_command';
our $RUN_COMMAND = 'r';
our $STEP_COMMAND = 's';
our $WAIT_COMMAND = 'WAIT_CMD';
our $SET_BREAKPOINT_COMMAND = 'b';
our $REMOVE_BREAKPOINT_COMMAND = 'remove_command';
our $RETURN_COMMAND = 'return';
our $EVAL_COMMAND = 'e';

our $DEBUG_PROCESS_TYPE = 'DEBUG_PROCESS';
our $DEBUG_GUI_TYPE = 'DEBUG_GUI';
our $DEBUG_BREAKPOINT_TYPE = 'DEBUG_BREAKPOINT_GUI';

my $requester = undef;

# ABSTRACT: communication module for debuging processes


sub initZeroMQ{
    if (!defined $requester){
        my $cxt = ZeroMQ::Context->new;
        $requester = $cxt->socket(ZeroMQ::Constants::ZMQ_REQ);
        $requester->connect("tcp://127.0.0.1:5000");
    }
}


sub send {
    my($data) = @_;

    my $programInfoStr = Storable::freeze($data);
    $requester->send($programInfoStr);

    my $reply = $requester->recv()->data();
    return Storable::thaw($reply);    
}


1;
