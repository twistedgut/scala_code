package Event::Import;
# vim: ts=8 sts=4 et sw=4 sr sta
use Moose;

has parsed_data => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_parsed_data',
    writer  => 'set_parsed_data',
);

has prepared_data => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_prepared_data',
    writer  => 'set_prepared_data',
);

has schema => (
    is      => 'rw',
    isa     => 'XTracker::Schema',
    reader  => 'get_schema',
    writer  => 'set_schema',
);

has wb => (
    is      => 'rw',
    isa     => 'Spreadsheet::ParseExcel::Workbook',
    reader  => 'get_wb',
    writer  => 'set_wb',
);

has ws => (
    is      => 'rw',
    isa     => 'Spreadsheet::ParseExcel::Worksheet',
    reader  => 'get_ws',
    writer  => 'set_ws',
);

has xls_version => (
    is      => 'rw',
    isa     => 'Str',
    reader  => 'get_xls_version',
    writer  => 'set_xls_version',
);

use namespace::clean -except => 'meta';

use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;
use XTracker::Database 'xtracker_schema';
# so we know about compile errors (e.g. no Constants::FromDB)
use XTracker::Schema;

use Data::Dump qw(pp);
use DateTime::Format::Excel;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::Utility qw( ExcelLocaltime );
use Text::CSV;
use Encode;
use Readonly;

Readonly my $FIELD_ENCODING => 'utf8';
Readonly my %FIELD_LENGTHS => (
    internal_title => 60,
    title => 30,
    subtitle => 75,
    dont_miss_out => 255,
);

sub BUILD {
    my ($self) = @_;

    $self->set_schema( xtracker_schema );

    return;
}

sub parse {
    my ($self, $file) = @_;
    my $version;

    my $parser = Spreadsheet::ParseExcel->new;
    my $workbook = $parser->Parse($file)
        or die qq{unable to parse Excel file\n};
    $self->set_wb( $workbook );

    # check all worksheets for a version in the first cell
    for my $worksheet ( $workbook->worksheets() ) {
        my $cell = $worksheet->get_cell(0,1);

        if ($cell->value =~ m{\A[vV]\d+\z}) {
            # let the poor schmuck running the script know what's going on
            warn
                  "Using version "
                . $cell->value
                . " format found in "
                . $worksheet->{Name}
                . " worksheet\n";

            # store the "tech worksheet"
            $self->set_ws( $worksheet );

            # store the version we found
            $self->set_xls_version(
                lc($cell && $cell->value || '')
            );

            # and don't look at any more worksheets
            last;
        }
    }

    # make sure we found a versioned tech worksheet
    if (not defined $self->get_ws) {
        die qq{unable to get (tech) worksheet\n};
    }

    # parse the worksheet based on its version
    my $parse_fn = 'parse_' . $self->get_xls_version;
    if ($self->can($parse_fn)) {
        return $self->$parse_fn;
    }
    else {
        die "Sorry, we don't know how to parse version '@{[$self->get_xls_version]}' workbooks\n";
    }
}

sub prepare {
    my ($self) = @_;

    my $prepare_fn = 'prepare_' . $self->get_xls_version;
    if ($self->can($prepare_fn)) {
        return $self->$prepare_fn;
    }
    else {
        die "no idea how to prepare the bugger\n";
    }

    return;
}

# because v0 and v1 have the same layout, just in different worksheets
sub cell_data_v0 {
    my $self = shift;
    my $cell_data;
    my $ws_data;

    # cell => [ row, col ]
    #   A1 => [ 0, 0 ]
    #   B1 => [ 0, 1 ]
    #   A2 => [ 1, 0 ]
    $cell_data = {
        internal_title      => [ 3, 2 ],            # C4
        event_type_id       => [ 5, 2 ],            # C6
        channel             => [ 6, 2 ],            # C7

        # dates
        publish_date        => [11, 2, 'date' ],    # C11
        publish_time        => [11, 3, 'time' ],    # D11
        publish_vis         => [11, 4 ],            # E11

        announce_date       => [12, 2, 'date' ],    # C12
        announce_time       => [12, 3, 'time' ],    # D12
        announce_vis        => [12, 4 ],            # E12

        start_date          => [13, 2, 'date' ],    # C13
        start_time          => [13, 3, 'time' ],    # D13
        start_vis           => [13, 4 ],            # E13

        end_price_drop_date => [14, 2, 'date' ],    # C14
        end_price_drop_time => [14, 3, 'time' ],    # D14
        end_price_drop_vis  => [14, 4 ],            # E14

        end_date            => [15, 2, 'date' ],    # C15
        end_time            => [15, 3, 'time' ],    # D15
        end_vis             => [15, 4 ],            # E15

        close_date          => [16, 2, 'date' ],    # C16
        close_time          => [16, 3, 'time' ],    # D16
        close_vis           => [16, 4 ],            # E16

        # content
        title               => [21, 2 ],            # C21
        subtitle            => [22, 2 ],            # C22
        description         => [23, 2 ],            # C23
        dont_miss_out       => [24, 2 ],            # C24

        # Retail
        pid_list            => [29, 2, 'csv'  ],    # C29
    };

    foreach my $location (sort keys %{$cell_data}) {
        my $cell_value = $self->cell_value( $self->get_ws, $cell_data->{$location} );
        $ws_data->{$location} = $cell_value;
    }

    return $ws_data;
}

