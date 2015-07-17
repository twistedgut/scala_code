#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

dbl_submit.t - Test the double submit token

=head1 DESCRIPTION

Perform the following steps:

    * Request a page 3 times to get three tokens
    * Parse the double submit token values out, check they look okay
    * Submit a form, make sure it works
    * Perform a sequence test after a POST
    * Strip out token, ensure missing token message appears
    * Try to submit a duplicate token
    * Try to submit an absolutely junk token, expect "duplicate submission" error
    * Try to submit another junk token (that matches token syntax)
    * Submit a duplicate token, ensure data change is not written to database
    * Try and use a different valid token, ensure data change happened correctly

NOTE: The mechanism for double submit has changed since moving XTracker to PSGI.
These tests possibly need to be updated.

#TAGS xpath http misc shoulddelete

=cut

# putting it in a BEGIN saves us wasting time loading all the other modules
# we skip/finish a mot faster
BEGIN {
    use Test::More;
    plan skip_all => q{Replaced DblSubmit with Plack::Middleware:CSRFBlock};
}

use FindBin::libs;
use Test::More::Prefix qw/ test_prefix /;
use Test::XTracker::Mechanize;
use Test::XTracker::Data;
use URI::Escape;

use XTracker::Constants::FromDB qw(
    :authorisation_level
);

my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

sub extract_sequence_number {
    my $token = shift;

    $token = uri_unescape($token);

    if ($token =~ /(\d+):(.*)/) {
        return $1;
    } else {
        die "No : in hash";
    }
}

sub is_duplicate_submission {
    my ($mech, $test_name) = @_;
    $mech->has_feedback_error_ok(qr/This is a duplicate submission/, $test_name);
}

# GRANT ACCESS TO ANY THREE SUB-SECTIONS
######################################################################

my @sub_sections = $schema->resultset('Public::AuthorisationSubSection')
    ->search
    ->slice( 0, 2 )
    ->all;

is( scalar @sub_sections, 3, 'Found three Authorisation Sub Sections' );

foreach my $sub_section ( @sub_sections ) {

    diag 'Authorisation Sub Section: ' . $sub_section->sub_section;

    Test::XTracker::Data->grant_permissions(
        'it.god',
        $sub_section->section->section,
        $sub_section->sub_section,
        $AUTHORISATION_LEVEL__OPERATOR
    );

}

# LOGIN
######################################################################

note('Login');
my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;

# REQUEST THE PAGE 3 TIMES TO GET THREE TOKENS
######################################################################
note('Get 3 tokens');

my @tokens;
for ( 1 .. 3 ) {
    $mech->get_ok('/My/UserPref', "Grabbed page with token $_ on it");
    my $token = $mech->find_xpath('//form[@class!="QuickSearch"]/input[@name="dbl_submit_token"]/@value');
    ok( $token, "Token found: $token" );
    push( @tokens, $token );
}

# PARSE THE DBLSUBMIT_TOKEN_SEQ VALUES OUT. ENSURE CLIMBING NUMERICAL
######################################################################
note('Check token sequence');
like(uri_unescape($tokens[0]), qr/(\d+):(.*)/,
    "token unescapes to expected format");

for my $increment ( 1 .. 2 ) {
    my $base_number = extract_sequence_number( $tokens[0] );
    my $compare     = extract_sequence_number( $tokens[ $increment ] );

    is( $compare, $base_number + $increment,
        "Token $increment is $increment larger than token 0" );
}

######################################################################
# SUBMIT A FORM. MAKE SURE IT WORKS

note('Submit form with token ' . $tokens[0] . ' setting default_home_page to ' . $sub_sections[0]->id);
$mech->submit_form_ok({
  with_fields => {
    dbl_submit_token  => $tokens[0],
    default_home_page => $sub_sections[0]->id,
  },
  button => 'submit'
}, "Form submit with valid information and token");

$mech->no_feedback_error_ok("Valid submit has no error bar");

#####################################################################
# ANOTHER QUICK SEQUENCE TEST AFTER A POST

note('Check sequence after POST');
my $my_seq4 = $mech->find_xpath('//form[@class!="QuickSearch"]/input[@name="dbl_submit_token"]/@value' );
my $seq_num4 = extract_sequence_number($my_seq4);

