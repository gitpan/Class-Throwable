
package Class::Throwable;

use strict;
use warnings;

our $VERSION = '0.03';

our $VERBOSE = 1;

# allow the creation of exceptions 
# without having to actually create 
# a package for them
sub import {
    shift;
    return unless @_;
    my @exceptions = @_;
    foreach my $exception (@exceptions) {
        next unless $exception;
        eval "package ${exception}; \@${exception}::ISA = qw(Class::Throwable);";  
        die "An error occured while constructing Class::Throwable exception ($exception) : $@" if $@;      
    }
}

# overload the stringify operation
use overload q|""| => "toString", fallback => 1;

# create an exception without 
# any stack trace information
sub new {
	my ($class, $message, $sub_exception) = @_;
	my $exception = {};
	bless($exception, ref($class) || $class);
	$exception->_init($message, $sub_exception);
	return $exception;		
}

# throw an exception with this
sub throw { 
	my ($class, $message, $sub_exception) = @_;
	# if i am being re-thrown, then just die with the class
	if (ref($class) && UNIVERSAL::isa($class, "Class::Throwable")) {
		# first make sure we have a stack trace, if we 
		# don't then we were likely created with 'new'
		# and not 'throw', and so we need to gather the
		# stack information from here 
		$class->_initStackTrace() unless my @s = $class->getStackTrace();
		die $class;
	}
	# otherwise i am being thrown for the first time so 
	# create a new 'me' and then die after i am blessed
	my $exception = {};
	bless($exception, $class);
	$exception->_init($message, $sub_exception);
	# init our stack trace
	$exception->_initStackTrace();	
	die $exception;
}

## initializers

sub _init {
	my ($self, $message, $sub_exception) = @_;
    # the sub-exception is another exception
    # which has already been caught, and is
    # the cause of this exception being thrown
    # so we dont want to loose that information
    # so we store it here
    # NOTE: 
    # we do not enforce the type of exception here
    # becuase it is possible this was thrown by
    # perl itself and therefore could be a string
    $self->{sub_exception} = $sub_exception; 
	$self->{message} = $message || "An ". ref($self) . " Exception has been thrown";
	$self->{stack_trace} = [];
}

sub _initStackTrace {
	my ($self) = @_;
	my @stack_trace;
    # these are the 10 values returned from caller():
    # 	$package, $filename, $line, $subroutine, $hasargs,
    # 	$wantarray, $evaltext, $is_require, $hints, $bitmask    
    # we do not bother to capture the last two as they are
    # subject to change and not meant for internal use
    {
        package DB;
        my $i = 1;            
        my @c;
        while (@c = caller($i++)) {
            # dont bother to get our caller
            next if $c[3] =~ /Class\:\:Throwable\:\:throw/;
            push @stack_trace, [ @c[0 .. 7] ];		
        }
    }
	$self->{stack_trace} = \@stack_trace;
}

# accessors

sub hasSubException {
    my ($self) = @_;
    return defined $self->{sub_exception} ? 1 : 0;
}

sub getSubException {
    my ($self) = @_;
    return $self->{sub_exception};
}

sub getMessage {
	my ($self) = @_;
	return $self->{"message"};
}

sub getStackTrace {
    my ($self) = @_;
    return wantarray ?
                @{$self->{stack_trace}}
                :
                $self->{stack_trace};
}

sub stackTraceToString {
	my ($self) = @_;
	my @output;
	my $i = 0;
	foreach my $frame (@{$self->{stack_trace}}) {
		my ($package, $filename, $line, $subroutine) = @{$frame};	
		$i++;
		push @output, join "\n" => (
						"  >> stack frame ($i)", 
                        "     ----------------",
                        "     package: $package", 
                        "     subroutine: $subroutine",
                        "     filename: $filename",
                        "     line number: $line"                            
                        );
	}
	return (join "\n" => @output);
}

