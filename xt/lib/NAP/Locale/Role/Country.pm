package NAP::Locale::Role::Country;

use NAP::policy "tt", qw( role );
with 'NAP::Locale::Role';

use NAP::Locale::Mapping::Country qw( $LOCALE_MAPPING__COUNTRY_NAME );

use XTracker::Database qw( schema_handle );

=head1 NAME

NAP::Locale::Role::Country

=head1 DESCRIPTION

Locale implementation for country

=head1 SYNOPSIS

    package NAP::Locale
    use NAP::policy "tt", 'class';

    with 'NAP::Locale::Role::SomeOtherRole';
    ...
    with 'NAP::Locale::Role::Country';

=head1 METHODS

=head2 country_name($country_code, $preposition)

    $country_name = $locale->country_name('Albania', 'to');

=cut

sub country_name {
    my ($self, $country_name, $preposition) = @_;

    my $schema = schema_handle();

    my $translated_string   = '';
    my $default_word_spacer = ' ';

    unless ($country_name) {
        $self->logger->warn('Neither a country name nor a country ISO was provided');
        return '';
    }

    my $country = $schema->resultset('Public::Country')->find_by_name($country_name);
    unless ($country) {
        $self->logger->warn('Can not find ISO code for country: '.$country_name);
        $translated_string  = $preposition.$default_word_spacer if ($preposition);
        $translated_string .= $country_name;
        return $translated_string;
    }

    # because '$LOCALE_MAPPING__COUNTRY_NAME' is a Read-only Constant need to check
    # if '$country->code' is in the Hash first before trying to get the Language
    # otherwise 'autovivification' will try and create the Country Code first and
    # throw a 'Modification of a read-only value attempted' Fatal error
    my $translation;
    $translation = $LOCALE_MAPPING__COUNTRY_NAME->{ $country->code }{ $self->language }
                                if ( $LOCALE_MAPPING__COUNTRY_NAME->{ $country->code } );
    unless($translation) {
        $self->logger->warn("Can not find translation for ISO: ".$country->code);
        $translated_string  = $preposition.$default_word_spacer if ($preposition);
        $translated_string .= $country_name;
        return $translated_string;
    }

    if ($preposition) {
        # need to test if 'preposition' has a value separately from testing for a key
        # in its Hash, because '$translation' comes from a Constant and as such is
        # tied to a Read-Only Hash and 'autovivification' will try and create the
        # 'preposition' key first before proceeding to test one of its keys, as the hash
        # is Read-Only a Fatal: 'Modification of a read-only value attempted' is thrown,
        # using 'exists' didn't seem to work either.
        if ( $translation->{preposition} && $translation->{preposition}{ $preposition } ) {
            $translated_string = $translation->{preposition}{$preposition};
        }
        else {
            $self->logger->warn("Can not find translation for prepostion: $preposition");
            $translated_string = $preposition.$default_word_spacer;
        }
    }

    $translated_string .= $translation->{country_name};

    return $translated_string;
}
