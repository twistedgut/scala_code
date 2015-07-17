package NAP::Locale::Role::Price;

use NAP::policy "tt", qw( role );

with 'NAP::Locale::Role';

use HTML::Entities;
use Number::Format;

=head1 NAME

NAP::Locale::Role::Price

=head1 DESCRIPTION

Locale implementation for Currency Formatting.

=head1 ATTRIBUTES

=head2 symbol_mapping

Mapping of currency_code to respective currency symbols. As of now the list contains only currencies we handle now.

=cut

# maps Currency_code to currency symbols for currencies we care for as of now
has symbol_mapping => (
    is  => 'ro',
    isa => 'HashRef',
    lazy_build  => 1,
);

#For French/ German they only like to see
#price formatting for price having euro currency
#for all other currencies they would like to see
#price formatter to locale of the symbol
has symbol_to_locale_mapping => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);

# Fr/DE share same currency
has language_to_symbol => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);

sub _build_symbol_mapping {
    my $self = shift;

    return {
        'GBP' => '£',
        'EUR' => '€',
        'HKD' => 'HK$',
        'AUD' => 'AU$',
        'USD' => '$',
    };

}

sub _build_symbol_to_locale_mapping {
    my $self =  shift;

    # We do not list EURO here as it does not map to a single locale
    return {
        'HK$' => 'en_US',
        '$'   => 'en_US',
        '£'   => 'en_GB',
        'AU$' => 'en_US',
    };
}

sub _build_language_to_symbol {
    my $self = shift;

    return {
        'fr' => '€',
        'de' => '€',
    };
}


=head1 METHODS

=head2 price ( $number );
=head2 price ( $currency_symbol_and_number_str );
=head2 price ( $number_with_three_char_currency_code );
=head2 price ( $string_containing_number_symbol_currency_code );

Returns currency formatted string in current Locale if it can else returns the input string as it is.

Here are various examples :
    $formatted_currency _string =  $locale->price ( '$12,3.00' );
    $formatted_currency _string =  $locale->price ( 'USD 12,3.00' );
    $formatted_currency _string =  $locale->price ( '$12,3.00 USD' );
    $formatted_currency_string  =  $locale->price ( '£45.00','USD');

Output would be:
        123.00 $ for de language
        123.00 $ for fr language
        $123.00 for zh and en language
        $45.00 for en as currency_code (optional parameter) has high precendence over symbol


=cut

