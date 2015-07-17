#!/usr/bin/env perl

use NAP::policy     qw( tt test );

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use File::Temp  qw( tempfile );
use Test::XT::Flow;

=head1 NAME

finance/transaction_reporting.t

=head1 DESCRIPTION

Tests the Finance / TransactionReporting page

Note that this can only be a partial test. The TransactionReporting page
is dependant upon the Payment Service to complete its functionality.

This test will verify that the page handles file upload failures correctly
and that files are uploaded properly.

# 1. Login

# 2. Load Finance / TransactionReporting

# 2.1 Ensure upload_file HTML input of type "file" is present
# 2.2 Ensure Submit button with value "Convert" is present

# 3. Provide file input and submit form.

# 4. Verify that the download link for the new CSV file is present.

# Try the above with valid file (.csv file) and invalid ones (no file,
# other file type, etc).

#TAGS finance file upload csv psp

=cut

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Finance',
    ],
);
my $mech = $framework->{mech};

$framework->login_with_roles( {
    paths => [ '/Finance/TransactionReporting' ]
} );

# We need some test data ...
my $test_data = "\"Test Data\", 123123-5890123901239, \"More Test Data\"\n\"Test Data\", 123123-5890123901339, \"More Test Data\"";

# Test twice. Once with a temp file with an invalid name and then one with
# a valid filename.

my ($temp_fh, $temp_filename) = tempfile();
ok( $temp_filename, "I have a temporary filename" );
ok( $temp_fh, "and a filehandle to the temp file" );

print $temp_fh $test_data;

close $temp_fh;

$mech->get_ok('/Finance/TransactionReporting');

my $upload_xpath = '//form[@name="upload_datacash_file"]/table[@class="data"]';
my $submit_xpath = '//form[@name="upload_datacash_file"]/table[2]/tbody/tr/td/input';

$mech->submit_form_ok( {
    form_name   => 'upload_datacash_file',
    with_fields => {
        upload_file => $temp_filename
    }
} );

$mech->has_feedback_error_ok(qr/is not a .csv file/);

# clean up the temporary file
unlink $temp_filename;

($temp_fh, $temp_filename) = tempfile(undef, SUFFIX => '.csv');
ok( $temp_filename, "I have a temporary filename" );
ok( $temp_fh, "and a filehandle to the temp file" );
ok( $temp_filename =~ /\.csv\z/, "the name of the temp file was a csv suffix" );

print $temp_fh $test_data;

close $temp_fh;

$mech->submit_form_ok( {
    form_name   => 'upload_datacash_file',
    with_fields => {
        upload_file => $temp_filename
    }
} );

$mech->no_feedback_error_ok();

# clean up the temporary file
unlink $temp_filename;

ok( $mech->find_xpath('//form[@name="upload_datacash_file"]/a'), "Download link for updated file is present" );

done_testing();
