package XT::DC;
# vim: set ts=4 sw=4 sts=4:
use Moose;
use namespace::autoclean;
use Catalyst::Runtime 5.80;
use XTracker::Logfile qw( xt_logger );
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Utilities         qw( parse_url_path );
use XTracker::Utilities::ACL    qw( main_nav_option_to_url_path );

use Scalar::Util qw/blessed/;

use Catalyst qw/
    ConfigLoader
    FillInForm
    Static::Simple

    Session
    Session::State::PSGI
    Session::Store::PSGI
/;

extends 'Catalyst';

our $VERSION = '0.01';

# Configure the application.
__PACKAGE__->config(
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    using_frontend_proxy => 1,
    encoding => 'utf-8',

    name => 'XTracker',
    'Plugin::Static::Simple' => {
        include_path => [
            __PACKAGE__->config->{root}.'/static/'
        ]
    },
    default_view => 'TT',
);

# Start the application
__PACKAGE__->setup();

sub check_access {
    my ($c, $section, $sub_section) = @_;

    my $handheld = $c->req->path =~ m{^/?[^/]+/HandHeld/};

    unless ($c->_is_logged_in) {
        if ( $c->is_ajax_request ) {
            xt_logger->warn('AJAX Request - Access Denied (not logged in)');
            return 0;
        } else {
            $handheld ||= ($c->req->params->{view} || '') =~ /handheld/i;
            $c->res->redirect( $handheld ? '/HandHeld' : '/Login' );
            xt_logger->warn('User redirected to login page');
            $c->detach;
        }
    }

    # ultimately the URL Path will be used to check whether access is authorised
    # or not to a page, but to keep backward compatibility the $section & $sub_section
    # will be used to form a URL if they have been passed in, then as we go through
    # each page for the XT Access Controls project we will stop passing those in
    my $url_path;
    if ( $section && $sub_section ) {
        $url_path = main_nav_option_to_url_path( $section, $sub_section );
    }
    else {
        $url_path       = $c->req->path;
        my $parsed_path = parse_url_path( $url_path );
        $section        = $parsed_path->{section};
        $sub_section    = $parsed_path->{sub_section};
    }

    my $authorised = $c->model('ACL')->has_permission( $url_path, {
        update_session   => 1,
        can_use_fallback => 1,
    } );

    unless ( $authorised ) {
        xt_logger('UserAccess')->warn("ACCESS DENIED: SECTION=\"$section/$sub_section\" "
                        .'OPERATOR_ID='.($c->session->{operator_id} // "[* UNKNOWN OPERATOR *]") . " "
                        .'USER='.($c->session->{operator_username} // "[* UNKNOWN OPERATOR *]") . " "
                        .'SESSION='.($c->session->{_session_id} // '[* NO SESSION *]')
                        );
        if ( $c->is_ajax_request ) {
            xt_logger->warn('AJAX Request - Access Denied (not authorised)');
            return 0;
        } else {
            $c->session->{xt_error}{message}{WARN} = "You don't have permission to access $sub_section in $section.";
            $handheld ||= ($c->req->params->{view} || '') =~ /handheld/i;
            $c->res->redirect( $handheld ? '/HandHeld/Home' : '/Home' );
            $c->detach;
        }
    }

    my $current_sub_section;
    if ( defined $sub_section and $sub_section !~ m{\A\s*\z} ) {
        $current_sub_section = qq{$sub_section &#8226; $section};
        $c->session->{current_sub_section} = $current_sub_section;
    }
    else {
        delete $c->session->{current_sub_section};
    }

    $c->stash(
        section => $section,
        subsection => $sub_section,
        current_sub_section => $current_sub_section,
    );

    return 1;

}

sub _is_logged_in {
    my ($c) = @_;

    return ! ! $c->session->{operator_id};
}

sub uri_for_order {
    my ($self, $order) = @_;

    $order = $order->id if blessed($order);

    return $self->uri_for('/CustomerCare/OrderSearch/OrderView', { order_id => $order } );
}

sub _add_feedback_msg {
    my ($c, $error_type, @error_messages) = @_;

    my $error_message;
    if (@error_messages > 1) {
        $error_message = sprintf($error_messages[0], @error_messages[1 .. $#error_messages]);
    } else {
        $error_message = $error_messages[0];
    }

    # append new message if we already have one or more (of this type)
    # [ multiple exists() to prevent issues with auto-vivification of
    #   {xt_error} ]
    if (
           exists( $c->flash->{user_feedback} )
        && exists( $c->flash->{user_feedback}{message} )
        && exists( $c->flash->{user_feedback}{message}{$error_type} )
    ) {
        # append new message
        $error_message = $c->flash->{user_feedback}{message}{$error_type} . "<br />$error_message";
    }

    # set the appropriate part of the flash
    $c->flash->{user_feedback}{message}{$error_type} = $error_message;

    return;
}

sub is_ajax_request {
    my $self = shift;

    my $header = $self->request->header('X-Requested-With') // '';

    return lc( $header ) eq 'xmlhttprequest'
        ? 1
        : 0;

}

sub feedback_warn { goto \&feedback_error };
sub feedback_error { shift->_add_feedback_msg(WARN => @_) }
sub feedback_info { shift->_add_feedback_msg(INFO => @_) }
sub feedback_success { shift->_add_feedback_msg(SUCCESS => @_) }
sub feedback_fatal { shift->_add_feedback_msg(FATAL => @_) }

=head1 NAME

XT::DC - Catalyst based application

=head1 SYNOPSIS

    script/xt_dc_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<XT::DC::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Rob Edwards,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
