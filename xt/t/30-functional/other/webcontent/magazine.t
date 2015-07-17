#!/usr/bin/env perl

=head1 NAME

magazine.t - Test Web Content pages: 'Magazine' and 'Designer Landing'

=head1 DESCRIPTION

1. Create a designer landing page.

2. Archive an existing magazine page.

#TAGS webcontent magazine misc http needswork

=head1 NOTES

A bit more coverage needed here, or preferably move the whole feature out of
XTracker and into a real content management system.

=cut

package WebContent::Magazine;

use NAP::policy "tt", 'test';

use FindBin::libs;

use Data::UUID;
use Data::Dump qw(pp);

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XT::BlankDB;
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(:page_instance_status :authorisation_level
                                   $WEB_CONTENT_TYPE__DESIGNER_FOCUS
                                   $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE
                                   $WEB_CONTENT_INSTANCE_STATUS__DRAFT
                                   $WEB_CONTENT_FIELD__TITLE
);

use base 'Test::Class';

sub startup : Test(startup) {
    my ( $self ) = @_;
    my $schema = Test::XTracker::Data->get_schema;
    $self->{schema} = $schema;
    $self->{mech} = Test::XTracker::Mechanize->new();
    Test::XTracker::Data->grant_permissions(
        'it.god', 'Web Content', 'Magazine', $AUTHORISATION_LEVEL__MANAGER
    );

    my $unique_value = Data::UUID->new->create_str;
    my $page = $self->{page} = $schema->resultset('WebContent::Page')->create({
        name => "Designer - test designer ($unique_value)",
        type_id => $WEB_CONTENT_TYPE__DESIGNER_FOCUS,
        template_id => $WEB_CONTENT_TEMPLATE__STANDARD_DESIGNER_LANDING_PAGE,
        page_key => "test_designer_page_-_$unique_value",
        channel_id => Test::XTracker::Data->get_local_channel()->id,
    });
    my $instance = $page->create_related('instances',{
        label => 'foo',
        status_id => $WEB_CONTENT_INSTANCE_STATUS__DRAFT,
        created => DateTime->now(),
        created_by => $APPLICATION_OPERATOR_ID,
        last_updated => DateTime->now(),
        last_updated_by => $APPLICATION_OPERATOR_ID,
    });
    my $content = $instance->create_related('contents',{
        field_id => $WEB_CONTENT_FIELD__TITLE,
        content => 'some title',
    });

    $self->{mech}->do_login;
}

sub check_links : Tests {
    my ( $self ) = @_;
    my $mech = $self->{mech};
    $mech->get_ok( '/WebContent/Magazine' );
    my @links = $mech->find_all_links( url_regex => qr{page_id} );
    $mech->links_ok( \@links );
}

sub archive_instance : Tests {
    my ( $self ) = @_;
    my $mech = $self->{mech};
    my $page = $self->{page};

    # Get or set a published instance of this page
    my $instance = $page->is_live
                 ? $page->published_instance
                 : $page->instances
                        ->slice(0,0)
                        ->single
                        ->update({ status_id => $WEB_CONTENT_INSTANCE_STATUS__PUBLISH });

    my $url = '/WebContent/Magazine/Instance'
            . '?page_id=' . $page->id
            . '&instance_id=' . $instance->id;
    $mech->get_ok( $url );

    $mech->form_name("contentForm");
    $mech->click_ok( 'status', 'Archive this page instance' );

    ok( $instance->discard_changes->is_archived, "Page instance was archived" );
}

Test::Class->runtests;
