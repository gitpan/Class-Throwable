#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

# check bad inline names

eval "use Class::Throwable '+';";
like($@, 
    qr/An error occured while constructing Class\:\:Throwable exception \(\+\)/, 
    '... got the exception we expected');
    
# these should all get ignored
    
use_ok('Class::Throwable', 0, "", undef);    



