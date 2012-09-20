use strict;
use warnings;
package Devel::Debug::ZeroMQ;

use Devel::ebug;
use ZeroMQ qw/:all/;
use Time::HiRes qw(usleep nanosleep);
use Storable;

my $NO_COMMAND = 'no_command';

my $ebug = undef;
my $requester = undef;
my $programName = undef;

# ABSTRACT: turns baubles into trinkets

sub init{
    my($progName) = @_;
    $ebug = Devel::ebug->new;
    my $programName = $progName;
    $ebug->program($programName);
    $ebug->backend("ebug_backend_perl");
    $ebug->load;
    my $cxt = ZeroMQ::Context->new;
    my $requester = $cxt->socket(ZeroMQ::Constants::ZMQ_REQ);
    $requester->connect("tcp://127.0.0.1:5000");
}

sub send {
    my($dataToSend) = @_;
    my $programInfo = { 
        pid         => $ebug->proc->pid ,
        name        => $programName ,
        line        => $ebug->line,
        subroutine  => $ebug->subroutine,
        package     => $ebug->package,
        filename    => $ebug->filename,
        finished   =>  $ebug->finished,
    };
    $programInfo->{data} = $dataToSend ;
    my $programInfoStr = Storable::freeze($programInfo);
    $requester->send($programInfoStr);

    my $reply = $requester->recv();
    return Storable::thaw($reply);    
}

sub loop {
    my($progName) = @_;
    
    init($progName);
    
    my $command = { command => $NO_COMMAND,
        arg1    => undef,
        arg2    => undef,
        arg3    => undef,
        result  => undef,
    };

    while (1){
        $command = Devel::Debug::ZeroMQ::send($command);

        my $commandName = $command->{command};
        my $arg1 = $command->{arg1};
        my $arg2 = $command->{arg2};
        my $arg3 = $command->{arg3};
        my $result = undef ;

        if ($commandName eq 'l') {
           $result = $ebug->codelines($command->{arg1});
        } elsif ($commandName eq 'p') {
            $result = $ebug->pad_human;
        } elsif ($commandName eq 's') {
            $ebug->step;
        } elsif ($commandName eq 'n') {
            $ebug->next;
        } elsif ($commandName eq 'r') {
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
            $result = $ebug->eval("use YAML; Dump($1)") || "";
        } elsif ($commandName eq 'e') {
            $result = $ebug->eval($1) || "";
        }
        $command->{result} = $result;
        
        Time::Hires::usleep(50);
    }
}

1;
