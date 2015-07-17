package XT::DC::View::TT;

use strict;
use warnings;
use base 'Catalyst::View::TT';
use Path::Class qw( dir );
use English '-no_match_vars';

use XTracker::Config::Local qw( app_root_dir config_var );
use XTracker::Navigation qw( build_sidenav );
use XTracker::RAVNI_transient 'remove_ravni_disabled_nav';

my $compile_dir = dir( config_var('SystemPaths','tt_compile_dir'), $EUID );

__PACKAGE__->config(
    INCLUDE_PATH => [
        map { app_root_dir . $_ } qw(
          root/base
          root/base/css
          root/base/print
          root/base/ordertracker
          root/base/stocktracker
        )
    ],
    POST_CHOMP  => 0,
    PRE_CHOMP   => 2,
    WRAPPER     => 'shared/layout/wrapper',
    COMPILE_DIR => $compile_dir,
    PLUGIN_BASE => 'NAP::Template::Plugin',
    VARIABLES => {
        config_dirs => {
            map {; $_ => config_var('SystemPaths',"${_}_dir") }
                qw(
                      barcode
                      document
                      xtdc_base
                      product_images
              ),
        },
    },
    TEMPLATE_EXTENSION => '.tt',
);

sub template_vars {
    my ($self, $c) = @_;

    my %vars = $self->next::method( $c );

    my $appname = 'XT-' . config_var('DistributionCentre', 'name');
    if (exists $c->stash->{current_sub_section}) {
        $vars{html_page_title} = $c->stash->{current_sub_section} . q{ &#8226; } . $appname;
    }
    elsif (defined $c->session->{current_sub_section}) {
        $vars{html_page_title} = $c->session->{current_sub_section} . q{ &#8226; } . $appname;
    }
    else {
        $vars{html_page_title} = $appname;
    }

    my $acl = $c->model('ACL');
    $vars{acl_obj} = $acl;
    $vars{mainnav} = ( $acl ? $acl->build_main_nav() : undef );

    $vars{sidenav} = build_sidenav( { navtype => $vars{sidenavtype}, po_id => $vars{po_id} } )
        if $vars{sidenavtype}; #  hmm bug alert .. seems i've hard coded pop type logic in this generic handler.

    $vars{instance} = config_var('XTracker', 'instance'),
    $vars{application} = $c->session->{application};
    $vars{operator_name} = $c->session->{operator_name};

    if (my $xt_error = delete $c->flash->{user_feedback} ) {
        $vars{xt_error} = $xt_error;
    }

    if (exists $vars{sidenav} && defined $vars{sidenav}) {
        $vars{sidenav} = remove_ravni_disabled_nav($vars{sidenav});
    }
    $vars{can_acl_protect_sidenav} = (
        $acl
        ? $acl->can_protect_sidenav( { url => $c->request->path } )
        : 0
    );

    return %vars;
}

1;

=head1 NAME

XT::DC::View::TT - TT View for XT::DC based around XTracker::XTemplate

=head1 DESCRIPTION

TT View for XT::DC.

=head1 SEE ALSO

L<XT::DC>

=head1 AUTHOR

Rob Edwards,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
