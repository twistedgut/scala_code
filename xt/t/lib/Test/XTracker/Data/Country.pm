package Test::XTracker::Data::Country;

use NAP::policy "tt", 'class';

use Test::XTracker::Data;

=head1 NAME

Test::XTracker::Data::Country

=head1 DESCRIPTION

=head1 METHODS

=head2 proforma_countries

Return a resultset of countries that require a Proforma not a Commercial
Invoice. Excludes Thailand as well - apparently this is a special case.

=cut

{
my $schema = Test::XTracker::Data->get_schema;
# NOTE: This bit of code is taken from a couple of tests that have copy-pasted
# this. One of them also sets 'country_tax_rate.country_id => undef' and
# 'sub_region_id => { q{!=} => undef }'. I don't think this is a requirement
# for proforma countries, but if we're getting some random failures it may be
# worth investigating down that path.
sub proforma_countries {
    return $schema->resultset('Public::Country')->search({
        is_commercial_proforma => 0,
        country                => { q{!=} => 'Thailand' },
        proforma               => { q{>} => 0 },
        returns_proforma       => { q{>} => 0 },
    });
}
}
