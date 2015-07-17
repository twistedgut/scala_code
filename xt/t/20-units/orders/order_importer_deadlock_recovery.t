#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XTracker::MessageQueue;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;

use Data::Printer;

use XTracker::Constants::FromDB qw( :pre_order_status :pre_order_note_type :pre_order_item_status );
use XTracker::Constants         qw( :application );

use XT::Data::Order qw( _attempt_with_deadlock_recovery );


# utility functions

sub _stringify_args {
    my ( $arg, $attempts ) = @_;

    return "$arg: $attempts->{made} of $attempts->{max},"
               ." $attempts->{remaining} left";
}

sub _always_deadlocks {
    my ( $arg, $attempts ) = @_;

    die "O NOES! A Deadlock will always occur! ("._stringify_args($arg,$attempts).")\n";
}

sub _always_dies {
    my ( $arg, $attempts ) = @_;

    die "O MY! Something Else will always occur! ("._stringify_args($arg,$attempts).")\n";
}

sub _deadlocks_then_works  {
    my ( $arg, $attempts ) = @_;

    die "O NOES! A Deadlock has occurred! ("._stringify_args($arg,$attempts).")\n"
        if $attempts->{remaining} || $attempts->{made} == 1;

    return { result => _stringify_args( $arg, $attempts ),
             attempts => $attempts };
}

sub _dies_then_works {
    my ( $arg, $attempts ) = @_;

    die "O MY! Something Else has occurred! ("._stringify_args($arg,$attempts).")\n"
        if $attempts->{remaining} || $attempts->{made} == 1;

    return { result => _stringify_args( $arg, $attempts ),
             attempts => $attempts };
}

sub _works_every_time {
    my ( $arg, $attempts ) = @_;

    return { result => _stringify_args( $arg, $attempts ),
             attempts => $attempts };
}

sub _returns_nothing {
    return;
}

