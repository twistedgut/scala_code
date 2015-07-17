package XTracker::Database::Location;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Perl6::Export::Attrs;
use XTracker::Database              qw( get_schema_using_dbh );
use XTracker::Database::Product     qw( get_product_id );
use XTracker::Database::Channel     qw( get_channel get_channel_details );
use XTracker::Database::Attributes;
use XTracker::Utilities             qw( generate_list :string );
use XTracker::Database::Utilities;

use XTracker::Config::Local         qw( config_var iws_location_name );
use XTracker::Constants::FromDB     qw( :variant_type :flow_type :flow_status :stock_process_type :business );

use XTracker::Logfile               qw( xt_logger );
use NAP::DC::Location::Format;

=head1 NAME

XTracker::Database::Location

=cut

sub location_allows_status :Export() {
    my ($schema, $location, $status) = @_;

    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema=get_schema_using_dbh($schema,'xtracker_schema');
    }

    my $location_obj=$schema->resultset('Public::Location')->get_location({location=>$location});

    return $location_obj->allows_status($status);
}


### Subroutine : get_held_deliveries            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_held_deliveries :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my $qry = "select d.id, l.location, des.designer, dt.type
               from delivery d, location l,
                    location_delivery ld,
                    link_delivery__stock_order ldso,
                    stock_order so, product p,
                    designer des, delivery_type dt
               where ld.delivery_id = d.id
               and   ldso.delivery_id = d.id
               and   ldso.stock_order_id = so.id
               and   so.product_id = p.id
               and   p.designer_id = des.id
               and   d.type_id = dt.id
               and   ld.location_id = l.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute( );

    return results_list($sth)
}

### Subroutine : get_location_list                           ###
# usage        : $hash_ptr = get_location_list($dbh,$arg_ref)  #
# description  : Gets a list of locations, pass in arg_ref     #
#                search parameters, 'qty' whether the qty of   #
#                stock is NULL or NOT NULL or leave blank and  #
#                'location_list' a list of locations to search #
#                on.
# parameters   : DB Handler and Pointer to a HASH of params    #
# returns      : A pointer to a hash containing the results    #

sub get_location_list :Export(:DEFAULT) {

    my ($dbh,$args) = @_;

    my $qry     = "";
    my $sth;

    my %qry_args    = (
        empty => q{ WHERE q.quantity IS NULL },
        full  => q{ WHERE q.quantity IS NOT NULL }
    );

    my $where_quantity  = '';
    my %search_results;
    my @exec_params;


    if ((exists $args->{qty}) && (exists $qry_args{$args->{qty}})) {
        $where_quantity = $qry_args{$args->{qty}};
    }

    # first, check the locations for the forbidden IWS name

    my @wanted_locations=trim( @{$args->{location_list}} );

    die "A location must be specified\n" unless @wanted_locations;

    die "Location '".iws_location_name()."' is not listable\n"
        if grep { matches_iws_location( $_ ) } @wanted_locations;

    my $where_location='';

    if ( @wanted_locations > 1 ) {
        $where_location = q{ WHERE location IN (}
                          . join( q{,}, map { $dbh->quote($_) } @wanted_locations)
                          . q{)};
    }
    else {
        $where_location = q{ WHERE location = }. $dbh->quote( $wanted_locations[0] );
    }

    $qry    =<<QUERY
SELECT  l.location,
        SUM(q.quantity) AS qty,
        CAST(v.product_id AS text),
        sku_padding(v.size_id) as size_id,
        'any' AS sales_channel,
        q.status_id,
        s.name AS status
FROM    (SELECT * FROM location $where_location) l
         LEFT JOIN quantity q ON l.id = q.location_id
         LEFT JOIN variant v ON q.variant_id = v.id
         LEFT JOIN flow.status s ON s.id = q.status_id
$where_quantity
GROUP BY    v.product_id,
            v.size_id,
            l.location,
            sales_channel,
            q.status_id,
            s.name
ORDER BY    location,
            v.product_id,
            v.size_id,
            q.status_id
QUERY
;

    $sth    = $dbh->prepare($qry);
    $sth->execute(@exec_params);

    while ( my $row = $sth->fetchrow_hashref() ) {
        # Add product to location
        if ( defined($row->{product_id}) && $row->{product_id} =~ /\d+/ ) {
            $search_results{$row->{location}}{product}->{$row->{status}}->{$row->{product_id}}->{$row->{size_id}} = $row->{qty};
        }
        $search_results{$row->{location}}{sales_channel}= $row->{sales_channel};
    }

    $qry    =<<QUERY
SELECT  l.location,
        las.status_id,
        s.name AS status
FROM    (SELECT * FROM location $where_location) l
        JOIN location_allowed_status las ON las.location_id = l.id
        JOIN flow.status s ON s.id = las.status_id
        LEFT JOIN quantity q ON l.id = q.location_id
$where_quantity
ORDER BY    location,
            las.status_id
QUERY
;

    $sth    = $dbh->prepare($qry);
    $sth->execute(@exec_params);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $search_results{$row->{location}}->{allowed_status}{$row->{status_id}}=$row->{status};
    }

    return \%search_results;
}

