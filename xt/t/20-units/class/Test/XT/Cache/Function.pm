package Test::XT::Cache::Function;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Cache::Function

=head1 SYNOPSIS

=head1 TESTS

=cut

use Test::XTracker::Data;

use Memoize;

# global to track calls to functions/methods
my %call_counters;

# to be done first before ALL the tests start
sub startup : Test( startup => 2 ) {
    my $self = shift;
    $self->SUPER::startup;

    use_ok( 'XT::Cache::Function', qw(
        cache_a_function
        cache_a_method
        cache_and_call_method
        :key
        :stop
    ) );

    can_ok( 'XT::Cache::Function', qw(
        cache_a_function
        cache_a_method
        cache_and_call_method
        generate_cache_key
        generate_method_cache_key
        stop_caching_a_function
        stop_all_caching
    ) );

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{json}   = JSON->new();
}

# to be done BEFORE each test runs
sub setup : Test( setup => 0 ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

    %call_counters  = ();
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

=head2 test_generate_cache_key

Tests the two functions that generate a key used for Caching: 'generate_cache_key' & 'generate_method_cache_key'

=cut

sub test_generate_cache_key : Tests {
    my $self    = shift;

    # get multiple Objects for the same Class but a different Record
    my @statuses    = $self->rs('Public::OrderStatus')->all;

    note "Test: 'generate_cache_key' for functions";
    my $key = generate_cache_key( {
        a => 2,
        c => 'key',
        b => 'qwerty',
        object => $statuses[0],
    } );
    is( $key, '[{"a":2,"b":"qwerty","c":"key","object":null}]',
            "Key generated is a JSON string" );

    note "Test: 'generate_method_cache_key' for methods";
    dies_ok {
        generate_method_cache_key( { a => 1 } );
    } "dies when first argument isn't BLESSED";

    note "pass a DBIC Object as the first Argument";
    $key    = generate_method_cache_key( $statuses[0], { b => 1, a => 2 } );
    is( $key, '["' . ref( $statuses[0] ) . '",' . $statuses[0]->id . ',{"a":2,"b":1}]',
            "Key has the Class name & Id of the record as the first 2 parts of the JSON string" );
    $key    = generate_method_cache_key( $statuses[1], { b => 1, a => 2 } );
    is( $key, '["' . ref( $statuses[1] ) . '",' . $statuses[1]->id . ',{"a":2,"b":1}]',
            "pass in same Object Class but different record then Key has the new Id" );

    note "pass an Object which doesn't have an 'id' method";
    $key    = generate_method_cache_key( $self, 'key', 'Test' );
    is( $key, '["' . ref( $self ) . '","key","Test"]',
            "the Class name of the Object is the first part of the JSON string" );
}

=head2 test_cache_a_function

Tests the functions 'cache_a_function' and 'stop_caching_a_function'.

=cut

sub test_cache_a_function : Tests {
    my $self    = shift;

    # call '_function_to_cache' in different
    # ways to test that the caching works
    my $calls   = $self->_test_calls;
    my $tests   = $calls->{calls_to_make};

    note "cache function then make calls to it";
    my $return_value    = _function_to_cache();     # all the calls should return this value
    $call_counters{to_function} = 0;
    cache_a_function( '_function_to_cache' );

    # loop round twice the first with the function
    # Cached, the second with it NOT Cached
    my $expected_calls  = $calls->{expected_cache_count};
    foreach my $n ( 1..2 ) {

        if ( $n == 2 ) {
            note "now STOP caching the function and make the Calls again";
            stop_caching_a_function( '_function_to_cache' );
            $call_counters{to_function}  = 0;
            $expected_calls = $calls->{expected_nocache_count};
        }

        foreach my $label ( keys %{ $tests } ) {
            my $test    = $tests->{ $label };
            note "calling " . $label . ", with params: " . p( $test->{params} );

            if ( $test->{context} eq 'SCALAR' ) {
                my $scalar  = (
                    $test->{params}
                    ? _function_to_cache( @{ $test->{params} } )
                    : _function_to_cache()
                );
                is_deeply( $scalar, $return_value, "function returned Expected Value" );
            }
            else {
                my @array   = (
                    $test->{params}
                    ? _function_to_cache( @{ $test->{params} } )
                    : _function_to_cache()
                );
                is_deeply( $array[0], $return_value, "function returned Expected Value" );
            }
        }
        cmp_ok( $call_counters{to_function}, '==', $expected_calls, "Function was called '${expected_calls}' times" );
    }
}

=head2 test_cache_a_method

Tests the functions 'cache_a_method' and 'stop_caching_a_function'.

=cut

sub test_cache_a_method : Tests {
    my $self    = shift;

    # call '_method_to_cache' in different
    # ways to test that the caching works
    my $calls   = $self->_test_calls;
    my $tests   = $calls->{calls_to_make};

    note "cache method then make calls to it";
    my $return_value    = $self->_method_to_cache();        # all the calls should return this value
    $call_counters{to_method} = 0;
    cache_a_method( '_method_to_cache' );

    # loop round twice the first with the function
    # Cached, the second with it NOT Cached
    my $expected_calls  = $calls->{expected_cache_count};
    foreach my $n ( 1..2 ) {

        if ( $n == 2 ) {
            note "now STOP caching the function and make the Calls again";
            stop_caching_a_function( '_method_to_cache' );
            $call_counters{to_method} = 0;
            $expected_calls = $calls->{expected_nocache_count};
        }

        foreach my $label ( keys %{ $tests } ) {
            my $test    = $tests->{ $label };
            note "calling " . $label . ", with params: " . p( $test->{params} );

            if ( $test->{context} eq 'SCALAR' ) {
                my $scalar  = (
                    $test->{params}
                    ? $self->_method_to_cache( @{ $test->{params} } )
                    : $self->_method_to_cache()
                );
                is_deeply( $scalar, $return_value, "method returned Expected Value" );
            }
            else {
                my @array   = (
                    $test->{params}
                    ? $self->_method_to_cache( @{ $test->{params} } )
                    : $self->_method_to_cache()
                );
                is_deeply( $array[0], $return_value, "method returned Expected Value" );
            }
        }
        cmp_ok( $call_counters{to_method}, '==', $expected_calls, "Method was called '${expected_calls}' times" );
    }
}

=head2 test_cache_and_call_method

Tests the functions 'cache_and_call_method' and 'stop_all_caching'.

=cut

sub test_cache_and_call_method : Tests {
    my $self    = shift;

    # call '_method_to_cache' in different
    # ways to test that the caching works
    my $calls           = $self->_test_calls;
    my $tests           = $calls->{calls_to_make};
    my $expected_count  = $calls->{expected_cache_count};

    note "make calls to the method";
    my $return_value    = $self->_method_to_cache();        # all the calls should return this value
    $call_counters{to_method} = 0;

    foreach my $label ( keys %{ $tests } ) {
        my $test    = $tests->{ $label };
        note "calling " . $label . ", with params: " . p( $test->{params} );

        if ( $test->{context} eq 'SCALAR' ) {
            my $scalar  = (
                $test->{params}
                ? cache_and_call_method( $self, '_method_to_cache', @{ $test->{params} } )
                : cache_and_call_method( $self, '_method_to_cache')
            );
            is_deeply( $scalar, $return_value, "method returned Expected Value" );
        }
        else {
            my @array   = (
                $test->{params}
                ? cache_and_call_method( $self, '_method_to_cache', @{ $test->{params} } )
                : cache_and_call_method( $self, '_method_to_cache')
            );
            is_deeply( $array[0], $return_value, "method returned Expected Value" );
        }
    }
    cmp_ok( $call_counters{to_method}, '==', $expected_count, "Method was called '${expected_count}' times" );

    note "now call 'stop_all_caching' and then 'cache_and_call_method' again";
    $expected_count++;
    stop_all_caching();
    my $value = cache_and_call_method( $self, '_method_to_cache' );
    is_deeply( $value, $return_value, "method returned Expected Value" );
    cmp_ok( $call_counters{to_method}, '==', $expected_count, "Method has now been called '${expected_count}' times" );
}

#----------------------------------------------------------------------

# a collection of calls to make to functions/methods with
# different paramaters and called in different contexts
sub _test_calls {
    my $self    = shift;

    my %calls   = (
        "with no Params in SCALAR context 1" => {
            params => undef,
            context => 'SCALAR',
        },
        "with no Params in SCALAR context 2" => {
            params => undef,
            context => 'SCALAR',
        },
        "with no Params in LIST context 1" => {
            params => undef,
            context => 'LIST',
        },
        "with no Params in LIST context 2" => {
            params => undef,
            context => 'LIST',
        },
        "with Params in SCALAR context 1" => {
            params => [ 1 ],
            context => 'SCALAR',
        },
        "with Params in SCALAR context 2" => {
            params => [ 1 ],
            context => 'SCALAR',
        },
        "with Params in LIST context 1" => {
            params => [ 1 ],
            context => 'LIST',
        },
        "with Params in LIST context 2" => {
            params => [ 1 ],
            context => 'LIST',
        },
        "with another set of Params in SCALAR context 1" => {
            params => [ 1, { a => 1 } ],
            context => 'SCALAR',
        },
        "with another set of Params in SCALAR context 2" => {
            params => [ 1, { a => 1 } ],
            context => 'SCALAR',
        },
        "with another set of Params in LIST context 1" => {
            params => [ 1, { a => 1 } ],
            context => 'LIST',
        },
        "with another set of Params in LIST context 2" => {
            params => [ 1, { a => 1 } ],
            context => 'LIST',
        },
    );

    return {
        calls_to_make           => \%calls,
        expected_cache_count    => ( scalar( keys %calls ) / 2 ),
        expected_nocache_count  => scalar( keys %calls ),
    };
}

# this function should only be called once when Cached
sub _function_to_cache {

    $call_counters{to_function}++;

    return { name => '_function_to_cache' };
}

# this method should only be called once when Cached
sub _method_to_cache {
    my $self    = shift;

    $call_counters{to_method}++;

    return { name => '_method_to_cache' };
}