my $scenarios = [
    {
        name    => 'Just works, no config',
        call    => sub{ _works_every_time @_ },
        with    => 'First Arg',
        config  => {},
        dies    => 0,
        expect  => 'First Arg: 1 of 0, 0 left'
    },
    {
        name    => 'Just works, zero config',
        call    => sub{ _works_every_time @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 0,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 0,
        expect  => 'First Arg: 1 of 0, 0 left'
    },
    {
        name    => 'Just works, once config',
        call    => sub{ _works_every_time @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 1,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 0,
        expect  => 'First Arg: 1 of 1, 0 left'
    },
    {
        name    => 'Just works, standard config',
        call    => sub{ _works_every_time @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 19,
                     max_deadlock_delay    => 11,
                     min_deadlock_delay    => 1
                   },
        dies    => 0,
        expect  => 'First Arg: 1 of 19, 18 left'
    },
    {
        name    => 'Deadlocks then works, no config',
        call    => sub{ _deadlocks_then_works @_ },
        with    => 'First Arg',
        config  => {},
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O NOES! A Deadlock has occurred! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Deadlocks then works, zero config',
        call    => sub{ _deadlocks_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 0,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O NOES! A Deadlock has occurred! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Deadlocks then works, once config',
        call    => sub{ _deadlocks_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 1,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'Deadlock detected processing order ORDER/NAME: retries exhausted'
    },
    {
        name    => 'Deadlocks then works, standard config',
        call    => sub{ _deadlocks_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 19,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 0,
        expect  => 'First Arg: 19 of 19, 0 left'
    },
    {
        name    => 'Deadlocks then works, delaying from zero config',
        call    => sub{ _deadlocks_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 3,
                     max_deadlock_delay    => 2,
                     min_deadlock_delay    => 0
                   },
        dies    => 0,
        expect  => 'First Arg: 3 of 3, 0 left'
    },
    {
        name    => 'Deadlocks then works, delaying from one config',
        call    => sub{ _deadlocks_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 3,
                     max_deadlock_delay    => 3,
                     min_deadlock_delay    => 1
                   },
        dies    => 0,
        expect  => 'First Arg: 3 of 3, 0 left'
    },
    {
        name    => 'Deadlocks then works, fixed delay config',
        call    => sub{ _deadlocks_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 3,
                     max_deadlock_delay    => 2,
                     min_deadlock_delay    => 2
                   },
        dies    => 0,
        expect  => 'First Arg: 3 of 3, 0 left'
    },
    {
        name    => 'Always deadlocks, no config',
        call    => sub{ _always_deadlocks @_ },
        with    => 'First Arg',
        config  => {},
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O NOES! A Deadlock will always occur! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Always deadlocks, zero config',
        call    => sub{ _always_deadlocks @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 0,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O NOES! A Deadlock will always occur! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Always deadlocks, once config',
        call    => sub{ _always_deadlocks @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 1,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'Deadlock detected processing order ORDER/NAME: retries exhausted'
    },
    {
        name    => 'Always deadlocks, standard config',
        call    => sub{ _always_deadlocks @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 19,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'Deadlock detected processing order ORDER/NAME: retries exhausted'
    },
    {
        name    => 'Dies then works, no config',
        call    => sub{ _dies_then_works @_ },
        with    => 'First Arg',
        config  => {},
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O MY! Something Else has occurred! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Dies then works, zero config',
        call    => sub{ _dies_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 0,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O MY! Something Else has occurred! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Dies then works, once config',
        call    => sub{ _dies_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 1,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'Error while processing order ORDER/NAME: O MY! Something Else has occurred! (First Arg: 1 of 1, 0 left)'
    },
    {
        name    => 'Dies then works, standard config',
        call    => sub{ _dies_then_works @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 19,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O MY! Something Else has occurred! (First Arg: 1 of 19, 18 left)"
    },
    {
        name    => 'Always dies, no config',
        call    => sub{ _always_dies @_ },
        with    => 'First Arg',
        config  => {},
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O MY! Something Else will always occur! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Always dies, zero config',
        call    => sub{ _always_dies @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 0,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => "Error while processing order ORDER/NAME: O MY! Something Else will always occur! (First Arg: 1 of 0, 0 left)"
    },
    {
        name    => 'Always dies, once config',
        call    => sub{ _always_dies @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 1,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'Error while processing order ORDER/NAME: O MY! Something Else will always occur! (First Arg: 1 of 1, 0 left)'
    },
    {
        name    => 'Always dies, standard config',
        call    => sub{ _always_dies @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 19,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'Error while processing order ORDER/NAME: O MY! Something Else will always occur! (First Arg: 1 of 19, 18 left)'
    },
    {
        name    => 'Returns nothing, standard config',
        call    => sub{ _returns_nothing @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => 19,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'FAILED to receive a result, and no error was thrown'
    },
    {
        name    => 'Always Dies, broken config',
        call    => sub{ _always_dies @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => -1,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'FAILED to process order ORDER/NAME: ran out of deadlock retries'
    },
    {
        name    => 'Just works, broken config',
        call    => sub{ _works_every_time @_ },
        with    => 'First Arg',
        config  => { max_deadlock_attempts => -1,
                     max_deadlock_delay    => 0,
                     min_deadlock_delay    => 0
                   },
        dies    => 1,
        expect  => 'FAILED to process order ORDER/NAME: ran out of deadlock retries'
    },
];

foreach my $scenario ( @$scenarios ) {
    note "Attempting scenario: $scenario->{name}";

    $scenario->{config}{order_name} = 'ORDER/NAME';

    if ( $scenario->{dies} ) {
        eval {
            my $return =
                XT::Data::Order::_attempt_with_deadlock_recovery(
                    $scenario->{with},
                    $scenario->{config},
                    $scenario->{call}
                );

            # whoops!
            ok( 0, qq{Scenario $scenario->{name} should have failed, but instead returned '$return'} );
        };

        if ( my $error = $@ ) {
            chomp $error;
            cmp_ok( $error,
                    'eq',
                    $scenario->{expect},
                    qq{Scenario $scenario->{name} correctly died with "$scenario->{expect}"}
            );
        }
    }
    else {
        my $return =
               XT::Data::Order::_attempt_with_deadlock_recovery(
                    $scenario->{with},
                    $scenario->{config},
                    $scenario->{call}
               );

        # check the result
        cmp_ok( $return->{result},
                'eq',
                $scenario->{expect},
                qq{Scenario $scenario->{name} correctly returned "$scenario->{expect}"}
        );

        # then check that the attempt history didn't violate anything
        #
        # check that we didn't do more attempts than were specified

        cmp_ok( $return->{attempts}{made},
                '<=',
                $scenario->{config}{max_deadlock_attempts} || 1,
                qq{Scenario $scenario->{name} did not exceed maximum retries}
        );

        # check that we didn't overflow the maximum delay, nor that we
        # underflowed the minimum delay

        if ( scalar @{$return->{attempts}{pauses}} ) {
            my @sorted_pauses = sort { $a <=> $b } @{$return->{attempts}{pauses}} ;

            cmp_ok( $sorted_pauses[0],
                    '>=',
                    $scenario->{config}{min_deadlock_delay} || 0,
                    qq{Scenario $scenario->{name} did not underflow minimum delay}
            );

            cmp_ok( $sorted_pauses[-1],
                    '<=',
                    $scenario->{config}{max_deadlock_delay} || 0,
                    qq{Scenario $scenario->{name} did not overflow maximum delay}
            );
        }
    }
}

done_testing;

