#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::Exception;
use File::Basename;

use XTracker::Config::Local 'config_var';
use XTracker::PrintFunctions;
use Digest::MD5 'md5_hex';

my $PRINT_DOCS_DIR = config_var( 'SystemPaths', 'document_dir' );

use base 'Test::Class';

sub startup : Tests(startup => 1) {
    my $test = shift;

    ok $PRINT_DOCS_DIR, 'should have a configured print documents directory';
}

sub test_path_generation : Tests {
    my $test = shift;

    my @test_cases = (
        {
            desc => 'call with no document_type',
            args => { },
            err => 'You must supply a document_type',
        },

        {
            desc => 'call with no id',
            args => { document_type => 'anything' },
            err => 'You must supply an id',
        },

        {
            desc => 'call with default file extension',
            args => { document_type => 'anything', id => 99 },
            path => "$PRINT_DOCS_DIR/anything/" .
                substr( md5_hex('anything-99'), 0, 2 ) .
                '/anything-99.html',
        },

        {
            desc => 'call with specified file extension',
            args => { document_type => 'anything', id => 99, extension => 'pdf' },
            path => "$PRINT_DOCS_DIR/anything/" .
                substr( md5_hex('anything-99'), 0, 2 ) .
                '/anything-99.pdf',
        },

        {
            desc => 'call with blank file extension',
            args => { document_type => 'anything', id => 99, extension => '' },
            path => "$PRINT_DOCS_DIR/anything/" .
                substr( md5_hex('anything-99'), 0, 2 ) .
                '/anything-99',
        },

        {
            desc => 'call with file extension including leading dot',
            args => { document_type => 'anything', id => 99, extension => '.jpg' },
            path => "$PRINT_DOCS_DIR/anything/" .
                substr( md5_hex('anything-99'), 0, 2 ) .
                '/anything-99.jpg',
        },

        {
            desc => 'call with mixed case document type',
            args => { document_type => 'Anything', id => 70 },
            path => "$PRINT_DOCS_DIR/anything/" .
                substr( md5_hex('anything-70'), 0, 2 ) .
                '/anything-70.html',
        },

        {
            desc => 'alphanumeric id',
            args => { document_type => 'anything', id => 'A17-BCD' },
            path => "$PRINT_DOCS_DIR/anything/" .
                substr( md5_hex('anything-A17-BCD'), 0, 2 ) .
                '/anything-A17-BCD.html',
        },

        {
            desc => 'non-numeric id',
            args => { document_type => 'anything', id => 'not_a_number' },
            path => "$PRINT_DOCS_DIR/anything/" .
                substr( md5_hex('anything-not_a_number'), 0, 2 ) .
                '/anything-not_a_number.html',
        },

        {
            desc => 'forced path',
            args => { document_type => 'anything', id => 99, path => "/tmp/print_docs_$$" },
            path => "/tmp/print_docs_$$/anything-99.html",
        },

        {
            desc => 'label with numeric id',
            args => { document_type => 'label', id => 123, extension => 'lbl' },
            path => "$PRINT_DOCS_DIR/label/" .
                substr( md5_hex('123'), 0, 2 ) .
                '/123.lbl',
        },

        {
            desc => 'barcode with no hyphen',
            args => { document_type => 'barcode', id => 'C0001', extension => 'png' },
            path => "$PRINT_DOCS_DIR/barcode/" .
                substr( md5_hex('C0001'), 0, 2 ) .
                '/C0001.png',
        },

        {
            desc => 'alternative currency invoice',
            args => { document_type => 'invoice', id => 'RON-123' },
            path => "$PRINT_DOCS_DIR/invoice/" .
                substr( md5_hex('invoice-RON-123'), 0, 2 ) .
                '/invoice-RON-123.html',
        },

        {
            desc => 'RMA request',
            args => { document_type => 'rma_request', id => 'NAP_rma_request_123' },
            path => "$PRINT_DOCS_DIR/rma_request/" .
                substr( md5_hex('NAP_rma_request_123'), 0, 2 ) .
                '/NAP_rma_request_123.html',
        },

        {
            desc => 'RTV shipment pick list',
            args => { document_type => 'rtv_ship_picklist', id => '123' },
            path => "$PRINT_DOCS_DIR/rtv_ship_picklist/" .
                substr( md5_hex('rtv_ship_picklist_123'), 0, 2 ) .
                '/rtv_ship_picklist_123.html',
        },

        {
            desc => 'RTV inspection pick list',
            args => { document_type => 'rtv_inspect_picklist', id => '123' },
            path => "$PRINT_DOCS_DIR/rtv_inspect_picklist/" .
                substr( md5_hex('rtv_inspect_picklist_123'), 0, 2 ) .
                '/rtv_inspect_picklist_123.html',
        },
    );

    for my $test_case (@test_cases) {
        my $path;
        if (exists $test_case->{err}) {
            dies_ok sub { $path = XTracker::PrintFunctions::path_for_print_document( $test_case->{args} ) },
                'should fail to get print doc path for call with '.$test_case->{desc};
        } else {
            lives_ok sub { $path = XTracker::PrintFunctions::path_for_print_document( $test_case->{args} ) },
                'should get print doc path for call with '.$test_case->{desc};
            is $path, $test_case->{path}, '  and path should be '.$test_case->{path};
        }
    }
}

