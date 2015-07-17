package XTracker::WebContent::Designer::Overview;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw(pp);
use Data::Dumper;
use Readonly;

use XTracker::Config::Local qw( create_cms_page_channels );
use XTracker::DB::Factory::CMS;
use XTracker::Error qw( xt_warn );
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Constants::FromDB qw( :department );

use base qw/ Helper::Class::Schema /;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema = $handler->{schema};

    my $operator = $schema->resultset('Public::Operator')->get_operator($handler->{data}{operator_id});

    if ( defined $handler->{param_of}{include_designers} ) {
        my $param_of = $handler->{param_of};
        my $designer_rs = $schema->resultset('Public::Designer')->search(
            { 'me.id' => { -in => $param_of->{include_designers} } }
        );

        my $environment_override;
        if($param_of->{environment} ne 'both'){
            $environment_override=$param_of->{environment};
        }

        eval {
            $designer_rs->update_field_content({
                channel_id    => $param_of->{channel_id},
                field_id      => $param_of->{html_field},
                field_content => $param_of->{field_content},
                operator_id   => $handler->{data}{operator_id},
                environment_override   => $environment_override,
            });
        };
        if ( my $e = $@ ) {
            xt_warn( $e );
        }
    }

    # get all channels
    my $channels = $schema->resultset('Public::Channel')->get_channels();

    # get a list of channel config sections that have pages for designers
    my $channel_with_pages = create_cms_page_channels();

    # delete any channels which don't have any pages for designers
    foreach my $channel ( keys %$channels ) {
        delete $channels->{$channel}
            if ( !grep { $channels->{$channel}{config_section} eq $_ } @$channel_with_pages );
    }

    $handler->{data}{content}    = 'webcontent/designer/overview.tt';
    $handler->{data}{section}    = 'Web Content';
    $handler->{data}{subsection} = 'Designer Landing Management';
    $handler->{data}{channels}   = $channels;


    # This restricts the bulk update feature to only web admin roles or those in IT
    my $is_in_IT_department;
    $is_in_IT_department = 1 if $handler->{data}{department_id} == $DEPARTMENT__IT;
    $handler->{data}{show_designer_bulk_upd} = $operator->check_if_has_role('Web content administrator') || $is_in_IT_department;

    # Get the fields allowed for the designer_bulk_update
    # NOTE: This assumes all Designer Focus pages have the same fields
    # NOTE: This filters to only be the promo fields to be bulk updated
    $handler->{data}{html_fields}
        = [ $schema->resultset('WebContent::Type')
                   ->search({ name => 'Designer Focus' })
                   ->slice(0,0)
                   ->single
                   ->fields
                   ->search( { name => { like=>'Promo%'} }, { order_by => 'id' } )
                   ->all
        ];

    my $channel_id = $handler->{param_of}{channel_id} || 0;
    if ( !$channel_id && !$handler->{param_of}{page_id} ) {
            $channel_id = $handler->pref_channel_id
                if ( $handler->pref_channel_id && !exists $handler->{param_of}{change} );
            $channel_id = $handler->{data}{auto_show_channel}{id}
                if ( defined $handler->{data}{auto_show_channel}{id}
                  && !exists $handler->{param_of}{change} );
    }

    if ( keys %$channels == 1 ) {
        ($channel_id) = keys %$channels;
    }

    if ( $handler->{param_of}{page_id}
      || ( $channel_id && exists $channels->{$channel_id} ) ) {

        my @left_nav;

        if ( keys %$channels > 1 ) {
            push @left_nav,
                { title => 'Change Channel',
                  url   => '/WebContent/DesignerLanding?change=1' };
        }

        my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $schema });

        # check for page id in URL
        if ( $handler->{param_of}{'page_id'} ) {
            $handler->{data}{page_id} = $handler->{param_of}{'page_id'};

            my $page
                = $schema->resultset('WebContent::Page')
                            ->get_page( $handler->{data}{page_id} );
            $channel_id = $page->channel_id;

            $handler->{data}{page} = $page;

            $handler->{data}{designer_template}{id}   = $page->template->id;
            $handler->{data}{designer_template}{name} = $page->template->name;
            $handler->{data}{des_template_list} = [
                $schema->resultset('WebContent::Template')->search(
                    { designer_landing => 1 },
                    { order_by => 'id' }
            )];

            # Create Version link for side nav
            if ( $handler->{data}{is_operator} ) {
                push @left_nav, {
                    title => 'Create New Version',
                    url   => '/WebContent/DesignerLanding/Instance?page_id='
                            . $handler->{param_of}{'page_id'}
                };
            }

            # get all page instances
            $handler->{data}{instances}
                = $cms_factory->get_page_instances( $handler->{param_of}{'page_id'} );

            # get publish log
            $handler->{data}{publish_history}
                = $cms_factory->get_publish_log( $handler->{param_of}{'page_id'} );
        }

        my $channel = $schema->resultset('Public::Channel')->find($channel_id);
        my $designer_rs = $channel->designers->search(undef,
            { order_by => 'designer' }
        );
        $handler->{data}{bulk_designers} = [ $designer_rs->all ];

        # get list of designer pages
        $handler->{data}{designers}
            = [ $cms_factory->get_designer_pages($channel_id) ];

        my $channel_info                = $channels->{ $channel_id };
        $handler->{data}{sales_channel} = $channel_info->{name};
        $handler->{data}{channel_id}    = $channel_info->{id};
        $handler->{data}{channel_info}  = $channel_info;

        push @{ $handler->{data}{sidenav} }, { 'None' => \@left_nav };
    }
    $handler->process_template( undef );
    return OK;
}

1;

__END__
