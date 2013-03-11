
use strict;
use warnings;
use ZeroMQ qw/:all/;
use Time::HiRes qw(usleep nanosleep);
use Storable;
use Data::Dumper;

use Storable;
use Devel::Debug::Server;
use JSON;
use File::Spec;


my $cxt = ZeroMQ::Context->new;
my $responder = $cxt->socket(ZeroMQ::Constants::ZMQ_REP);
$responder->bind("tcp://127.0.0.1:5000");

my %processesInfos = ();

#commandes to send to process to debug (undef = nothing to do)
#each command is as below
#{command   => 'COMMAND_CODE',
#  arg1     => 'first argument if needed',
#  arg2     => 'second argument if needed',
#  arg3     => 'third argument if needed'
#  }
my %commands = ();

#a hash containing source files
my %files = ();

my $breakPointVersion = 0;
my $breakPoints = {}; #all the requested breakpoints
my $effectiveBreakpoints = {}; #all the breakpoints effectively set, with their real line number

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

=head2  setRunningProcessInfo

C<setRunningProcessInfo($pid);>
update the process info when we send the 'continue' command because the process won't update its status until it id finished or it reached a breakpoint

=cut
sub setRunningProcessInfo {
    my ($pid) = @_;
    my $processInfo = $processesInfos{$pid};

    my $programInfo = { 
        pid         => $processInfo->{pid} ,
        name        => $processInfo->{name} , 
        line        => '??',
        subroutine  => '??',
        package     => '??',
        fileName    => '??',
        finished    =>  $processInfo->{finished},
        halted      =>  0,
        stackTrace  => [],
        variables   => {},
        result      => '',
        fileContent => $processInfo->{fileContent} , 
        breakPointVersion => $processInfo->{breakPointVersion},
        lastEvalCommand => '',
        lastEvalResult => '',
    };
    $processesInfos{$pid} = $programInfo;
}

=head2  getDebuggingInfos

return a hash containg all debugging info + details for $pid

=cut
sub getDebuggingInfos {
    my ($pid) = @_;
    
    my $returnedData = {sourceFileName      => undef,
                        sourceFileContent   => undef};

    $returnedData->{processesInfo} = \%processesInfos;

    $returnedData->{requestedBreakpoints} = $breakPoints ;
    $returnedData->{effectiveBreakpoints} = $effectiveBreakpoints;


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
    if (! File::Spec->file_name_is_absolute( $file )){
        $file =  File::Spec->rel2abs( $file ) ;
    }

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


sub updateEffectiveBreakpoints{
    my ($effectiveBreakpointsList) = @_;

    for my $breakpoint (@{$effectiveBreakpointsList}){
        my $file=                 $breakpoint->{file};                  
        my $requestedLineNumber =                 $breakpoint->{requestedLineNumber};
        my $effectiveLineNumber=  $breakpoint->{effectiveLineNumber};
        $effectiveBreakpoints->{$file}->{$requestedLineNumber} = $effectiveLineNumber ;
        if ($effectiveLineNumber != $requestedLineNumber){
            #we are in the case where where the requested line number wasn't on a breakable line, we correct the breakpoints info
            #only %effectiveBreakpoints keep informations about invalid breakpoints
            $effectiveBreakpoints->{$file}->{$effectiveLineNumber} = $effectiveLineNumber;
            delete $breakPoints->{$file}{$requestedLineNumber};
            $breakPoints->{$file}{$effectiveLineNumber} = 1;#condition always true for now
        }
    }
}

while (1) {
    # Wait for the next request from client
    my $message = $responder->recv();
    if (defined $message){
        my $requestStr = $message->data();
        my $request = Storable::thaw($requestStr);
        my $messageToSend = undef;

        if ($request->{type} eq $Devel::Debug::Server::DEBUG_PROCESS_TYPE){ #message from a debugged process
            my $pid = updateProcessInfo($request);
            
            my $commandInfos= $commands{$pid};
            $messageToSend = {command       =>  $commandInfos,
                              fileName      => $files{$pid}->{fileName},
                              breakPoints  => $breakPoints,
                              breakPointVersion => $breakPointVersion,
                          };
            $commands{$pid} = undef; #don't send the same command twice
            if (defined $commandInfos  && defined $commandInfos->{command}
                 && $commandInfos->{command} eq $Devel::Debug::Server::RUN_COMMAND){
               setRunningProcessInfo($pid); 
            }
        } elsif ($request->{type} eq $Devel::Debug::Server::DEBUG_GUI_TYPE){ #message from the GUI
            my $command = $request->{command};
            my $pid = $request->{pid};
            if (defined $command){
                if ($command->{command} 
                    eq $Devel::Debug::Server::SET_BREAKPOINT_COMMAND){
                    setBreakPoint($command);
                }elsif ($command->{command} 
                    eq $Devel::Debug::Server::REMOVE_BREAKPOINT_COMMAND){
                    removeBreakPoint($command);

                }elsif(!defined $commands{$pid}){
                    $commands{$pid} = $command;
                }
            }
            
            $messageToSend = getDebuggingInfos($pid);
        } elsif ($request->{type} eq $Devel::Debug::Server::DEBUG_BREAKPOINT_TYPE){ #breakpoint has been set in debugged process
            updateEffectiveBreakpoints($request->{effectiveBreakpoints});
            $messageToSend = {message =>"NOTHING TO SAY"};
        }
 


        # Send reply back to client
        $responder->send(Storable::freeze($messageToSend));
    }else{
        usleep(500);
    }

}