is( extract_sequence_number( $tokens[2] ) + 1, $seq_num4,
    'generating unique sequence test 3');

#####################################################################
# STRIP OUT TOKEN, ENSURE MISSING TOKEN MESSAGE APPEARS OK

note('Check missing token message');
my $no_dbl_submit_token = $mech->content;
$no_dbl_submit_token =~ s/\<input type="hidden" id="dbl_submit_token" name="dbl_submit_token" value=".*"\>//g;
$mech->update_html($no_dbl_submit_token);

$mech->submit_form_ok({
  with_fields => {
    default_home_page => $sub_sections[0]->id,
  },
  button => 'submit'
}, "Form submit without Double Submit Token");

$mech->has_feedback_error_ok(qr/This page is missing a Double Submit token/, "Missing Double Submit Token Feedback Error");

#####################################################################
# TRY TO SUBMIT A DUPLICATE TOKEN

note('Submit duplicate token');
$mech->get_ok('/My/UserPref');
$mech->submit_form_ok({
  with_fields => {
    dbl_submit_token  => $tokens[0],
    default_home_page => $sub_sections[0]->id,
  },
  button => 'submit'
}, "Form submit with duplicate double submission Token");

is_duplicate_submission($mech, "Double Submission");

#####################################################################
# TRY TO SUBMIT AN ABSOLUTELY JUNK TOKEN

note('Submit junk token');
$mech->submit_form_ok({
  with_fields => {
    dbl_submit_token  => 'garbage',
    default_home_page => $sub_sections[0]->id,
  },
  button => 'submit'
}, "Form submit with garbage");

# Expect generic "duplicate submission" for garbage.
is_duplicate_submission($mech, "Garbage Token 1");

#####################################################################
# TRY TO SUBMIT ANOTHER JUNK TOKEN (That matches token syntax)

note('Submit another junk token');
$mech->get_ok('/My/UserPref');
$mech->submit_form_ok({
  with_fields => {
    dbl_submit_token  => '1739%3AvjPNHET2%2Fa8NJDKSgJz4DD',
    default_home_page => $sub_sections[0]->id,
  },
  button => 'submit'
}, "Form submit with garbage 2");

is_duplicate_submission($mech, "Garbage Token 2");

#####################################################################
# SUBMIT A DUPLICATE TOKEN, ENSURE DATA CHANGE IS NOT WRITTEN TO DB

note('Check duplicate token not written');
$mech->get_ok('/My/UserPref');

my $drop_down_value_before= $mech->findnodes('//input[@name="default_home_page" and @checked="checked"]/@value')->string_value;
is($drop_down_value_before, $sub_sections[0]->id, "Ensure before value is " . $sub_sections[0]->sub_section);

$mech->submit_form_ok({
  with_fields => {
    dbl_submit_token  => $tokens[0],
    default_home_page => $sub_sections[1]->id,
  },
  button => 'submit'
}, "Duplicate Key changing value to " . $sub_sections[1]->sub_section . ", Ensure data isn't changed.");

is_duplicate_submission($mech, "Ensuring data isn't changed. Ensure caught as dupe");
my $drop_down_value_after = $mech->findnodes('//input[@name="default_home_page" and @checked="checked"]/@value')->string_value;
is($drop_down_value_after, $sub_sections[0]->id, "Ensure after value is still " . $sub_sections[0]->sub_section);

#######################################################################
# TRY AND USE A DIFFERENT VALID TOKEN, ENSURE DATA CHANGE HAPPENED

note('Check different valid token');
$mech->submit_form_ok({
  with_fields => {
    dbl_submit_token  => $tokens[1],
    default_home_page => $sub_sections[2]->id,
  },
  button => 'submit'
}, "Form submit with valid information and token");

$mech->no_feedback_error_ok("Valid Submission Check, Ensuring data change occurred");

$drop_down_value_after = $mech->findnodes('//input[@name="default_home_page" and @checked="checked"]/@value')->string_value;
is($drop_down_value_after, $sub_sections[2]->id, "Ensure new value is " . $sub_sections[2]->sub_section);

done_testing;

