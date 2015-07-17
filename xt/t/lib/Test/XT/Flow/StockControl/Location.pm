package Test::XT::Flow::StockControl::Location;

use strict;
use warnings;

use NAP::policy "tt", 'test';



use Moose::Role;
requires 'mech';

with 'Test::XT::Flow::AutoMethods';

=head1 NAME

Test::XT::Flow::StockControl::Location

=head1 DESCRIPTION

Flow convenience methods for the Locations page.


=head1 METHODS

=head2 flow_mech__stockcontrol__location__print_locations_form'

Retrieves the StockControl -> Location -> PrintLocationsForm page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__stockcontrol__location__print_locations_form',
    page_description => 'Print Locations Form',
    page_url         => '/StockControl/Location/PrintLocationsForm',
);


=head2 flow_mech__stockcontrol__location__submit_print_form

Remove sticky pages for the given operator ids.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__stockcontrol__location__submit_print_form',
    form_name        => 'new_location',
    form_button      => 'submit',
    form_description => 'Print range of location barcodes',
    assert_location  => qr{^/StockControl/Location/PrintLocationsForm$},
    transform_fields => sub {
        my ($self,$range_specs,$printer_name) = @_;

        my %form_params = %$range_specs;
        $form_params{'printer_name'} = $printer_name;

        return \%form_params;
    },
);

1;
