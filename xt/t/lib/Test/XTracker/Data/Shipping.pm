package Test::XTracker::Data::Shipping;
use NAP::policy     qw( test );

=head1 NAME

Test::XTracker::Data::Shipping

=head1 DESCRIPTION

Provides methods to help with Shipping Charges/Shipping Restrictions and Shipping Accounts.

=cut

use Test::XTracker::Data;
use Test::XT::Rules::Solve;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
    :country
    :sub_region
    :shipping_charge_class
);


=head1 METHODS

=cut

sub premier_account_id {
    my ($class, $name) = @_;

    my $schema = Test::XTracker::Data->get_schema();
    return $schema->resultset("Public::ShippingAccount")->find_premier({
        channel_name => $name,
    })->id;
}

sub no_shipment_account_id {
    my ($class, $name) = @_;

    my $schema = Test::XTracker::Data->get_schema();
    return $schema->resultset("Public::ShippingAccount")->find_no_shipment({
        channel_name => $name,
    })->id;
}

# 2011-09-16* ==> 16/09/2011*
sub to_uk_web_date_format {
    my ($class, $iso_dt) = @_;
    return $iso_dt =~ s|(\d+)-(\d+)-(\d+)(.*)|$3/$2/$1$4|r;
}

sub test_shipment_note {
    my ($class, $shipment, $expected) = @_;
    return unless $expected;

    note("Test DB shipment note");
    my @shipment_notes = $shipment->shipment_notes;
    is(scalar @shipment_notes, 1, "Found one shipment_note");
    like(
        $shipment_notes[0]->note,
        $expected->{shipment_note_qr},
        "  and the description is correct",
    );
}

sub is_shippingcharge_sku {
    my ($class,$sku) = @_;
    my $schema = Test::XTracker::Data->get_schema();
    return $schema->resultset('Any::Variant')
        ->is_shippingcharge_sku( $sku );
}

sub grab_shipping_description {
    my $class = shift;
    my $args  = shift//{};

    if ( $args->{force_create} ) {
        return $class->create_shipping_description($args);
    }

    my $schema = Test::XTracker::Data->get_schema();

    my $sc_rs = $schema->resultset('Public::ShippingCharge')->search(
        {
            'shipping_description.name' => { '!=' => undef },
        },
        {
            join => 'shipping_description',
        }
    );

    if ( $args->{country_override} ) {
        $sc_rs = _restrict_with_override_prices($sc_rs, 'country');
    }
    elsif ( $args->{region_override} ) {
        $sc_rs = _restrict_with_override_prices($sc_rs, 'region');
    }

    my $sc = $sc_rs->slice(0,0)->single();

    if ( $sc && $sc->shipping_description ) {
        return $sc->shipping_description;
    }
    else {
        return $class->create_shipping_description($args);
    }

}

sub _restrict_with_override_prices {
    my ( $rs, $type ) = @_;

    my $table = "${type}_charges";

    $rs = $rs->search(
        {},
        {
            join    => $table,
            select => [ 'me.id', { count => "$table.id" } ],
            group_by => [ 'me.id' ],
            having  => { "count($table.id)" => { '>=', 1 } }
        },
    );

    return $rs;
}

sub create_shipping_description {
    my ($class, $args) = @_;

    my $schema = Test::XTracker::Data->get_schema();

    my $sd = $schema->resultset('Shipping::Description')->create({
        name                      => $args->{name}//'name',
        public_name               => $args->{public_name}//'public name',
        title                     => $args->{title}//'title',
        public_title              => $args->{public_title}//'public title',
        short_delivery_description => $args->{short_delivery_descirption}//'short',
        long_delivery_description => $args->{long_delivery_description}//'long',
        estimated_delivery        => $args->{estimated_delivery}//'estimated delivery',
        delivery_confirmation
            => $args->{delivery_confirmation}//'delivery confirmation',
        shipping_charge_id
            => $args->{shipping_charge_id}//$class->grab_shipping_charge_id({ force_create => 1 }),
    });

    if ( $args->{country_override} ) {
        $sd->shipping_charge->create_related('country_charges', {
            country_id => 1,
            currency_id => 1,
            charge => 100,
        });
    }
    elsif ( $args->{region_override} ) {
        $sd->shipping_charge->create_related('region_charges', {
            region_id => 1,
            currency_id => 1,
            charge => 100,
        });
    }

    return $sd;

}

sub grab_shipping_charge {
    my $class = shift;
    my $args  = shift;

    my $schema = Test::XTracker::Data->get_schema();

    if ( $args->{force_create} ) {
        return $class->create_shipping_charge($args);
    }

    return $schema->resultset('Public::ShippingCharge')->search(undef,{rows=>1})->single;

}

sub create_shipping_charge {
    my $class = shift;
    my $args  = shift;

    my $schema = Test::XTracker::Data->get_schema();

    # Attempt to make a somewhat unique SKU - it's a unique constraint
    # and it needs to be XXXXX-YYY and the parts need to be numeric
    # to avoid warns. This is not perfect but hopefully will do.
    my $sku = substr( rand(1), 2, 5 ) . "-" .  substr( rand(1), 2, 3 );

    my $default_channel_id = Test::XTracker::Data->get_local_channel_or_nap('nap')->id;

    return $schema->resultset('Public::ShippingCharge')->create({
        sku => $args->{sku}//$sku,
        description => $args->{description}//'description',
        charge => $args->{charge}//100,
        class_id => $args->{class_id}//1,
        currency_id => $args->{currency_id}//1,
        flat_rate => $args->{flat_rate}//1,
        channel_id => $args->{channel_id}//$default_channel_id,
        is_enabled => 1,
        is_return_shipment_free => 1,
    });

}

