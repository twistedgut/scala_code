package XTracker::Order::CustomerCare::CustomerSearch::Search;

use NAP::policy "tt", qw( exporter );

use Perl6::Export::Attrs;
use XTracker::Database qw ( get_database_handle );
use XTracker::Database::Customer qw( check_customer );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Database::Utilities qw( enliken );
use XTracker::Config::Local qw( config_var );
use XTracker::Utilities qw( trim );
use XTracker::Logfile qw( xt_logger );
use XTracker::DBEncode qw( encode_db decode_db );

my $mysql_where = {
    customer_number => q{id = ?},
              email => q{email LIKE ?},
         first_name => q{first_name LIKE ?},
          last_name => q{last_name LIKE ?},
      customer_name => q{first_name LIKE ? AND last_name LIKE ?},
};

sub find_customers :Export(:search) {
    my ( $dbh, $arghash, $limit ) = @_;

    die "No DB handle" unless $dbh;
    die "dbh is not a real dbh" unless $dbh->can('prepare');

    my ( $search_type, $search_terms, $sales_channel )
        = @$arghash{ qw( search_type search_terms sales_channel) };

    die "No search type provided"
      unless $search_type;

    die "No search terms provided, and at least one must be"
      unless $search_terms;

    if ( ref $search_type ) {
        if ( ref $search_type ne 'ARRAY' ) {
            xt_logger->warn("If you pass search_type to find_customers as a reference it must be an array ref");
            return;
        }
        unless ( $mysql_where->{$search_type->[0]} // 0 ) {
            xt_logger->warn("find_customers called with no search_type");
            return;
        }
    }
    else {
        $search_type = 'customer_number' if $search_type eq 'any';
        unless ($mysql_where->{$search_type} // 0) {
            xt_logger->warn("find_customers called with no search_type");
            return;
        }
    }

    my %merged_results = ();

    for my $channel ( _get_channels( $dbh, $sales_channel ) ) {
        next unless $channel->{config_section};

        # get correct web db handle for channel
        my $dbh_web = get_database_handle( { name => 'Web_Live_'.$channel->{config_section},
                                             type => 'transaction' } );

        die "Unable to connect to Web_Live DB for ".$channel->{config_section}
            unless $dbh_web;

        my $results = _search_customers($dbh, $dbh_web,
                                $search_type, $search_terms, $channel, $limit);

        # Just dumb merge them - shouldn't be any duplicate keys
        @merged_results{keys %$results} = values %$results ;

        $dbh_web->commit();
        $dbh_web->disconnect();
    }

    return \%merged_results;
}

sub _search_customers {
    my ($dbh, $dbh_web, $search_type, $search_terms, $channel, $limit) = @_;

    # Trim the search results and make sure at least one term has characters in it
    my $valid_terms = 0;

    if ( ref( $search_terms ) ) {
        foreach ( 0..$#{ $search_terms }) {
            my $trimmed = trim( $search_terms->[ $_ ]);
            $search_terms->[ $_ ] = $trimmed;
            $valid_terms = 1 if (defined $trimmed && $trimmed ne "");
        }
    } else {
        $search_terms = trim( $search_terms );
        $valid_terms = 1 if (defined $search_terms && $search_terms ne "");
    }

    my $results = {};

    if ( !ref( $search_type ) && $search_type eq 'customer_name' ) {
        my ($first, $last) = split(/\s+/, $search_terms, 2);
        if ( ! $last ) {
            # customer name with only one element is last_name
            $search_type = 'last_name';
        }
    }

    my $query = _build_query ( $search_type );
    $query .= "LIMIT ?" if $limit && $limit >= 1;

    if($query && $valid_terms){
        my $sth = $dbh_web->prepare( $query );
        if ( $search_type eq 'customer_name' ) {
            my @bind_params = enliken(split(/\s+/, $search_terms, 2));
            push @bind_params, $limit if $limit && $limit >= 1;
            @bind_params = encode_db(@bind_params);
            $sth->execute( @bind_params ) or die "Cannot Execute $query for $search_terms";
        }
        else {
            my @bind_params;
            # We may get the search terms as an array ref
            if ( ref $search_terms eq 'ARRAY' ) {
                foreach my $index (0 .. $#$search_terms) {
                    my $term = $search_terms->[$index];
                    $term = enliken( $term ) unless $search_type->[$index] eq 'customer_number';
                    push @bind_params, $term;
                }
            }
            else {
                $search_terms = enliken($search_terms) unless $search_type eq 'customer_number';
                @bind_params = ( $search_terms );
            }
            push @bind_params, $limit if $limit && $limit >= 1;
            @bind_params = encode_db(@bind_params);
            $sth->execute( @bind_params ) or die "Cannot execute $query for $search_terms";
        }

        while ( my $row = $sth->fetchrow_hashref() ) {
            $results->{ $row->{id} } = decode_db($row);

            # add the channel id to the result
            $results->{ $row->{id} }{channel_id} = $channel->{id};

            # check if customer in XT database
            $results->{ $row->{id} }{customer_id} = check_customer( $dbh, $row->{id}, $channel->{id} );
        }
    } else {
        XTracker::Error::xt_warn('You submitted an invalid query. Please use a valid query.');
    }
    return $results;
}

sub _build_query {
    my $search_type = shift;
    my $where_clause;
    if ( ref $search_type eq 'ARRAY' ) {
        foreach my $type (@$search_type) {
            $where_clause .= ' AND ' if $where_clause;
            $where_clause .= $mysql_where->{$type};
        }
    }
    else {
        $where_clause = $mysql_where->{$search_type};
    }

    return unless $where_clause;

    return qq{ SELECT id,
                     email,
                     first_name,
                     last_name
                FROM customer
               WHERE $where_clause
               ORDER BY last_name,
                        first_name,
                        id
             };
}

sub _get_channels {
    my $dbh  = shift;
    my $channel = trim( shift );

    my @channels;

    if ( $channel ) {
        my ($id, $config_section) = split( /-/, $channel, 2 );

        die "Unable to determine channel ID from channel '$channel'"
            unless $id;

        die "Unable to determine config section from channel '$channel'"
            unless $config_section;

        @channels = ( { id => $id, config_section => $config_section } );
    }
    else {
        @channels = ( map { { id => $_->{id},
                              config_section => $_->{config_section}
                            }
                          }
                      values %{ get_channels( $dbh, { fulfilment_only => 0 } ) }
                    );
    }

    return @channels;
}

=head1 find_customers

    find_customers($dbh, {
        search_type => "some_type",
        search_terms => "Something",
        sales_channel => "channel",
    }, $limit);

The I<search_type> may be one of:

=item customer_number

=item customer_name

=item email

=item first_name

=item last_name

The I<sales_channel> parameter is optional

The final, optional, parameter is a number limiting the maximum number of DB rows to be returned.

=cut

1;
