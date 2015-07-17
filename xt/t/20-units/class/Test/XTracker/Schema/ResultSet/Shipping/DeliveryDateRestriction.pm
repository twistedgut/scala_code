
package Test::XTracker::Schema::ResultSet::Shipping::DeliveryDateRestriction;
use NAP::policy "tt", ("test", "class");
use FindBin::libs;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::NominatedDay::WithRestrictedDates";
};


use DateTime;

use XTracker::Schema::ResultSet::Shipping::DeliveryDateRestriction;
use XTracker::Constants::FromDB qw(
    :shipment_type
);
use XT::Data::DateStamp;


sub restricted_shipping_charge_ids_grouped_by_type_date : Tests() {
    my $self = shift;

    note "*** Test empty set";
    $self->with_emptied_restriction( sub {
        my @all = $self->restriction_rs
            ->restricted_shipping_charge_ids_grouped_by_type_date();
        is(scalar @all, 0, "Empty table finds 0");
    });

    note "*** Test known set";
    $self->with_emptied_restriction( sub {
        note "* Setup";
        my @shipping_charges
            = $self->shipping_charge_rs->search
                ({}, { order_by => 'id', rows => 3 })->all;
        my @restriction_types = $self->restriction_type_rs->all;
        my @dates = map {
            XT::Data::DateStamp->from_datetime( DateTime->now()->add(days => $_) )
        } 1..3;
        for my $date (@dates) {
            for my $restriction_type (@restriction_types) {
                for my $shipping_charge (@shipping_charges) {
                    $self->restriction_rs->create({
                        date                => $date,
                        shipping_charge_id  => $shipping_charge->id,
                        restriction_type_id => $restriction_type->id,
                    });
                }
            }
        }

        my $test_sub = sub {
            my @dates_times_restriction_types = (@dates, @dates, @dates);
            my @all = $self->restriction_rs
                ->restricted_shipping_charge_ids_grouped_by_type_date();
            eq_or_diff(
                [ map { $_->date->ymd } @all ],
                [ map { "$_" } @dates_times_restriction_types ],
                "Dates ok",
            );

            eq_or_diff(
                [ map { $_->get_column("shipping_charge_ids") } sort @all ],
                [
                    map { join("-", map { $_->id } @shipping_charges) }
                        @dates_times_restriction_types,
                ],
                "Compound shipping_charge ids ok",
            );
            my $type_count;
            $type_count->{ $_->restriction_type_id }++ for @all;
            eq_or_diff(
                $type_count,
                {
                    map { $_->id => scalar @dates } @restriction_types },
                "Restriction type count ok"
            );
        };

        note "\nTest the full set of dates";
        $test_sub->();

        note "\nTest that is_restricted: 0 dates aren't taken into account";
        my $disabled_date = pop(@dates);
        $self->restriction_rs
            ->search({ date => $disabled_date })
            ->update({ is_restricted => 0 });
        $test_sub->();

#        warn Data::Dumper->new([ map { +{ $_->get_columns } } @all ])->Maxdepth(3)->Dump(); use Data::Dumper;
    });

}

sub between_dates_per_channel_rs__empty : Tests() {
    my $self = shift;

    note "*** Test empty set";
    my $channel = Test::XTracker::Data->channel_for_any;
    $self->with_emptied_restriction( sub {
        my @all = $self->restriction_rs->between_dates_per_channel_rs({
            begin_date => "1960-01-01",
            end_date   => "2100-01-01",
            channel    => $channel,
            });
        is(scalar @all, 0, "Empty table finds 0");
    });
}


sub between_dates_per_channel_rs__finds_the_correct_rows : Tests() {
    my $self = shift;
    $self->with_emptied_restriction(
        sub { $self->_between_dates_per_channel_rs__finds_the_correct_rows()},
    );
}

sub _between_dates_per_channel_rs__finds_the_correct_rows {
    my $self = shift;

    note "Set up a few dates for/not for a channel, a few
inside/outside the window, along with multiple delivery types to make
sure we don't get dupes";

    # Channels with/without restrictions after setup
    my $channel_with    = Test::XTracker::Data->channel_for_nap;
    my $channel_without = Test::XTracker::Data->channel_for_mrp;

    my $begin_date = "1995-04-04";
    my $end_date   = "1995-05-05";
    my @restricted_dates_within = qw/ 1995-04-04 1995-05-05 /;
    my @restricted_dates = ( "1995-04-03", @restricted_dates_within, "1995-05-06" );
    # 2 just to get multiple
    my @shipping_charge_rows_for_channel_with
        = $self->nominated_day_shipping_charges($channel_with, 2);
    my @shipping_charge_rows = (
        @shipping_charge_rows_for_channel_with,
        # Count doesn't matter, they won't get selected anyway
        $self->nominated_day_shipping_charges($channel_without, 1),
    );
    my @restriction_types = qw/ dispatch delivery transit /;
    for my $date (@restricted_dates) {
        for my $shipping_charge (@shipping_charge_rows) {
            for my $type (@restriction_types) {
                note "Creating ($date) (" . $shipping_charge->sku . ") ($type)";
                my $restricted_date = XT::Data::NominatedDay::RestrictedDate->new({
                    date               => $date,
                    shipping_charge_id => $shipping_charge->id,
                    restriction_type   => $type,
                });
                $restricted_date->restrict($self->operator, "Change reason");
            }
        }
    }

    my @all = $self->restriction_rs->between_dates_per_channel_rs({
        begin_date => $begin_date,
        end_date   => $end_date,
        channel    => $channel_with,
    })->all;
    my @restriction_data = map {
        +{
            shipping_charge_sku => $_->shipping_charge->sku,
            date                => $_->date->ymd,
            restriction_type    => $_->restriction_type->token,
            channel             => $_->shipping_charge->channel->web_name,
        };
    } @all;

    # warn Data::Dumper->new([\@restriction_data])->Maxdepth(2)->Dump(); use Data::Dumper;
    is(
        scalar @all,
        @shipping_charge_rows_for_channel_with
            * @shipping_charge_rows_for_channel_with
            * @restriction_types,
        "Found the correct number of restrictions",
    );
}

sub nominated_day_shipping_charges {
    my ($self, $channel, $row_count) = @_;
    return $self->rs("ShippingCharge")->is_nominated_day->search(
        { channel_id => $channel->id },
        { rows       => $row_count   },
    )->all;
}

1;
