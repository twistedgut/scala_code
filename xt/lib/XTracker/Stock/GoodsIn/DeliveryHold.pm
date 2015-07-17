package XTracker::Stock::GoodsIn::DeliveryHold;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::XTemplate;
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database;
use XTracker::Database::Location;
use XTracker::Constants::FromDB qw( :delivery_action );

use XTracker::Error;
use Data::Dump qw(pp);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content} = 'goods_in/delivery_hold.tt';
    $handler->{data}{section} = 'Goods In';
    $handler->{data}{subsection} = 'Delivery Hold';

    my $delivery_rs         = $handler->{schema}->resultset('Public::Delivery');
    my $delivery_note_rs    = $handler->{schema}->resultset('Public::DeliveryNote');
    my $log_delivery_rs     = $handler->{schema}->resultset('Public::LogDelivery');

    my $description         = $handler->{request}->param('description');
    my $delivery_id         = $handler->{request}->param('delivery_id');
    my $delivery_note_id    = $handler->{request}->param('delivery_note_id');
    my $delete_id           = $handler->{request}->param('delete');
    my $operator_id         = $handler->{data}{operator_id};

    # If description parameter passed
    if ( $description ) {
        # If delivery_id passed then create a note, hold the delivery and
        # update the log
        if ( $delivery_id ) {

            my $tx_ref = sub {

                my $delivery = $delivery_rs->find($delivery_id);

                $delivery->create_note(
                    $operator_id,
                    $description,
                );
                if ( not $delivery->on_hold ) {
                    $log_delivery_rs->create({
                        delivery_id         => $delivery->id,
                        type_id             => 1,
                        delivery_action_id  => $DELIVERY_ACTION__HELD,
                        operator_id         => $operator_id,
                        quantity            => 0,
                        notes               => '',
                    });
                }
                $delivery->hold;
            };

            eval {
                $delivery_note_rs->result_source->schema->txn_do( $tx_ref );
            };

            if ( $@ ) {
                xt_warn(qq{ There was an unexpected error holding the delivery: $@} );
            }
        }
        # If delivery_note_id passed then edit the note
        elsif ( $delivery_note_id ) {
            my $delivery_note = $delivery_note_rs->find($delivery_note_id);
            if ( $delivery_note->creator->id == $operator_id ) {
                $delivery_note->edit_note(
                    $operator_id,
                    $description,
                );
            }
            else {
                xt_warn(q{You may not edit other operators' notes});
            }
        }
    }

    # If delete parameter passed
    elsif ( $delete_id ) {
        my $delivery_note = $delivery_note_rs->find($delete_id);

        # If the delivery note exists
        if ( $delivery_note ) {
            # If note is not user's
            if ( $delivery_note->creator->id != $operator_id ) {
                xt_warn(q{You may not delete other operators' notes});
            }

            # Check that note is not first for delivery
            elsif ( $delivery_note->is_first ) {
                xt_warn(q{This note may not be deleted as it is the first for the delivery});
            }

            # Delete note
            else {
                $delivery_note->delete;
            }
        }
    }

    else {

        # Loop through parameters, release delivery if parameters found
        foreach my $action ( $handler->{request}->param ) {

            if ( $action =~ /release_(\d+)/ ) {
                eval {
                    my $schema = $delivery_rs->result_source->schema;
                    $schema->txn_do(
                        sub { _txn_release_delivery( $schema, $operator_id, $1 ) }
                    );
                };
                if ( $@ ) {
                    xt_warn( q{The delivery could not be released} );
                }
            }
        }
    }

    $handler->{data}{deliveries}        = $delivery_rs->get_held_deliveries;
    $handler->{data}{hours}             = 72; # The number of hours since holding before the delivery is considered overdue
    $handler->{data}{yui_enabled}       = 1;
    $handler->process_template( undef );
    return OK;
}

sub _txn_release_delivery {

    my ( $schema, $operator_id, $delivery_id ) = @_;

    my $delivery = $schema->resultset('Public::Delivery')->find($delivery_id);

    $delivery->release;

    $schema->resultset('Public::LogDelivery')->create({
        delivery_id         => $delivery->id,
        type_id             => 1,
        delivery_action_id  => $DELIVERY_ACTION__RELEASED,
        operator_id         => $operator_id,
        quantity            => 0,
        notes               => '',
    });
}

1;