sub toString {
	my ($self, $verbosity) = @_;
    $verbosity = $VERBOSE unless defined $verbosity;
    # get out of here quick if 
    # exception handling is off
    return "" if $verbosity <= 0;
    # otherwise construct our output
    my $output = $self->{"message"};
    # if we VERBOSE is set to 1, then 
    # we just return the message
    return $output if $verbosity <= 1;
    # however, if VERBOSE is 2 or above
    # then we include the stack trace
	$output .= "\n" . (join "\n" => $self->stackTraceToString()) . "\n";
    # now we gather any sub-exceptions too 
    if ($self->hasSubException()) {
        my $e = $self->getSubException();
        # make sure the sub-exception is one
        # of our objects, and ....
        if (ref($e) && UNIVERSAL::isa($e, "Class::Throwable")) {
            # deal with it appropriately
            $output .= $e->toString($verbosity);
        }
        # otherwise ...
        else {
            # just stringify it
            $output .= $e;
        }
    }
    return $output;
}

sub stringValue {
    my ($self) = @_;
    return overload::StrVal($self);
}

1;

__END__

=head1 NAME

Class::Throwable - A minimal lightweight exception class

=head1 SYNOPSIS

  use Class::Throwable;     
  
  # simple usage
  eval {
      # code code code,
      if ($something_goes_wrong) {
          throw Class::Throwable "Something has gone wrong";
      }
  };
  if ($@) {
      # we just print out the exception message here
      print "There has been an exception: " $@->getMessage();  
      # but if we are debugging we get the whole
      # stack trace as well
      if (DEBUG) {
          print $@->getStackTraceAsString();
      }
  }
  
  # it can be used to catch perl exceptions
  # and wrap them in a Class::Throwable exception
  eval {
      # generate a perl exception
      eval "2 / 0";
      # then throw our own with the 
      # perl exception as a sub-exception
      throw Class::Throwable "Throwing an exception" => $@ if $@;
  };    
  if ($@) {
      # setting the verbosity to 
      # 2 gives a full stack trace
      # including any sub-exceptions
      # (see below for examples of 
      # this output format)
      $@->toString(2);  
  }
  
  # you can also declare inline exceptions
  use Class::Throwable qw(My::App::Exception::IllegalOperation);
  
  eval {
      throw My::App::Exception::IllegalOperation "Bad, real bad";
  };
  
  # you can even create exceptions, then throw them later
  my $e = Class::Throwable->new("Things have gone bad, but I need to do something first", $@);
  
  # do something else ...
  
  # then throw the exception we created earlier
  throw $e

=head1 DESCRIPTION

This module implements a minimal lightweight exception object. It is meant to be a compromise between more basic solutions like L<Carp> which can only print information and cannot handle exception objects, and more more complex solutions like L<Exception::Class> which can be used to define complex inline exceptions and has a number of module dependencies. 

=head1 METHODS

=head2 Constructor

=over 4

=item B<throw ($message, $sub_exception)>

The most common way to construct an exception object is to C<throw> it. This method will construct the exception object, collect all the information from the call stack and then C<die>. 

The optional C<$message> argument can be used to pass custom information along with the exception object. Commonly this will be a string, but this module makes no attempt to enforce that it be anything other than a scalar, so more complex references or objects can be used. If no C<$message> is passed in, a default one will be constructed for you.

The second optional argument, C<$sub_exception>, can be used to retain information about an exception which has been caught but might not be appropriate to be re-thrown and is better wrapped within a new exception object. While this argument will commonly be another Class::Throwable object, that fact is not enforced so you can pass in normal string based perl exceptions as well.

If this method is called as an instance method on an exception object pre-built with C<new>, only then is the stack trace information populated and the exception is then passed to C<die>.

=item B<new ($message, $sub_exception)>

This is an alternate means of creating an exception object, it is much like C<throw>, except that it does not collect stack trace information or C<die>. It stores the C<$message> and C<$sub_exception> values, and then returns the exception instance, to be possibly thrown later on.

