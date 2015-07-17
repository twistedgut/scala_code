package Test::XTracker::Postcode::Analyser;
use NAP::policy qw/class test/;

BEGIN { extends 'NAP::Test::Class' };

use XTracker::Postcode::Analyser;

sub test__extract_postcode_matcher :Tests {
    my ($self) = @_;

    # Note in test names below: l = letter (A-z), Nn= number (0-9)
    for my $test (
        {
            name => 'United Kingdom postcode: ln',
            setup => { country => 'GB', postcode => 'a2 6td' },
            result => { matcher => 'A2' }
        },
        {
            name => 'United Kingdom postcode: lln',
            setup => { country => 'GB', postcode => 'SW26td' },
            result => { matcher => 'SW2' }
        },
        {
            name => 'United Kingdom postcode: llnn',
            setup => { country => 'GB', postcode => 'B H 25 7 H Z' },
            result => { matcher => 'BH25' }
        },
        {
            name => 'United Kingdom (invalid) postcode: lll',
            setup => { country => 'GB', postcode => 'BHE5 7HZ' },
            result => { matcher => undef }
        },

        {
            name => 'United States postcode: nnnnn-nnnn',
            setup => { country => 'US', postcode => '12345-1234' },
            result => { matcher => '12345' }
        },
        {
            name => 'United States postcode: nnnnn',
            setup => { country => 'US', postcode => '12345' },
            result => { matcher => '12345' }
        },
        {
            name => 'United States (invalid) postcode: nnnn-n',
            setup => { country => 'US', postcode => '1234-5' },
            result => { matcher => undef }
        },

        {
            name => 'Austria postcode: nnnn',
            setup => { country => 'AT', postcode => '1234' },
            result => { matcher => '1234' }
        },
        {
            name => 'Austria (invalid) postcode: nnn',
            setup => { country => 'AT', postcode => '123' },
            result => { matcher => undef }
        },

        {
            name => 'Czech Republic postcode: nnn nn',
            setup => { country => 'CZ', postcode => '123 45' },
            result => { matcher => '12345' }
        },
        {
            name => 'Czech Republic (invalid) postcode: nnn',
            setup => { country => 'CZ', postcode => '123' },
            result => { matcher => undef }
        },

        {
            name => 'Denmark postcode: DK-nnnn',
            setup => { country => 'DK', postcode => 'DK-1234' },
            result => { matcher => '1234' }
        },
        {
            name => 'Denmark postcode: nnnn',
            setup => { country => 'DK', postcode => '1234' },
            result => { matcher => '1234' }
        },
        {
            name => 'Denmark (invalid) postcode: DK-nnn',
            setup => { country => 'DK', postcode => 'DK-123' },
            result => { matcher => undef }
        },

        {
            name => 'Finland postcode: nnnnn',
            setup => { country => 'FI', postcode => '12345' },
            result => { matcher => '12345' }
        },
        {
            name => 'Finland (invalid) postcode: nnn-nn',
            setup => { country => 'FI', postcode => '123-45' },
            result => { matcher => undef }
        },

        {
            name => 'France postcode: nnnnn',
            setup => { country => 'FR', postcode => '12345' },
            result => { matcher => '12345' }
        },
        {
            name => 'France (invalid) postcode: nnn-nn',
            setup => { country => 'FR', postcode => '123-45' },
            result => { matcher => undef }
        },

        {
            name => 'Germany postcode: nnnnn',
            setup => { country => 'DE', postcode => '12345' },
            result => { matcher => '12345' }
        },
        {
            name => 'Germany (invalid) postcode: nnn-nn',
            setup => { country => 'DE', postcode => '123-45' },
            result => { matcher => undef }
        },

        {
            name => 'Guernsey postcode: llnn',
            setup => { country => 'GG', postcode => 'BH25 7HZ' },
            result => { matcher => 'BH25' }
        },
        {
            name => 'Guernsey (invalid) postcode: nnnnn',
            setup => { country => 'GG', postcode => '12345' },
            result => { matcher => undef }
        },

        {
            name => 'Hungary postcode: nnnn',
            setup => { country => 'HU', postcode => '1234' },
            result => { matcher => '1234' }
        },
        {
            name => 'Hungary (invalid) postcode: nnnnn',
            setup => { country => 'HU', postcode => '12345' },
            result => { matcher => undef }
        },

        {
            name => 'Netherlands postcode: NL-nnnnll',
            setup => { country => 'NL', postcode => 'NL-1234AB' },
            result => { matcher => '1234' }
        },
        {
            name => 'Netherlands postcode: NLnnnnn',
            setup => { country => 'NL', postcode => 'NL-1234' },
            result => { matcher => '1234' }
        },
        {
            name => 'Netherlands (invalid) postcode: nnnll',
            setup => { country => 'NL', postcode => '123AB' },
            result => { matcher => undef }
        },

        {
            name => 'Spain postcode: nnnnn',
            setup => { country => 'ES', postcode => '12345' },
            result => { matcher => '1234' }
        },
        {
            name => 'Spain (invalid) postcode: nnnn',
            setup => { country => 'ES', postcode => '1234' },
            result => { matcher => undef }
        },

        {
            name => 'Sweden postcode: nnnnn',
            setup => { country => 'SE', postcode => '12345' },
            result => { matcher => '12345' }
        },
        {
            name => 'Spain (invalid) postcode: nnnn',
            setup => { country => 'SE', postcode => '1234' },
            result => { matcher => undef }
        },

        {
            name => 'Switzerland postcode: nnnn',
            setup => { country => 'CH', postcode => '1234' },
            result => { matcher => '1234' }
        },
        {
            name => 'Switzerland (invalid) postcode: nnn',
            setup => { country => 'CH', postcode => '123' },
            result => { matcher => undef }
        },
        {
            name => 'Australia postcode: nnnn',
            setup => { country => 'AU', postcode => '1234' },
            result => { matcher => '1234' }
        },
        {
            name => 'Australia (invalid) postcode: nnn',
            setup => { country => 'AU', postcode => '123' },
            result => { matcher => undef }
        },

    ) {
        subtest $test->{name} => sub {

            my $country = $self->schema->resultset('Public::Country')->find({
                code => $test->{setup}->{country},
            });

            my $matcher = XTracker::Postcode::Analyser->extract_postcode_matcher({
                country     => $country,
                postcode    => $test->{setup}->{postcode},
            });
            is($matcher, $test->{result}->{matcher},
                sprintf('Postcode matcher as expected: %s', $test->{result}->{matcher} // 'undefined' ));
        };
    }
}
