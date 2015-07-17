package XTracker::Stock::Actions::PrintLocations;

use strict;
use warnings;

use XT::LP;
use XTracker::Constants::FromDB ':authorisation_level';

use Carp;

use XTracker::Handler;
use XTracker::XTemplate;
use XTracker::Database::Location;
use XTracker::Database::Attributes;
use XTracker::Utilities qw( get_start_end_location );
use XTracker::PrintFunctions;
use XTracker::Config::Local qw( config_var );

use IPC::Open2;

# Handles printing of location bar codes, printing a range of location barcodes
# to a selected printer. Takes 8 parameters specifying the print range (start_floor,
# start_zone, start_location, start_level, end_floor, end_zone, end_location,
# end_level) and 1 additional parameter (printer_name) specifying the target printer.

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $auth_level  = $handler->auth_level;
    my $session     = $handler->session;

    if ($auth_level < $AUTHORISATION_LEVEL__OPERATOR) {
        return $handler->redirect_to('/StockControl/Location/SearchLocationsForm');
    }

    my $redir_url
        = (grep { defined $_ && m{/SearchLocationsForm$} } $handler->{referer})
        ? '/StockControl/Location/SearchLocationsForm'
        : '/StockControl/Location/PrintLocationsForm';

    eval {
        my $printer_name = $handler->{param_of}{"printer_name"};
        my $printer_info = get_printer_by_name($printer_name);

        # This duplicates the error message to the user - xt_warn has no place
        # in the printer classes
        unless ( %{$printer_info||{}} ) {
            $handler->xt_warn( "Could not find printer $printer_name\n" );
            return $handler->redirect_to( $redir_url );
        }

        my $printer = $printer_info->{lp_name};

        my ($start, $end) = get_start_end_location($handler->{param_of});
        my @locations     = generate_location_list($start, $end, $handler->{param_of}{"location_format"});

        # Get Locations for any Location Type
        my @existing_locations = @{get_locations($handler->{dbh})};

        foreach my $location (@locations) {
            if (
                $handler->iws_rollout_phase == 0
             && $handler->prl_rollout_phase == 0
             && (grep {$_->{location} eq $location} @existing_locations) == 0
            ) {
                $handler->xt_info("Skipping $location, does not exist");
                next;
            }

            my ($unit, $aisle, $bay, $position, $floor, $zone, $location_tier);
            my ($level, $readable_location, $data);
            if ($handler->{param_of}{"location_format"} eq 'long_format') {
                ($unit, $floor, $aisle, $bay, $level, $position, $readable_location)
                    = NAP::DC::Location::Format::parse_location_long_format($location);

                $data->{unit}  = $unit;
                $data->{floor} = $floor;
            } else {
                ($floor, $zone, $location_tier, $level, $readable_location)
                    = NAP::DC::Location::Format::parse_location($location);
            }

            $data->{location}          = $location;
            $data->{readable_location} = $readable_location;

            my $label    = "";
            my $template = XTracker::XTemplate->template();

            # create template code
            if ($printer_info->{print_language} eq 'EPL2') {
                $template->process( 'print/location-label-epl2.tt', { template_type => 'none', %$data }, \$label );
            }
            else {
                $template->process( 'print/location-label-zpl.tt', { template_type => 'none', %$data }, \$label );
            }

            # write to label file
            my $label_file_name = XTracker::PrintFunctions::path_for_print_document({
                document_type => 'location',
                id => $location,
                extension => 'lbl',
            });
            open my $fh, ">", $label_file_name || die "Couldn't open file: $!";
            print $fh $label;
            close $fh;

            # print label
            XT::LP->print({
                printer     => $printer_info->{lp_name},
                filename    => $label_file_name,
                copies      => 1,
            });
            $handler->xt_info("Printing $location");
        }
    };
    if ($@) {
        $handler->xt_warn($@);
    }

    return $handler->redirect_to($redir_url);
}


1;