sub price {
    my $self                = shift;
    my $price               = shift;
    my $optional_curr_code  = shift;

    my $formatted_result;

    if( ! $price ) {
        $self->logger->warn( __PACKAGE__ . '::price called without any input');
        return '';
    }

    # CANDO-2172 : Until the front end systems have been updated to display
    # prices correctly for different locales we have to revert to the previous
    # behaviour for XT.

    return $self->trim_str(join(' ', $price, $optional_curr_code // ''));

    ## no critic(ProhibitUnreachableCode)

    # parse the input
    my $input = $self->_price_split_input( $price );

    if( $optional_curr_code &&  $optional_curr_code=~ m/\b([A-Z]{3})\b/ ) {
        $input->{currency_code} = $optional_curr_code;
    }

    my $return_as_is = 0;

    # overwrite input->{symbol} if currency_code was part of input string
    if ( exists $input->{currency_code} ) {
        if( exists $self->symbol_mapping->{ $input->{currency_code} } ) {
            $input->{symbol}  =  $self->symbol_mapping->{ $input->{currency_code} };
        } else {
            # would be used if we did not have the currency_code mapping
            # then we want to return input string as it is.
            $return_as_is = 1;
        }
    }


    # by default formatted_price is whatever was inputed
    $formatted_result->{formatted_price}  = defined $optional_curr_code ? "$price $optional_curr_code" : $price;
    # save the currenct locale in case we set with a new one for formatting
    my $old_locale = $self->locale;
    # We initialise this once here and only change it if we need to change the locale
    my $nf = Number::Format->new(%{ $self->localeconv } );

    if( exists $input->{symbol} && $input->{number} ) {

        my $language = $self->language;

        # Case 1 : Chinese price formatting needs currency symbols suffixed with formatted price
        # hence handling it separately
        if( $language eq 'zh') {
            my $number = $self->_role_price_format ($nf,$input->{number},'');
            my $result;
            $result = $number. " " .$self->_role_zh_currency_format($input->{symbol}) if $number;
            return $result ? $result : $formatted_result->{formatted_price} ;
        }

        # Case 2: when Locale is FR/DE then we need to format price to fr/de locale if currency is euro
        # otherwise we need to format to the locale of currency_symbol
        if( exists $self->language_to_symbol->{$self->language}) {
            # Is the symbol we were given the same as the language's own?
            if ( $self->language_to_symbol->{$self->language} eq $input->{symbol} ) {
                my $result = $self->_role_price_format( $nf, $input->{number},$input->{symbol});
                return $result ? $result : $formatted_result->{formatted_price};
            }
            else {
                # If it is FR/ DE but ccurrency is NOT Euro
                my $result;
                if( exists $self->symbol_to_locale_mapping->{ $input->{symbol} } ) {
                    # We change the locale to that of the currency ...
                    $self->locale($self->symbol_to_locale_mapping->{ $input->{symbol} });
                    # ... reset Number::Format ...
                    $nf = Number::Format->new(%{ $self->localeconv } );
                    $result = $self->_role_price_format( $nf, $input->{number}, $input->{symbol});
                    # ... and change the locale back to the one we had before.
                    $self->locale($old_locale);
                }
                return $result ? $result : $formatted_result->{formatted_price} ;
            }
        } else {
            # Case 3: For all other locale, format price in respective locale irrespective of
            # currency
            my $result =  $self->_role_price_format( $nf, $input->{number}, $input->{symbol} );
            return $result ? $result : $formatted_result->{formatted_price} ;
        }

     } elsif ( $return_as_is == 1 ) {
        # Return what was given to us as we were unable to translate symbol/curency_code attached to the price.
        return $formatted_result->{formatted_price};
    } elsif ( $input->{number} ) {
        # If only Number was passed in format the number to respective locale
        my $result = $self->_role_price_format ($nf, $input->{number},$self->localeconv->{currency_symbol});

        if( $result ) {
            # There is Bug in POSIX it does not return currency symbol for EUR
            $result =~ s/EUR/€/g;
            return $result;
        }
    }

    return $formatted_result->{formatted_price};


}

sub _role_price_format {
    my $self            = shift;
    my $nf_obj          = shift;
    my $number          = shift;
    my $currency_symbol = shift;

    my $result;
    try {
        $result = $nf_obj->format_price( $number,undef ,$currency_symbol );
    }
    catch {
        # If anything went wrong, add a warning to the log.
        $self->logger->warn( __PACKAGE__ . ":: price format_price failed: $_" );
    };
    return $result;
}

sub _price_split_input {
    my $self    = shift;
    my $input_string  = shift;

    my $return_hash;
    # Decode html entities if any to corresponding symbols
    $input_string = decode_entities($input_string);

    # Hard coding the currencies we handle as of now
    my $symbol_search = '\$|\£|\€|\¥|\₩|HK\$|AU\$';

    # Extract the symbol
    my ($symbol) = $input_string =~ m/($symbol_search)/;
    $return_hash->{symbol} = $symbol if $symbol;

    # Extract the currency name
    my ($currency_code) = $input_string =~ m/\b([A-Z]{3})\b/;
    $return_hash->{'currency_code'} =  $currency_code if $currency_code;

    # Get rid of currency name
    $input_string =~ s/$currency_code// if $currency_code;
    # Get rid of commas and whitespaces
    $input_string =~ s/[\,\s]*//g;

    my ($number) = $input_string =~ m{ ([+-]?\d+\.?\d*)}x;
    $return_hash->{'number'} = $number if $number;

    return $return_hash;
}


sub _role_currency_format {
    my $self        = shift;
    my $symbol      = shift;
    my $price       = shift;

    # Return undef
    unless ( $price && $symbol ) {
        return;
    }

    # We are using CLDR format strings for currencyFormats
    given ( $self->language ) {
        when ( 'en' ) { return "$symbol$price" }
        when ( 'fr' ) { return "$price $symbol" }
        when ( 'de' ) { return "$price $symbol" }
        when ( 'zh' ) { return "$symbol$price" }
        default { return }
    };

    return;
}


sub _role_zh_currency_format {
    my $self   = shift;
    my $symbol  = shift;

    # Return undef
    unless ( $symbol ) {
        return;
    }

    given ( $symbol ) {
        when (/^\$$/)      { return "美元" }
        when (/^£$/)      { return "英镑" }
        when (/^€$/x)      { return "欧元" }
        when (/^AU\$$/)    { return "澳大利亚元" }
        when (/^HK\$$/)    { return "港币" }
        default {return "$symbol"; }
    }

}