### Subroutine : get_stock_in_location          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_stock_in_location :Export() {

    my ( $dbh, $location ) = @_;

    $location = trim($location);

    die "Location '$location' may not have its stock listed\n"
        if matches_iws_location( $location );

    my $qry
        = qq{SELECT v.id, v.product_id, q.quantity,
                sku_padding(v.size_id) as size_id, v.legacy_sku,
                l.id as location_id, l.location,
                vt.type AS variant_type,
                c.name AS sales_channel,
                s.name AS status,
                q.status_id
            FROM variant v
                INNER JOIN variant_type vt ON v.type_id = vt.id
                INNER JOIN quantity q ON v.id = q.variant_id
                INNER JOIN location l ON l.id = q.location_id
                INNER JOIN flow.status s ON q.status_id = s.id
                INNER JOIN channel c ON q.channel_id = c.id
            WHERE l.location = ?
            AND v.type_id <> $VARIANT_TYPE__SAMPLE
            ORDER BY l.location, v.product_id, v.size_id
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $location );

    return results_list($sth);
}

### Subroutine : get_location_log               ###
# usage        : get_location_log($dbh,           #
#                                 $location)      #
# description  : Get the date, product_id,        #
#                size_id and operator name for    #
#                the single specified location    #
#                sorted by date                   #
# parameters   : $dbh, $location                  #
# returns      : $location_log->$date->{          #
#                   $product_id,                  #
#                   $size_id,                     #
#                   operator}                     #

sub get_location_log :Export() {

    my ( $dbh, $location ) = @_;

    $location = trim($location);

    die "The log for location '$location' is not listable\n"
        if matches_iws_location( $location );

    my $qry = qq{
        SELECT ll.date,
               v.product_id,
               sku_padding(v.size_id) as size_id,
               o.name
          FROM location l
          JOIN log_location ll ON ll.location_id = l.id
          JOIN variant v ON ll.variant_id = v.id
          JOIN operator o ON ll.operator_id = o.id
         WHERE l.location = ?
      ORDER BY ll.date
    };

    my $sth = $dbh->prepare($qry);

    $sth->execute($location);

    my $location_log;

    while (my $row = $sth->fetchrow_hashref() ) {
        $location_log->{$row->{date}}->{product_id} = $row->{product_id};
        $location_log->{$row->{date}}->{size_id} = $row->{size_id};
        $location_log->{$row->{date}}->{operator} = $row->{name};
    }

    return $location_log;
}

