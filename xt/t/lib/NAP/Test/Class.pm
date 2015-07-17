
=head1 NAME

NAP::Test::Class - base class for NAP-specific Test::Class classes

=cut

package NAP::Test::Class;
use NAP::policy "tt", 'class', 'test';

# Loads Test::XTracker::Config, which needs to be loaded before
# Test::Role::WithSchema
use FindBin::libs;
use Test::XTracker::LoadTestConfig;

BEGIN { # at BEGIN time to play nicely with Test::Class
    use MooseX::NonMoose;
    extends "Test::Class";
    with (
        "Test::Role::WithSchema",
        "Test::Role::SolveRules",
        'XTracker::Role::WithPRLs',
        'XTracker::Role::WithIWSRolloutPhase',
    );
};

use Carp;


use Test::More::Prefix;

use XTracker::Config::Local qw( config_var );
use XT::Warehouse;

# use modules needed by all Test::Class classes here, e.g.
# use Test::DBIx::Class::Schema;
# use Test::XTracker::Data;
# use XTracker::Config::Local;



=head2 DESCRIPTION

The startup/shutdown, setup/teardown methods often become messy, so
don't introduce new methods. Instead, override the methods below in
sub-classes and chain to the parent by calling e.g.

  $self->SUPER::setup();

=cut

sub startup : Test(startup) {
    my $self = shift;
}

sub setup : Test(setup) {
    my $self = shift;
}

sub teardown : Test(teardown) {
    my $self = shift;
    undef($Test::More::Prefix::prefix);
    # Make sure we clear our warehouse singleton after every test in case we've
    # overridden it
    XT::Warehouse->_clear_instance;

}

sub shutdown : Test(shutdown) {
    my $self = shift;
}

=head2 test_hashref_values($hashref, $name_expected)

Test that $hashref has the correct values in $key_expected_value
(hashref with (keys: hashref keys; values: expected values, or regexes
to match against))

=cut

sub test_hashref_values {
    my ($self, $hashref, $key_expected_value) = @_;

    for my $key (keys %$key_expected_value) {
        my $key_expected_value_value = $key_expected_value->{$key};
        if(ref($key_expected_value_value) eq "Regexp") {
            like(
                $hashref->{$key},
                $key_expected_value_value,
                "    attribute ($key) is ($key_expected_value_value)",
            );
        }
        else {
            is(
                $hashref->{$key},
                $key_expected_value_value,
                "    attribute ($key) is ($key_expected_value_value)",
            );
        }
    }
}

=head2 dc : Str $DC

Return the current DC (e.g. DC1).

=cut

sub dc {
    my $self = shift;
    return config_var("DistributionCentre", "name");
}

=head2 per_dc(%$dc_value) : $dc_specific_value | die

Return the $dc_value->{DC1|2}, or die if it doesn't exist.

=cut

sub per_dc {
    my ($self, $dc_value) = @_;
    my $dc = $self->dc;
    exists $dc_value->{$dc} or croak("No key with the current DC ($dc) passed to ->per_dc()");
    return $dc_value->{$dc};
}

sub test_scenarios {
    my $self = shift;
    my ( $scenarios, $name, $options ) = @_;

    $name       //= $self->current_method;
    $options    //= {};

    my $method_prefix = exists $options->{method_prefix}
        ? $options->{method_prefix}
        : $self->current_method;

    my @init_args = ( exists $options->{init_args} && ref( $options->{init_args} ) eq 'ARRAY' )
        ? @{ $options->{init_args} }
        : ();

    my @test_args = ( exists $options->{test_args} && ref( $options->{test_args} ) eq 'ARRAY' )
        ? @{ $options->{test_args} }
        : ();

    # Method names.
    my $init_method_name    = $method_prefix . '_INIT';
    my $test_method_name    = $method_prefix . '_TEST';

    subtest( $name => sub {

        return fail("The list of scenarios passed to test_scenarios must be a HashRef for '$name'")
            unless ref( $scenarios ) eq 'HASH';

        return fail("Missing test method '$test_method_name' for '$name'")
            unless $self->can( $test_method_name );

        # If an 'init' method exists, call it.
        my @init_result = $self->can( $init_method_name )
            ? $self->$init_method_name( @init_args )
            : ();

        # Call the 'test' method for every key/value in $scenarios, passing in the key,
        # value and result of the 'init' method.
        subtest( $_, sub { $self->$test_method_name( $_, $scenarios->{$_}, @test_args, @init_result ) } )
            foreach keys %{ $scenarios }

    });

}

# This makes it possible to "prove ../Test/Blah.pm" a sub class of
# this one to run those tests.
INIT {
    # scan the caller() chain, looking for files that are not '*.pm'
    my $seen_not_pm;my $depth=0;
    while (my @caller = caller(++$depth)) {
        if ($caller[1] !~ /\.pm$/) {
            $seen_not_pm=1;last;
        }
    }
    # if we have seen a non-pm file, we're being called from inside a
    # test script, let that one call ->runtests
    #
    # if, instead, all the caller()s are .pm, we're being run directly
    # from prove or similar, let's run the tests magically
    Test::Class->runtests
          unless $seen_not_pm;
}

1;
