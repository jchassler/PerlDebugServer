use strict;
use warnings;
use Time::HiRes qw(usleep nanosleep);


for (my $i=0;1;$i++){
    print "blabla : ".$i."\n";
    print "blibli : ".$i."\n";
    usleep(100);
}


