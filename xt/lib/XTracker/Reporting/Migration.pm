package XTracker::Reporting::Migration;
use NAP::policy "class", "tt";

use Time::ParseDate;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Config::Local ("config_var");

use XT::Data::Fulfilment::Report::Migration;
use NAP::DC::Barcode::Container;

sub handler {
    my $handler = XTracker::Handler->new(shift);
    my $data = $handler->{data};

    $data->{export_to_csv} = $handler->clean_body_param("export_to_csv");

    # If invalid container id, warn but allow it through anyway,
    # leading to an empty report
    my $container_id = $handler->clean_body_param("container_id");
    if ($container_id) {
        try {
            $container_id = NAP::DC::Barcode::Container->new_from_id(
                $container_id,
            );
        }
        catch { $handler->xt_warn($_) };
    }

    my %dates = try {
        maybe_date_tuple($handler, "begin_date"),
        maybe_date_tuple($handler, "end_date"),
    }
    catch {
        $handler->xt_warn($_);
        ();
    };

    $data->{report} = try {
        XT::Data::Fulfilment::Report::Migration->new({
            %dates,
            container_id => $container_id,
            pid          => $handler->clean_body_param("pid"),
        });
    }
    catch {
        $handler->xt_warn($_);
        XT::Data::Fulfilment::Report::Migration->new();
    };

    if($handler->xt_has_warnings) {
        return render_template($handler);
    }


    # CSV export
    if( $handler->clean_body_param("export_to_csv") ) {
        return render_csv($handler, $data->{report});
    }


    return render_template($handler);
}

=head2 render_template($handler) : OK

Render the template using $handler, and return the OK HTTP response
code.

=cut

sub render_template {
    my ($handler) = @_;

    my $data = $handler->{data};
    $data->{content} = "reporting/migration.tt";
    $data->{css}     = "/css/reporting/migration.css";
    $data->{js}      = [ "/javascript/jquery.tablesorter.min.js" ];

    return $handler->process_template( undef );
}

=head2 maybe_date_tuple($handler, $name) : ($name => date) | ()

If the param $name is a date, return a tuple, else return ().

=cut

sub maybe_date_tuple {
    my ($handler, $name) = @_;
    my $date = parse_date( $handler->clean_body_param("$name") ) or return ();
    return ($name => $date);
}

=head2 parse_date($date_string) : $datetime | die

Return a DateTime parsed from $date_string (loose, forgiving parsing,
to allow human input).

Die if $date_string is completey incomprehensible.

=cut

sub parse_date {
    my ($date_string) = @_;
    $date_string or return undef;
    my $local_timezone = config_var("DC", "timezone");
    my $epoch = parsedate($date_string, ZONE => $local_timezone)
        or die "Invalid date ($date_string)\n";
    return DateTime->from_epoch( epoch => scalar $epoch);
}

=head2 render_csv($handler, $report) : OK

Render the $report as a CSV file using $handler.

=cut

sub render_csv {
    my ($handler, $report) = @_;
    my $response = $handler->{r};

    # Generate before setting headers, so any errors are sent as text
    my $csv_string = $report->as_csv;

    $response->content_type( "text/csv" );

    # This seems to have limited effect, but is the "correct" way of
    # doing this. The thing that actually sets the download file name
    # is the form action. And that only works because the Apache
    # dispatch ignores the trailing bit.
    my $csv_file_name = $report->csv_file_name;
    $response->headers_out->{"Content-Disposition"}
        = q{attachment;filename="$csv_file_name"};

    $response->print( $csv_string );

    return OK;
}
