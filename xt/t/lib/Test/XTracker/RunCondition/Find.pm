#!/usr/bin/env perl
package Test::XTracker::RunCondition::Find;

use strict;
use warnings;

use PPI;

=head2 evaluate_file

Accepts a filename, a coderef, and a configuration hash that's passed to
C<create_context> (where you can read the docs). It then reads in the file,
creates a context, and passes the filename and the context to your coderef.

Here is a simple example:

 my $coderef =  sub {
    my ( $filename, $context ) = @_;

    return
        $context->supports( dc => 'DC2' ) &&
        $context->supports( phase => 0  );
};

 Test::XTracker::RunCondition::Find->evaluate_file(
    'filename.t', $coderef, { inclusive => 0 }
 );

If you pass in a hashref INSTEAD of a code-ref, you can specify pairs that will
be passed directly in to 'support'. The following has the same effect as the
above:

 Test::XTracker::RunCondition::Find->evaluate_file(
    'filename.t', { dc => 'DC2', phase => 0 }, { inclusive => 0 }
 );

=cut

my $default_coderef = sub {
    my ( $constraints, $filename, $context ) = @_;

    for my $key ( keys %$constraints ) {
        return unless $context->supports( $key, $constraints->{ $key } );
    }

    return 1;
};

sub evaluate_file {
    my ( $class, $filename, $coderef, $config ) = @_;

    my $file_params = $class->retrieve_params_from_file( $filename );
    my $context = $class->create_context( $file_params, $config );

    if ( ref( $coderef ) eq 'HASH' ) {
        return $default_coderef->( $coderef, $filename, $context );
    } else {
        return $coderef->( $filename, $context );
    }
}

=head2 create_context

Accepts the output of C<retrieve_params_from_file>, and a params hash, and
returns a L<Test::XTracker::RunCondition::Find::Context> object. The params hash
can have the following keys:

 inclusive (bool, default true) - if true, then in files without a RunCondition
                                  line, everything is assumed to be allowed

=cut

sub create_context {
    my ( $class, $file_params, $config ) = @_;
    $config ||= { inclusive => 1 };

    my %values = ( %$file_params, %$config );
    my $obj = bless \%values, 'Test::XTracker::RunCondition::Find::Context';

    return $obj;
}

=head2 retrieve_params_from_file

Given a filename, returns a hash. The hash definitely contains
C<has_run_condition> set to 0 or 1. It MAY contain a hashref with the key
C<params> that contains the arguments passed to L<Test::XTracker::RunCondition>'s
C<import()>.

=cut

sub retrieve_params_from_file {
    my ( $class, $filename ) = @_;

    # Attempt to load the document
    my $document = PPI::Document->new( $filename );
    die "Couldn't create a PPI document from [$filename]" unless $document;

    # Get the use statement
    my $use = $document->find(
        sub {
            $_[1]->isa('PPI::Statement::Include') &&
            $_[1]->module eq 'Test::XTracker::RunCondition'
        }
    );

    # What to do when we can't find it
    unless ( $use && $use->[0] ) {
        return { has_run_condition => 0 };
    }

    # Knock out the use part itself...
    my @children = $use->[0]->children;
    while (1) {
        my $token = shift(@children);
        last if $token->content eq 'Test::XTracker::RunCondition';
    }

    my $remainder = join '', map { $_->content } @children;
    $remainder =~ s/;.*//ms;
    $remainder = '(' . $remainder . ')';

    my %params = eval $remainder; ## no critic(ProhibitStringyEval)

    die "Couldn't parse RunCondition code in [$filename]: [$@]" if $@;

    return {
        has_run_condition => 1,
        params => { %params }
    };
}

package Test::XTracker::RunCondition::Find::Context; ## no critic(ProhibitMultiplePackages)

use strict;
use warnings;

# Stolen from Test::XTracker::RunCondition because I don't want to import it.
my %valid = (
    phase    => { map { $_ => 1 } qw( 0 1 2 iws all ) },
    dc       => { map { $_ => 1 } qw( DC1 DC2 DC3 all ) },
    database => { map { $_ => 1 } qw( blank full all ) }
);

sub supports {
    my ( $self, $type, $value ) = @_;

    die "Unknown run condition [$type]" unless $valid{ $type };

    # If the file had no run condition line, we don't care what was asked about
    unless ( $self->{'has_run_condition'} ) {
        if ( $self->{'inclusive'} ) {
            return 1;
        } else {
            return;
        }
    }

    # If the file has no /relevant/ run condition, then it's allowed by default
    my $relevant = $self->{'params'}->{ $type };
    return 1 unless $relevant;

    # Get a list of what's allowed
    my @allowed = ref $relevant ? @$relevant : ( $relevant );

    # Short-circuit the 'all'
    return 1 if grep { $_ eq 'all' } @allowed;

    # Validate that the caller of this method has actually chosen a valid value
    die "Invalid constraint [$value] for run condition [$type]"
        unless $valid{$type}->{$value};

    # Multiply out 'iws'
    push( @allowed, (1,2) ) if grep { $_ eq 'iws' } @allowed;

    # Actually do the lookup
    return 1 if grep { $_ eq $type } @allowed;
    return;
}

1;
