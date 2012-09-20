use strict;
use warnings;
package Devel::Debug::ZeroMQ;

use Devel::ebug;
use ZeroMQ qw/:all/;
use Time::HiRes qw(usleep nanosleep);
use Storable;

my $NO_COMMAND = 'no_command';
our $READY_COMMAND = 'ready_command';
our $RUN_COMMAND = 'r';
our $STEP_COMMAND = 's';
our $WAIT_COMMAND = 'WAIT_CMD';

our $DEBUG_PROCESS_TYPE = 'DEBUG_PROCESS';
our $DEBUG_GUI_TYPE = 'DEBUG_GUI';

my $ebug = undef;
my $requester = undef;
my $programName = undef;

# ABSTRACT: communication module for the program to debug

sub init{
    my($progName) = @_;
    $ebug = Devel::ebug->new;
    my $programName = $progName;
    $ebug->program($programName);
    $ebug->backend("ebug_backend_perl");
    $ebug->load;
    initZeroMQ();
}

sub initZeroMQ{
    if (!defined $requester){
        my $cxt = ZeroMQ::Context->new;
        $requester = $cxt->socket(ZeroMQ::Constants::ZMQ_REQ);
        $requester->connect("tcp://127.0.0.1:5000");
    }
}

sub sendAgentInfos {
    my($status) = @_;
    my @stackTrace = $ebug->stack_trace_human();
    my $programInfo = { 
        pid         => $ebug->proc->pid ,
        name        => $programName ,
        line        => $ebug->line,
        subroutine  => $ebug->subroutine,
        package     => $ebug->package,
        fileName    => $ebug->filename,
       finished    =>  $ebug->finished,
       stackTrace  => \@stackTrace,
       variables   => $ebug->pad,
       result      => $status->{result},
       fileContent => $status->{fileContent},
       type        => $Devel::Debug::ZeroMQ::DEBUG_PROCESS_TYPE,
    };
    return Devel::Debug::ZeroMQ::send($programInfo);
}

sub send {
    my($data) = @_;

    my $programInfoStr = Storable::freeze($data);
    $requester->send($programInfoStr);

    my $reply = $requester->recv()->data();
    return Storable::thaw($reply);    
}

sub loop {
    my($progName) = @_;
    
    init($progName);
    
    my $status = { 
        result  => undef,
    };
    
    my $fileName = undef;
    while (1){
        my $fileContent = undef;
        if (!defined $fileName || $fileName ne $ebug->filename()){
            my @fileLines = $ebug->codelines();
            $fileContent = \@fileLines;
            $status->{fileContent} = $fileContent ;
        }
        my $message = Devel::Debug::ZeroMQ::sendAgentInfos($status);
        
        my $command = $message->{command};
        my $result = undef ;

        $fileName = $message->{fileName};

        if (defined $command){
            my $commandName = $command->{command};

            my $arg1 = $command->{arg1};
            my $arg2 = $command->{arg2};
            my $arg3 = $command->{arg3};
            

            if ($commandName eq 'l') {
                $result = $ebug->codelines($command->{arg1});
            } elsif ($commandName eq 'p') {
                $result = $ebug->pad;
            } elsif ($commandName eq $STEP_COMMAND) {
                $ebug->step;
            } elsif ($commandName eq 'n') {
                $ebug->next;
            } elsif ($commandName eq $RUN_COMMAND) {
                $ebug->run;
            } elsif ($commandName eq 'restart') {
                $ebug->load;
            } elsif ($commandName eq /return/) {
                $ebug->return($arg1);
            } elsif ($commandName eq 'T') {
                $result = $ebug->stack_trace_human;
            } elsif ($commandName eq 'f') {
                $result = $ebug->filenames;
            } elsif ($commandName eq 'b') {
                $ebug->break_point($arg1, $arg2, $arg3);
            } elsif ($commandName eq 'd') {
                $ebug->break_point_delete($arg1, $arg2);
            } elsif ($commandName eq 'w') {
                $ebug->watch_point($arg1);
            } elsif ($commandName eq 'q') {
                exit;
            } elsif ($commandName eq 'x') {
                $result = $ebug->eval("use YAML; Dump($arg1)") || "";
            } elsif ($commandName eq 'e') {
                $result = $ebug->eval($arg1) || "";
            }
        }
        $status->{result} = $result;
        usleep(50);
    }
}

1;
