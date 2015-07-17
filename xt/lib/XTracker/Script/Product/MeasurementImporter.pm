package XTracker::Script::Product::MeasurementImporter;

use NAP::policy qw/class tt/;

use Filesys::SmbClient;
use List::AllUtils 'first_index';
use Text::CSV_XS;

use XTracker::Config::Local 'config_var';
use XTracker::Constants::Regex ':sku';
use XTracker::Logfile 'xt_logger';

extends 'XT::Common::Script';

with qw/
    XTracker::Script::Feature::SingleInstance
    XTracker::Role::WithAMQMessageFactory
    XTracker::Role::WithSchema
/;

=head1 NAME

XTracker::Script::Product::MeasurementImporter

=head1 DESCRIPTION

Module to import measurement data from Cubiscan's CSV, shared via Samba.

=head1 ATTRIBUTES

=head2 smb

=cut

has smb => (
    is      => 'ro',
    isa     => 'Filesys::SmbClient',
    lazy    => 1,
    builder => '_build_smb',
);
sub _build_smb {
    return Filesys::SmbClient->new(
        username  => config_var(qw/CubiscanSambaShare username/),
        password  => config_var(qw/CubiscanSambaShare password/),
        workgroup => config_var(qw/CubiscanSambaShare workgroup/),
    );
}

=head2 csv

=cut

has csv => (
    is => 'ro',
    isa => 'Text::CSV_XS',
    lazy => 1,
    builder => '_build_csv',
);
sub _build_csv {
    return Text::CSV_XS->new({binary => 1, auto_diag => 1, empty_is_undef => 1});
}

=head2 samba_server

=cut

has samba_server => (
    is => 'ro',
    isa => 'Str',
    default => sub { config_var(qw/CubiscanSambaShare server/); },
);

=head2 samba_dir

=cut

has samba_dir => (
    is => 'ro',
    isa => 'Str',
    default => sub { config_var(qw/CubiscanSambaShare dir/); },
);

=head2 samba_share

=cut

has samba_share => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    builder => '_build_samba_share',
);
sub _build_samba_share {
    my $self = shift;
    return sprintf 'smb://%s%s', $self->samba_server, $self->samba_dir;
}

=head2 headers

=cut

has headers => (
    is => 'ro',
    isa => 'ArrayRef',
    init_arg => undef,
    default => sub { [qw/sku length width height weight/]; },
);

=head1 METHODS

=head2 invoke() :

Entry point for the script.

=cut

sub invoke {
    my $self = shift;

    my @filenames = $self->get_filenames or return;

    # Get the input from the CSV file
    my $input;
    for my $filename ( @filenames ) {
        $self->wait_until_stable($filename);
        my $product_data = $self->parse_csv_file($filename);
        @{$input->{$filename}}{keys %$product_data} = values %$product_data;
    }

    my $sender = $self->msg_factory;
    my $schema = $self->schema;
    my $product_rs = $schema->resultset('Public::Product');
    # We do each file in a transaction, so if we fail the renaming we can roll
    # back our changes (at the moment we should have one pid per file anyway)
    for my $filename ( sort keys %$input ) {
        try {
            $schema->txn_do(sub{
                my @products;
                for my $product_id ( sort { $a <=> $b } keys %{$input->{$filename}} ) {
                    # I realise this is lazy as we'll only error on the first
                    # row we didn't find, but it doesn't really matter as in
                    # practice we'd only expect the CSV to have one record
                    # anyway
                    my $product = $product_rs->find($product_id)
                        or die "No product found for product_id $product_id\n";
                    my $shipping_attribute = $product->shipping_attribute
                        or die "No shipping attribute found for product_id $product_id\n";
                    $shipping_attribute->update($input->{$filename}{$product_id});
                    push @products, $product;
                }
                # It really sucks that PidUpdate can't take multiple pids,
                # making this operation non-atomic. I still think it's better
                # to do *within* the transaction as a failure here will cause
                # the file *not* to be unlinked, which means it'll get picked
                # up in this script's next run anyway (and the pids not having
                # measurements in XT will imply to the users that something
                # didn't work, even though IWS might have updated some of these
                # pids already)
                $sender->transform_and_send(
                    'XT::DC::Messaging::Producer::WMS::PidUpdate', $_
                ) for @products;
            });
        }
        catch {
            xt_logger->warn("There were errors importing $filename: $_");
        };
        # We don't think we'll ever need these files again once they've
        # been read... maybe for debugging? But then we'd need to maintain
        # the directories - let's delete these for now, and we can always
        # change our minds later and move them either into a local or
        # remote (samba-shared) dated subdirectories.
        #
        # Seems that there are corrupted files that make this importer to
        # fail, so we will remove the file either way so the script can
        # go pick other files. If the file it's corrupted the first time,
        # it will be the second time too and so on and we need to skip it
        $self->smb->unlink($filename) or die "Can't unlink file: $!\n";
    }
}

=head2 get_filenames() : @filenames

Return a list of fully qualified CSV filenames that are present on the Samba
share.

