package NAP::ShippingOption;
use Moose;

=head1 NAME

NAP::ShippingOption - A Shipping Option factory and sub classes for various codes

=cut

use Carp qw/ croak /;
use MooseX::Types::Moose qw(Bool Str Int Num ArrayRef HashRef Maybe);
use MooseX::Params::Validate;

use XTracker::Config::Local qw( config_var );

# use Module::Pluggable(
#     search_path => ['NAP::ShippingOption'],
#     sub_name    => 'shipping_options',
#     require     => 1,
# );

#use XTracker::Constants::FromDB qw( :shipment_type );

=head1 PROPERTIES

=head2 label_count : Int

The number of labels to print.

Readonly.

=head2 global_product_code

This is a single character code that DHL uses to specify a particular service,
e.g. N denotes DOMESTIC EXPRESS (see the ReferenceData.xls file provided with the
DHL XMLPI toolkit for the full product code list).

This code is used at the labelling stage to request a particular service, which
will appear on the label.

=cut

sub label_count {
    my $self = shift;
    return 2;
}

has code                                   => (is => "ro", isa => "Str", required => 1    );
has routing_number                         => (is => "ro", isa => "Int"                   );
has physical_vouchers_only_fallback_code   => (is => "ro", isa => "Str", default  => undef);
has description                            => (is => "ro", isa => "Str"                   );

# Does not correspond to a country. Could me made to correspond to a
# zone but probably not
has region_description                     => (is => "ro", isa => "Str", required => 1    );
has type                                   => (is => "ro", isa => "Str", required => 1    );
has carrier_product_name                   => (is => "ro", isa => "Str", required => 1    );
has default_description_of_goods           => (is => "ro", isa => "Str", required => 1    );
has default_dhl_service_type               => (is => "ro", isa => "Str", required => 1    );
has global_product_code                    => (is => "ro", isa => "Str", required => 1    );

no Moose;
__PACKAGE__->meta->make_immutable;


=head1 CLASS METHODS

=head2 new_from_query_hash(%$args) : $new_subclassed_shipping_option_objects

Create a new object depending on the values in $args. $args:

 * shipping_account_name - e.g. International Road. Really the Shipping Account Type.
 * shipment_type - e.g. Domestic, or International DDU.
 * is_voucher_only - 1|0. Whether the shipment contains only physical vouchers.

Die if an object couldn't be created.

Note: this is currently only valid for Carrier: DHL.

=cut

sub new_from_query_hash {
    my $class = shift;
    my %args = validated_hash( \@_,
        shipping_account_name          => { isa => 'Str' , required => 1 },
        shipment_type                  => { isa => 'Str' , required => 1 },
        sub_region                     => { isa => 'Str' , required => 1 },
        is_voucher_only                => { isa => 'Bool', required => 1 },
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1,
    );

    my $code;
    if ( config_var('DHL', 'use_2nd_gen_products') eq 'yes' ) {
        if ($args{shipment_type} eq "Domestic") {
            $code = 'DOM';
        }
        elsif ( $args{is_voucher_only} ) {
            $code = 'BTC';
        }
        else {
            $code = 'WPX';
        }
    }
    else {
        if ( config_var('DHL', 'xmlpi_region_code') eq 'AM' ) {
           $code = $args{is_voucher_only} ? 'DOX' : 'WPX';
        }
        else {
            my $dhl_shipping_option_code = {
                EU    => "ECX",
                Other => "WPX",
            };
            if ($args{shipping_account_name} eq "International Road") {
                $dhl_shipping_option_code = {
                    EU    => "ESU",
                    Other => "ESI",
                };
            }

            # Domestic UK - DOM
            if ($args{shipment_type} eq "Domestic") {
                $code = "DOM";
            }
            # EC Countries - ECX / ESU
            elsif ($args{sub_region} eq "EU Member States") {
                $code = $dhl_shipping_option_code->{EU};
            }
            # Other - WPX / ESI
            else {
                $code = $dhl_shipping_option_code->{Other};
            }

            # If WPX and only vouchers, downgrade the product_code to DOX
            # (there is no corresponding downgrade for ESI)
            if ( $code eq "WPX" && $args{is_voucher_only} ) {
                $code = "DOX";
            }
        }
    }

    return $class->new_from_code(
        code => $code,
    );
}

