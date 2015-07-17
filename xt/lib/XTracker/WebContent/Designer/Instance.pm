package XTracker::WebContent::Designer::Instance;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dumper;
use Readonly;

use XTracker::Handler;
use XTracker::Error;
use XTracker::Logfile                   qw( xt_logger );
use XTracker::DB::Factory::CMS;
use XTracker::Config::Local             qw( get_file_paths );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content}           = 'webcontent/designer/instance.tt';
    $handler->{data}{yui_enabled}       = 0;
    $handler->{data}{section}           = 'Web Content';
        $handler->{data}{subsection}    = 'Designer Landing Management';

        $handler->{data}{css}   = ['/yui/container/assets/skins/sam/container.css'];
        $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/container/container-min.js' ];

    # get schema database handle
    my $db_handle       = $handler->{schema};

        # check for page id in URL
        if ( $handler->{param_of}{page_id} ) {

                $handler->{data}{page_id}       = $handler->{param_of}{page_id};
                my $page                                        = $db_handle->resultset('WebContent::Page')->get_page( $handler->{data}{page_id} );

                my $channel_info                                = $db_handle->resultset('Public::Channel')->get_channel( $page->channel_id );
                $handler->{data}{channel_info}  = $channel_info;
                $handler->{data}{sales_channel} = $channel_info->{name};
                $handler->{data}{channel_id}    = $channel_info->{id};
                $handler->{data}{template_name} = $page->template->name;

                my $file_paths  = get_file_paths( $channel_info->{config_section} );
                $handler->{data}{file_paths}    = $file_paths;

                # Back link for side nav
                push( @{ $handler->{data}{sidenav}[ 0 ]{'None'} }, { title => 'Back', url => '/WebContent/DesignerLanding?page_id='.$handler->{param_of}{page_id} } );

                # create CMS object
                my $cms_factory = XTracker::DB::Factory::CMS->new({ schema => $db_handle });

                # check for instance id in URL - we're editing an instance
                if ( $handler->{param_of}{instance_id} ) {

                        $handler->{data}{page_instance_id}      = $handler->{param_of}{instance_id};
                        $handler->{data}{page_instance}         = $cms_factory->get_instance( $handler->{param_of}{instance_id} );
                        $handler->{data}{page_inst_content}     = $cms_factory->get_instance_content( $handler->{param_of}{instance_id} );

                        if ( $handler->{data}{page_instance}->get_column('status') eq 'Archived' ) {
                                $handler->{data}{subsubsection} = 'Archived Version';
                        }
                        else {
                                $handler->{data}{subsubsection} = 'Edit Version';
                        }

                        # pre-process contents
                        while (my $content = $handler->{data}{page_inst_content}->next) {

                                # lower case the field name to prevent any case matching issues
                                my $field_name = lc($content->get_column('field_name'));

                                # main area content
                                if ( $field_name eq 'main area image' ) {
                                        $handler->{data}{contents}{main_area}{image}{id}                = $content->get_column('id');
                                        $handler->{data}{contents}{main_area}{image}{content}   = $content->get_column('content');
                                }

                                # text content
                                if ( $field_name eq 'designer description' ) {

                                        my $text_content = $content->get_column('content');
                                        # DCS-591 commented out the following as now directly entering into a textarea tag
#                                       $text_content =~ s/\'/\\'/g;
#                                       $text_content =~ s/\"/DQUOTE/g;
#                                       $text_content =~ s/\r//g;
#                                       $text_content =~ s/\n//g;

                                        $handler->{data}{contents}{text}{text}{id}              = $content->get_column('id');
                                        $handler->{data}{contents}{text}{text}{content} = $text_content;
                                }


                                # page title
                                if ( $field_name eq 'title' ) {
                                        $handler->{data}{contents}{page_title}{id}              = $content->get_column('id');
                                        $handler->{data}{contents}{page_title}{content} = $content->get_column('content');
                                }

                                # content links - awkwardly named "Left Nav Link..." due to the web devs
                                if ( $field_name =~ m/^(left nav link )(\d{1}) (text|url)/ ) {
                                        $handler->{data}{contents}{'link'.$2.'_'.$3}{id}                = $content->get_column('id');
                                        $handler->{data}{contents}{'link'.$2.'_'.$3}{content}   = $content->get_column('content');
                                }


                                # left nav links
                                if ( $field_name =~ m/^(link )(\d{1}) (text|url)/ ) {
                                        $handler->{data}{contents}{'leftlink'.$2.'_'.$3}{id}            = $content->get_column('id');
                                        $handler->{data}{contents}{'leftlink'.$2.'_'.$3}{content}       = $content->get_column('content');
                                }

                # promo block
                                if ( $field_name eq 'promo block' ) {
                                        $handler->{data}{contents}{promo_block}{id}                 = $content->get_column('id');
                                        $handler->{data}{contents}{promo_block}{content}    = $content->get_column('content');
                                }

                # promo block 2
                                if ( $field_name eq 'promo block two' ) {
                                        $handler->{data}{contents}{promo_block_2}{id}           = $content->get_column('id');
                                        $handler->{data}{contents}{promo_block_2}{content}      = $content->get_column('content');
                                }

                                # designer name font class
                                if ( $field_name eq 'designer name font class' ) {
                                        $handler->{data}{contents}{des_font_class}{id}          = $content->get_column('id');
                                        $handler->{data}{contents}{des_font_class}{content}     = $content->get_column('content');
                                }

                                # runway video
                                if ( $field_name eq 'designer runway video' ) {
                                        $handler->{data}{contents}{runway_video}{id}            = $content->get_column('id');
                                        $handler->{data}{contents}{runway_video}{content}       = $content->get_column('content');
                                }

                                # featured products
                                if ( $field_name =~ m/^fp (.*) - (pid|image.*type)/ ) {
                                        my $seq         = $1;
                                        my $type        = $2;
                                        $type           =~ s/ //g;
                                        $handler->{data}{contents}{'fp_'.$seq.'_'.$type}{id}            = $content->get_column('id');
                                        $handler->{data}{contents}{'fp_'.$seq.'_'.$type}{content}       = $content->get_column('content');
                                }
                        }

                }
                # otherwise we're creating a new instance
                else {
                        $handler->{data}{subsubsection} = 'Create Version';
                }

        }
        # should have a page id otherwise kick back to overview
        else {
                return $handler->redirect_to( "/WebContent/DesignerLanding" );
        }

    $handler->process_template( undef );

    return OK;
}


1;

__END__