sub cell_data_v1 {
    my $self = shift;
    my $cell_data;
    my $ws_data;

    # cell => [ row, col ]
    #   A1 => [ 0, 0 ]
    #   B1 => [ 0, 1 ]
    #   A2 => [ 1, 0 ]
    $cell_data = {
        internal_title      => [ 3, 2 ],            # C4
        event_type_id       => [ 5, 2 ],            # C6
        channel             => [ 6, 2 ],            # C7

        # dates
        publish_date        => [13, 2, 'date' ],    # C14
        publish_time        => [13, 3, 'time' ],    # D14
        publish_vis         => [13, 4 ],            # E14

        announce_date       => [14, 2, 'date' ],    # C15
        announce_time       => [14, 3, 'time' ],    # D15
        announce_vis        => [14, 4 ],            # E15

        start_date          => [15, 2, 'date' ],    # C16
        start_time          => [15, 3, 'time' ],    # D16
        start_vis           => [15, 4 ],            # E16

        end_price_drop_date => [16, 2, 'date' ],    # C17
        end_price_drop_time => [16, 3, 'time' ],    # D17
        end_price_drop_vis  => [16, 4 ],            # E17

        end_date            => [17, 2, 'date' ],    # C18
        end_time            => [17, 3, 'time' ],    # D18
        end_vis             => [17, 4 ],            # E18

        close_date          => [18, 2, 'date' ],    # C19
        close_time          => [18, 3, 'time' ],    # D19
        close_vis           => [18, 4 ],            # E19

        # content
        title               => [23, 2 ],            # C24
        subtitle            => [24, 2 ],            # C25
        description         => [25, 2 ],            # C26
        dont_miss_out       => [26, 2 ],            # C27

        # Retail
        pid_list            => [31, 2, 'csv'  ],    # C32
    };

    foreach my $location (sort keys %{$cell_data}) {
        my $cell_value = $self->cell_value( $self->get_ws, $cell_data->{$location} );
        $ws_data->{$location} = $cell_value;
    }

    return $ws_data;
}

sub parse_v0 {
    my ($self) = @_;
    my $ws_data;

    # v0 only has one worksheet, the tech one
    # if we have any more than this it's the "incorrect" version with the
    # business worksheet added (but version left at v0)
    if ( (my $wscount = @{$self->get_wb->{Worksheet}}) > 1 ) {
        die "v0 spreadsheets only have one tab, this workbook has $wscount\n";
    }

    $self->set_parsed_data(
        $self->cell_data_v0
    );

    return 1;
}

sub parse_v1 {
    my ($self) = @_;
    my $ws_data;

    # v1 should have exactly two worksheets
    if ( 2 != (my $wscount = @{$self->get_wb->{Worksheet}}) ) {
        die "v0 spreadsheets only have one tab, this workbook has $wscount\n";
    }

    $self->set_parsed_data(
        $self->cell_data_v1
    );

    return 1;
}

