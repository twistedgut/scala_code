package XTracker::Retail::Attribute::ManualSort;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dumper;
use Readonly;

use XTracker::Handler;
use XTracker::DB::Factory::ProductAttribute;
use XTracker::Error;
use XTracker::Logfile                           qw( xt_logger );
use XTracker::Config::Local         qw( config_var );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # get schema database handle
    my $db_handle = $handler->{schema};

    my $channel             = $db_handle->resultset('Public::Channel')->get_channel($handler->{param_of}{channel_id});
    $handler->{data}{channel_id}            = $handler->{param_of}{channel_id};
    $handler->{data}{sales_channel}         = $channel->{name};
    $handler->{data}{channel_info}          = $channel;

    $handler->{data}{cells_across}          = 3;
    if ( $channel->{config_section} eq "OUTNET" ) {
        $handler->{data}{cells_across}  = 2;
    }

    $handler->{data}{content}                   = 'retail/attribute/manual_sort.tt';
    $handler->{data}{yui_enabled}               = 1;
    $handler->{data}{section}                   = 'Retail';
    $handler->{data}{subsection}            = 'Attribute Management';
    $handler->{data}{subsubsection}         = 'Manual Sorting';
    $handler->{data}{xt_url}            = config_var('URL', 'url');

    $handler->{data}{attribute_type_id}     = $handler->{param_of}{'attribute_type_id'};
    $handler->{data}{attribute_type}        = $handler->{param_of}{'attribute_type'};
    $handler->{data}{attribute_id}          = $handler->{param_of}{'attribute_id'};
    $handler->{data}{attribute_name}        = $handler->{param_of}{'attribute_name'};
    $handler->{data}{attribute_key}         = $handler->{param_of}{'attribute_key'};

#    while ((my $tk, my $tv) = each (%{ $handler->{data} })) {
#        xt_logger->debug("Key: $tk, Value: $tv");
#    }

    push @{ $handler->{data}{sidenav} }, {'None', [{
            title   => 'Back',
            url             => '/Retail/AttributeManagement?attribute_type_id='.$handler->{data}{attribute_type_id}.'&attribute_type='.$handler->{data}{attribute_type}.'&attribute_id='.$handler->{data}{attribute_id}.'&attribute_name='.$handler->{data}{attribute_name}.'&attribute_key='.$handler->{data}{attribute_key}.'&channel_id='.$handler->{data}{channel_id}
        }]
    };

        # create Product Attribute object
    my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $db_handle });

    # get list of attribute products
    $handler->{data}{products} = $factory->get_attribute_products(
        {
            'attribute_id'  => $handler->{data}{attribute_id},
            'live'                  => undef,
            'visible'               => undef,
            'channel_id'    => $handler->{data}{channel_id}
        }
    );

    $handler->process_template( undef );

    return OK;
}

1;

__END__
