package XTracker::Schema::ResultSet::Public::CountrySubdivision;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

use XTracker::Config::Local qw( config_var );
use JSON;

=head1 NAME

XTracker::Schema::ResultSet::Public::CountrySubdivision

=head1 DESCRIPTION

ResultSet class for Public::CountrySubdivision

=head1 METHODS

=head2 get_country_subdivision_with_group

    my $hashref = $schema->resultset('Public::CountrySubdivision')->get_country_subdivision_with_group;

Returns Hashref containing subdivision_grp and corresponding subdivision(district/state/county) for countries country_subdivision table
of the form :

   $return_data = {
    {

       country_id => {
                country_subdivision_name => [
                    $country_subdivision_row,
                    ],
                country_subdivsion_name => [].....
        }
        country_id=> {
            none => [...]
        }
    };


=cut

sub get_country_subdivision_with_group {
    my $self = shift;

    my $grp_rs = $self->search( {},{
        select => [ 'me.id','me.country_id','me.name','me.iso','country_subdivision_group.name','country.country'],
        order_by  => [ 'country_subdivision_group.name', 'me.name'],
        prefetch => [ 'country_subdivision_group', 'country'],
    });

    my $result;
    while ( my $row = $grp_rs->next ) {

        my $grp_name = 'none';
        if( $row->country_subdivision_group ) {
            $grp_name =  $row->country_subdivision_group->name;
        }

        push( @{ $result->{$row->country->country}{$grp_name} }, $row );

    }

    return $result;


}

=head2 json_country_subdivision_for_ui

    my $json_data = $schema->resultset('Public::CountrySubdivision')->json_country_subdivision_for_ui;

returns json data to build dropdown for a county_subdivision and country_subdivision_grp name for
countries set in config (countries_with_districts_for_ui).

It returns data of the format:
"United States" : { "none" : ['AL' :  'AL - Alabama', .........] } ....
here AL is the iso code, which is used to built dropdown value and text (label).
Note : None implies country_subdivision_group was empty.

For countries which does not have ISO in the table, the data struucture looks like

"Hongkong": { 'Kowloon': [ { 'Shek O': 'Shek O', 'Hung Hom' => 'Hung Hom' } ]};

=cut
sub json_country_subdivision_for_ui {
    my $self = shift;

    # Read config to see which countries are configured
    my $config_val =  config_var('countries_with_districts_for_ui', 'country' );


    my $list = {};
    my $country_subdivision_list = {};

    if( $config_val ) {
        my $country_arr =  ( ref ( $config_val ) ? $config_val : [ $config_val ] );
        $list = $self->get_country_subdivision_with_group();

        foreach my $country ( @ { $country_arr } ) {
            if( exists $list->{$country} ) {

               # $country_subdivision_list->{ $country } = $list->{$country};
                foreach my $grp_name ( %{ $list->{$country}} ) {
                    foreach my $row ( @{  $list->{$country}->{$grp_name}} ) {
                        my $value = $row->iso // $row->name;
                        my $label = ( $row->iso ) ? $row->iso. " - ". $row->name : $row->name;
                        push @{ $country_subdivision_list->{ $country }{ $grp_name } }, {
                            $value => $label,
                        }

                    }
                } # foreach
           } # if
        }

    }
    return ( encode_json( $country_subdivision_list ) );

}

1;





