#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 29;

BEGIN { 
    use_ok('Class::Throwable');
}

can_ok("Class::Throwable", 'throw');

# test without a message

eval { throw Class::Throwable };
isa_ok($@, 'Class::Throwable');

can_ok($@, 'getMessage');
is($@->getMessage(), 
  'An Class::Throwable Exception has been thrown', 
  '... the error is as we expected');

can_ok($@, 'toString');
is($@->toString(), 
  'An Class::Throwable Exception has been thrown', 
  '... the error is as we expected');

# test with a message 

eval { Class::Throwable->throw("Test Message") };
isa_ok($@, 'Class::Throwable');

is($@->getMessage(), 
  'Test Message',
  '... the error is as we expected');

is($@->toString(), 
  'Test Message', 
  '... the error is as we expected');
  
# test the stack trace now

can_ok($@, 'getStackTrace');
is_deeply(scalar $@->getStackTrace(),
        # these are the values in the stack trace:
        # $package, $filename, $line, $subroutine, 
        # $hasargs, $wantarray, $evaltext, $is_require
        [[ 'main', 't/10_Class_Throwable_test.t', '31', '(eval)', 0, undef, undef, undef ]],
        '... got the stack trace we expected');
        
is_deeply($@->getStackTrace(),
        # same thing in array context :)
        [ 'main', 't/10_Class_Throwable_test.t', '31', '(eval)', 0, undef, undef, undef ],
        '... got the stack trace we expected');   
        
can_ok($@, 'stackTraceToString');
is($@->stackTraceToString(),
   q{  >> stack frame (1)
     ----------------
     package: main
     subroutine: (eval)
     filename: t/10_Class_Throwable_test.t
     line number: 31},
   '... got the stack trace string we expected');    
   
ok(overload::Overloaded($@), '... stringified overload');

Class::Throwable->import(VERBOSE => 0);

is("$@", '', '... got the stringified result we expected');  

Class::Throwable->import(VERBOSE => 1);

is("$@", 'Test Message', '... got the stringified result we expected');  

Class::Throwable->import(VERBOSE => 2);

is("$@",
   q{Test Message
  >> stack frame (1)
     ----------------
     package: main
     subroutine: (eval)
     filename: t/10_Class_Throwable_test.t
     line number: 31
},
   '... got the stringified result we expected');    
   
my $e = $@;
eval { throw $e };
isa_ok($@, 'Class::Throwable');

is($@->stringValue(), $e->stringValue(), '... it is the same object, just re-thrown');

# some misc. weird stuff

eval {
    throw Class::Throwable [ 1 .. 5 ];
};
isa_ok($@, 'Class::Throwable');

is_deeply($@->getMessage(),
          [ 1 .. 5 ],
          '... you can use anything for a message');
                                                    
my $exception = Class::Throwable->new("A message for you");
isa_ok($exception, 'Class::Throwable');

is($exception->getMessage(), 'A message for you', '... got the message we expected');
is_deeply(scalar $exception->getStackTrace(), [], '... we dont have a stack trace yet');

eval {
	throw $exception;
};
isa_ok($@, 'Class::Throwable');
is($@, $exception, '... it is the same exception too');

is_deeply($@->getStackTrace(),
		  [ 'main', 't/10_Class_Throwable_test.t', '113', '(eval)', 0, undef, undef, undef ],
          '... got the stack trace we expected');  

														          
  