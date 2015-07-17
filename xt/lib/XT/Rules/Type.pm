package XT::Rules::Type;

use strict;
use warnings;
use Moose::Util::TypeConstraints;

my $n = 'XT::Rules::Type::';

# Define DBIC object class types, used for coercions
class_type $n . $_, { class => $_ } for map {
    "XTracker::Schema::Result::Public::$_"
} qw{Shipment Business Location Product Channel};

subtype 'XT::Rules::Type::carrier_id', as 'Int';

subtype 'XT::Rules::Type::carrier_name', as 'Str',
    where { my $c = $_; grep { $_ eq $c } ('UPS', 'DHL Express') };

subtype 'XT::Rules::Type::dc_name', as 'Str', where { /^DC[123]$/ };

# Used by PickSheet::select_printer
subtype 'XT::Rules::Type::location', as 'Str';

SMARTMATCH: {
    use experimental 'smartmatch';
    subtype 'XT::Rules::Type::manifest_format', as 'Str',
        where { $_ ~~ [q{}, qw/csv dhl/] };
}

# Used by PickSheet::select_printer
subtype 'XT::Rules::Type::printer', as 'Str';

subtype 'XT::Rules::Type::dummy', as 'Bool';

# Used by PickSheet::select_printer
subtype 'XT::Rules::Type::printer_type', as 'Str';

# Used by PickSheet::select_printer
subtype "XT::Rules::Type::Shipment::is_transfer", as 'Bool';
coerce 'XT::Rules::Type::Shipment::is_transfer'
    => from $n . 'XTracker::Schema::Result::Public::Shipment'
        => via { $_->is_transfer_shipment };

# Used by PickSheet::select_printer
subtype "XT::Rules::Type::Shipment::is_premier", as 'Bool';
coerce 'XT::Rules::Type::Shipment::is_premier'
    => from $n . 'XTracker::Schema::Result::Public::Shipment'
        => via { $_->is_premier };

# Used by PickSheet::select_printer
subtype "XT::Rules::Type::Shipment::is_staff", as 'Bool';
coerce 'XT::Rules::Type::Shipment::is_staff'
    => from $n . 'XTracker::Schema::Result::Public::Shipment'
        => via { $_->is_staff_order };

# Used by PickSheet::select_printer
subtype "XT::Rules::Type::Business::config_section", as 'Str';
coerce 'XT::Rules::Type::Business::config_section'
    => from $n . 'XTracker::Schema::Result::Public::Business'
        => via { $_->config_section };

# Used by PickSheet::select_printer
subtype "XT::Rules::Type::Location::floor", as 'Str';
coerce 'XT::Rules::Type::Location::floor'
    => from $n . 'XTracker::Schema::Result::Public::Location'
        => via { $_->floor };

subtype 'XT::Rules::Type::channel_id', as 'Int';

subtype 'XT::Rules::Type::printer_name', as 'Str';

# to be used in case when more then one printer name is required
subtype 'XT::Rules::Type::printer_names', as 'ArrayRef[Str]';

# Used by Utilities::location_format
subtype 'XT::Rules::Type::location_format', as 'Str',
    where { /^\d\d/ };

# Used by PrintFunctions::small_label_template
subtype 'XT::Rules::Type::small_label_template', as 'Str';
subtype 'XT::Rules::Type::print_language', as 'Str',
    where { /(ZPL|EPL2)/ };
subtype 'XT::Rules::Type::printer_name', as 'Str';

# Used by PrintFunctions::large_label_template
subtype 'XT::Rules::Type::large_label_template', as 'Str';

subtype 'XT::Rules::Type::validate_rtv_stock_location', as 'Str';
subtype 'XT::Rules::Type::validate_main_stock_location', as 'Str';
subtype 'XT::Rules::Type::stock_type', as 'Str';
subtype 'XT::Rules::Type::is_outnet', as 'Bool';
subtype 'XT::Rules::Type::floor', as 'Int|Undef';

# Used by Shipment::tax_included
subtype 'XT::Rules::Type::country_record', as 'HashRef',
    where {
        exists $_->{id}            &&
        exists $_->{country}       &&
        exists $_->{sub_region_id}
    };

# Used by Shipment::restrictions
subtype 'XT::Rules::Type::product_ref', as 'Undef|HashRef',
    where {
        foreach my $record ( values %$_ ) {
            return 0 unless
                exists $record->{country_of_origin} &&
                exists $record->{cites_restricted} &&
                exists $record->{is_hazmat} &&
                exists $record->{fish_wildlife};
        }
        return 1;
    };

subtype 'XT::Rules::Type::address_ref', as 'HashRef',
    where {
        exists $_->{country}       &&
        exists $_->{country_code}  &&
        exists $_->{sub_region}    &&
        exists $_->{county}        &&
        exists $_->{postcode}
    };

# Used by Database::Pricing::product_selling_price::vertext_workaround
subtype 'XT::Rules::Type::country', as 'Str';
subtype 'XT::Rules::Type::county', as 'Str';

# Used by Shipment::exclude_shipping_charges_on_restrictions
subtype 'XT::Rules::Type::shipping_charges_ref', as 'HashRef';
subtype 'XT::Rules::Type::shipping_attributes', as 'HashRef';
subtype 'XT::Rules::Type::always_keep_sku', as 'Str|Undef';

# Used by Shipment::restrictions
subtype 'XT::Rules::Type::channel', as 'XTracker::Schema::Result::Public::Channel';

# Used by Configuration::Schema
subtype 'XT::Rules::Type::schema', as 'XTracker::Schema';

# Used by 'Address::is_postcode_in_list_for_country'
subtype 'XT::Rules::Type::country_id', as 'Int';
subtype 'XT::Rules::Type::postcode', as 'Undef|Str';
subtype 'XT::Rules::Type::postcode_list', as 'Undef|ArrayRef[Str]';

subtype 'XT::Rules::Type::department_id', as 'Int';
subtype 'XT::Rules::Type::signature_required_flag', as 'Bool';
1;
