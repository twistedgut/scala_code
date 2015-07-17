package Test::XTracker::Schema::Result::Public::ShipmentHoldReason;

use NAP::policy     qw( tt class test );
BEGIN {
    extends "NAP::Test::Class";
};

=head1 NAME

Test::XTracker::Schema::Result::Public::ShipmentHoldReason

=head1 DESCRIPTION

Test methods/resultset methods for 'Public::ShipmentHoldReason'.

=cut

use XTracker::Config::Local;
use XTracker::Constants::FromDB         qw( :shipment_hold_reason );


=head1 TESTS

=head2 test_get_reasons_for_hold_page

Tests the ResultSet method 'get_reasons_for_hold_page' that gets Shipment Hold Reasons
used on the 'Hold Shipment' page.

=cut

sub test_get_reasons_for_hold_page : Tests {
    my $self    = shift;

    my @all_reasons = $self->rs('Public::ShipmentHoldReason')->all;

    my $iws_config  = $XTracker::Config::Local::config{IWS};
    my $original_iws_phase = $iws_config->{rollout_phase};

    my %tests = (
        "IWS Phase set to ZERO should get 'Incomplete Pick' Reason Returned" => {
            iws_phase => 0,
            expected  => [ map { $_->id } @all_reasons ],
        },
        "IWS Phase set to 1 should NOT get 'Incomplete Pick' Reason Returned" => {
            iws_phase => 1,
            expected  => [
                map { $_->id }
                    grep { $_->id != $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK }
                            @all_reasons
            ],
        },
        "IWS Phase set to 2 should NOT get 'Incomplete Pick' Reason Returned" => {
            iws_phase => 2,
            expected  => [
                map { $_->id }
                    grep { $_->id != $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK }
                            @all_reasons
            ],
        },
        "IWS Phase set to 3 should NOT get 'Incomplete Pick' Reason Returned" => {
            iws_phase => 3,
            expected  => [
                map { $_->id }
                    grep { $_->id != $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK }
                            @all_reasons
            ],
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        $iws_config->{rollout_phase} = $test->{iws_phase};

        my $got = $self->rs('Public::ShipmentHoldReason')->get_reasons_for_hold_page;
        my @got_ids = keys %{ $got };
        cmp_bag( \@got_ids, $test->{expected}, "Got Expected Reasons" );

        $iws_config->{rollout_phase} = 0;

        $got = $self->rs('Public::ShipmentHoldReason')->get_reasons_for_hold_page( $test->{iws_phase} );
        @got_ids = keys %{ $got };
        cmp_bag( \@got_ids, $test->{expected}, "Got Expected Reasons - passing 'iws_phase' has a parameter" );
    }


    # restore original IWS config setting
    $XTracker::Config::Local::config{IWS}{rollout_phase} = $original_iws_phase;
}

