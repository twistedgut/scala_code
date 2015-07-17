package XTracker::Database::Address;

use strict;
use warnings;

use Perl6::Export::Attrs;
use Digest::MD5;

use Try::Tiny;

use XTracker::DBEncode qw( encode_it decode_db );
use XTracker::Database qw( get_schema_using_dbh );

use Carp;
use Storable 'dclone';

use XTracker::Database  qw( get_schema_using_dbh );

use XTracker::Logfile   qw( xt_logger );

use XT::Net::Seaview::Client;


### Subroutine : create_address                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_address :Export(:DEFAULT) {
    my ( $dbh, $data ) = @_;

    my $schema = get_schema_using_dbh ($dbh, 'xtracker_schema');

    my $address_data = {};
    my $input_data   = dclone($data);

    # Rename non-db-matching address digest key
    $input_data->{address_hash} = delete $input_data->{hash};

    my @keys = qw/first_name
                  last_name
                  address_line_1
                  address_line_2
                  address_line_3
                  towncity
                  county
                  country
                  postcode
                  address_hash
                  urn
                  last_modified/;

    foreach my $key (@keys){
        if(defined $input_data->{$key}){
            $address_data->{$key} = $input_data->{$key}
        }
    }

    my $address
      = $schema->resultset('Public::OrderAddress')->create($address_data);

    return $address->id;
}

sub check_address :Export(:DEFAULT) {
    my ( $dbh, $address_hash ) = @_;

    my $address_id = 0;

    my $qry = "SELECT id FROM order_address WHERE address_hash = ?";
    my $sth = $dbh->prepare($qry);

    $sth->execute($address_hash);
    while ( my $rows = $sth->fetchrow_arrayref ) {
        $address_id = $rows->[0];
    }

    return $address_id;
}

sub hash_address :Export(:DEFAULT) {
    my ( $dbh, $data_ref ) = @_;

    my $data;
    foreach my $key (keys %$data_ref) {
        $data->{$key} = $data_ref->{$key};
    }

    my $md5 = Digest::MD5->new;

    foreach my $addressline ( sort keys %{$data} ) {
        $md5->add( encode_it($data->{$addressline} // "") );
    }

    my $address_hash = $md5->b64digest;

    return $address_hash;
}

=head2 get_address_info

    $hash_ref   = get_address_info( $schema, $address_id );
            or
    $hash_ref   = get_address_info( $dbh, $address_id );

This will return a Hash Ref of the 'order_address' record for the given Address Id.

You can pass in either a DBH or a DBIC Schema object. If you pass in a DBH then a DBIC Schema
object will be created and used to get the record but this does take time so if you are using
this function in a loop then you should pass in the DBIC Schema directly.

=cut

sub get_address_info :Export(:DEFAULT) {
    my ( $schema_or_dbh, $address_id )  = @_;

    my $schema  = $schema_or_dbh;
    if ( ref( $schema_or_dbh ) !~ /Schema/ ) {
        $schema = get_schema_using_dbh( $schema_or_dbh, 'xtracker_schema' );
    }

    my $address = $schema->resultset('Public::OrderAddress')->find($address_id);
    my $address_info;
    if ( $address ) {
        $address_info = { $address->get_inflated_columns };
    }
    return $address_info;
}

sub get_country_list :Export(:DEFAULT) {
    my ($dbh) = @_;

    my $qry  = "SELECT * FROM country";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $$row{id} } = decode_db($row);
    }
    return \%data;
}

sub get_country_tax_info :Export(:DEFAULT) {
    my ( $dbh, $country, $channel_id ) = @_;

    my $qry = "SELECT ctr.country_id, ctr.tax_name, ctr.rate, ctc.code as tax_code
               FROM country c
                   LEFT JOIN country_tax_code ctc ON c.id = ctc.country_id AND ctc.channel_id = ?,
               country_tax_rate ctr
               WHERE c.country = ?
               AND c.id = ctr.country_id";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id, $country );

    my $row = $sth->fetchrow_hashref();

    return $row;
}

=head2 get_country_data( $country_name ) : \%country_data

Returns everything from the country table for a specific country

=cut

sub get_country_data :Export(:DEFAULT) {
    my ( $schema, $country ) = @_;

    my $country_object = $schema
        ->resultset('Public::Country')
        ->search(\[ 'LOWER(me.country) = LOWER(?)', [ 'country', $country ] ])
        ->slice(0,0)
        ->single;

    return $country_object ? { $country_object->get_columns } : $country_object;
}

=head2 add_addr_key

    $address_hash_ref = add_addr_key( $address_hash_ref );

Will add the key 'addr_key' to the passed in Hash Ref and then Return It.
The 'addr_key' will be the 'urn' if available else it will be the 'id'.

=cut

sub add_addr_key :Export(:DEFAULT) {
    my $addr = shift;

    $addr->{addr_key} = (
        defined $addr->{urn}
        ? $addr->{urn}
        : $addr->{id}
    );

    return $addr;
}

=head2 get_dbic_country

    $country_rec    = get_dbic_country( $schema, $country_name );

Returns a DBIC Country object given a Country Name and a Schema connection.

=cut

sub get_dbic_country :Export(:DEFAULT) {
    my ( $schema, $country )    = @_;

    my $rec = $schema->resultset('Public::Country')
                        ->search( { country => $country } )
                            ->first;
    if ( !defined $rec ) {
        croak "Couldn't find Country: $country, in function 'get_dbic_country'";
    }
    return $rec;
}

=head2 get_seaview_address_for_id

    $hash_ref = get_seaview_address_for_id( $schema, $address_rec->id );

Return the corresponding Seaview Address (if there is one) for the 'order_address' Id.

=cut

sub get_seaview_address_for_id :Export(:DEFAULT) {
    my ( $schema, $address_id ) = @_;

    return      if ( !$address_id );

    my $address;

    try {
        my $seaview = XT::Net::Seaview::Client->new( {
            schema => $schema,
        } );

        if ( my $address_urn = $seaview->registered_address( $address_id ) ) {
            my $resource = $seaview->address( $address_urn );
            $address     = $resource->as_dbi_like_hash      if ( $resource );
        }
    } catch {
        xt_logger->info( "Address Id: '${address_id}' - Couldn't get Seaview Address: " . $_ );
    };

    return $address;
}


1;
