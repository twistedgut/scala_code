package XT::Net::XTrackerAPI::Request::NominatedDay;
use NAP::policy "tt", "class";
extends "XT::Net::XTrackerAPI::Request";

=head1 NAME

XT::Net::XTrackerAPI::Request::NominatedDay - Request endpoints for serving Nominated Day related requests

=cut

use Memoize;
use POSIX;

use MooseX::Params::Validate;

use XT::Data::Types;
use XT::Data::NominatedDay::RestrictedDate;
use XT::Data::NominatedDay::RestrictedDatesDiff;

=head1 METHODS

=cut

sub restriction_rs     { return shift->schema->resultset("Shipping::DeliveryDateRestriction") }
sub restriction_log_rs { return shift->schema->resultset("Shipping::DeliveryDateRestrictionLog") }
sub shipping_charge_rs { return shift->schema->resultset("Public::ShippingCharge") }


=head2 GET_shipping_delivery_date_restriction({ :$begin_date!, :$end_date! }) : ?


=cut

sub GET_shipping_delivery_date_restriction {
    my ($self,%args) = validated_hash( \@_,
        begin_date => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
        end_date   => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
    );

    return {
        restriction_type => $self->type_date_shipping_charge_ids(\%args),
        date_range => {
            begin => $args{begin_date},
            end   => $args{end_date},
        }
    };
}

=for example

    {
        delivery => {
            "2012-05-05" => [ "62-64-72", "61-63-71", ],
            "2012-05-06" => [ "62-64-72", "61-63-71", ],
        },
        fulfilment_or_transit => { ... },
    },

=cut

sub type_date_shipping_charge_ids {
    my ($self, %args) = validated_hash( \@_,
        begin_date => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
        end_date   => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
    );

    my @rows = $self->restriction_rs->search({
        -and => [
            date => { ">=" => $args{begin_date} . "" },
            date => { "<=" => $args{end_date}   . "" },
        ],
    })->restricted_shipping_charge_ids_grouped_by_type_date();

    my $group_count
        = $self->shipping_charge_rs->search_nominated_day_id_description()->count;
    my $type_date_shipping_charge_ids = {};
    for my $row (@rows) {
        my $type = $self->restriction_type( $row->restriction_type_id );
        my $date = $row->date->ymd();

        # Add "all" to the ids, if all of the groups are already present
        my $composite_shipping_charge_ids = $row->composite_shipping_charge_ids();
        if(@$composite_shipping_charge_ids == $group_count) {
            push(@$composite_shipping_charge_ids, "all");
        }

        $type_date_shipping_charge_ids->{$type}->{$date} = $composite_shipping_charge_ids;
    }

    return $type_date_shipping_charge_ids;
}

memoize "restriction_type";
sub restriction_type {
    my ($self, $id) = @_;
    return $self->schema->resultset(
        "Shipping::DeliveryDateRestrictionType",
    )->find($id)->token;
}

=head2 POST_shipping_delivery_date_restriction({ ... }) :

Receive restricted_dates and original_restricted_dates, and update the
restricted dates.

(Finding the before/after diff could be done client-side, but is
easier to do in Perl space)

=cut

sub POST_shipping_delivery_date_restriction {
    my ($self, %args) = validated_hash( \@_,
        begin_date                => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
        end_date                  => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
        change_reason             => { isa => "Str" },
        original_restricted_dates => { isa => "XT::Data::Types::FromJSON", coerce => 1 },
        restricted_dates          => { isa => "XT::Data::Types::FromJSON", coerce => 1 },
    );
    $self->authorization->verify_level(
        "manager",
        "Updating Delivery Date Restrictions",
    );

    my $restricted_dates_diff = XT::Data::NominatedDay::RestrictedDatesDiff->new({
        current_restricted_dates => $self->get_dates($args{original_restricted_dates}),
        new_restricted_dates     => $self->get_dates($args{restricted_dates}),
        begin_date               => $args{begin_date},
        end_date                 => $args{end_date},
        change_reason            => $args{change_reason},
        operator                 => $self->operator,
    });

    $self->schema->txn_do( sub {
        $restricted_dates_diff->save_to_database();
        $restricted_dates_diff->publish_to_web_sites();
    } );

    return { };
}