# and test the ensure_directory_exists flag
sub test_directory_creation : Tests {
    my $test = shift;

    my $args = { document_type => 'test_junk', id => 999 };

    # find out which directory should be created
    my $junk_print_doc = XTracker::PrintFunctions::path_for_print_document( $args );
    my $junk_print_dir = dirname( $junk_print_doc );

    # ensure directory doesn't already exist
    if ( -e $junk_print_dir ) {
        rmdir $junk_print_dir || die "Couldn't delete test directory '$junk_print_dir': $@";
    }
    ok ! -e $junk_print_dir, 'directory should not exist before calling';

    # now call path_for_print_document with ensure_directory_exists set true
    $args->{ensure_directory_exists} = 1;
    lives_ok sub { XTracker::PrintFunctions::path_for_print_document( $args ) }, 'should ensure directory exists';

    # check that directory has been created
    ok -e $junk_print_dir, 'directory should now have been created';

    # clean up
    rmdir $junk_print_dir;
}

sub test_document_details_from_name : Tests {
    my $test = shift;

    my @test_cases = (
        {
            filename => 'invoice-123.html',
            expected => {
                document_type => 'invoice',
                id => 123,
                extension => 'html',
            },
        },
        {
            filename => 'outward-C1001.lbl',
            expected => {
                document_type => 'label',
                id => 'outward-C1001',
                extension => 'lbl',
            },
        },
        {
            filename => 'withouthyphen.lbl',
            expected => {
                document_type => 'label',
                id => 'withouthyphen',
                extension => 'lbl',
            },
        },
        {
            filename => 'somebarcode.png',
            expected => {
                document_type => 'barcode',
                id => 'somebarcode',
                extension => 'png',
            },
        },
        {
            filename => '123.lbl',
            expected => {
                document_type => 'label',
                id => '123',
                extension => 'lbl',
            },
        },
        {
            filename => 'invoice-RON-123.html',
            expected => {
                document_type => 'invoice',
                id => 'RON-123',
                extension => 'html',
            },
        },
        {
            filename => 'pickorder9.png',
            expected => {
                document_type => 'barcode',
                id => 'pickorder9',
                extension => 'png',
            },
        },
        {
            filename => 'NAP_rma_request_04578.html',
            expected => {
                document_type => 'rma_request',
                id => 'NAP_rma_request_04578',
                extension => 'html',
            },
        },
        {
            filename => 'rtv_ship_picklist_2709.html',
            expected => {
                document_type => 'rtv_ship_picklist',
                id => '2709',
                extension => 'html',
            },
        },
        {
            filename => 'rtv_inspect_picklist_123.html',
            expected => {
                document_type => 'rtv_inspect_picklist',
                id => '123',
                extension => 'html',
            },
        },
    );

    for my $test_case (@test_cases) {
        note 'get details for filename '.$test_case->{filename};
        my $doc_details = XTracker::PrintFunctions::document_details_from_name(
            $test_case->{filename},
        ) ;
        for my $expected_key ( sort keys %{ $test_case->{expected} } ) {
            my $expected_value = $test_case->{expected}{$expected_key};
            is $doc_details->{$expected_key}, $expected_value, "$expected_key should be '$expected_value'";
        }
    }
}

Test::Class->runtests;
