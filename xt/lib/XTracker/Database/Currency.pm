package XTracker::Database::Currency;

use strict;
use warnings;

use Perl6::Export::Attrs;
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw(:currency);
use Carp;


## Subroutine  : get_currency_id                 ###
# usage        : $id=get_currency_id($dbh, 'GBP')  #
# description  : converts a currency code to an id #
# parameters   : $dbh, $currency                   #
# returns      : scalar                            #

sub get_currency_id :Export(:DEFAULT) {
    my ($dbh, $currency_code) = @_;
    my $qry = "SELECT id FROM currency WHERE currency = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($currency_code);
    my $id =  $sth->fetchrow_array();
    if (!$id) {
        Carp::confess("Couldn't find a currency_id for currency $currency_code");
    }
    return $id;
}

## Subroutine  : get_currency_by_id              ###
# usage        : $ccy=get_currency_by_id($dbh, 1)  #
# description  : converts an id to a currency code #
# parameters   : $dbh, $currency_id                #
# returns      : scalar                            #

sub get_currency_by_id :Export(:DEFAULT) {
    my ($dbh, $currency_id) = @_;
    my $qry = "SELECT currency FROM currency WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($currency_id);
    my $ccy =  $sth->fetchrow_array();
    if (!$ccy) {
    die("Couldn't find a currency for currency_id $currency_id");
    }
    return $ccy;
}

## Subroutine  : get_local_currency_id           ###
# usage        : $id=get_local_currency_id($dbh)   #
# description  : Returns the currency_id for the   #
#              : local currency, as defined in the #
#              : config file                       #
# parameters   : $dbh                              #
# returns      : scalar                            #

sub get_local_currency_id :Export(:DEFAULT) {
    my ($dbh) = @_;
    my $local_currency_code = config_var('Currency', 'local_currency_code');
    return get_currency_id($dbh, $local_currency_code);
}

## Subroutine  : get_currency_glyph_map          ###
# usage        : $map=get_currency_glyph_map($dbh) #
# description  : Returns a hash of the glyphs      #
#              : (£, $ etc) for each currency.     #
#              : Glyphs are represented as HTML    #
#              : entities, and you can use the     #
#              : currency code (e.g. USD) or the   #
#              : database id as a key              #
# parameters   : $dbh                              #
# returns      : hashref                           #

sub get_currency_glyph_map :Export(:DEFAULT) {
    my ( $dbh ) = @_;

    my %map = ();
    my $qry = q{
    SELECT c.id AS currency_id, c.currency AS currency_code, cg.html_entity
        FROM currency_glyph cg, currency c, link_currency__currency_glyph l
    WHERE l.currency_glyph_id = cg.id AND l.currency_id = c.id
    };
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while (my $row = $sth->fetchrow_hashref()) {
    $map{$row->{currency_id}}   = $row->{html_entity};
    $map{$row->{currency_code}} = $row->{html_entity};
    }

    return \%map;
}

## Subroutine  : get_currency_glyph              ###
# usage        : don't                             #
# description  : This is probably deprecated, even #
#              : though it's new. Use              #
#              : get_currency_glyph_map() instead  #
#              : If I haven't found a use for it by#
#              : the time I merge to trunk, I'll   #
#              : remove the sub.
# parameters   : $dbh, $currency_code              #
# returns      : scalar (html entity)              #

sub get_currency_glyph :Export(:DEFAULT) {
    my ($dbh, $currency_code) = @_;

    my $qry = "SELECT cg.html_entity FROM currency_glyph cg, currency c, link_currency__currency_glyph link
               WHERE c.currency = ?
               AND link.currency_id = c.id
               AND link.currency_glyph_id = cg.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($currency_code);

    my ($glyph) = $sth->fetchrow_array();
    return $glyph;
}

## Subroutine : get_local_conversion_rate       ###
# usage       : $rate=get_local_conversion_rate   #
#             : ($dbh, $currency_id);             #
# description : Returns the rate for  converting  #
#             : from $currency_id into the local  #
#             : currency, as defined in the config#
#             : file.                             #
# parameters  : $dbh, $from_currency_id           #
#             : You can use a code in place of an #
#             : id, e.g. GBP.                     #
# returns     : scalar                            #

sub get_local_conversion_rate :Export(:DEFAULT) {
    my ( $dbh, $from_currency_id ) = @_;

    my $local_currency_code = config_var('Currency', 'local_currency_code');

    return get_currency_conversion_rate($dbh, $from_currency_id, $local_currency_code);
}


## Subroutine : get_local_conversion_rate_mapping ###
# usage       : $mapping=get_local_conversion_rate_mapping   #
#             : ($dbh);             #
# description : Returns a hash of conversion rates #
#             : from each currency back to the local  #
#             : currency, as defined in the config #
#             : file.                             #
# parameters  : $dbh                                #
# returns     : hash                            #

