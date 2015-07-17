#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

roles_based_permissions.t - check OLD XT role based permissions

=head1 DESCRIPTION

Verifies that an operator is only able to access the
/WebContent/DesignerLanding section of XT if the operator has been
given the OLD style 'Web content administrator' role

#tags webcontent needsrefactor http html

=cut

use Data::Dump qw(pp);

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local qw( create_cms_page_channels );
use Test::XT::BlankDB;
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(:channel :department
                                   :web_content_type
                                   :web_content_template
                                   :designer_website_state
                              );

my $schema = Test::XTracker::Data->get_schema;

diag "User security and content tests";

my @stuff_to_delete;
END {
    for my $o (@stuff_to_delete) {
        if (ref($o) eq 'CODE') {
            $o->();
        }
        else {
            $o->delete();
        }
    }
}

if (Test::XT::BlankDB::check_blank_db($schema)) {
    my $channel = Test::XTracker::Data->get_local_channel(
        create_cms_page_channels()->[0]
    );
    # make sure at least one DLP is there
    my $page = $schema->resultset('WebContent::Page')->create({
        'name'        => 'test dlp',
        'type_id'     => $WEB_CONTENT_TYPE__DESIGNER_FOCUS,
        'template_id' => $WEB_CONTENT_TEMPLATE__DESIGNER_FOCUS,
        'page_key'    => 'test page',
        'channel_id'  => $channel->id
    });
    push @stuff_to_delete,
        $page;
    my $designer=$schema->resultset('Public::Designer')->slice(0,0)->single;
    my $dc = $designer->find_related('designer_channels',{
        channel_id => $channel->id,
    });
    if ($dc) {
        $dc->page_id($page->id);
        unshift @stuff_to_delete,sub{$dc->page_id(undef)};
    }
    else {
        $dc = $designer->find_or_create_related('designer_channels',{
            channel_id => $channel->id,
            website_state_id => $DESIGNER_WEBSITE_STATE__VISIBLE,
            page_id => $page->id,
            description => 'foo',
        });
        unshift @stuff_to_delete,$dc;
    }
}

diag "create operator instance";
my $operator    = Test::XTracker::Data->_get_operator( 'it.god' );

diag "check instance loaded";
ok($operator->id(),'operator loaded');
my $id_store=$operator->id;

diag "ensure department of operator is IT and has web admin role";
$operator->update({department_id => $DEPARTMENT__IT});
$operator->_set_role('Web content administrator');

diag "check that operator department now IT and has web admin role";
is($operator->department_id(),$DEPARTMENT__IT,'operator department is IT');
ok($operator->check_if_has_role('Web content administrator'),'operator has web admin role');

diag "set permissions for the menu option";
Test::XTracker::Data->grant_permissions('it.god', 'Web Content','Designer Landing', 2);

diag "create new mech instance";
my $mech = Test::XTracker::Mechanize->new();

diag "log in as operator";
$mech->do_login;

diag "get page and check bulk section and live/staging options available";
$mech->get_ok( '/WebContent/DesignerLanding' );
$mech->content_contains('Bulk Update Designers','bulk update options available' );
$mech->content_contains('Staging</option>','live/staging options available' );

diag "set operator department to not be IT and user id changed to not have role";
$operator->update({department_id => 1});
$operator->_remove_role('Web content administrator');

diag "check that operator department now not IT";
isnt($operator->department_id(),$DEPARTMENT__IT,'operator department is NOT IT');
is($operator->check_if_has_role('Web content administrator'),0,'operator has NO web admin role');

diag "get page and check bulk section and live/staging options NOT available";
$mech->get_ok( '/WebContent/DesignerLanding' );
$mech->content_lacks('Bulk Update Designers','bulk update options NOT available' );

diag "set operator department to be IT and make sure pages come back then remove department again";
$operator->update({department_id => $DEPARTMENT__IT});
$mech->get_ok( '/WebContent/DesignerLanding' );
$mech->content_contains('Bulk Update Designers','bulk update options available' );
$mech->content_contains('Staging</option>','live/staging options available' );
$operator->update({department_id => 1});

diag "get page and check bulk section and live/staging options NOT available";
$mech->get_ok( '/WebContent/DesignerLanding' );
$mech->content_lacks('Bulk Update Designers','bulk update options NOT available' );

diag "set operator role and make sure pages come back then remove role";
$operator->_set_role('Web content administrator');
$mech->get_ok( '/WebContent/DesignerLanding' );
$mech->content_contains('Bulk Update Designers','bulk update options available' );
$mech->content_contains('Staging</option>','live/staging options available' );
$operator->_remove_role('Web content administrator');

diag "restore operators department and role";
$operator->update({department_id => $DEPARTMENT__IT});
$operator->_set_role('Web content administrator');

diag "check that operator department now IT and role restored";
is($operator->department_id(),$DEPARTMENT__IT,'operator department is IT');
is($operator->check_if_has_role('Web content administrator'),1,'operator has web admin role');

# testing complete
done_testing();

