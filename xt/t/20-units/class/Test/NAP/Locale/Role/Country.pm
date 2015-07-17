package Test::NAP::Locale::Role::Country;

use NAP::policy "tt", qw( test );
use parent 'NAP::Test::Class';

use NAP::Locale;
use NAP::Locale::Mapping::Country qw( $LOCALE_MAPPING__COUNTRY_NAME );

use Encode qw( is_utf8 encode );

use feature 'unicode_strings';

use Test::XTracker::Data::Locale;

=head2 test_all_country_names
=cut

sub startup : Tests(startup) {
    my $self = shift;

    $self->{locales} = ['de_DE',
                        'fr_FR',
                        'zh_CN'];
}

sub test_all_country_names : Tests() {
    my ($self) = @_;

    foreach my $locale (@{$self->{locales}}) {

        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);

        my @countries = $self->schema->resultset('Public::Country')->all;

        foreach my $country (@countries) {

            next unless $country->code;

            note "Translating ".$country->country.' ('.$country->code.') in '.$locale;

            my $translation = $LOCALE_MAPPING__COUNTRY_NAME->{$country->code}{$loc->language};

            isnt($translation, undef, 'translation for country is available');
            ok(defined $translation->{country_name}, 'country name defined');

            my $translated_country_name = $loc->country_name($country->country);

            is($translated_country_name,
               $translation->{country_name},
               'country name translated correctly');

            foreach my $prepos ( qw{ to in for } ) {

                my $expected_translated_prepos = $prepos.' ';

                if ( $translation->{preposition} && $translation->{preposition}{ $prepos } ) {
                    $expected_translated_prepos = $translation->{preposition}{$prepos};
                }

                my $expected_translation
                    = $expected_translated_prepos.$translation->{country_name};

                my $translated_string
                    = $loc->country_name($country->country, $prepos);

                is($translated_string,
                   $expected_translation,
                   'string translated correctly');
            }
        }
    }
}

sub test_utf8_country_names : Tests() {
    my $self = shift;

    my %tests = (
        'Reunion Island' => {
            fr_FR => 'Île de la Réunion',
            de_DE => 'Réunion',
            zh_CN => '留尼汪',
        },
        'Faroe Islands' => {
            fr_FR => 'Îles Féroé',
            de_DE => 'Färöer',
            zh_CN => '法罗群岛',
        },
        'South Korea' => {
            fr_FR => 'Corée du Sud',
            de_DE => 'Südkorea',
            zh_CN => '韩国',
        }
    );

    foreach my $country (keys %tests) {
        foreach my $locale (keys %{$tests{$country}}) {

            note "Translating $country for $locale";

            my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);

            my $translated_string = $loc->country_name($country);

            ok(is_utf8($translated_string), 'translated string is utf8');

            is($translated_string,
               $tests{$country}{$locale},
               'country name translated correctly');
        }
    }
}

=head2 test_unknownm_preposition
=cut

sub test_unknown_preposition : Tests() {
    my ($self) = @_;

    for my $locale (@{$self->{locales}}) {

        note "Using locale $locale";

        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);

        my $country_name    = 'Germany';
        my $bad_preposition = 'banana';

        my $expected_translation = $bad_preposition.' '.$LOCALE_MAPPING__COUNTRY_NAME->{'DE'}{$loc->language}{country_name};

        my $translated_country_name = $loc->country_name($country_name, $bad_preposition);

        is($translated_country_name,
           $expected_translation,
           'Bad preposition was returned with the translated country');
    }
}

=head2 test_unknown_country
=cut

sub test_unknown_country : Tests() {
    my ($self) = @_;

    for my $locale (@{$self->{locales}}) {

        note "Using locale $locale";

        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);

        my $country_name = 'Republic of Scotland';
        my $preposition  = 'to';

        my $expected_translation = $preposition.' '.$country_name;

        my $translated_country_name = $loc->country_name($country_name, $preposition);

        is($translated_country_name,
           $expected_translation,
           'string returned as given');
    }
}
