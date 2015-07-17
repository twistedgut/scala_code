package Test::NAP::Locale::Role::Price;

use NAP::policy "tt", qw ( test );
use feature 'unicode_strings';

use parent 'NAP::Test::Class';

use Test::XTracker::Data::Locale;
use Test::XTracker::Data;

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup();

    ok($self->schema->isa('XTracker::Schema'), "Got DB Schema object");
}

sub test_that_price_method_returns_exactly_what_was_entered : Tests {
    my $self = shift;

    # CANDO-2172 This test is only needed until the front end handling
    # of price is corrected and we can re-enable the price method.

    my @expected = (
        '12,000.3456 EURO',
        '$ 34.00',
        '&pound;   56.00 GBP',
        [ '1,234.05', 'GBP' ],
    );

    my @languages = $self->schema
                        ->resultset('Public::Language')
                        ->get_all_language_codes;

    foreach my $language ( @languages ) {
        note("Language is $language");
        my $locale  = Test::XTracker::Data::Locale->get_locale_object($language);

        ok($locale, "I have a locale object");

        foreach my $value ( @expected ) {
            my $translated;
            if ( ref $value eq 'ARRAY' ) {
                $translated = $locale->price($value->[0], $value->[1]);
                ok($translated eq join(' ', @$value),
                    "localised value from 2 inputs is correct");
            }
            else {
                $translated = $locale->price($value);
                ok($translated eq $value,
                    "localised value from single input is correct");
            }
        }
    }
}

# CANDO-2172 This test is disabled until the front end handling of price
# is corrected and we can re-enable the price method.
sub test_price_split_input_method {
    my $self = shift;

    my $locale  = Test::XTracker::Data::Locale->get_locale_object('en');

    my $expected = {
        '12,000.3456 EURO' => {
            'number' => '12000.3456',
        },
        '$ 34.00'   => {
            'symbol' => '$',
            'number' => '34.00'
        },
        '&pound;   56.00 GBP' => {
            'symbol' => "£",
            'number' => '56.00',
            'currency_code' => 'GBP',
        },
        '53453,0005345,555,33.0 AUD £' => {
            'symbol' => '£',
            'number' => '53453000534555533.0',
            'currency_code' => 'AUD'
        },
        'Rs32 66 77.45 INR' => {
            'number'  => '326677.45',
            'currency_code' => 'INR',
        },
        'AUD 23,450 $' => {
            number => '23450',
            currency_code => 'AUD',
            symbol  => '$',
        },
       'YEN 55,00,00 ¢'=> {
            number  => 550000,
            currency_code => 'YEN',
        }
    };

    my $got;
    foreach my $string ( keys %{$expected} ) {
        note " Testing string: '${string}' ";

        $got->{$string} = $locale->_price_split_input($string) ;
    }
    is_deeply( $got, $expected, "price_split_input method - Returns Expected results" );
}

# CANDO-2172 This test is disabled until the front end handling of price
# is corrected and we can re-enable the price method.
sub test_role_currency_format {
    my $self = shift;

    my $got;
    my $expected = {
        fr_FR => '123.00 $',
        de_DE => '123.00 $',
        zh_CN => '$123.00',
        en_GB => '$123.00',
        es_ES => undef,
    };
    foreach my $locale ( keys %{$expected}) {
        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);
        $got->{$locale} = $loc->_role_currency_format('$','123.00');
    }

    is_deeply( $got, $expected, "role_split_currency_format method - Returns Expected results" );
}

# CANDO-2172 This test is disabled until the front end handling of price
# is corrected and we can re-enable the price method.
sub test_price_method {
    my $self = shift;

    my $expected = {
        'fr_FR' => {
            '1345.00 EUR' => "1 345,00 €",
            "YEN 55,00,00 ¢" => "YEN 55,00,00 ¢", #as we do not have locale mapping for this currency
            "AUD 23,450 ¥ " => 'AU$23,450.00',
            "¥ 23.00 RS" => "¥ 23.00 RS",
            '55.00 GBP' => '£55.00',
            'AU$ 23,450' => 'AU$23,450.00',
            'HK$ 233.00' => 'HK$233.00',
            '23.000'  => '23,00 €',
            'EUROS' =>'EUROS',
            'GBP'  => 'GBP',
            '£$' => '£$',
            '40822222291010101010' => '40822222291010101010',
            '16.99&#8364;'  => "16,99 €",
        },
       'es_ES' => {
            '345.00 EUR' => '€ 345,00',
             "YEN 55,00,00 ¢" => "YEN 55,00,00 ¢",
             "AUD 23,450 ¥" => 'AU$ 23.450,00',
             "¥ 23.00 RS" => "¥ 23,00",
             'AU$ 23,450' => 'AU$ 23.450,00',
             'HK$ 233.00' => 'HK$ 233,00',
        },
       'zh_HK' => {
            '345.00 EUR' => "345.00 欧元",
             "YEN 55,00,00 ¢" => "YEN 55,00,00 ¢",
             "AUD 23,450 ¥" => '23,450.00 澳大利亚元',
             "¥ 23.00 RS" => "23.00 ¥",
             '45.00 &#165' => '45.00 ¥',
             'AU$ 23,450' => '23,450.00 澳大利亚元',
             'HK$ 233.00' => '233.00 港币',
             '55.00 GBP' => '55.00 英镑',
        },
        'en_GB' => {
            '345.0090 EUR' => "€345.01",
             "YEN 55,00,00 ¢" => "YEN 55,00,00 ¢",
             "AUD 23,450 ¥" => 'AU$23,450.00',
             "¥ 23.00 RS" => "¥23.00",
             '45.00 &#165' => '¥45.00',
             '55.00 GBP' => '£55.00',
             'AU$ 23,450' => 'AU$23,450.00',
             'HK$ 233.00' => 'HK$233.00',
             '23.000'  => '£23.00',
        },
        'de_DE' => {
            '1345.00 EUR' => "1.345,00 €",
            "YEN 55,00,00 ¢" => "YEN 55,00,00 ¢",
            "AUD 23,450 ¥" => 'AU$23,450.00',
            "¥ 23.00 RS" => "¥ 23.00 RS",
            'AU$ 23,450' => 'AU$23,450.00',
            'HK$ 233.00' => 'HK$233.00',
        }

    };

    my $got =();
    foreach my $locale ( keys %{$expected} ) {
        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);
        foreach my $string ( keys %{$expected->{$locale}} ) {
            note " Testing string: '${string}' for locale $locale ";
            $got->{$locale}->{$string} = $loc->price($string);
        }
    }
    is_deeply( $got, $expected, "price method - Returns formatted price in respective Locale" );

}
