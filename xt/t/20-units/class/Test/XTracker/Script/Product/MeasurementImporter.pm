package Test::XTracker::Script::Product::MeasurementImporter;

use NAP::policy 'test';

use parent 'NAP::Test::Class';

use Data::Dump 'pp';
use Filesys::SmbClient;
use Test::Fatal;
use Test::MockModule;
use Test::MockObject::Extends;
use Text::CSV_XS;

use Test::XTracker::Data;
use Test::XTracker::RunCondition dc => 'DC1';
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Script::Product::MeasurementImporter;

=head1 NAME

Test::XTracker::Script::Product::MeasurementImporter

=head1 METHODS

=head2 test_parse_csv_file

This test will mock the samba calls generating a CSV string for each structure
defined in the iterations and test that.

=cut

sub test_parse_csv_file : Tests {
    my $self = shift;

    my $importer = Test::MockObject::Extends->new(
        XTracker::Script::Product::MeasurementImporter->new
    );
    for (
        [
            'test single sku',
            [ { sku => '1234-123', height => 1.000, length => 2, weight => 3, width => 4, } ],
        ],
        [
            'test single sku different column order',
            [ { sku => '1234-123', height => 1, length => 2, weight => 3, width => 4, } ],
            [qw/length height weight sku width/],
        ],
        [
            'test multiple skus',
            [
                { sku => '1234-123', height => 1, length => 2, weight => 3, width => 4, },
                { sku => '2345-678', height => 2, length => 3, weight => 4, width => 5, },
            ],
        ],
        [
            'test missing sku',
            [ { height => 1, length => 2, weight => 3, width => 4, }, ],
            undef,
            qr{Missing SKU},
        ],
        [
            'test missing height',
            [ { sku => '1234-123', length => 2, weight => 3, width => 4, }, ],
            undef,
            qr{Empty value passed for height for SKU},
        ],
        [
            'test invalid SKU',
            [ { sku => 'foo', height => 1, length => 2, weight => 3, width => 4, }, ],
            undef,
            qr{SKU 'foo' isn't a valid SKU},
        ],
    ) {
        my ( $test_name, $rows, $column_order, $error_re ) = @$_;
        # Default order if one isn't provided
        $column_order //= [qw/sku height length weight width/];

        # Mock our samba/csv parser
        $importer->mock('read_csv_file', sub {
            $self->generate_csv_data($column_order, $rows);
        });

        if ( $error_re ) {
            like(
                exception { $importer->parse_csv_file('foo'); },
                $error_re,
                $test_name
            );
            next;
        }

        # Test our method returns the expected data
        my $got = $importer->parse_csv_file('foo');
        my $expected = {map {
            my $row = $_;
            my ($pid) = $row->{sku} =~ m{(^\d+)-};
            $pid => { map { $_ => $row->{$_} } qw/height length weight width/ }
        } @$rows};
        cmp_deeply($got, $expected, $test_name) or diag 'Got: ' . pp $got;;
    }
}

=head2 generate_csv_data(\@column_order, \@rows) : $csv_data

Generate a CSV string from a given data structure (C<\@rows>) with the given
column order.

=cut

sub generate_csv_data {
    my ( $self, $column_order, $rows ) = @_;

    # Cubiscan generally does a ucfirst on its headings, keep a map of
    # exceptions here
    my %header_map = ( sku => 'SKU' );
    # Use Windows line endings to match the ones Cubiscan drops
    my $csv = Text::CSV_XS->new({ eol => "\r\n" });
    my $csv_data = q{};
    for my $fields (
        [map { $header_map{$_} || ucfirst $_ } @$column_order],
        map { my $field = $_; [ map { $field->{$_} } @$column_order ] } @$rows
    ) {
        $csv->combine(@$fields);
        $csv_data .= $csv->string;
    }
    return $csv_data;
}

=head2 test_invoke

A high-level test that will mock the guts of the CSV parsing and mainly check
we're updating the database correctly.

=cut

sub test_invoke : Tests {
    my $self = shift;

    # We need to test a samba unlink call, so we'll need to mock it
    my $smb = Test::MockObject::Extends->new( Filesys::SmbClient->new );
    $smb->mock('unlink', \&_mock_smb_unlink);

    # We also need to mock our parse_csv_file call, which we test separately,
    # so let's mock that too, and pass it our mocked samba client
    my $importer = Test::MockObject::Extends->new(
        XTracker::Script::Product::MeasurementImporter->new( smb => $smb )
    );

    # Mock our logger to warn somewhere we can catch the message
    my $logger = Test::MockModule->new('Log::Log4perl');
    $logger->mock('get_logger', \&Mock::Log::Log4perl::new);

    my @products = map { $_->{product} }
        @{(Test::XTracker::Data->grab_products({
            force_create => 1, how_many => 2
        }))[1]};

    my $nonexistent_product_id
        = $self->schema->resultset('Public::Product')->get_column('id')->max+1;

    my $corrupted_product_id = q{547561`};

    for (
        [
            'test one file one row successful update',
            { foo => [$products[0]] },
            { unlinked_files => ['foo'], expect_updates_for => [$products[0]] }
        ],
        [
            'test one file multiple rows successful update',
            { foo => [@products] },
            { unlinked_files => ['foo'], expect_updates_for => [@products] }
        ],
        [
            'test multiple files successful update',
            { foo => [$products[0]], bar => [$products[1]] },
            { unlinked_files => [qw/foo bar/], expect_updates_for => [@products] }
        ],
        [
            'test update nonexistent product failure',
            { foo => {
                $nonexistent_product_id => { height => 1, length => 2, weight => 3, width => 4 },
            } },
            { unlinked_files => ['foo'], error_re => qr{No product found for product_id} }
        ],
        [
            'test one file with corrupted product_id',
            { foo => {
                $corrupted_product_id => { height => 1, length => 2, weight => 3, width => 4 },
            } },
            { unlinked_files => ['foo'], error_re => qr{ Argument "$corrupted_product_id" isn't numeric in sort at} }
        ],
    ) {
        my ( $test_name, $data, $expected ) = @$_;

        subtest $test_name => sub {
            # We mock these as they reads a samba filesystem
            $importer->mock('get_filenames', sub { keys %$data; });
            $importer->mock('wait_until_stable', sub {});

            # We test this separately, so we mock it for the purposes of this
            # test
            $importer->mock('parse_csv_file', sub {
                $self->_mock_parse_csv_file($data->{$_[1]});
            });

            $self->clear_deleted_files;
            # Store our values before the update if we've passed existing
            # products to check they've changed later
            my $pre_update_values = $self->_extract_pre_update_values(
                grep { ref $_ eq 'ARRAY' } values %$data
            );

            # Initiate our message monitor
            my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

            $importer->invoke;

            # Check our update errored
            if ( $expected->{error_re} ) {
                like( $Mock::Log::Log4perl::warnings[0], $expected->{error_re},
                    'got expected warning' );
            }
            # Check our updates worked
            else {
                my @products = map { @$_ } values %$data;
                for my $product ( @products ) {
                    # Assume expected 0 if undefined... not 100% correct (then
                    # again does a dimension of 0 make sense?) but does the job
                    # and prevents undef warnings
                    cmp_ok(
                        $product->shipping_attribute->discard_changes->$_,
                        q{!=},
                        ($pre_update_values->{$product->id}{$_}//0),
                        sprintf "%s updated for product %i", $_, $product->id
                    ) for qw/height length weight width/;
                }
                # Check we sent messages to IWS
                $xt_to_wms->expect_messages(
                    { messages => [ ({ type => 'pid_update' }) x @products ] }
                );
            }

            # Check we unlinked the correct files
            is( keys %{$self->deleted_files},
                scalar @{$expected->{unlinked_files}},
                sprintf '%d files unlinked', scalar @{$expected->{unlinked_files}}
            ) or diag sprintf(
                'Unlinked files %s', join q{, }, keys %{$self->deleted_files}
            );
            ok( $self->deleted_files->{$_}, "$_ deleted" )
                for @{$expected->{unlinked_files}};
        };
    }
}

# Pass one of the $data values from test_invoke to extract a hashref with the
# existing values
sub _extract_pre_update_values {
    my ( $self, $products ) = @_;

    my $pre_update_values;
    for my $sa ( map { $_->shipping_attribute } @$products ) {
        $pre_update_values->{$sa->product_id} = {
            map { $_ => $sa->$_ } qw/height length weight width/
        };
    }
    return $pre_update_values;
}

# A bunch of helper subs to help us test that we're deleting files
{
my $deleted_files = {};
sub deleted_files { $deleted_files; }
sub clear_deleted_files { $deleted_files = {}; }
sub _mock_smb_unlink { $deleted_files->{$_[1]} = 1; }
}

sub _mock_parse_csv_file {
    my ( $self, $data ) = @_;

    # If we reference a hashref then our test passed the exact data we want to
    # return, so return it directly
    return $data if ref $data eq 'HASH';

    # Else we have an arrayref of products so we increment all measurement
    # values by 1 to make sure we're performing updates
    my $return;
    for my $product ( @$data ) {
        my $sa = $product->shipping_attribute;
        $return->{$product->id} = { map {
            $_ => defined $sa->$_ ? $sa->$_ + 1 : 1
        } qw/height length weight width/ };
    }
    return $return;
}

# Tiny class to allow us to override xt_logger->warn and test its output
{
package Mock::Log::Log4perl; ## no critic(ProhibitMultiplePackages)

our @warnings;
sub new { @warnings = (); bless {}, __PACKAGE__; }
sub warn { push @warnings, $_[1]; }
}