### Subroutine : get_location_of_stock          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_location_of_stock :Export() {
    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};
    confess "get_location_of_stock does not accept location_type anymore"
        if defined $args_ref->{location_type};

    my $stock_status_id = $args_ref->{stock_status_id};

    $type = 'product'    if ( $type eq 'product_id' && $id =~ m/^\d+-\d+$/ );
    $type = 'product_id' if ( defined $args_ref->{stock_status_id} and $stock_status_id == $FLOW_STATUS__SAMPLE__STOCK_STATUS );

    my %clause = (
        'sku'           => q{q.variant_id = ( select id from variant where legacy_sku = ? )},
        'variant_id'    => q{q.variant_id = ?},
        'product_id'    => q{q.variant_id IN ( select id from variant where product_id = ? )},
        'product'       => q{q.variant_id IN ( select id from variant where product_id || '-' || sku_padding(size_id) = ? )},
    );

    my $restriction_clause = "";

    # the only time we want to see samples is if the stock status is samples;
    my $not_samples_clause = qq{AND v.type_id <> $VARIANT_TYPE__SAMPLE};

    if (defined $stock_status_id) {
        if ($stock_status_id == $FLOW_STATUS__SAMPLE__STOCK_STATUS) {
            $restriction_clause = qq{ AND v.type_id = $VARIANT_TYPE__SAMPLE};
            $not_samples_clause = q{}; # we WANT samples!
        }
        else {
            $restriction_clause = " AND q.status_id = ?";
        }
    }

    my $qry
        = qq{SELECT v.id, v.product_id, q.quantity,
                sku_padding(v.size_id) as size_id, v.legacy_sku,
                l.id as location_id, l.location,
                vt.type AS variant_type,
                q.channel_id AS qty_channel_id,
                c.name AS sales_channel,
                q.status_id AS qty_status_id
            FROM variant v INNER JOIN location l INNER JOIN quantity q
                ON l.id = q.location_id
                ON v.id = q.variant_id INNER JOIN variant_type vt
                    ON v.type_id = vt.id,
                channel c
            WHERE $clause{$type}
            $restriction_clause
            $not_samples_clause
            AND q.channel_id = c.id
            ORDER BY l.location, v.product_id, v.size_id
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $id, ( defined $stock_status_id ? $stock_status_id : () ) );

    return results_list($sth);
}

# DCS-866
### Subroutine : get_suggested_stock_location                          ###
# usage        : $hash_ptr = get_suggested_stock_location(               #
#                     $dbh,                                              #
#                     $variant_id,                                       #
#                     $channel_id                                        #
#                 );                                                     #
# description  : This returns a location for a variant based on these    #
#                rules: if variant has a location(s) then choose the one #
#                with the most stock if more than one has the same most  #
#                stock then sort by location (alphabetically) and choose #
#                that one, if variant has no locations then choose the   #
#                location for other sizes for the product that have the  #
#                most stock sort alphabetically if necessary, if still   #
#                no locations then get the last location for the variant #
#                and using that locations zone use the mapping table to  #
#                suggest an appropriate zone for the user to scan in a   #
#                location for.                                           #
# parameters   : A Database Handler, A Variant Id, A Sales Channel Id.   #
# returns      : A HASH Ptr. containing the following:                   #
#                   {                                                    #
#                      location => [ array of locations ],               #
#                      type => 'LOCATION' or 'ZONE' - indicates whether  #
#                               the 'location' key is populated with     #
#                               actual locations or zones.               #
#                   }                                                    #

