#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

=head1 NAME

script/website_api/fake_response.pl

=head1 DESCRIPTION

Fake a response for the XT::Net::WebsiteAPI::TestUserAgent which is
used in dev and test environments.

=head1 SYNOPSIS

  # Fake a response to any request to a Website API
  script/website_api/fake_response.pl
      [--code=200]
      [--message=OK]
      [--body=EMPTY_JSON]
      [--keep]

Create a response with HTTP response --code and --message.

The default --body is an 200 OK empty (no items) API response.

If --keep, the response is persistent and will not be cleared out
after any requests. Remove it by faking another response without
--keep and making a request.

=head2 EXAMPLES

  ./script/website_api/fake_response.pl --body='{ "data": [ { "dispatch_date": "2011-12-24", "delivery_date": "2011-12-25" }], "errors": null }'

  ./script/website_api/fake_response.pl --code=404 --keep

=cut

use lib 'lib';
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Script::WebsiteAPI::FakeResponse;

use Getopt::Long;
use Pod::Usage;

my %opt = (
    verbose => 1,
    code    => 200,
    message => "OK",
    body    => "{
  data: [
  ],
  errors: null
}",
);

my $result = GetOptions(
    \%opt,
    'verbose|v',
    "help|h|?",
    "code|c:i",
    "message|m:s",
    "body|b:s",
    "keep|k",
);

pod2usage(1) if (!$result || $opt{help});

XTracker::Script::WebsiteAPI::FakeResponse->new->invoke(%opt);
