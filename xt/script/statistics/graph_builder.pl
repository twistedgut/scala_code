#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;

use Getopt::Long;
use Data::Dump                              qw( pp );

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Statistics::Graph             qw( read_graph_file
                                                write_graph_image );
use XTracker::Database                      qw( xtracker_schema );
use XTracker::Database::Channel             qw( get_channels );
use XTracker::Config::Local;


my $from_file  = undef;
my $graph_name = undef;
my $group      = undef;
GetOptions( 'from_file=s'  => \$from_file,
            'graph_name=s' => \$graph_name,
            'group=s'      => \$group, );


# run the right graph collection
my %dispatch = ( 'daily'       => \&daily,
                 'order_stats' => \&order_stats,
               );

# database handle
my $dbh = xtracker_schema->storage->dbh;

$dispatch{$group}->();

$dbh->disconnect();


# need a file and a graph name
sub build_graph {

    my ( $from_file, $graph_name, $graph_type, $graph_size, $x_axis, $channels, $chan_to_do )   = @_;

    if( $from_file && $graph_name ) {

        my @gdata;
        my @dcolours;
        my @legend;
        my %bspoke_settings;

        print "Building $graph_name graph from file: $from_file\n";

        my $xml_path    = config_var('Statistics','stats_base_path');
        my $graph_path  = config_var('Statistics','graph_image_base') . config_var('Statistics','graph_image_relative');

        my ( $data, $labels, $legend ) = read_graph_file($xml_path.$from_file, $x_axis);

        push @gdata, shift @$data;
        foreach my $channel ( sort keys %$channels ) {
            my @row;
            my $config_section = $channels->{$channel}{config_section};
            if ( defined $chan_to_do ) {
                next if ( !exists $chan_to_do->{$config_section} );
            }

            foreach my $line ( @$data ) {
                foreach my $datum ( @$line ) {
                    push @row,$datum->{$config_section};
                }
            }

            push @gdata,[ @row ];
            my @colours = config_var('CSS_'.$config_section, 'primary_colour');
            push @dcolours, $colours[0];
            push @legend, $channels->{$channel}{name};
        }

        %bspoke_settings    = (
            bar_width   => 12,
            dclrs       => \@dcolours
        );

        write_graph_image( \@gdata, $labels, $graph_type, $graph_size, \@legend, $graph_path.$graph_name.".png", \%bspoke_settings );
    }
}

sub order_stats {
    my $channels    = get_channels($dbh);

    #build_graph( 'yearly_orders.xml', 'yearly_orders', 'lines', 'large', 'date');
    #build_graph( 'monthly_orders.xml', 'monthly_orders', 'lines', 'large', 'date');
    #build_graph( 'weekly_orders.xml', 'weekly_orders', 'lines', 'large', 'name');
    build_graph( 'order_flow.xml', 'order_overview', 'hbars_c', 'dc_home', 'name', $channels );
    build_graph( 'order_flow_premier.xml', 'order_overview_premier', 'hbars_c', 'dc_home', 'name', $channels );

    foreach ( keys %$channels ) {
        build_graph( 'order_flow.xml', 'order_overview_'.$channels->{$_}{config_section}, 'hbars_c', 'dc_home', 'name', $channels, { $channels->{$_}{config_section} => 1 } );
        build_graph( 'order_flow_premier.xml', 'order_overview_premier_'.$channels->{$_}{config_section}, 'hbars_c', 'dc_home', 'name', $channels, { $channels->{$_}{config_section} => 1 } );
    }
}