sub get_suggested_stock_location :Export() {

    my ( $dbh, $variant_id, $channel_id, $sp_type_id )   = @_;

    my $retval;
    my $location;
    my $suggested_type  = "VARIANT";

    # get location for the variant
    $location   = get_location_of_stock( $dbh, {
                            type            => 'variant_id',
                            id              => $variant_id,
                            stock_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                        }
                  );
    # get rid of zero quantity locations
    $location   = [ grep { $_->{quantity} > 0 } @{$location} ];

    # no variant location found
    if ( !@{$location} ) {
        $suggested_type = "PRODUCT";
        my $product_id  = get_product_id( $dbh, { type => 'variant_id', id => $variant_id } );

        # get location for any variants for the product id
        $location   = get_location_of_stock( $dbh, {
                                type            => 'product_id',
                                id              => $product_id,
                                stock_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                            }
                      );
        # get rid of zero quantity locations
        $location   = [ grep { $_->{quantity} > 0 } @{$location} ];
    }

    if ( !@{$location} ) {
        # no location found for any variants for the product

        # check location log for previously used locations for this variant
        my $channel_details = get_channel_details( $dbh, $channel_id );
        my $sales_channel   = get_channel( $dbh, $channel_id );
        my $location_log    = XTracker::Database::Logging::get_location_log( $dbh, { type => 'variant_id', id => $variant_id } );
        my $last_location   = "";

        # any previous locations found?
        if ( defined $location_log->{ $sales_channel->{name} } ) {
            # yes, so suggest using the same zone
            $last_location  = $location_log->{ $sales_channel->{name} }[-1]->{location};
            my $last_zone   = substr( $last_location, 0, 4 );       # get the zone out of the location

            my $qry =<<MAP_ZONE
SELECT  lztzm.*
FROM    location_zone_to_zone_mapping lztzm
WHERE   zone_from = ?
AND     channel_id = ?
MAP_ZONE
;
            my $sth = $dbh->prepare($qry);
            $sth->execute( $last_zone, $channel_id );
            my $zone_mapping    = $sth->fetchrow_hashref();

            $retval = {
                type    => 'ZONE',
                location=> [ {
                                location => $zone_mapping->{zone_to},
                                location_type => 'ZONE',
                                quantity => ''
                           } ]
            };
        }
    }
    else {
        # found locations, so choose the first
        # (sorted by quantity descending, number ascending)
        my @locations   = sort { return ( $b->{quantity} <=> $a->{quantity} ? $b->{quantity} <=> $a->{quantity} : $a->{location} cmp $b->{location} ); } @{ $location };

        $retval = {
            type    => $suggested_type,
            location=> [ $locations[0] ]
        };
    }

    return $retval;
}


=head2 generate_location_list_long_format

Generates a list of location strings between $start and $end
inclusive for long format

parameters   : $start, $end
returns      : @list

=cut

sub generate_location_list_long_format :Export(:DEFAULT) {
    my ($start, $end, $template_format) = @_;

    my $logger = xt_logger();

    #$logger->debug("START: $start");
    #$logger->debug("END: $end");

    my ($start_unit, $start_floor, $start_aisle, $start_bay, $start_level, $start_position)
    = NAP::DC::Location::Format::parse_location_long_format($start);
    my ($end_unit, $end_floor, $end_aisle, $end_bay, $end_level, $end_position)
    = NAP::DC::Location::Format::parse_location_long_format($end);

    my @units     = generate_list($start_unit, $end_unit);
    my @floors    = generate_list($start_floor, $end_floor);
    my @aisles    = generate_list($start_aisle, $end_aisle);
    my @bays      = generate_list($start_bay, $end_bay);
    my @levels    = generate_list($start_level, $end_level);
    my @positions = generate_list($start_position, $end_position);
    my @return_list = ();

    ## no critic(ProhibitDeepNests)
    foreach my $unit (@units) {
        foreach my $floor (@floors) {
            foreach my $aisle (@aisles) {
                foreach my $bay (@bays) {
                    foreach my $level (@levels) {
                        foreach my $position (@positions) {

                            my $location_format = config_var('DistributionCentre', 'name') . '_' . $template_format;
                            my $final_location = NAP::DC::Location::Format::get_formatted_location_name($location_format, {
                                unit            => $unit,
                                floor           => $floor,
                                aisle           => $aisle,
                                bay             => $bay,
                                level           => $level,
                                position        => $position
                            });

                            push(@return_list, $final_location);

                            #$logger->debug("$final_location");
                        }
                    }
                }
            }
        }
    }

    return @return_list;
}


=head2 generate_location_list

Generates a list of location strings between $start and $end inclusive