sub get_local_conversion_rate_mapping :Export() {
    my ( $dbh ) = @_;

    my $local_currency_code = config_var('Currency', 'local_currency_code');

    my %conversion_rates;

    my $qry = "SELECT source_currency, conversion_rate
                    FROM sales_conversion_rate
                    WHERE current_timestamp > date_start
                    AND destination_currency = (select id from currency where currency = ?)
                    ORDER BY date_start ASC";
    my $sth = $dbh->prepare($qry);
    $sth->execute($local_currency_code);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $conversion_rates{ $row->{source_currency} } = $row->{conversion_rate};
    }

    return \%conversion_rates;
}

## Subroutine : get_conversion_rate_from_local  ###
# usage       : $rate=get_local_conversion_rate   #
#             : ($dbh, $currency_id);             #
# description : Returns the rate for  converting  #
#             : into $currency_id from the local  #
#             : currency, as defined in the config#
#             : file.                             #
# parameters  : $dbh, $to_currency_id             #
#             : You can use a code in place of an #
#             : id, e.g. GBP.                     #
# returns     : scalar                            #
sub get_conversion_rate_from_local :Export(:DEFAULT) {
    my ( $dbh, $to_currency_id ) = @_;

    my $local_currency_code = config_var('Currency', 'local_currency_code');

    return get_currency_conversion_rate($dbh, $local_currency_code, $to_currency_id);
}


## Subroutine : get_currency_conversion_rate    ###
# usage       : $rate=get_currency_conversion_rate#
#             : ($dbh, $from_id, $to_id);         #
# description : Returns the rate for  converting  #
#             : from currency $from_id into $to_id#
#             : Note that the most recent rate is #
#             : used, which is still not a 'live' #
#             : rate. It's the rate at which that #
#             : seasons products where originally #
#             : purchased. So it could be months  #
#             : out of date compared to the market#
# parameters  : $dbh, $from_currency_id, $to_id   #
#             : You can use a code in place of an #
#             : id, e.g. GBP.                     #
# returns     : scalar                            #

sub get_currency_conversion_rate :Export(:DEFAULT) {
    my ( $dbh, $from_currency_id, $to_currency_id ) = @_;

    foreach my $ccy (\$from_currency_id, \$to_currency_id) {
        if ($$ccy !~ /^[0-9]+$/) {
            $$ccy = get_currency_id($dbh, $$ccy);
        }
    }

    my $qry = "
        select conversion_rate
        from sales_conversion_rate
        where current_timestamp > date_start
        and source_currency = ?
        and destination_currency = ?
        order by date_start desc limit 1
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($from_currency_id, $to_currency_id);

    my $rate = $sth->fetchrow_array() || 1;

    return $rate;
}

=head2 get_currencies_from_config

Returns a ref to an array of currency objects of all the configured
currencies, with the local currency at the start of the list, and any
additional currencies in the order specified in the config file afterwards.

Requires a schema as its only parameter.

=cut

sub get_currencies_from_config :Export(:DEFAULT) {
    my ( $schema ) = @_;

    my $currency_glyph_map = get_currency_glyph_map( $schema->storage->dbh );
    my $currency_rs        = $schema->resultset('Public::Currency');

    my @currencies = ();

    my $local_currency_code= config_var('Currency', 'local_currency_code');

    if ( $local_currency_code ) {
        my $local_currency     = $currency_rs->find_by_name( $local_currency_code );

        if ( $local_currency ) {
            push(@currencies, {
                    id          => $local_currency->id,
                    name        => $local_currency->currency,
                    html_entity => $currency_glyph_map->{$local_currency->id},
                    default     => 1
            });
        }
        else {
            warn("Local currency '$local_currency_code' specified in config file, but not found in DB");
        }
    }
    else {
        warn "No local currency code defined in config file";
    }

    my $additional_currency = config_var('Currency', 'additional_currency');

    if ( $additional_currency ) {
        my @additional_currency_names;

        if ( ref( $additional_currency ) eq 'ARRAY' ) {
            @additional_currency_names = @$additional_currency;
        }
        else {
            @additional_currency_names = ( $additional_currency );
        }

        foreach my $currency_name ( @additional_currency_names ) {
            my $currency = $currency_rs->find_by_name( $currency_name );

            if ( $currency ) {
                push(@currencies, {
                    id          => $currency->id,
                    name        => $currency->currency,
                    html_entity => $currency_glyph_map->{$currency->id},
                    default     => 0
                });
            }
            else {
                warn("Currency '$currency_name' specified in config file, but not found in DB");
            }
        }
    }

    return \@currencies
}

1;