=back

=head2 Accessors

=over 4

=item B<getMessage>

This allows access to the message in the exception, to allow more granular exception reporting.

=item B<getStackTrace>

This returns the raw stack trace information as an array of arrays. There are 10 values returned by C<caller> (C<$package>, C<$filename>, C<$line>, C<$subroutine>, C<$hasargs>, C<$wantarray>, C<$evaltext>, C<$is_require>, C<$hints>, C<$bitmask>) we do not bother to capture the last two as they are subject to change and meant for internal use, all others are retained in the order returned by C<caller>.

=item B<hasSubException>

The returns true (C<1>) if this exception has a sub-exception, and false (C<0>) otherwise.

=item B<getSubException>

This allows access to the stored sub-exception.

=back

=head2 Output Methods

This object overloads the stringification operator, and will call the C<toString> method to perform that stringification. 

=over 4

=item B<toString ($verbosity)>

This will print out the exception object's information at a variable level of verbosity which is specified be either the optional argument C<$verbosity> or the value of C<$Class::Throwable::VERBOSE>. If either value is set to 0 or below, an empty string is returned. If the value is set to 1, then the exception's message is returned. If the value is set to 2 or above, a full stack trace along with full stack traces for all sub-exceptions are returned in the format shown in C<stackTraceToString>. This is meant to be a simple and flexible way to control the level of exception output on either a global level (with C<$Class::Throwable::VERBOSE>) or a more granular level (with the C<$verbosity> argument). 

=item B<stringValue>

This will return the normal perl stringified value of the object without going through the C<toString> method.

=item B<stackTraceToString>

This method is used to print the stack trace information, the stack trace is presented in the following format:

  >> stack frame (1)
     ----------------
     package: main
     subroutine: main::foo
     filename: my_script.pl
     line number: 12

Each subsequent stack frame will also be printed with the stack-frame number incremented for each one. 

=back

=head1 BUGS

None that I am aware of. Of course, if you find a bug, let me know, and I will be sure to fix it. This is based on code which has been heavily used in production sites for over 2 years now without incident.

=head1 CODE COVERAGE

I use B<Devel::Cover> to test the code coverage of my tests, below is the B<Devel::Cover> report on this module test suite.

 ------------------------ ------ ------ ------ ------ ------ ------ ------
 File                       stmt branch   cond    sub    pod   time  total
 ------------------------ ------ ------ ------ ------ ------ ------ ------
 Class/Throwable.pm        100.0   96.2   58.3  100.0  100.0  100.0   95.7
 ------------------------ ------ ------ ------ ------ ------ ------ ------
 Total                     100.0   96.2   58.3  100.0  100.0  100.0   95.7
 ------------------------ ------ ------ ------ ------ ------ ------ ------

=head1 SEE ALSO

There are a number of ways to do exceptions with perl, I was not really satisifed with the way anyone else did them, so I created this module. However, if you find this module unsatisfactory, you may want to check these out.

=over 4

=item L<Exception::Class>

This in one of the more common exception classes out there. It does an excellent job with it's default behavior, and allows a number of complex options which can likely serve any needs you might have. My reasoning for not using this module is that I felt these extra options made things more complex than they needed to be, it also introduced a number of dependencies. I am not saying this module is bloated at all, but that for me it was far more than I have found I needed. If you have heavy duty exception needs, this is your module.

=item L<Error>

This is the classic perl exception module, complete with a try/catch mechanism. This module has a lot of bad karma associated with it because of the obscure nested closure memory leak that try/catch has. I never really liked the way its exception object Error::Simple did things either.

=item L<Exception>

This module I have never really experimented with, so take my opinion with a large grain of salt. My problem with this module was always that it seemed to want to do too much. It attempts to make perl into a language with real exceptions, but messing with C<%SIG> handlers and other such things. This can be dangerous territory sometimes, and for me, far more than my needs. 

=back

=head1 AUTHOR

stevan little, E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
