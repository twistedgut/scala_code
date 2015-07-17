package NAP::Locale::Role::CurrencyName;

use NAP::policy "tt", 'role';

with 'NAP::Locale::Role';

=head1 NAME

NAP::Locale::Role::CurrencyName

=head1 DESCRIPTION

Locale implementation for Currency Name. Given Currency Code, it returns localised
Currency Name.

=cut

=head1 ATTRIBUTES

=head2 currency_lookup

Mapping of currency_code to currency Names in respective locale. As of now the list contains only 4 currency_codes.

=cut

has currency_lookup => (
    is  => 'ro',
    isa => 'HashRef[HashRef]',
    lazy_build  => 1,
);

sub _build_currency_lookup {
    my $self = shift;

    return {
        'en' => {
            'GBP' => 'British Pounds',
            'EUR' => 'Euros',
            'HKD' => 'Hong Kong Dollars',
            'USD' => 'US Dollars',
            'AUD' => 'Australian Dollars',
        },
        'de' => {
            'GBP' => 'Britisches Pfund Sterling',
            'EUR' => 'Euro',
            'HKD' => 'Hongkong-Dollar',
            'USD' => 'US-Dollar',
            'AUD' => 'Australische Dollar',
        },
        'fr' => {
            'GBP' => 'livres sterling',
            'EUR' => 'euros',
            'HKD' => 'dollars de Hong Kong',
            'USD' => 'dollars américains',
            'AUD' => 'dollars australiens',
        },
        'zh' => {
            'GBP' => '英镑',
            'EUR' => '欧元',
            'HKD' => '港币',
            'USD' => '美元',
            'AUD' => '澳大利亚元',
        }
    };

}


=head1 METHODS

=head2 currency_name( $three_char_currency_code )

Returns localised currency name for given currency code or undef if nothing was passed.
It'll return the currency_code itself incase it does not have currency_name in the lookup.

    $currency_name = $locale->currency_name ('USD');

If locale language is fr it would return 'dollars américains'

=cut

sub currency_name {
    my $self            = shift;
    my $currency_code   = shift;

    unless (defined $currency_code ) {
        $self->logger->warn( __PACKAGE__ . '::currency_name method requires - 3 digits Currency Code');
        return '';
    }

    if( exists $self->currency_lookup->{$self->language}->{$currency_code} ) {
        return $self->currency_lookup->{$self->language}->{$currency_code};
    }

    # Log the fact that the currency code does not exists
    $self->logger->warn(__PACKAGE__ . "::currency_name : Currency code $currency_code does not exist" );
    return $currency_code;

}

