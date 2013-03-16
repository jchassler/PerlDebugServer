use strict;
use warnings;
package Devel::Debug::Server::Agent;

use Devel::Debug::Server;
use Devel::ebug;

use Time::HiRes qw(usleep nanosleep);
use File::Spec;

my $ebug = undef;
my $programName = undef;
my $breakPointsVersion = -1; #the version of the breakpoints
my $lastEvalCommand = '';
my $lastEvalResult = '';

#keep the breakpoint list up-to-date with the debug server
sub updateBreakPoints {
    my ($breakPointsServerVersion,$breakPointsList) = @_;

    if ($breakPointsServerVersion == $breakPointsVersion){
        return; #first check if there were no modification since last time
    }

    $breakPointsVersion = $breakPointsServerVersion;
    my @breakPoints = $ebug->all_break_points_with_condition();
    foreach my $breakPoint (@breakPoints) {

        #suppress all useless breakpoints
        my $file = $breakPoint->{filename};
        if (! File::Spec->file_name_is_absolute( $file )){
            $file = File::Spec->rel2abs( $file ) ;
        }
        my $line = $breakPoint->{line}; 
        my $condition = $breakPoint->{condition}; 
        if (!(exists $breakPointsList->{$file} 
            && exists $breakPointsList->{$file}{$line})){
            $ebug->break_point_delete($file,$line);
        }
    }

    my $effectiveBreakpointList = [];

    #add all remaining breakpoints
    foreach my $file (keys %$breakPointsList) {
        foreach my $line (keys %{$breakPointsList->{$file}}) {
            my $effectiveLineNumber = $ebug->break_point($file,$line);
            if (defined $effectiveLineNumber){
                push (@{$effectiveBreakpointList} ,
                    {   file => $file, 
                        requestedLineNumber => $line, 
                        effectiveLineNumber => $effectiveLineNumber});
            }
        }
    }
    if (scalar @{$effectiveBreakpointList} >0){
        #we notify the server for each breakpoint effectly set, so the real line numbers are stored in the server
        sendBreakPointsInfo($effectiveBreakpointList);
    }
    return;
}

sub init{
    my($progName) = @_;
    $ebug = Devel::ebug->new;
    my $programName = $progName;
    $ebug->program($programName);
    $ebug->backend("ebug_backend_perl");
    $ebug->load;
    Devel::Debug::Server::initZeroMQ();
}

=head2  loop

Start the inifinite loop to communicate with the debug server

=cut
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
        my $message = Devel::Debug::Server::Agent::sendAgentInfos($status);
        
        my $command = $message->{command};
        my $result = undef ;

        $fileName = $message->{fileName};

        updateBreakPoints($message->{breakPointVersion}, $message->{breakPoints});

        if (defined $command){
            my $commandName = $command->{command};

            my $arg1 = $command->{arg1};
            my $arg2 = $command->{arg2};
            my $arg3 = $command->{arg3};
            

            if ($commandName eq $Devel::Debug::Server::STEP_COMMAND) {
                clearEvalResult();
                $ebug->step;
            } elsif ($commandName eq 'n') {
                clearEvalResult();
                $ebug->next;
            } elsif ($commandName eq $Devel::Debug::Server::RUN_COMMAND) {
                clearEvalResult();
                $ebug->run;
            } elsif ($commandName eq 'restart') {
                $ebug->load;
            } elsif ($commandName eq $Devel::Debug::Server::RETURN_COMMAND) {
                $ebug->return($arg1);
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
                $lastEvalCommand = $arg1;
                $lastEvalResult = $ebug->eval("use YAML; Dump($arg1)") || "";
            } elsif ($commandName eq $Devel::Debug::Server::EVAL_COMMAND) {
                $lastEvalCommand = $arg1;
                $lastEvalResult = $ebug->eval($arg1) ;
            }
        }
        $status->{result} = $result;
        usleep(1000); #wait 1 ms
    }
}

=head2  clearEvalResult

clear the last 'eval' command result (usefull when the program continues)

=cut
sub clearEvalResult {
    $lastEvalCommand = '';
    $lastEvalResult  = '';
}

sub sendBreakPointsInfo {
    my($effectiveBreakPoints) = @_;
    my $breakpointsInfo = { 
       type        => $Devel::Debug::Server::DEBUG_BREAKPOINT_TYPE,
       effectiveBreakpoints => $effectiveBreakPoints
    };
    return Devel::Debug::Server::send($breakpointsInfo);
}

sub sendAgentInfos {
    my($status) = @_;
    my @stackTrace = $ebug->stack_trace_human();
    my $variables = $ebug->pad();
    $variables = {} unless defined $variables;
    my $programInfo = { 
        pid         => $ebug->proc->pid ,
        name        => $programName ,
        line        => $ebug->line,
        subroutine  => $ebug->subroutine,
        package     => $ebug->package,
        fileName    => $ebug->filename,
       finished    =>  $ebug->finished,
       halted       => 1,  #program wait debugging commands
       stackTrace  => \@stackTrace,
       variables   => $variables ,
       result      => $status->{result},
       fileContent => $status->{fileContent},
       type        => $Devel::Debug::Server::DEBUG_PROCESS_TYPE,
       breakPointVersion => $breakPointsVersion,
       lastEvalCommand => $lastEvalCommand,
       lastEvalResult => $lastEvalResult,
    };
    return Devel::Debug::Server::send($programInfo);
}

1;