sub prepare_v0 {
    my ($self) = @_;
    my ($data, $prepared_data, $time_zone);

    $data = $self->get_parsed_data;

    # get the channel we're using
    # (promotions doesn't use channels in the same way - it was
    # pre-chanellisation)
    my $channel_rs = $self->get_schema->resultset('Promotion::Website');
    my $channel = $channel_rs->search({name => { -ilike => $data->{channel} }})->first;
    if (not defined $channel) {
        die "CHANNEL: '$data->{channel}' is not a valid channel\n";
    }
    # choose the timezone
    if (q{OUT-Intl} eq $channel->name) {
        $time_zone = 'Europe/London';
    }
    elsif (q{OUT-AM} eq $channel->name) {
        $time_zone = 'America/New_York';
    }
    # choose the target city
    my $target_city_rs = $self->get_schema->resultset('Promotion::TargetCity');
    my $target_city = $target_city_rs->search({timezone => { -ilike => $time_zone }})->first;

    foreach my $field (qw/internal_title title subtitle description dont_miss_out/) {
        if (defined $FIELD_LENGTHS{$field}) {
            my $actual_len = length( $data->{$field} );
            my $allow_len = $FIELD_LENGTHS{$field};
            if ($actual_len > $allow_len) {
                pp $data;
                warn $data->{$field};
                die   "Data for field ($field) is too long ($actual_len). "
                    . "Only $allow_len chars allowed. "
                    . "$actual_len given.\n";
            }
        }
    }

    # event.detail record data
    $prepared_data->{detail} = {
        internal_title                  => $data->{internal_title},
        title                           => $data->{title},
        subtitle                        => $data->{subtitle},
        description                     => $data->{description},
        event_type_id                   => $data->{event_type_id},
        dont_miss_out                   => ($data->{dont_miss_out} ? $data->{dont_miss_out} : undef),
        product_page_visible            => 1, # always 1, I hope
        target_city_id                  => $target_city->id,

        publish_to_announce_visibility  => $data->{publish_vis},
        announce_to_start_visibility    => $data->{announce_vis},
        start_to_end_visibility         => $data->{start_vis},
        end_to_close_visibility         => $data->{end_vis},

        created_by                      => 1, # else it complains on pushing to pws
    };

    # turn separate datetimes into a single datetime
    my @datefields = qw<publish announce start end_price_drop end close>;
    foreach my $datefield (@datefields) {
        my $date = $data->{ "${datefield}_date" };
        my $time = $data->{ "${datefield}_time" };

        if (not defined $date or $date =~ m{\A\s*\z}) {
            # make sure the field is "undefined"
            $prepared_data->{detail}{ "${datefield}_date" } = undef;
            warn "no ${datefield}_date\n";
            next;
        }

        # set the time zone (based on channel/website)
        # *BEFORE* we specify any time data
        $date->set_time_zone($time_zone);

        if (defined $time and q{ARRAY} eq ref($time)) {
            my ($sec, $min, $hr) = @{ $time };
            $date->set( hour => $hr, minute => $min, second => $sec );
        }

        # now change the date to be in UTC
        $date->set_time_zone('UTC');

        # store the date in the event.detail record data
        $prepared_data->{detail}{ "${datefield}_date" } = $date;
    }

    # event.detail_websites
    my $websites_rs = $self->get_schema->resultset('Promotion::Website')->search(
        {
            name => { ilike => $data->{channel} },
        }
    );

    if (not defined $websites_rs or $websites_rs->count == 0 or $websites_rs->count > 1) {
        die "Either cannot match $data->{channel} or multiple matches";
    }

    $prepared_data->{website_id} = $websites_rs->first->id;

    # event.detail_product
    my $product_rs = $self->get_schema->resultset('Public::Product');
    foreach my $pid ( @{ $data->{pid_list} } ) {
        my $product_exists = $product_rs->count(id => $pid);

        if ($product_exists) {
            push @{ $prepared_data->{detail_product} }, $pid;
        }
        else {
            warn "product #$pid doesn't exist in the product table\n";
        }
    }

    $self->set_prepared_data( $prepared_data );
    return 1;
}

sub prepare_v1 {
    my $self = shift;
    # thankfully the prepare work is the same as the v0 format
    return $self->prepare_v0;
}

sub create_event {
    my ($self) = @_;

    if (not defined $self->get_prepared_data) {
        $self->prepare;
        if (not defined $self->get_prepared_data) {
            die "no prepared data to create event from\n";
        }
    }

    # if we don't have any products, don't create anything
    if (not exists $self->get_prepared_data->{detail_product}) {
        die "no products. no event.\n";
    }

    # do everything inside a transaction
    my $event;
    eval {
        $self->get_schema->txn_do(sub{
            # create the core details
            $event = $self->get_schema->resultset('Promotion::Detail')->create(
                $self->get_prepared_data->{detail}
            );
            $event->discard_changes; # so we can get the DB generated values

            if (not $self->get_schema->resultset('Promotion::DetailWebsites')->create(
                {
                    event_id => $event->id,
                    website_id => $self->get_prepared_data->{website_id},
                }
            )) {

                die "Cannot create promotion.detail_websites join record for "
                    .$event->id ."/". $self->get_prepared_data->{website_id};
            }

            # now we have an event we can tie our products to it
            foreach my $pid ( @{ $self->get_prepared_data->{detail_product} } ) {
                # insert an event-product join record
                my $rec = $self->get_schema->resultset('Promotion::DetailProducts')->create(
                    {
                        event_id    => $event->id,
                        product_id  => $pid,
                    }
                );
                if (not defined $rec or not $rec->id) {
                    die "Could not create promotion.detail_product";
                }
            }

            # TODO create a custom list

            # TODO populate it
            #$self->get_schema->txn_rollback; warn "ROLLBACK\n";
        });
    };
    if (my $e = $@) {
        die $e;
    }

    # print a vaguely helpful report
    $self->print_vaguely_helpful_report($event);

    return;
}

