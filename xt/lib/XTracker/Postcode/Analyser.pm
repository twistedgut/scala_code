package XTracker::Postcode::Analyser;
use NAP::policy;

=head1 NAME

XTracker::Postcode::Analyser

=head1 DESCRIPTION

Module for analysing postcodes and extracting the parts we need for analysing (e.g. to
 compare to data we have about remote delivery locations)

=cut

use MooseX::Params::Validate;
use XTracker::Constants::Regex qw( :postcode );

=head1 PUBLIC METHODS

=head2 extract_postcode_matcher

Given a postcode and a country, this will return the part of the postcode we can use for
 further analysis

 param - country : XTracker::Schema::Result::Public::Country object representing the
  country this postcode is related to
 param - postcode : The actual postcode

 return - $postcode_matcher : The bit of the postcode we can use for further analysis.
  This will be undef if either we do not understand the given country's postcode format,
  or if the postcode does not appear to adhere to that format

=cut
sub extract_postcode_matcher {
    my $class = shift;
    my ($country, $postcode) = validated_list(\@_,
        country => { isa => 'XTracker::Schema::Result::Public::Country' },
        postcode => { isa => 'Str' },
    );

    my $regex_by_country_hash = $POSTCODE_REGEX;
    my $country_code = $country->code();

    # See if we know what the format for this country's postcodes are...
    return undef unless exists $regex_by_country_hash->{$country_code};

    my $regex_data = $regex_by_country_hash->{$country_code};

    # We do, so now we need to extract the bit of the postcode we use to match against
    # out db records (this is not always the whole postcode)

    # Normalise the postcode data stored in the address by removing any whitespace
    # and converting everything to uppercase (it is assumed that any values in the
    # system we will be checking this against will already have no whitespace and all
    # characters converted to uppercase)
    my $normalised_postcode = uc($postcode);
    $normalised_postcode =~ s/\s//g; # strip whitespace

    # Some countries prefix postcodes with the country's
    # two letter ISO code and a dash. e.g NL-
    # We can make our lives easier by stripping this optional bit out
    $normalised_postcode =~ s/^$country_code-//;

    my $postcode_matcher;
    if ($normalised_postcode =~ $regex_data->{expression}) {
        my @matches = ($1, $2, $3);
        $postcode_matcher = $matches[$regex_data->{matcher_at} - 1];
    }
    return $postcode_matcher;
}
