package XT::Data::StockReconcile::PrlStockReconcile;
# vim: set ts=4 sw=4 sts=4:
use NAP::policy "tt", "role";

=head1 DESCRIPTION

This module contains methods to reconcile XTracker's stock with PRLs'.

=cut

use File::Temp;
use MooseX::Params::Validate;

use XTracker::Config::Local qw( config_var );
use XT::Data::StockReconcile::XTInventoryQuery;
use XT::Data::StockReconcile::StockReconciler;
use XT::Domain::PRLs;


has reconciler  => ( is => 'rw', isa => 'Object' );
has report_file => ( is => "rw" );
has summary     => ( is => "rw" );

=head2 reconcile_against_prl()

Main reconciliation method. Given a PRL name and a path to its stock
dump file, we compare it to XTracker's stock for that PRL and send an
email report describing the differences.

=cut

sub reconcile_against_prl {
    my ( $self, $amq_identifier, $file_name, $prl_stock_path ) = validated_list( \@_,
        amq_identifier => { isa => "Str" },
        file_name      => { isa => "Str", optional => 1 },
        prl_stock_path => { isa => "Str", optional => 1 },
    );
    my $prl = XT::Domain::PRLs::get_prl_from_amq_identifier({
        amq_identifier => $amq_identifier,
    });
    $prl_stock_path ||= $self->get_prl_stockfile( $prl, $file_name );

    # Compare the stock files
    my $starttime = time;
    my $discreps = $self->compare_stock( $prl, $prl_stock_path );

    # Generate detailed report of differences
    $self->report_file( $self->gen_report );

    # Generate summary of differences
    $self->summary( $self->gen_summary( $starttime ) );

    return;
}


=head2 get_prl_stockfile()

Get access to the stock file from the PRL and return a full path to
that file (which might be the original or a copy that is easy to
access).

=cut

sub get_prl_stockfile {
    my ($self, $prl, $file_name) = @_;

    my $path = XT::Domain::PRLs::lookup_config_value({
        from_key   => 'name',
        from_value => $prl->name,
        to         => 'stock_file_directory',
    }) or die("No stock_file_directory specified for PRL '" .
              $prl->name . "'\n");
    my $fullpath = File::Spec->catfile($path, $file_name);

    return $fullpath;
}


=head2 gen_xt_stockfile()

Generate a stock file with our version of what the PRL has

=cut

sub gen_xt_stockfile {
    my ($self, $prl) = @_;

    my $stockfile_fullpath = $self->xt_stockfile_fullpath($prl->identifier_name);

    # Delete previous version of file. That way if we fail then old
    # one will not be hanging around to confuse things.
    unlink( $stockfile_fullpath );

    # Open temporary file into which we will write the stock dump
    my $fh = File::Temp->new(DIR => $self->xt_stockfile_dir, UNLINK => 0);
    binmode( $fh, ":utf8" );
    my $filename = $fh->filename;
    print $fh "channel,sku,status,allocated,available\n";

    # Run query to get our stock dump
    my $prl_location = $prl->location->location;
    my @queries = XT::Data::StockReconcile::XTInventoryQuery::gen_queries(
        $prl_location,
    );

    my $schema = $self->schema;
    # Create a new, temporary connection to the DB so that the temp table
    # gets dropped as it goes out of scope.
    my $temp_schema = $schema->connect(@{$schema->storage->connect_info});
    my $dbh = $temp_schema->storage->dbh;
    foreach my $query (@queries) {
        my $sth = $dbh->prepare($query);
        $sth->execute;

        # NUM_OF_FIELDS is only set for queries that return data
        if ($sth->{NUM_OF_FIELDS}) {
            # Write the result set to the temporary file
            while (my @sku_data = $sth->fetchrow_array) {
                print $fh join(',', @sku_data), "\n";
            }
        }
    }
    close($fh);

    # Rename the temporary file to the permanent name
    rename( $filename, $stockfile_fullpath );
}


=head2 xt_stockfile_fullpath()

Generate a stock file with our version of what the PRL has

=cut

sub xt_stockfile_fullpath {
    my ($self, $prl_identifier) = @_;
    return File::Spec->catfile(
        $self->xt_stockfile_dir,
        "xtracker_stockfile_dump_for_prl_$prl_identifier",
    )
}


=head2 xt_stockfile_dir()

Return the full path name of the directory in which we place the
XTracker stock file

=cut

sub xt_stockfile_dir {
    my ($self) = @_;

    my $dir = config_var('SystemPaths','reports_dir')
        or die("Missing SystemPaths/reports_dir in config\n");

    return $dir;
}

=head2 compare_stock()

Do comparison of two stock files and return a hash describing
discrepancies

=cut

sub compare_stock {
    my ( $self, $prl, $prl_stock_path ) = @_;

    # Column definitions for the stock files, in order
    my $key_columns  = [
        {
            name  => 'channel',
            alias => ['client'],
            type  => 'text',
        },
        {
            name  => 'sku',
            alias => ['article'],
            type  => 'sku',
        },
        {
            name  => 'status',
            alias => ['stockstatus'],
            type  => 'text',
        },
    ];
    my $data_columns = [
        {
            name  => 'allocated',
            alias => ['allocatedquantity'],
            type  => 'count',
        },
        {
            name  => 'available',
            alias => ['freequantity'],
            type  => 'count',
        },
    ];

    # Run the reconciliation
    my $reconciler = XT::Data::StockReconcile::StockReconciler->new({
        attr_prefix      => 'prl',
        stockholder_name => 'PRL ' . $prl->name,
        key_columns      => $key_columns,
        data_columns     => $data_columns,
    });
    $self->reconciler($reconciler);
    my $xt_column_names_by_number = [];
    my $prl_column_names_by_number = [];
    $reconciler->reconcile_files(
        $self->xt_stockfile_fullpath($prl->identifier_name),
        undef,
        $xt_column_names_by_number,
        $prl_stock_path,
        undef,
        $prl_column_names_by_number,
    );

    return $reconciler->stock;
}


=head2 gen_summary()

Given a hash describing descrepancies, return a string which is a
summary stock reconciliation report suitable for use as an email
body.

=cut

sub gen_summary {
    my ( $self, $starttime ) = @_;
    return $self->reconciler->gen_summary($starttime);
}


=head2 gen_report()

Generate a stock reconciliation detail report and return the full
path of the file containing the report.

=cut

sub gen_report {
    my ( $self ) = @_;
    return $self->reconciler->gen_report;
}


=head2 email_report_to_recipient($prl) :

Email the ->summary and ->report_file to the configured recpipient.

=cut

sub email_report_to_recipient {
    my ($self, $prl) = @_;

    my $recipient = config_var('Reconciliation', 'prl_report_email')
        or die("Missing Reconciliation/prl_report_email in config\n");
    $self->email_report( $self->summary, $self->report_file, $prl, $recipient );
}

=head2 email_report()

Email the report of discrepancies

=cut

sub email_report {
    my ( $self, $summary, $reportfile, $prl, $recipient ) = @_;
    $self->reconciler->email_report($summary, $reportfile, $prl, $recipient);
}

1;