sub print_vaguely_helpful_report {
    my ($self, $event) = @_;

    my $tz = $event->target_city->timezone;
    print "\n----------------\n";
    print "      New Event:  " . $event->visible_id . "\n";
    print "          Title:  " . $event->internal_title . "\n";
    print "   Public Title:  " . $event->title . "\n";
    print "      Target TZ:  " . $event->target_city->timezone . "\n";
    print "   Publish Date:  " . utc_and_local($event->publish_date, $tz) . "\n";
    print "  Announce Date:  " . utc_and_local($event->announce_date, $tz) . "\n";
    print "     Start Date:  " . utc_and_local($event->start_date, $tz) . "\n";
    print "Price Drop Date:  " . utc_and_local($event->end_price_drop_date, $tz) . "\n";
    print "       End Date:  " . utc_and_local($event->end_date, $tz) . "\n";
    print "     Close Date:  " . utc_and_local($event->close_date, $tz) . "\n";
    print "----------------\n";

    return;
}


sub utc_and_local {
    my ($datetime, $time_zone) = @_;
    my $return_string;

    return '' if (not defined $datetime);

    $return_string = sprintf(
        "%s %s %s (%s %s %s)",
        $datetime->set_time_zone('UTC')->ymd,
        $datetime->set_time_zone('UTC')->hms,
        $datetime->set_time_zone('UTC')->time_zone_short_name,
        $datetime->set_time_zone($time_zone)->ymd,
        $datetime->set_time_zone($time_zone)->hms,
        $datetime->set_time_zone($time_zone)->time_zone_short_name,
    );

    return $return_string;
}

sub cell_value {
    my (undef, $ws, $rowcol) = @_;
    my $cell = $ws->get_cell($rowcol->[0], $rowcol->[1]);
    my $value;

    if (defined $cell) {
        # deal with oddness caused by extended dashes, and other oddities
        # e.g. Mo INTL GGG should Fail – kfkd
        if (defined $cell->{Code} and 'ucs2' eq $cell->{Code}) {
            $value = Encode::decode("ucs2", $cell->unformatted);
        }
        else {
            $value = $cell->unformatted;
        }
    }

    if (defined $value && defined (my $type = $rowcol->[2])) {
        # parse dates
        if ('date' eq $type) {
            if ($value !~ m{\A\s*\z}) {
                eval {
                    $value = DateTime::Format::Excel->parse_datetime( $value );
                };
                if (my $e = $@) {
                    # tidy up the error:
                    $e =~ s/ at.+line.*$//s;
                    warn "Invalid date '$value' at @{[_excel_cell(@{$rowcol})]} - $e\n";
                }
            }
        }
        # parse times
        elsif ('time' eq $type) {
            if ($value !~ m{\A\s*\z}) {
                my @values = ExcelLocaltime( $value );
                $value = \@values;
            }
        }
        # comma separated values
        elsif ('csv' eq $type) {
            my $csv = Text::CSV->new(
                {allow_whitespace=>1}
            );
            $csv->parse($value);
            my @columns = $csv->fields();
            $value = \@columns;
        }
        # unexpected type
        else {
            die "unknown type '$type' for cell\n";
        }
    }

    return $value;
}

sub _excel_cell {
    my ($r, $c);

    if (@_ == 1) {
        ($r, $c) = @{$_[0]};
    } else {
        ($r, $c) = @_;
    }

    my $letters = ['A' .. 'Z'];

    if ($c > 25) {
        $c = join('', @$letters[ $c/26 - 1, $c % 26]);
    } else {
        $c = $letters->[$c];
    }

    return $c . ($r+1);
}
1;
