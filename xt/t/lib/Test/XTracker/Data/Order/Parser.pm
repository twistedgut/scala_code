package Test::XTracker::Data::Order::Parser;
use Moose;

# bring in ->dc
with 'XT::Role::DC';

use NAP::policy "tt", 'test';
use Carp qw/ croak /;
use File::Find::Rule;


use Test::XTracker::Data;

has schema => (
    is      => "ro",
    lazy    => 1,
    default => sub { Test::XTracker::Data->get_schema },
);

# Override in sub classes
has dc_order_template_file => (
    is      => "ro",
    isa     => 'Str',
    default => '',
);

sub order_template_file {
    my $self = shift;
    my $dc = $self->dc;
    my $order_file = $self->dc_order_template_file or die("No Order Template File for DC ($dc)\n" );
    return "$dc/$order_file";
}

# If there aren't any line items then get some.
# Modify $arg in place, and return it.
sub _ensure_order_line_items {
    my ($self, $arg) = @_;

    my $channel = $arg->{channel} || Test::XTracker::Data->channel_for_nap();
    if( ! exists $arg->{order}{items} ) {
        note "No Line Items - So Generating PID's for Channel: " . $channel->name;
        my ($forget, $pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
            channel  => $channel,
            # if fulfilment only (JC) channel make sure Third Party SKUs are created
            ( $channel->business->fulfilment_only ? ( force_create => 1 ) : () ),
        });
        $arg->{order}{items} = [
            {
                sku         => $pids->[0]->{sku},
                description => $pids->[0]->{product}->product_attribute->name,
                unit_price  => 691.30,
                tax         => 48.39,
                duty        => 0.00
            },
        ];
    }

    my $third_party_sku_rs = $self->schema->resultset('Public::ThirdPartySku');
    for my $item( @{ $arg->{order}{items} || [] } ) {
        my $third_party_sku = $third_party_sku_rs->find_by_sku_and_business({
            sku         => $item->{sku},
            business_id => $channel->business->id,
        }) or next;
        $item->{sku} = $third_party_sku->third_party_sku;
    }

    return $arg;
}

=head2 create_and_parse_order( { order data } or [ { order data } ... ] );

Given some Order Data will create an XML file and parse it using the
New Order Importer.  Will return an array ref of 'XT::Data::Order'
objects. Can create multiple files if you pass in the order data in an
Array Ref.

=cut

sub create_and_parse_order {
    my ($self, $args) = @_;
    croak("Abstract method");
}

1;