=cut

sub get_filenames {
    my $self = shift;

    my $smb = $self->smb;
    my $uri = $self->samba_share;

    my $dir = $smb->opendir($uri) or die "Couldn't open $uri: $!\n";
    my @basenames = grep { m{\.csv$} } $smb->readdir($dir);
    $smb->closedir($dir);

    return map { "$uri/$_" } @basenames;
}

=head2 parse_csv_file($filename) : $input_data

Pass this method a filename of a CSV file in the Samba share and it will parse
it and return a hashref with the following structure:

    { $product_id => { $field_name => $field_value, ... }, ... }

The list of attributes is in the L<headers> attribute (except for C<sku> that
is ignored).

=cut

sub parse_csv_file {
    my ( $self, $filename ) = @_;

    # Read CSV file as string and split on Windows line endings
    my @rows = split m{\r\n}, $self->read_csv_file($filename);

    # Create our header-to-index map
    my $header_index = $self->header_index($rows[0]);

    my $input;
    for my $row ( splice @rows, 1 ) {
        my @fields = $self->get_fields($row);
        # We only need the 'sku' value to get the product id as that's what we
        # do our inserts against
        my $sku = $fields[$header_index->{sku}] or die "Missing SKU on row '$row'\n";

        my ($product_id) = $sku =~ $SKU_REGEX
            or die "SKU '$sku' isn't a valid SKU\n";

        # Error if any values are undefined (this should never happen as I
        # don't think Cubiscan allows it, but let's make sure)
        while ( my ( $i, $field ) = each @fields ) {
            next if defined $field;
            # Values are unique, so we can just reverse the hash
            my %index_header = reverse %$header_index;
            die "Empty value passed for $index_header{$i} for SKU $sku\n";
        }

        # Put all keys except for sku into a hashref keyed by the product_id
        $input->{$product_id} = {
            map { $_ => $fields[$header_index->{$_}] }
            grep { $_ ne 'sku' } keys %$header_index
        };
    }
    return $input;
}

=head2 header_index($row) : \%header_indexes

This method exists so we don't rely on Cubiscan's CSV order. It returns a
hashref mapping our L<headers> attribute to their positional index in the CSV
file.

=cut

sub header_index {
    my ( $self, $row ) = @_;

    my @got_headers = $self->get_fields($row);

    my %header_indexes;
    for my $header ( @{$self->headers} ) {
        my $i = first_index { m{^$header$}i } @got_headers;
        die "Couldn't find expected header $header\n" if $i == -1;
        $header_indexes{$header} = $i;
    }
    return \%header_indexes;
}

=head2 get_fields($row) : @fields

Parses the CSV row and returns a list of the fields in it.

=cut

sub get_fields {
    my ( $self, $row ) = @_;
    my $csv = $self->csv;
    $csv->parse($row);
    return $csv->fields;
}

=head2 read_csv_file($filename) : $content

Returns a string representation of the file's contents.

=cut

sub read_csv_file {
    my ( $self, $filename ) = @_;

    my $smb = $self->smb;
    my $fd = $smb->open($filename);
    # Read the file into a string
    my $content = q{};
    # 50 is a little arbitrary and taken from the docs...
    while ( my $buf = $smb->read($fd,50) ) {
        last unless defined $buf;
        $content .= $buf;
    }
    $smb->close($fd);
    return $content;
}

=head2 wait_until_stable($filename) :

Waits until the file isn't being written to any more. 'Borrowed' from
script/iws_reconciliation/process_iws_export.

=cut

sub wait_until_stable {
    my ( $self, $filename ) = @_;

    # We're keeping these values relatively low as a starting point - bearing
    # in mind that we expect the files that are written to be very small. They
    # are quite arbitrary though
    my $stability = {
        seconds_until_stable   => 10,
        seconds_between_checks => 3,
        max_stability_checks   => 3,
    };

    my ($file_mtime,$file_size) = $self->get_file_info($filename);

    return if (time() - $file_mtime) >= $stability->{seconds_until_stable};

    my $checks_remaining = $stability->{max_stability_checks};

    my $last_file_size = -1;  # drive us around the loop at least once

    while ( (my $file_age = time() - $file_mtime) < $stability->{seconds_until_stable}
        || ($file_size != $last_file_size)) {

        die "File $filename is taking too long to stabilize\n"
            unless $checks_remaining-- > 0;

        my $seconds_until_stable = $stability->{seconds_between_checks} - $file_age;

        sleep ( $seconds_until_stable > $stability->{seconds_between_checks}
                ? $seconds_until_stable
                : $stability->{seconds_between_checks}
            ) ;

        $last_file_size = $file_size;

        ($file_mtime,$file_size) = $self->get_file_info($filename);
    }
    return $filename;
}

=head2 get_file_info($filename): $mtime, $size

Returns C<mtime> and C<size> for the given file.

=cut

sub get_file_info {
    my ( $self, $filename ) = @_;

    my @file_stat = $self->smb->stat($filename);

    return @file_stat[9,7]; # mtime, size
}
