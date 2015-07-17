package XTracker::DB::Factory::CMS;

use strict;
use warnings;

use Carp;
use Class::Std;
use Encode::Encoder qw(encoder);
use Error;

use XTracker::Comms::DataTransfer   qw(:web_cms_transfer);
use XTracker::Constants::FromDB qw( :page_instance_status );
use XTracker::Logfile qw( xt_logger );


my $logger = xt_logger();

use base qw/ Helper::Class::Schema /;

{
    sub create_page {
        my( $self, $args ) = @_;

        my $schema = $self->get_schema;

        # create XT record
        my $page = $schema->resultset('WebContent::Page')->create({
            'name'        => $args->{name},
            'type_id'     => $args->{type},
            'template_id' => $args->{template},
            'page_key'    => $args->{page_key},
            'channel_id'  => $args->{channel_id}
        });

        # get id of page created
        my $page_id = $page->id;

        # transfer to website
        transfer_web_cms_data({
            'dbh_ref'           => $args->{transfer_dbh_ref},
            'transfer_category' => 'web_cms_page',
            'ids'               => $page_id,
        });

        # transfer to staging website
        if ( $args->{staging_transfer_dbh_ref} ) {
            transfer_web_cms_data({
                'dbh_ref'           => $args->{staging_transfer_dbh_ref},
                'transfer_category' => 'web_cms_page',
                'ids'               => $page_id,
            });
        }
        return $page_id;
    }

    sub update_page {
        my( $self, $args ) = @_;
        my $schema = $self->get_schema;

        # get page db record
        my $page = $schema->resultset('WebContent::Page')->find( $args->{page_id} );
        return unless $page;

        # This bit of code has been changed a few times now, and
        # causes different bugs each time. It seems right to only
        # update properties which have been explicitly set.
        # By using 'exists' you can still set a property to undef
        # if you need to, by passing in $args->{property} = undef;
        foreach (qw(name type_id template_id page_key)){
            $page->$_($args->{$_}) if exists $args->{$_};
        }
        $page->update;
        # transfer to live website
        transfer_web_cms_data({
            'dbh_ref'             => $args->{transfer_dbh_ref},
            'transfer_category'   => 'web_cms_page',
            'ids'                 => $page->id,
        });

        # transfer to staging website
        if ( $args->{staging_transfer_dbh_ref} ) {
            transfer_web_cms_data({
                'dbh_ref'             => $args->{staging_transfer_dbh_ref},
                'transfer_category'   => 'web_cms_page',
                'ids'                 => $page->id,
            });
        }
        return;
    }

    sub create_instance {
        my( $self, $args ) = @_;

        my $schema = $self->get_schema;

        # create XT record
        my $instance = $schema->resultset('WebContent::Instance')->create({
            'page_id'         => $args->{page_id},
            'label'           => $args->{name},
            'status_id'       => $WEB_CONTENT_INSTANCE_STATUS__DRAFT,
            'created_by'      => $args->{operator_id},
            'last_updated_by' => $args->{operator_id},
        });

        # get id of instance created
        my $instance_id = $instance->id;

        # transfer to website
        transfer_web_cms_data({
            'dbh_ref'           => $args->{transfer_dbh_ref},
            'transfer_category' => 'web_cms_page_instance',
            'ids'               => $instance_id,
        });

        # transfer to staging website
        if ( $args->{staging_transfer_dbh_ref} ) {
            transfer_web_cms_data({
                'dbh_ref'           => $args->{staging_transfer_dbh_ref},
                'transfer_category' => 'web_cms_page_instance',
                'ids'               => $instance_id,
            });
        }
        return $instance_id;
    }

    sub create_content {
        my( $self, $args ) = @_;

        my $schema = $self->get_schema;
        my $content_id;

        my $content = $schema->resultset('WebContent::Content')->create({
            'instance_id' => $args->{instance_id},
            'field_id'    => $args->{field_id},
            'content'     => $args->{content},
            'category_id' => $args->{category_id} || undef,
        });

        $content_id = $content->id;

        # transfer to website
        transfer_web_cms_data({
            'dbh_ref'           => $args->{transfer_dbh_ref},
            'transfer_category' => 'web_cms_page_content',
            'ids'               => $content_id,
        });

        # transfer to staging website
        if ( $args->{staging_transfer_dbh_ref} ) {

            transfer_web_cms_data({
                'dbh_ref'           => $args->{staging_transfer_dbh_ref},
                'transfer_category' => 'web_cms_page_content',
                'ids'               => $content_id,
            });

        }

        return $content_id;

    }



    sub set_instance_status {
        my( $self, $args ) = @_;

        my $schema = $self->get_schema;

        my $live_inst;

        # if we're publishing instance we need to archive current live instance
        if ( $args->{status_id} == $WEB_CONTENT_INSTANCE_STATUS__PUBLISH ) {

            $live_inst
                = $schema->resultset('WebContent::Instance')->find({
                    'page_id'   => $args->{page_id},
                    'status_id' => $WEB_CONTENT_INSTANCE_STATUS__PUBLISH
                });

            if ( $live_inst ) {
                $live_inst->status_id( $WEB_CONTENT_INSTANCE_STATUS__ARCHIVED );
                $live_inst->last_updated( 'now()' );
                $live_inst->last_updated_by( $args->{operator_id} );
                $live_inst->update;

                # transfer to website
                transfer_web_cms_data({
                    'dbh_ref'           => $args->{transfer_dbh_ref},
                    'transfer_category' => 'web_cms_page_instance',
                    'ids'               => $live_inst->id,
                });


                # if we're publishing to staging then we need to change the current instance back to Publish status
                if ( $args->{environment} eq 'staging' ) {
                    $live_inst->status_id( $WEB_CONTENT_INSTANCE_STATUS__PUBLISH );
                    $live_inst->last_updated( 'now()' );
                    $live_inst->last_updated_by( $args->{operator_id} );
                    $live_inst->update;
                }
            }

            # update any existing instances to ARCHIVED for that page_id
            my $qry = "update page_instance set status = 'ARCHIVED' where page_id = ? and status = 'PUBLISH'";
            my $sth = $args->{transfer_dbh_ref}->{dbh_sink}->prepare($qry);
            $sth->execute($args->{page_id});

        }

        # get instance db record
        my $inst = $schema->resultset('WebContent::Instance')->find( $args->{instance_id} );

        if ( $inst ) {
            $inst->status_id( $args->{status_id} );
            $inst->last_updated( 'now()' );
            $inst->last_updated_by( $args->{operator_id} );
            $inst->update;

            # transfer to website
            transfer_web_cms_data({
                'dbh_ref'           => $args->{transfer_dbh_ref},
                'transfer_category' => 'web_cms_page_instance',
                'ids'               => $inst->id,
            });


            # if we're publishing to staging then we need to change the instance back to draft status
            if ( $args->{environment} eq 'staging' ) {
                $inst->status_id( $WEB_CONTENT_INSTANCE_STATUS__DRAFT );
                $inst->last_updated( 'now()' );
                $inst->last_updated_by( $args->{operator_id} );
                $inst->update;
            }
        }
        return;
    }

    # TODO: Investigate if this can be called from within set_content and
    # create_content so we don't need to call it separately every time after
    # having called set_content
    sub set_instance_last_updated {
        my( $self, $args ) = @_;

        my $schema = $self->get_schema;

        # get instance db record
        my $inst = $schema->resultset('WebContent::Instance')
                          ->find( $args->{instance_id} );

        if ( $inst ) {
            $inst->last_updated( 'now()' );
            $inst->last_updated_by( $args->{operator_id} );
            $inst->update;

            # transfer to website
            if ( $args->{transfer_dbh_ref} ) {
                transfer_web_cms_data({
                    'dbh_ref'           => $args->{transfer_dbh_ref},
                    'transfer_category' => 'web_cms_page_instance',
                    'ids'               => $inst->id,
                });
            }

            # transfer to staging website
            if ( $args->{staging_transfer_dbh_ref} ) {
                transfer_web_cms_data({
                    'dbh_ref'           => $args->{staging_transfer_dbh_ref},
                    'transfer_category' => 'web_cms_page_instance',
                    'ids'               => $inst->id,
                });
            }
        }
        return;
    }

    sub set_content {
        my( $self, $args ) = @_;
        my $schema = $self->get_schema;

        my $content = $schema->resultset('WebContent::Content')->find($args->{content_id});
        return unless $content;

        $content->content( $args->{content} );
        $content->category_id( $args->{category_id} || undef );
        if ($args->{field_id}) {
            $content->field_id( $args->{field_id} );
        }
        $content->update;

        # transfer to website
        if ( $args->{transfer_dbh_ref} ) {
            transfer_web_cms_data({
                'dbh_ref'             => $args->{transfer_dbh_ref},
                'transfer_category'   => 'web_cms_page_content',
                'ids'                 => $content->id,
            });
        }
        # transfer to staging website
        if ( $args->{staging_transfer_dbh_ref} ) {
            transfer_web_cms_data({
                'dbh_ref'             => $args->{staging_transfer_dbh_ref},
                'transfer_category'   => 'web_cms_page_content',
                'ids'                 => $content->id,
            });
        }
    }

    sub get_category_pages {
        my( $self ) = @_;

        my $schema = $self->get_schema;

        return $schema->resultset('Product::Attribute')->search(
            {
                'type.web_attribute' => 'NAV_LEVEL1',
                'me.deleted'         => 0,
                'me.page_id'         => { '!=' => undef },
            },
            {
                'select'   => [ qw( me.name me.page_id ) ],
                'join'     => [ qw( type ) ],
                'order_by' => [ qw( me.name ) ],
                'prefetch' => [ qw( type ) ]
            }
        );
    }

    sub get_designer_pages {
        my( $self, $channel_id ) = @_;

        my $schema = $self->get_schema;

        my %cond = (
            'designer_channel.page_id' => { '!=' => undef }
        );

        if ( $channel_id ) {
            $cond{'designer_channel.channel_id'} = $channel_id;
        }

        return $schema->resultset('Public::Designer')->search( \%cond, {
            'join'     => 'designer_channel',
            '+select'  => [ qw( designer_channel.page_id designer_channel.channel_id ) ],
            '+as'      => [ qw( page_id channel_id ) ],
            'order_by' => 'designer',
        });
    }

    sub get_page_instances {
        my( $self, $page_id ) = @_;

        my $schema = $self->get_schema;

        return $schema->resultset('WebContent::Instance')->search(
            { 'me.page_id' => $page_id, },
            {
                'join'     => [ qw( status operator_created operator_updated ) ],
                '+select'  => [ qw( status.status operator_created.name operator_updated.name ) ],
                '+as'      => [ qw( status created_by_name updated_by_name ) ],
                'order_by' => 'me.created DESC',
                'prefetch' => [ qw( status operator_created operator_updated ) ]
            }
        );

    }

    sub get_instance {
        my( $self, $instance_id ) = @_;

        my $schema = $self->get_schema;

        return $schema->resultset('WebContent::Instance')->find(
            { 'id' => $instance_id, },
            {
                'join'     => [ qw( page status operator_created operator_updated ) ],
                '+select'  => [ qw( page.name page.page_key status.status operator_created.name operator_updated.name ) ],
                '+as'      => [ qw( page_name page_key status created_by_name updated_by_name ) ],
                'prefetch' => [ qw( page status operator_created operator_updated ) ]
            }
        );

    }

    sub get_instance_content {
        my( $self, $instance_id ) = @_;

        my $schema = $self->get_schema;

        return $schema->resultset('WebContent::Content')->search(
            { 'me.instance_id' => $instance_id, },
            {
                'join'     => [ qw( field ) ],
                '+select'  => [ qw( field.name ) ],
                '+as'      => [ qw( field_name ) ],
                'prefetch' => [ qw( field ) ]
            }
        );

    }

    sub get_content {
        my( $self, $content_id ) = @_;

        my $schema = $self->get_schema;

        return $schema->resultset('WebContent::Content')->find(
            { 'me.id' => $content_id, },
            {
                'join'     => [ qw( field ) ],
                '+select'  => [ qw( field.name ) ],
                '+as'      => [ qw( field_name ) ],
                'prefetch' => [ qw( field ) ]
            }
        );

    }

    sub get_live_instance_from_pageid {
        my( $self, $page_id ) = @_;

        my $schema = $self->get_schema;

        my $rs = $schema->resultset('WebContent::Instance')->search({
            'page_id'   => $page_id,
            'status_id' => $WEB_CONTENT_INSTANCE_STATUS__PUBLISH,
        });

        my $inst = $rs->first;

        if ($inst){
            return $inst->get_column('id');
        }
        else {
            return 0;
        }

    }

    sub get_instance_from_name {
        my( $self, $page_id, $name ) = @_;

        my $schema = $self->get_schema;

        my $rs = $schema->resultset('WebContent::Instance')->search({
            'page_id'      => $page_id,
            'UPPER(label)' => uc($name),
        });

        my $inst = $rs->first;

        if ($inst){
                return $inst->get_column('id');
        }
        else {
                return 0;
        }
    }

    sub get_publish_log {
        my( $self, $page_id ) = @_;

        my $schema = $self->get_schema;

        return $schema->resultset('WebContent::PublishedLog')->search(
            {
                'page.id'   => $page_id,
                'date'      => \" >= CURRENT_TIMESTAMP - INTERVAL '100 day'",
            },
            {
                'join'     => [ 'operator', { 'instance' => 'page' } ],
                '+select'  => [ qw( operator.name instance.label ) ],
                '+as'      => [ qw( operator_name label ) ],
                'order_by' => 'me.date DESC',
                'prefetch' => [ 'operator', { 'instance' => 'page' } ]
            }
        );
    }
}

1;

__END__

=pod

=head1 NAME

XTracker::DB::Factory::CMS

=head1 DESCRIPTION

Everything you need for the CMS stuff

=head1 SYNOPSIS


=head1 AUTHOR

Ben Galbraith C<< <ben.galbraith@net-a-porter.com> >>

=cut
