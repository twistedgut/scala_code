package XT::Data::Fulfilment::Report::Migration;
use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";

=head1 NAME

XT::Data::Fulfilment::Report::Migration - Migration report

=head2 SYNOPSIS

    my $report = $data->{report} = XT::Data::Fulfilment::Report::Migration->new({
        maybe_date_tuple($param, "begin_date"),
        maybe_date_tuple($param, "end_date"),
        container_id => $param->{container_id},
        pid          => $param->{pid},
    });

    for my $row ( $report->stock_adjust_messages_rs->all ) {
        my $container_id = $row->migration_container_id;
        my $container_info = $self->container_info_by_id->{ $container_id };
        say $row->created, $row->delta_quantity, $container_info->{status}
    }

    print $report->as_csv();



=head1 DESCRIPTION

The parameters, and result, for generating the result of the Migration
report.

The interesting bits after instantiating the $report are

  $report->stock_adjust_messages_rs

  $report->container_info_by_id
    hashref with (keys: container_id, values: hashref)

=cut

use DateTime;

use XTracker::Config::Local ( "config_var" );
use NAP::DC::Barcode::Container;

=head1 ATTRIBUTES

=cut

has activemq_message_rs => (
    is      => "ro",
    lazy    => 1,
    default => sub { shift->schema->resultset("Public::ActivemqMessage") },
);

has local_tz => (
    is => "ro",
    default => sub {
        config_var("DistributionCentre", "timezone");
    },
);

=head2 begin_date :

The start date of the report (incusive). Default yesterday.

=cut

has begin_date => (
    is         => "ro",
    isa        => "DateTime",
    lazy_build => 1,
);
sub _build_begin_date {
    my $self = shift;
    return DateTime
        ->now(time_zone => $self->local_tz)
        ->truncate(to => "day")
        ->add(days => -1);
}

=head2 end_date :

End date of the report (inclusive). Default today.

=cut

has end_date => (
    is         => "ro",
    isa        => "DateTime",
    lazy_build => 1,
);
sub _build_end_date {
    my $self = shift;
    return DateTime
        ->now(time_zone => $self->local_tz)
        ->truncate(to => "day");
}

=head2 pid :

Limit the query to this optional Product

=cut

has pid => (
    is  => "rw",
    isa => "Str | Undef",
);

=head2 container_id :

Limit the query to this optional Container

=cut

has container_id => (
    is  => "rw",
    isa => "NAP::DC::Barcode::Container | Str | Undef",
);

=head2 stock_adjust_messages_rs : $rs | undef

ActivemqMessage rs with stock_adjusts within ->begin_date and
->end_date, possibly only for ->pid and ->container_id.

=cut

has stock_adjust_messages_rs => (
    is         => "ro",
    lazy_build => 1,
);
sub _build_stock_adjust_messages_rs {
    my $self = shift;

    my $stock_adjust_messages_rs
        = $self->activemq_message_rs->filter_migration_stock_adjust->search(
            {
                created => {
                    -and => {
                        ">=" => $self->begin_date->ymd,
                        "<"  => $self->end_date->clone->add(days => 1)->ymd,
                    },
                },
                $self->search_clause_for_pid,
                $self->search_clause_for_container_id,
            },
            { order_by => [ { -desc => "created" } ] },
        );

    return $stock_adjust_messages_rs;
}

=head2 container_ids : \@container_ids | undef

Arrayref with container_ids in the stock adjust messages within the
time frame.

If ->container_id is specified, that's the only one
allowed.

=cut

has container_ids => (
    is         => "ro",
    lazy_build => 1,
);
sub _build_container_ids {
    my $self = shift;
    my $stock_adjust_messages_rs = $self->stock_adjust_messages_rs or return undef;
    my $container_ids = $stock_adjust_messages_rs->migration_container_ids;

    if(my $container_id = $self->container_id) {
        $container_ids = [
            grep { $_ eq $container_id }
            @$container_ids,
        ];
    }

    return $container_ids;
}

=head2 container_info_by_id : \%container_info_by_id | undef

Hash ref with (keys: container_id; values: hash ref with (status,
modified, operator_name)), or undef if it couldn't be computed.

