package Test::XT::Data::Quantity;

use NAP::policy "tt",     qw( test role );

requires 'dbh';
requires 'schema';

has 'attr__quantity__quantities_by_variant' => (
    is  => 'rw',
);

#
# Quantity data for the Test Framework
#
#use XTracker::Config::Local;
#use Test::XTracker::Data;


use XTracker::Constants::FromDB qw(
    :flow_status
);


# Finda quantity record for a variant in a given location, or create one
# if there is not one
#
# Takes hashref of params and returns quantity resultset, or undef
#
# Required params:
#   location OR location_id OR location_name
#   variant OR variant_id
#
# Optional params:
#   quantity (default 23)
#   status_id ($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS)
#
# Updates attr__quantities_by_variant, which is a hashref (keyed on variant_id)
# of arrayrefs of quantity ids
#
sub data__quantity__insert_quantity {
    my($self,$args) = @_;

    note "SUB data__quantity__insert_quantity";

    my ($variant_id, $location_id, $quantity_value, $status_id, $channel_id);

    $quantity_value  = $args->{'quantity'}  ||  23;
    $status_id       = $args->{'status_id'} ||  $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    if ($args->{'location_id'}) {
        $location_id = $args->{'location_id'};
    } elsif ($args->{'location_name'}) {
        my $location = $self->schema->resultset('Public::Location')->search({
            'location' => $args->{'location_name'},
        })->first;
        $location_id = $location->id;
    } elsif ($args->{'location'}) {
        $location_id = $args->{'location'}->id;
    } else {
        note "you must supply location OR location_id OR location_name";
        return;
    }

    if ($args->{'variant_id'}) {
        $variant_id = $args->{'variant_id'};
    } elsif ($args->{'variant'}) {
        $variant_id = $args->{'variant'}->id;
    } else {
        note "you must supply variant OR variant_id";
        return;
    }

    if ($args->{'channel_id'}) {
        $channel_id = $args->{'channel_id'};
    } elsif ($args->{'channel'}) {
        $channel_id = $args->{'channel'}->id;
    } else {
        note "you must supply channel OR channel_id";
        return;
    }

    my $quantity = $self->schema->resultset('Public::Quantity')->find_or_create({
        location_id => $location_id,
        variant_id  => $variant_id,
        channel_id  => $channel_id,
        status_id   => $status_id,
    });
    $quantity->update({
        quantity => $quantity_value,
    });

    note "inserted quantity [".$quantity->id."] for variant [$variant_id]";

    # TODO: there must be a nicer moose way to do this
    my $attr__quantity__quantities_by_variant = $self->attr__quantity__quantities_by_variant;
    $attr__quantity__quantities_by_variant->{$variant_id} ||= [];
    push @{$attr__quantity__quantities_by_variant->{$variant_id}}, $quantity->id;
    note "pushed ".$quantity->id." onto attr__quantity__quantities_by_variant for ".$variant_id;
    $self->attr__quantity__quantities_by_variant($attr__quantity__quantities_by_variant);

    return $quantity;
}

sub data__quantity__delete_quantity_by_type{
    my($self,$args) = @_;
    my ($variant_id,  $channel_id);

    if (!$args->{status_id}){
        note "you must supply a quantity status_id ";
        return;
    }
    if ($args->{'variant_id'}) {
        $variant_id = $args->{'variant_id'};
    }
    elsif ($args->{'variant'}) {
        $variant_id = $args->{'variant'}->id;
    }
     else {
        note "you must supply variant OR variant_id";
        return;
    }

    if ($args->{'channel_id'}) {
        $channel_id = $args->{'channel_id'};
    } elsif ($args->{'channel'}) {
        $channel_id = $args->{'channel'}->id;
    } else {
        note "you must supply channel OR channel_id";
        return;
    }

    my $quantity = $self->schema->resultset('Public::Quantity')->search({
                variant_id => $variant_id,
                status_id  => $args->{status_id},
                channel_id => $channel_id
            })->delete_all;

    return;


}
1;
