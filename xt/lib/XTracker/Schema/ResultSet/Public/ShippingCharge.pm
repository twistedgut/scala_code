package XTracker::Schema::ResultSet::Public::ShippingCharge;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp;

=head1 NAME

XTracker::Schema::ResultSet::Public::ShippingCharge - DBIC resultset

=head1 DESCRIPTION

DBIx::Class resultset for shipping charges

=head1 METHODS

=head2 find_by_sku

Finds shipping chage by its SKU

=cut

sub find_by_sku {
    my $self = shift;
    my $sku = shift or croak 'Must supply a SKU';

    return $self->search({sku => $sku})->first;
}

=head2 find_unknown

    my $charge = $shipping_charge_rs->find_unknown;

Finds the 'Unknown' shipping charge.

=cut

sub find_unknown {
    my ( $self ) = @_;

    return $self->search({ description => 'Unknown' })->first;
}

=head2 find_by_channel_sku

Finds shipping charge by its channel/sku

=cut

sub find_by_channel_sku {
    my($self,$channel_id,$sku) = @_;
    croak 'Must supply a SKU' if (!defined $sku);
    croak 'Must supply a channel_id' if (!defined $channel_id);

    return $self->search({
        sku         => $sku,
        channel_id  => $channel_id,
    });
}

=head2 enabled : ResultSet

A filter to only give the shipping_charge records where is_enabled is TRUE

=cut

sub enabled {
    my($self) = @_;
    return $self->search({
        is_enabled => 1,
    });
}

sub is_nominated_day {
    my $self = shift;
    $self->search({ latest_nominated_dispatch_daytime => { "!=" => undef } });
}

sub search_nominated_day_id_description {
    my $self = shift;

    $self->is_nominated_day->search(
        { },
        {
            select   => [ "me.description", \"array_to_string( array_agg(me.id order by me.id), '-')" ],
            as       => [ "description", "composite_id" ],
            group_by => "me.description",
            order_by => "me.description",
        }
    );
}

# Return e.g.
#     [
#     {
#         description  => "Premier Daytime",
#         composite_id => "61-63-71",
#     },
#     {
#         description  => "Premier Evening",
#         composite_id => "62-64-72",
#     },
# ];
sub get_all_nominated_day_id_description {
    my $self = shift;

    my $shipping_charges = [
        map {
            +{
                description  => $_->description,
                composite_id => $_->get_column("composite_id"),
            };
        }
        $self->search_nominated_day_id_description()->all
    ];

    return $shipping_charges;
}

1;