=cut

has container_info_by_id => (
    is         => "ro",
    lazy_build => 1,
);
sub _build_container_info_by_id {
    my $self = shift;
    my $container_ids = $self->container_ids
        or return undef;

    my $pprep_container_rs = $self->schema->resultset("Public::PutawayPrepContainer");
    my $stock_adjust_pprep_container_rs = $pprep_container_rs->search(
        { container_id => { -in => $container_ids } },
        {
            prefetch     => [
                "putaway_prep_status",
                "putaway_prep_inventories",
                "operator",
            ],
            order_by => "created",
        },
    );
    my $container_info_by_id = {
        map {
            my $mgid = do {
                if( my $inventory_row = $_->putaway_prep_inventories->first ) {
                    $inventory_row->pgid;
                }
            };

            # in case of duplicates, more recent ones will overwrite
            # earlier (irrelevant) ones
            $_->container_id => {
                status        => $_->putaway_prep_status->status,
                modified      => $_->modified,
                operator_name => $_->operator->name,
                mgid          => $mgid,
            };
        }
        $stock_adjust_pprep_container_rs->all
    };

    return $container_info_by_id;
}

=head1 METHODS


=head2 container_info( $activemq_message_row ) : \%container_info

Return the associated \%container_info (keys: status, modified,
operator_name) for $activemq_message_row, or return undef if there
wasn't one.

=cut

sub container_info {
    my ($self, $activemq_message_row) = @_;
    return $self->container_info_by_id->{
        $activemq_message_row->migration_container_id,
    };
}

=head2 search_clause_for_pid() : () | ( entity_pid => $where_clause )

If ->pid is set, return a DBIC search where clause to limit the query
to that Product, else return empty list.

This relies on the fact that migration stock adjust rows contain the
migrated sku (and on the shape of SKUs).

=cut

sub search_clause_for_pid {
    my $self = shift;
    $self->pid or return ();
    return ( entity_id => { -like => $self->pid . "-%" } );
}

=head2 search_clause_for_container_id() : () | ( content => $where_clause )

If ->container_id is set, return a DBIC search where clause to limit
the query to that Container, else return empty list.

Resilience note: This relies on the fact that migration stock adjust
rows contain the container id in the message payload. It also relies
on the exact JSON formatting of the payload.

Performance note: This is quite inefficient, but probably the least
inefficient way to get at this.

=cut

sub search_clause_for_container_id {
    my $self = shift;
    $self->container_id or return ();
    return (
        content => {
            -like => sprintf(
                q{%%"migration_container_id":"%s"%%},
                $self->container_id,
            ),
        },
    );
}

=head2 csv_file_name : $file_name

The default file name when downloading a CSV file of this report.

=cut

sub csv_file_name {
    my $self = shift;
    return join(
        "_",
        (
            "Migration-report",
            "StockAdjust",
            $self->begin_date->ymd,
            $self->end_date->ymd,
            $self->pid          ? ("PID-"       . $self->pid)          : (),
            $self->container_id ? ("Container-" . $self->container_id) : (),
        )
    ) . ".csv";
}

=head2 as_csv() : $csv_data

Return string with the report rendered as CSV.

=cut

sub as_csv {
    my $self = shift;

    my $csv_string = "";
    my $csv = Text::CSV_XS->new({
        binary=>1,
    });
    my @columns = (
        "Date Adjusted",
        "Container",
        "SKU",
        "Qty adjusted",
        "Operator",
        "Advice Status",
        "MGID",
        "Advice Date",
    );
    $csv->combine(@columns);
    $csv_string .= $csv->string() . "\n";

    for my $row ( $self->stock_adjust_messages_rs->all ) {
        my $container_id = $row->migration_container_id;
        my $container_info = $self->container_info_by_id->{ $container_id };

        $csv->combine(
            $row->created . "",
            $container_id,
            $row->sku,
            $row->delta_quantity,
            $container_info->{operator_name},
            $container_info->{status},
            $container_info->{mgid},
            $container_info->{modified} . "",
        );
        $csv_string .= $csv->string() . "\n";
    }

    return $csv_string;
}