sub new_from_code {
    my $class = shift;
    my %args = validated_hash( \@_,
        code => { isa => 'Str' , required => 1 },
    );


    # Instantiate sub-classes here if needed to put logic specific to
    # a ShippingOption code somewhere


    my $object_args = $class->code_attributes->{$args{code}} or die("Could not find attributes for code ($args{code})");
    my $self = $class->new({
        code => $args{code},
        %$object_args,
    });

    return $self;
}

# These values are bound for a table, so keep them here in one place
sub code_attributes {
    my $code_attributes = {
        DOM => {
            physical_vouchers_only_fallback_code => "",
            description                          => "National",
            region_description                   => "UK",
            type                                 => "Domestic",
            carrier_product_name                 => "DHL Domestic Worldwide",
            routing_number                       => 46,
            default_description_of_goods         => "CLOTHING PERSONAL USE",
            default_dhl_service_type             => "",
            global_product_code                  => "N",
        },
        ECX => {
            physical_vouchers_only_fallback_code => "",
            description                          => "",
            region_description                   => "EU",
            type                                 => "International",
            carrier_product_name                 => "DHL Express Worldwide",
            routing_number                       => 51,
            default_description_of_goods         => "CLOTHING PERSONAL USE",
            default_dhl_service_type             => "",
            global_product_code                  => "U",
        },
        DOX => {
            physical_vouchers_only_fallback_code => "",
            description                          => "Non dutiable. Used e.g. for vouchers-only",
            region_description                   => "Outside EU",
            type                                 => "International",
            carrier_product_name                 => "DHL Express Worldwide",
            routing_number                       => 42,
            default_description_of_goods         => "CLOTHING PERSONAL USE",
            default_dhl_service_type             => "DOX",
            global_product_code                  => "D",
        },
        WPX => {
            physical_vouchers_only_fallback_code => "DOX",
            description                          => "Dutiable",
            region_description                   => "Outside EU",
            type                                 => "International",
            carrier_product_name                 => "DHL Express Worldwide",
            routing_number                       => 48,
            default_description_of_goods         => "CLOTHING PERSONAL USE/",
            default_dhl_service_type             => "DDP",
            global_product_code                  => "P",
        },
        ESU => {
            physical_vouchers_only_fallback_code => "",
            description                          => "",
            region_description                   => "EU",
            type                                 => "International Road",
            carrier_product_name                 => "DHL Economy Select",
            routing_number                       => 40,
            default_description_of_goods         => "CLOTHING PERSONAL USE",
            default_dhl_service_type             => "",
            global_product_code                  => "W",
        },
        ESI => {
            physical_vouchers_only_fallback_code => "",
            description                          => "",
            region_description                   => "Outside EU",
            type                                 => "International Road",
            carrier_product_name                 => "DHL Economy Select",
            routing_number                       => 57,
            default_description_of_goods         => "CLOTHING PERSONAL USE/",
            default_dhl_service_type             => "DDP",
            global_product_code                  => "H",
        },
        BTC => {
            physical_vouchers_only_fallback_code => "",
            description                          => "Non dutiable. Used e.g. for vouchers-only",
            region_description                   => "International",
            type                                 => "International",
            carrier_product_name                 => "DHL Express Worldwide",
            routing_number                       => 42,
            default_description_of_goods         => "CLOTHING PERSONAL USE",
            default_dhl_service_type             => "",
            global_product_code                  => "2",
        },
    };
}

=head1 METHODS

=head2 dhl_service_type({ shipment_type, is_voucher_only }) : Str

Return the DHL service type string for this shipping code.

=cut

sub dhl_service_type {
    my $self = shift;
    my %args = validated_hash( \@_,
        shipment_type   => { isa => 'Str', required => 1 },
        is_voucher_only => { isa => 'Str', required => 1 },
    );

    # Only for International (e.g. not for International DDU)
    if($args{shipment_type} ne "International") {
        return "";
    }

    my $dhl_service_type = $self->default_dhl_service_type or return "";

    if($args{is_voucher_only}) {
        $dhl_service_type = config_var('DHL', 'use_2nd_gen_products') eq 'yes' ? "" : "DOX";
    }

    return $dhl_service_type;
}

1;
