
use strict;
use warnings;
use ZeroMQ qw/:all/;
use Time::HiRes qw(usleep nanosleep);
use Storable;
use Data::Dumper;

use Storable;
use Devel::Debug::ZeroMQ;
use JSON;


my $cxt = ZeroMQ::Context->new;
my $responder = $cxt->socket(ZeroMQ::Constants::ZMQ_REP);
$responder->bind("tcp://127.0.0.1:5000");

my %processesInfos = ();
#commandes to send to process to debug (undef = nothing to do)
my %commands = ();

#a hash containing source files
my %files = ();

my $breakPointVersion = 0;
my $breakPoints = {};

=head2  updateProcessInfo

    Update informations of the process into the process table

     my $programInfo = { 
        pid          
        name         
        line         
        subroutine   
        package      
        filename     
        finished    
        stackTrace   
        variables    
        result       

    };
=cut
sub updateProcessInfo {
    my ($infos) = @_;

    my $pid = $infos->{pid};
    $processesInfos{$pid} = $infos;

    #initialize other hashes if necessary
    if (!exists $commands{$pid}){
        $commands{$pid} = undef;
    }
    if (!exists $files{$pid}){
        $files{$pid} = {fileName => undef,
                        content => ''
                        };
    }
    my $file = $files{$pid};
    if (!defined $file->{fileName} || $file->{fileName} ne $infos->{fileName}){
        $file->{content} = $infos->{fileContent};
        $file->{fileName} = $infos->{fileName};
    }
    return $pid;
}

=head2  getDebuggingInfos

return a hash containg all debugging info + details for $pid

=cut
sub getDebuggingInfos {
    my ($pid) = @_;
    
    my $returnedData = {sourceFileName      => undef,
                        sourceFileContent   => undef};

    $returnedData->{processesInfo} = \%processesInfos;

    if (defined $pid && exists $files{$pid}){
        my $file = $files{$pid};

        $returnedData->{sourceFileName } = $file->{fileName};
        $returnedData->{sourceFileContent} = $file->{fileContent};
    }

    return $returnedData;
}

sub setBreakPoint{
    my ($command)=@_;
    my $file = $command->{arg1};
    my $lineNumber = $command->{arg2}; 

    $breakPointVersion ++;
    $breakPoints->{$file}{$lineNumber} = 1;#condition always true for now
}

sub removeBreakPoint{
    my ($command)=@_;
    my $file = $command->{arg1};
    my $lineNumber = $command->{arg2}; 

    $breakPointVersion ++;
    if (exists $breakPoints->{$file} && exists $breakPoints->{$file}{$lineNumber}){
        delete $breakPoints->{$file}{$lineNumber};
    }
}

while (1) {
    # Wait for the next request from client
    my $message = $responder->recv();
    if (defined $message){
        my $requestStr = $message->data();
        my $request = Storable::thaw($requestStr);
        my $messageToSend = undef;

        if ($request->{type} eq $Devel::Debug::ZeroMQ::DEBUG_PROCESS_TYPE){ #message from a debugged process
            my $pid = updateProcessInfo($request);

            $messageToSend = {command       => $commands{$pid},
                              fileName      => $files{$pid}->{fileName},
                              breakPoints  => $breakPoints,
                              breakPointVersion => $breakPointVersion,
                          };
            $commands{$pid} = undef; #don't send the same command twice
        } elsif ($request->{type} eq $Devel::Debug::ZeroMQ::DEBUG_GUI_TYPE){ #message from the GUI
            my $command = $request->{command};
            my $pid = $request->{pid};
            if (defined $command){
                if ($command->{command} 
                    eq $Devel::Debug::ZeroMQ::SET_BREAKPOINT_COMMAND){
                    setBreakPoint($command);
                }elsif ($command->{command} 
                    eq $Devel::Debug::ZeroMQ::REMOVE_BREAKPOINT_COMMAND){
                    removeBreakPoint($command);

                }elsif(!defined $commands{$pid}){
                    $commands{$pid} = $command;
                }
            }
            
            $messageToSend = getDebuggingInfos($pid);
        }



        # Send reply back to client
        $responder->send(Storable::freeze($messageToSend));
    }else{
        usleep(500);
    }

}