sub grab_shipping_charge_sku {
    my $class = shift;
    my $args  = shift;

    return $class->grab_shipping_charge($args)->sku;
}

sub grab_shipping_charge_id {
    my $class = shift;
    my $args  = shift;

    return $class->grab_shipping_charge($args)->id;
}

sub get_restriction_countries_and_update_product {
    my ($class,  $product ) = @_;

    die 'get_restriction_countries_and_update_product requires a product'
        unless $product;

    die 'get_restriction_countries_and_update_product must be called in array context'
        unless wantarray;

    my $schema = Test::XTracker::Data->get_schema();

    # We're using the non DC specific part of RESTRICTION 1 to test with.
    my @restricted_countries = ( $COUNTRY__TURKEY, $COUNTRY__MEXICO );

    # Get a country gauranteed to pass.
    my $country_pass = $schema->resultset('Public::CountryShippingCharge')
        ->search( {
            'me.country_id'         => { '-not_in' => \@restricted_countries },
            # Make sure it's not an EU country, as this will cause it to
            # fail for the wrong reason.
            'country.sub_region_id' => { '!=' => $SUB_REGION__EU_MEMBER_STATES },
            # make sure it's not the DCs own Country
            'country.country'       => { '!=' => config_var( 'DistributionCentre', 'country' ) },
        }, {
            join => 'country',
        } )
        ->first->country;
    isa_ok( $country_pass, 'XTracker::Schema::Result::Public::Country' );

    my $restriction = Test::XT::Rules::Solve->solve( 'Shipment::restrictions', { restriction => 'CHINESE_ORIGIN' } );

    my $country_fail= $schema->resultset('Public::Country')->find_by_name( $restriction->{address}{country} );
    isa_ok( $country_fail, 'XTracker::Schema::Result::Public::Country' );

    # Set the product shipping attributes.
    $product->shipping_attribute->update( {
        fish_wildlife    => 0, # ensures it doesn't fail bacause of this.
        cites_restricted => 0, # ensures it doesn't fail bacause of this.
        %{ $restriction->{shipping_attribute} },
    } );

    return ( $country_pass, $country_fail );
}

=head2 create_shipping_charges_for_country

    $hash_ref = __PACKAGE__->create_shipping_charges_for_country(
        $country_rec,
        $channel_rec,
        [
            # list of Shipping Amounts to
            # create the Charge records for
            20,
            15,
            10,
        ],
        # optional, will default to DC's currency:
        $currency_rec,
    );

This will create 'shipping_charge' records and then link them to a Country
using the 'country_shipping_charge' table. Pass in a list of Gross Values
that you want the Shipping Charges to be created with.

This method will get the Tax Rate for the Country and then work out what
the Charge should be less Tax and that amount will actually be on the
Shipping Charge record.

This will mean when a Shipping Charge is used for the Country then the
Value should be what is specified in the list of Values passed in to
this Method which will make testing easier as there will be a predicatble
Value.

This returns a Hash Ref. keyed by the Values passed in, each prefixed with
'ship_charge' and then containing the following structure:

    ship_charge_20 => {
        gross_charge  => 20,
        net_charge    => 16,    # with a Tax Rate of 25%
        charge_record => $shipping_charge_rec,
    }

=cut

sub create_shipping_charges_for_country {
    my ( $class, $country, $channel, $charges_to_use, $currency ) = @_;

    my $schema = Test::XTracker::Data->get_schema();

    # get the Tax Rate, if there is one
    my $tax_rate = ( $country->country_tax_rate ? $country->country_tax_rate->rate : 0 );

    # get the Default Currency, if needed
    $currency //= $schema->resultset('Public::Currency')->find_by_name(
        config_var( 'Currency', 'local_currency_code' )
    );

    my %charges;

    # loops round a list of Charges and creates 'shipping_charge' records
    foreach my $charge ( @{ $charges_to_use } ) {

        # make sure when Taxes are added the Shipping Charge
        # is what is expected, so take any taxes off now
        my $actual_charge = $charge;
        if ( $tax_rate ) {
            # using 'sprintf' because I wan't to round the number up
            $actual_charge = sprintf( "%0.2f", ( $charge / ( 1 + $tax_rate ) ) );
        }

        my $rec = $class->create_shipping_charge( {
            charge      => $actual_charge,
            class_id    => $SHIPPING_CHARGE_CLASS__GROUND,
            currency_id => $currency->id,
            channel_id  => $channel->id,
        } );
        $rec->create_related( 'country_shipping_charges', {
            country_id => $country->id,
            channel_id => $channel->id,
        } );
        $charges{ "ship_charge_${charge}" } = {
            gross_charge  => $charge,
            net_charge    => $actual_charge,
            charge_record => $rec->discard_changes,
        };
    }

    return \%charges;
}

=head2 create_shipping_charges_for_shipment

    $hash_ref = __PACKAGE__->create_shipping_charges_for_country(
        $shipment,
        [
            # list of Shipping Amounts to
            # create the Charge records for
            20,
            15,
            10,
        ],
    );

This will create 'shipping_charge' records suitable for a Shipment.
It will get the Shipping Address's Country and then call the
method 'create_shipping_charges_for_country' to create the Charges.

Please see 'create_shipping_charges_for_country' for how the Charges
will be created and what will be returned.

=cut

sub create_shipping_charges_for_shipment {
    my ( $class, $shipment, $charges_to_use ) = @_;

    my $order = $shipment->order;

    # get what's required for 'create_shipping_charges_for_country'
    my $country  = $shipment->shipment_address->country_ignore_case;
    my $currency = $order->currency;
    my $channel  = $order->channel;

    return $class->create_shipping_charges_for_country(
        $country,
        $channel,
        $charges_to_use,
        $currency,
    );
}

1;