=head2 get_dates($type_date_composite_sku) : ArrayRef[XT::Data::NominatedDay::RestrictedDate]

Extract XT::Data::NominatedDay::RestrictedDate objects from the depths
of $type_date_composite_sku (the JSON request from when the user
submits "Save Restricted Dates").

=for example

+{
    'transit' => {
        '2012-05-18' => [
            '241-243-254',
            '242-244-255',
            'all'
        ],
        '2012-05-21' => [
            '242-244-255'
        ],
    },
    'dispatch' => {
        '2012-05-16' => [
            '241-243-254',
        ],
    }
    'delivery' => {
        '2012-05-16' => [
            '241-243-254',
        ],
    }
}

=cut

sub get_dates {
    my ($self, $type_date_composite_skus) = @_;

    my @dates;
    eval {
        for my $type (sort keys %$type_date_composite_skus) {
            # 'delivery' => {
            my $date_composite_skus = $type_date_composite_skus->{$type};
            for my $date (sort keys %$date_composite_skus) {
                # '2012-05-16' => [
                my $composite_skus = $date_composite_skus->{$date};
                for my $composite_sku (@$composite_skus) {
                    # '241-243-254',  |  'all',
                    $composite_sku eq "all" and next;
                    for my $sku (split(/-/, $composite_sku)) {
                        # '241'  |  'all'
                        $sku =~ /^\d+$/ or next;
                        push(
                            @dates,
                            XT::Data::NominatedDay::RestrictedDate->new({
                                restriction_type   => $type,
                                date               => $date,
                                shipping_charge_id => $sku,
                            }),
                        );
                    }
                }
            }
        }
        1;
    } or die("Invalid data structure: $@\n");

    return \@dates;
}

=head2 GET_shipping_delivery_date_has_restriction({ :$begin_date!, :$end_date! }) : %$date_has_restriction

Return hash ref with (keys: date strings; values: 1) for all dates
between $begin_date and $end_date (inclusive) that has a restriction
of any Restriction Type.

=cut

sub GET_shipping_delivery_date_has_restriction {
    my ($self, %args) = validated_hash( \@_,
        begin_date => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
        end_date   => { isa => "XT::Data::Types::DateStamp", coerce => 1 },
    );

    my $restriction_type = $self->type_date_shipping_charge_ids(\%args);

    my $date_has_restriction = {
        map { $_ => 1 } (
            map { keys %{ $restriction_type->{$_} || {} } }
                qw/ delivery transit dispatch /
        )
    };

    return $date_has_restriction
}

sub GET_shipping_delivery_date_log {
    my ($self, %args) = validated_hash( \@_,
        rows                           => { isa => "Int", default => 10 },
        page                           => { isa => "Int", default => 1 },
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1,
    );

    my $paged_rs = $self->restriction_log_rs->search(
        { },
        {
            prefetch => "delivery_date_restriction",
            page     => $args{page},
            rows     => $args{rows},
            order_by => { -desc => ["me.datetime", "me.id"] },
        },
    );
    my $total_count = $paged_rs->pager->total_entries;
    my $page_index = $paged_rs->pager->current_page;
    my $page_count = POSIX::ceil( $total_count / $args{rows} );;
    my @rows = $paged_rs->all;

    return {
        log_entries => [ map { $_->as_data } @rows ],
            # e.g.
            # {
            #     id               => 23,
            #     change_time      => "2012-05-02 12:32",
            #     operator         => "Johan Lindstrom",
            #     change_reason    => "Over capacity",
            #     restricted_date  => "2012-06-01",
            #     shipping_charge  => "OUT - 903008-001 - Premier Daytime",
            #     restriction_type => "Fulfilment/Transit",
            #     is_restricted    => "Yes",
            # },
        #],
        pagination => {
            page_index   => $page_index,
            page_count   => $page_count,
            record_count => $total_count,
        },
    };
}

1;
