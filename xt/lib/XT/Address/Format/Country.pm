package XT::Address::Format::Country;
use NAP::policy 'class';

extends 'XT::Address::Format';

=head1 NAME

XT::Address::Format::Country

=head1 DESCRIPTION

Applies all the formats specified under the System Config group
'PaymentAddressFormatForCountry' and Setting for the country code associated
with the Country in the 'country' field of the address.

For example, if the following System Config settings where present:

PaymentAddressFormatForCountry
    [0] DE = 'FormatOne'

The format 'FormatOne' would be applied to the address.

If the following was present in the config:

PaymentAddressFormatForCountry
    [0] DE = 'FormatOne'
    [1] DE = 'FormatTwo'

The formats 'FormatOne' and 'FormatTwo' would be applied to the address in sequence.

=cut

use XTracker::Config::Local 'sys_config_var';

sub APPLY_FORMAT {
    my $self = shift;

    my $formats = sys_config_var( $self->schema, 'PaymentAddressFormatForCountry',
        $self->address->lookup_country_code_by_country );

    if ( $formats ) {

        $formats = ref( $formats ) eq 'ARRAY'
            ? $formats
            : [ $formats ];

        $self->address->apply_format( $_ )
            foreach @$formats;

    }

}