parameters   : $start, $end
returns      : @list

=cut

sub generate_location_list :Export(:DEFAULT) {
    my ($start, $end, $template_format) = @_;

    my $logger = xt_logger();

    #$logger->debug("START: $start");
    #$logger->debug("END: $end");

    return generate_location_list_long_format($start, $end, $template_format)
        if ( ($template_format // "") eq 'long_format' );

    my ($start_floor, $start_zone, $start_location, $start_level)
        = NAP::DC::Location::Format::parse_location($start);
    my ($end_floor, $end_zone, $end_location, $end_level)
        = NAP::DC::Location::Format::parse_location($end);

    #$logger->debug("START SPLIT: $start_floor, $start_zone, $start_location, $start_level");
    #$logger->debug("END SPLIT : $end_floor, $end_zone, $end_location, $end_level");

    my @floors      = generate_list($start_floor, $end_floor);
    my @zones       = generate_list($start_zone, $end_zone);
    my @locations   = generate_list($start_location, $end_location);
    my @levels      = generate_list($start_level, $end_level);
    my @return_list = ();

    foreach my $floor (@floors) {
        foreach my $zone (@zones) {
            foreach my $location (@locations) {
                foreach my $level (@levels) {

                    my $location_format = config_var('DistributionCentre', 'name');
                    my $final_location = NAP::DC::Location::Format::get_formatted_location_name($location_format, {
                        floor       => $floor,
                        zone        => $zone,
                        location    => $location,
                        level       => $level,
                    });

                    push(@return_list, $final_location);

                    #$logger->debug("$final_location");
                }
            }
        }
    }

    return @return_list;
}

### Subroutine : create_locations               ###
# usage        : $changes = create_locations(     #
#              :            $dbh, $start, $end);  #
# description  : Creates new locations between    #
#              : $start and $end and returns a    #
#              : reference to a hash describing   #
#              : the changes made to the DB       #
# parameters   : $dbh, $start[, $end]             #
# returns      : {created_location => 1,          #
#              :  skipped_location => 0,          #
#              :  ...}                            #

sub create_locations :Export(:DEFAULT) {

    my ($schema, $start, $end, $allowed_statuses, $table) = @_;

    die "hard deprecation - create_locations can't operate on arbitrary tables ($table)" if defined $table;

    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema=get_schema_using_dbh($schema,'xtracker_schema');
    }

    $end    = $start        if (!$end);

    $allowed_statuses = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
        unless $allowed_statuses;

    $allowed_statuses = [ $allowed_statuses ] unless ref($allowed_statuses) eq 'ARRAY';

    for my $s (@$allowed_statuses) {
        $s =~ s/[^0-9]//g;
    }

    my %changes = ();
    # Get locations with any Location Types
    my @existing_locations = @{get_locations($schema, undef)};

    my @location_list      = generate_location_list($start, $end);
    my @new_locations      = ();
    my $qry                = '';

    foreach my $new_location (@location_list) {

        if ((grep {$_->{location} eq $new_location} @existing_locations) > 0) {
            #$session->{message} .= "skipping location $new_location - already exists<br />";
            $changes{$new_location} = 0;
        } else {
            #$session->{message} .= "creating location $new_location<br />";
            $changes{$new_location} = 1;
            push @new_locations, {
                location => $new_location,
                location_allowed_statuses => [
                    map {; { status_id => $_ } } @$allowed_statuses,
                ],
            };
        }
    }

    return \%changes unless @new_locations;

    eval { $schema->txn_do(sub{$schema->resultset('Public::Location')->populate(\@new_locations)}) };

    if ($@) {
        # error - redirect back
        croak($@);
    }

    return \%changes;
}

### Subroutine : delete_locations               ###
# usage        : $changes = delete_locations(     #
#              :            $dbh, $start, $end);  #
# description  :                                  #
# parameters   : $dbh, $start[, $end]             #
# returns      : {deleted_location => 1,          #
#              :  nonexistant_location => 0,      #
#              :  nonempty_location => -1,        #
#              :  ...}                            #

sub delete_locations :Export(:DEFAULT) {
    my $dbh     = shift;
    my $start   = shift;
    my $end     = shift;
    my $table   = shift;

    die "hard deprecation - delete_locations can't operate on arbitrary tables ($table)" if defined $table;

    if (!$end) {
        $end = $start;
    }

    my %changes = ();
    # Get locations with any Location Types
    my @existing_locations      = @{get_locations($dbh, undef)};
    my @location_list           = generate_location_list($start, $end);
    my $location_list_scalar    = "'" . join("','", @location_list) . "'";

    my $qry = "SELECT l.id, l.location FROM location l WHERE l.location IN ($location_list_scalar)";
    my %location_map = map { $_->[1], $_->[0] } @{$dbh->selectall_arrayref($qry)};
    my $all_ids=join ',',values %location_map;

    $qry =
    "SELECT DISTINCT l.location FROM location l, quantity q WHERE q.location_id = l.id AND l.id IN ($all_ids) UNION ".
    "SELECT DISTINCT l.location FROM location l, log_location ll WHERE ll.location_id = l.id AND l.id IN ($all_ids)";

    my @locatons_in_use = @{$dbh->selectcol_arrayref($qry)};

    my @ids=();

    eval {

    foreach my $delete_location (@location_list) {
        if ((grep {$_ eq $delete_location} @locatons_in_use) > 0) {
            $changes{$delete_location} = -1;
        } elsif ((grep {$_->{location} eq $delete_location} @existing_locations) == 0) {
            $changes{$delete_location} = 0;
        } else {
            $changes{$delete_location} = 1;
            push @ids,$location_map{$delete_location};
        }

    }

    if (@ids) {
        my $qry = "DELETE FROM location_allowed_status WHERE location_id IN (".join(',',@ids).")";
        my $sth = $dbh->prepare($qry);
        $sth->execute();
        $qry = "DELETE FROM location WHERE id IN (".join(',',@ids).")";
        $sth = $dbh->prepare($qry);
        $sth->execute();
    }
    };

    if ($dbh->err) {
        my $errstr = $dbh->errstr;
        $dbh->rollback();
        croak ($errstr . "\n$qry")
    } elsif ($@) {
        $dbh->rollback();
        croak($@);
    } else {
        $dbh->commit();
    }

    return \%changes;
}

### Subroutine : get_location_allowed_statuses                                  ###
# usage        : $location_statuses_ref = get_location_allowed_statuses($argref); #
# description  : return a hashref of statuses allowed in locations                #
#              :                                                                  #
# parameters   : { schema => $schema [, include_transit => $flag ] }              #
# returns      : hash ref of status names, keyed by id                            #
# NOTE: this horrible thing is made to return the same format as get_location_types used to, for sideways compatibility #
sub get_location_allowed_statuses :Export() {
    my ($argref) = shift;

    my ($schema, $include_transit) = @{$argref}{qw( schema include_transit )};

    my $search_condition = { type_id => $FLOW_TYPE__STOCK_STATUS };

    # exclude 'in transit' by default
    unless ($include_transit) {
        $search_condition->{id} = [ { 'not in' => [
            $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS,
            $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS
        ] } ] ;
    }

    my $statuses=$schema->resultset('Flow::Status')
        ->search( $search_condition,
                 {columns=>['id','name'],
                  order_by => { -asc => 'name' } });

    require DBIx::Class::ResultClass::HashRefInflator;

    $statuses->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my $ret={ map { $_->{id} => { type => $_->{name} } } $statuses->all };

    return $ret;
}

sub transit_location_name :Export(:iws) { return 'Transit'; }

sub matches_iws_location :Export(:iws) {
    my ($location_name) = trim(shift);

    return unless $location_name;

    return 1 if uc($location_name) eq uc(iws_location_name());
}


1;

__END__
