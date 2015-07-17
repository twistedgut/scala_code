package XTracker::Home;
use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Utilities                 qw( format_currency );
use XTracker::Database::Finance;
use XTracker::Database::Currency;
use XTracker::Statistics::Graph         qw( read_graph_file );
use XTracker::Config::Local             qw( config_var );
use XTracker::Utilities                 qw( get_random_id );
use XTracker::Error;
use XTracker::Database::Channel         qw( get_channels );
use DateTime;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $error       = delete($handler->{session}{error}{message});
    my @levels      = split /\//, $handler->{data}{uri};
    my $dt          = DateTime->now( time_zone => "local" );

    $handler->{data}{section}           = 'Home';
    $handler->{data}{subsection}        = '';
    $handler->{data}{subsubsection}     = '';
    $handler->{data}{show_graph}        = 1;
    $handler->{data}{sidenav}           = ( $handler->{data}{uri} !~ m{^/HandHeld} ? [ {'None' => [{ title => 'My Preferences', url => '/My/UserPref' }] } ] : "" );
    $handler->{data}{random_id}         = get_random_id();
    $handler->{data}{error_msg}         = $error;
    $handler->{data}{dc_name}           = config_var('DistributionCentre', 'name');
    $handler->{data}{view_type}         = $handler->{param_of}{'view_type'};
    $handler->{data}{date_today}        = $dt->date;
    $handler->{data}{date_yesterday}    = $dt->subtract( hours => 24 )->date;


    if (defined $levels[1] && $levels[1] eq "HandHeld"){
        $handler->{data}{content}   = "shared/home_handheld.tt";
        $handler->{data}{view}      = "HandHeld";
    }
    else {
        $handler->{data}{content}   = "shared/home.tt";
        $handler->{data}{graph_path}= config_var('Statistics','graph_image_relative');

        # read in stats from file
        # to create output tables
        my ($data_count, $data_value, $data_dispatch);
        my ($currency_count, $currency_value, $currency_dispatch);

        try {
            ($data_count,    undef, $currency_count)    = read_graph_file( config_var('Statistics', 'order_count'),     'name');
            ($data_value,    undef, $currency_value)    = read_graph_file( config_var('Statistics', 'order_value'),     'name');
            ($data_dispatch, undef, $currency_dispatch) = read_graph_file( config_var('Statistics', 'dispatch_count') , 'name');

            _prepare_page_data(
                $handler,
                $data_count, $data_value, $data_dispatch,
                $currency_count, $currency_value, $currency_dispatch,
            );
        }
        catch {
            when (m{Could not create file parser context}) {
                xt_info('Graph data not present on this system');
                $handler->{data}{section}       = ''; # hide title
                $handler->{data}{show_graph}    = 0;
            }

            default {
                xt_die( $_ );
            }
        };
    }

    $handler->process_template( undef );
}

sub _prepare_page_data {
    my (
        $handler,
        $data_count, $data_value, $data_dispatch,
        $currency_count, $currency_value, $currency_dispatch
    ) = @_;

    my $channels                = get_channels($handler->{dbh});
    $handler->{data}{channels}  = $channels;

    $handler->{data}{currency_glyph_map}    = get_currency_glyph_map($handler->{dbh});
    $handler->{data}{local_currency_id}     = get_local_currency_id($handler->{dbh});
    $handler->{data}{graph_img_suffix}      = "";

    # If a user has a preferred channel then use it but not if they have actually specfied a different channel from the page
    if ( !exists $handler->{param_of}{channel_toview} && $handler->pref_channel_id ) {
        $handler->{param_of}{channel_toview}    = $handler->pref_channel_id;
    }

    # get the Sales Channel to view or set to 'ALL' to get totals instead
    my $channel_conf_section    = "ALL";
    if ( exists $channels->{ $handler->{param_of}{channel_toview} || "" } ) {
        my $channel_toview      = $handler->{param_of}{channel_toview};

        $channel_conf_section               = $channels->{$channel_toview}{config_section} || 'ALL';
        $handler->{data}{sales_channel}     = $channels->{$channel_toview}{name};
        $handler->{data}{graph_img_suffix}  = "_".$channel_conf_section;
    }

    my %order_details           = ();
    my %dispatch_details        = ();
    my %local_currency_totals   = ();

    _populate_hash($data_count, $currency_count, \%order_details, 'count', $channel_conf_section);
    _populate_hash($data_value, $currency_value, \%order_details, 'value', $channel_conf_section);

    my $today_index             = $data_dispatch->[0]->[0] =~ /Today$/ ? 0 : 1;
    my $yesterday_index         = 1 - $today_index;
    $dispatch_details{today}    = $data_dispatch->[1]->[$today_index]->{$channel_conf_section};
    $dispatch_details{yesterday}= $data_dispatch->[1]->[$yesterday_index]->{$channel_conf_section};

    # calculate totals
    foreach my $currency (@$currency_value) {
        my $conversion_rate = get_local_conversion_rate($handler->{dbh}, $currency);
        foreach my $day (qw(today yesterday)) {
            $local_currency_totals{$day}->{value} += ($order_details{$currency}->{$day}->{value} * $conversion_rate);
            $local_currency_totals{$day}->{count} +=  $order_details{$currency}->{$day}->{count};
            #debug
            $order_details{$currency}->{local_conversion_rate} = $conversion_rate;
        }
    }

    # format the currency values now that we've finished with them
    foreach my $day (qw(today yesterday)) {
        $local_currency_totals{$day}->{value} = format_currency($local_currency_totals{$day}->{value});
        foreach my $currency (@$currency_value) {
            $order_details{$currency}->{$day}->{value} = format_currency($order_details{$currency}->{$day}->{value});
        }
    }

    $handler->{data}{order_totals}          = \%order_details;
    $handler->{data}{dispatched}            = \%dispatch_details;
    $handler->{data}{local_currency_total}  = \%local_currency_totals;

    return;
}

# All the data for orders recieved is in the form required for GD::Graph,
# just in case it one day needs to be a pie chart or something. This
# format is akward to work with, so we need to convert it to a more
# usable hash. That's what this sub is for.
sub _populate_hash {
    my ( $data, $currency, $order_details, $key, $channel_toview )  = @_;

    my $currency_index   = 0;
    my $today_index      = $data->[0]->[0] =~ /Today$/ ? 0 : 1;
    my $yesterday_index  = 1 - $today_index;
    my %currency_indices = ();

    # Currency names are in an array. The order in which the currencies
    # appear in the array is the same as the order of data for individual
    # currencies in the $data array. We need a lookup hash

    foreach my $c (@$currency) {
        $currency_indices{$c}   = $currency_index + 1; # +1 to skip the ['Orders Today', 'Orders Yest'] bit
        $currency_index++;
    }

    foreach my $currency (keys(%currency_indices)) {
        $currency_index                                 = $currency_indices{$currency};
        $order_details->{$currency}->{today}->{$key}    = $data->[$currency_index]->[$today_index]->{$channel_toview};
        $order_details->{$currency}->{yesterday}->{$key}= $data->[$currency_index]->[$yesterday_index]->{$channel_toview};
    }
}

1;

__END__
