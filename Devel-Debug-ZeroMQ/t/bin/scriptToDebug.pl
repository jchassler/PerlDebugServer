use strict;
use warnings;
use Time::HiRes qw(usleep nanosleep);

#this dummy script is just a test program to manipulate with the debugger

sub dummySubroutine($){
    my ($value) = @_;
    return $value++;
}


my $dummyVariable = "dummy";

for (my $i=0;1;$i++){
    print $dummyVariable.$i."\n";
    my $computedValue = dummySubroutine($i);
    print "foo : ".$computedValue."\n";
    usleep(100);
}


