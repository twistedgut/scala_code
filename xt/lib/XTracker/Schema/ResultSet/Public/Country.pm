package XTracker::Schema::ResultSet::Public::Country;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Carp;

use Carp;

use base 'DBIx::Class::ResultSet';

sub get_exchange_countries {
    return $_[0]->search({local_currency_code => { '!=', undef },})->by_name;
}

sub by_name {
    return $_[0]->search(undef, { order_by => 'country' });
}

=head1 find_code($str)

Find the country by code. There should only be one record

=cut

sub find_code {
    my($self,$code) = @_;

    my $rs = $self->search({
        code => $code,
    });

    die "'$code' Found multiple matches with the same code - only be one!"
        if ($rs->count > 1);

    return if ($rs->count == 0);

    return $rs->first;
}

sub add {
    my($self,$args) = @_;

    carp "country name has to be defined and not an empty string"
        if (!defined $args->{country} || $args->{country} eq '');

    carp "country code has to be defined and not an empty string"
        if (!defined $args->{code} || $args->{code} eq '');


    return $self->create($args);
}


=head2 find_by_name

    my $country = $country_rs->find_by_name( 'Denmark' );

Return the first country row matching the country name passed in.

=cut

sub find_by_name {
    my ( $self, $name ) = @_;

    croak 'Country name required' unless defined $name;

    return $self->search({ country => $name })->first;
}

=head2 _is_country_valid

    $boolean    = $country->_is_country_valid($country_name);

This method returns TRUE if it is a valid country
=cut

sub _is_country_valid {
    my ($self, $country) = @_;

    carp '_is_country_valid called with no parameters' unless $country;
    my $country_rs = $self->search({
        country => { 'ILIKE' => $country },
    })->count;
    return 1 if $country_rs;
    return;
}

=head2 valid_countries_for_editing_address

    $result_set = $self->valid_countries_for_editing_address();

Will return a Result Set of Countries that can be Selected by an Operator
when chosing a Country for an Address, which basically means that any
Country without a 'code' is excluded along with explicitly excluding
the 'Unknown' Country.

=cut

sub valid_countries_for_editing_address {
    my $self = shift;

    return $self->search(
        {
            code    => { '!=' => '' },
            # explicitly excluding the 'Unknown' Country
            country => { '!=' => 'Unknown' },
        }
    );
}

1;
