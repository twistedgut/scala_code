use NAP::policy 'tt';
use Getopt::Long;
use Text::CSV_XS;
use XTracker::Role::WithSchema;
use XTracker::Constants::FromDB qw/
    :business
/;

=head1 NAME

insert_missing_third_party_skus.pl

=head1 DESCRIPTION

This script will check all of the variants listed in a given jimmy choo migration mappings
file, and insert third_party_skus where they are missing

=cut

# EVIL GLOBALS
my $verbose = 0;
my $schema;

# CONSTANTS
my $XT_PRODUCT_ID_ROW = 2;
my $XT_SIZE_ID_ROW = 3;
my $THIRD_PARTY_SKU_ROW = 7;

my $RESULT__ALREADY_CORRECT = 'SKU already correct';
my $RESULT__UPDATED = 'SKU updated';
my $RESULT__EXCEPTION = 'Unknown exception';
my $RESULT__NO_VARIANT = 'Variant not in db';
my $RESULT__WRONG_SKU = 'Variant already has another sku';
my $RESULT__WRONG_VARIANT = 'SKU already assigned to another variant';

unless(caller) {

    GetOptions(
        'file=s'   => \(my $file_path),
        'verbose'   => \$verbose,
    );
    $verbose //= 0;

    if (!$file_path) {
        print "File-path to JC migration mappings file required";
        exit(1);
    }

    main($file_path);
}

sub main {
    (my $file_path) = @_;

    my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });

    open my $csv_file_handle, "<:encoding(utf8)", $file_path
        or die sprintf('Problem opening CSV file "%s" : %s', $file_path, $!);

    my $headers = $csv->getline($csv_file_handle);
    die sprintf('CSV file columns are not as expected') unless(
        $headers->[$XT_PRODUCT_ID_ROW] eq 'destination_pid' &&
        $headers->[$XT_SIZE_ID_ROW] eq 'destination_size_id' &&
        $headers->[$THIRD_PARTY_SKU_ROW] eq 'external_sku'
    );

    $schema = XTracker::Role::WithSchema->build_schema();

    my $process_results = {};
    while (my $csv_row = $csv->getline($csv_file_handle)) {
        my ($result, $xt_sku, $third_party_sku);
        try {
            $xt_sku = sprintf('%s-%s',
                $csv_row->[$XT_PRODUCT_ID_ROW], $csv_row->[$XT_SIZE_ID_ROW]);
            $third_party_sku = $csv_row->[$THIRD_PARTY_SKU_ROW];

            # Check this SKU, update the third_party_sku if necessary or make a note
            # of problems we find
            $result = _process_sku($xt_sku, $third_party_sku);

        } catch {
            my $error = $_;
            warn sprintf('Problem processing SKU "%s": %s', $xt_sku, $error);
            $result = $RESULT__EXCEPTION;
        };
        _debug(sprintf('XT SKU %s / JC SKU %s : %s', $xt_sku, $third_party_sku, $result));
        $process_results->{$result} //= 0;
        $process_results->{$result}++
    }
    close $csv_file_handle;

    _debug("\nResults");
    _debug("-------");
    for my $result_type (keys %$process_results) {
        _debug(sprintf('%s: %s', $result_type, $process_results->{$result_type}));
    }

    _debug("\nDone");
}

sub _process_sku {
    my ($xt_sku, $third_party_sku) = @_;

    # Return error if there is no variant with this SKU
    my $variant_obj = $schema->resultset('Public::Variant')->find_by_sku($xt_sku);
    return $RESULT__NO_VARIANT unless $variant_obj;

    # Return OK if the variant already has the correct third_party_sku
    my $current_third_party_sku = $variant_obj->get_third_party_sku();
    return $RESULT__ALREADY_CORRECT if ($current_third_party_sku
        &&  $current_third_party_sku eq $third_party_sku);

    # Return error if the variant is already assigned to ANOTHER third_party_sku
    return $RESULT__WRONG_SKU if ($current_third_party_sku
        && $current_third_party_sku ne $third_party_sku);

    # Return error if the third_party_sku is assigned to ANOTHER variant
    my $third_party_sku_obj = $schema->resultset('Public::ThirdPartySku')->find({
        third_party_sku => $third_party_sku,
        business_id     => $BUSINESS__JC
    });
    return $RESULT__WRONG_VARIANT if ($third_party_sku_obj
        && $third_party_sku_obj->variant_id()
        && $third_party_sku_obj->variant_id() != $variant_obj->id());

    # The variant exists, but is has no third_party_sku currently assigned.
    # The third_party_sku itself may or may not already be in the system, but is
    # currently not assigned to any variant.
    # So we can assign it to the proper SKU :)
    $third_party_sku_obj //= $schema->resultset('Public::ThirdPartySku')->new_result({
        third_party_sku => $third_party_sku,
        business_id     => $BUSINESS__JC,
    });
    $third_party_sku_obj->variant_id($variant_obj->id());
    $third_party_sku_obj->update_or_insert();
    return $RESULT__UPDATED;
}

sub _debug {
    my ($message) = @_;
    return unless $verbose;
    print sprintf("%s\n", $message);
}
