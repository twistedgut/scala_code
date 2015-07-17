#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;



use Test::XTracker::LoadTestConfig;
use XTracker::Database::Utilities qw( :DEFAULT enliken escape_like_wildcards );
use XTracker::Constants           qw( $PG_MAX_INT );

use base 'Test::Class';

sub startup : Test(startup => 2) {
    my ( $self ) = @_;

    use_ok('XTracker::Database::Utilities', qw(
                            is_valid_database_id
                        ) );

    use_ok('XTracker::Constants', qw(
                            $PG_MAX_INT
                            ));
}

sub wildcard_testing : Tests {
    my @wildcard_tests=(
         { name => "Simple string without magic",
           param =>  "Simple string" ,
           result => q{Simple string}
         },
         { name => "Single per cent",
           param => q{%},
           result => q{\\%}
         },
         { name => "Embedded per cents",
           param => q{Hello%Dolly%Wolly},
           result => q{Hello\\%Dolly\\%Wolly}
         },
         { name => "Single underscore",
           param => q{_},
           result => q{\\_}
         },
         { name => "Embedded underscores",
           param => q{Hello__Dolly_Wolly},
           result => q{Hello\\_\\_Dolly\\_Wolly}
         },
         { name => "Mixed per cents and underscores",
           param => q{Hello_Dolly%Wolly_%Golly%_Brolly%%Jolly__Trolley},
           result => q{Hello\\_Dolly\\%Wolly\\_\\%Golly\\%\\_Brolly\\%\\%Jolly\\_\\_Trolley}
         },
    );

    is(escape_like_wildcards(),undef,'escape_like_wildcards without parameters');
    is(              enliken(),undef,'enliken without parameters');

    my @all_params=();
    my @all_results=();

    foreach my $test (@wildcard_tests) {
        my $param          =      $test->{param};
        my $enliken_result = q{%}.$test->{result}.q{%};

        push @all_params,  $param;
        push @all_results, $enliken_result;

        is(escape_like_wildcards($param), $test->{result}, 'escape_like_wildcards: '.$test->{name});
        is(              enliken($param), $enliken_result, 'enliken: '.$test->{name});
    }

    # now pass them all in at once (only enliken, not escape_like_wildcards)

    is_deeply([ enliken(@all_params) ],\@all_results, "enliken array test");

}

sub test_is_valid_database_id : Tests {

    ok(is_valid_database_id(12345), 'Valid PID');
    ok(is_valid_database_id(1), 'Valid PID');
    ok(is_valid_database_id($PG_MAX_INT), 'Valid PID');

    ok(!is_valid_database_id(12345678900), 'Oversized PID detected');
    ok(!is_valid_database_id(-2424), 'negative PID detected');
    ok(!is_valid_database_id(0), 'Zero PID detected');
    ok(!is_valid_database_id($PG_MAX_INT+1), 'Oversized PID detected');
    ok(!is_valid_database_id(5464532136), 'Invalid PID');

    ok(!is_valid_database_id(''), 'Empty string detected');
    ok(!is_valid_database_id(undef), 'undefined value detected');

    ok(!is_valid_database_id('a12345'), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id('12345a'), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id('123e45'), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id('123.45'), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id('123-45'), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id('123 45'), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id('123,453'), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id("123\n453"), 'Invalid PID with non-digit detected');
    ok(!is_valid_database_id('rgdrtertierjtioerjtioetj'), 'Invalid PID with non-digits detected');
}

Test::Class->runtests;

1;
