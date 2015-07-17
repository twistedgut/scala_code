package Test::NAP::Locale::Role::CurrencyName;

use NAP::policy "tt", qw( test );
use feature 'unicode_strings';

use parent 'NAP::Test::Class';

use NAP::Locale;
use Test::XTracker::Data::Locale;

sub test_currency_code : Tests {

    my $expected = {
        'fr_FR' => {
            'INR' => 'INR',
            'GBP' => 'livres sterling',
            'EUR' => 'euros',
            'HKD' => 'dollars de Hong Kong',
            'USD' => 'dollars américains',
            'AUD' => 'dollars australiens',
        },
        'zh_CN' => {
            'INR' => 'INR',
            'GBP' => '英镑',
            'EUR' => '欧元',
            'HKD' => '港币',
            'USD' => '美元',
            'AUD' => '澳大利亚元',
         },
        'de_DE' => {
            'INR' => 'INR',
            'GBP' => 'Britisches Pfund Sterling',
            'EUR' => 'Euro',
            'HKD' => 'Hongkong-Dollar',
            'USD' => 'US-Dollar',
            'AUD' => 'Australische Dollar',
        },
        'en_GB' => {
            'INR' => 'INR',
            'GBP' => 'British Pounds',
            'HKD' => 'Hong Kong Dollars',
            'EUR' => 'Euros',
            'USD' => 'US Dollars',
            'AUD' => 'Australian Dollars',
        },
        'en_AU' => {
            'INR' => 'INR',
            'GBP' => 'British Pounds',
            'EUR' => 'Euros',
            'HKD' => 'Hong Kong Dollars',
            'USD' => 'US Dollars',
            'AUD' => 'Australian Dollars',
        }
    };

    my $got_result = ();

    foreach my $locale (keys %{$expected} ) {
        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);

        foreach my $currency_code ( keys %{$expected->{$locale}} ) {
            $got_result->{$locale}->{ $currency_code } = $loc->currency_name( $currency_code );
        }
    }


   is_deeply($got_result, $expected,'Currency names are as expected');
}

