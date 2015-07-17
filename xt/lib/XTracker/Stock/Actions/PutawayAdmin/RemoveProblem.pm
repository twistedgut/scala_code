package XTracker::Stock::Actions::PutawayAdmin::RemoveProblem;

=head1 NAME

XTracker::Stock::Actions::PutawayAdmin::RemoveProblem - Remove a 'problem' group from Putaway Prep Admin (Overview) page

=head1 SYNOPSIS

See <form> usage in XTracker::Stock::GoodsIn::PutawayAdmin

=head1 DESCRIPTION

Removes a 'problem' group and tidies up a bit.
Problem groups are those with successful AdviceResponse messages,
but perhaps there's a surplus or other problem.

As opposed to the full Putaway Problem Resolution page,
which deals with more complex problems involving failed AdviceResponse messages.

=cut

use strict;
use warnings;

use Try::Tiny;
use Smart::Match instance_of => { -as => 'match_instance_of' };
use MooseX::Params::Validate qw/validated_list/;

use XTracker::Handler;
use XTracker::Error qw/xt_warn xt_info/;
use XTracker::Constants::FromDB qw(
    :putaway_prep_group_status
);
use NAP::XT::Exception;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    # Mark the group as 'Resolved'
    my $error_message = remove({
        schema => $handler->schema,
        handler => $handler,
        %{ $handler->{param_of} }
    });
    return error($handler, $error_message) if $error_message;

    # If no error, then success
    my $group_id = $handler->{param_of}{group_id};
    xt_info("Group '$group_id' was removed, the discrepancy has been logged, and a stock check has been raised.");
    return finish($handler);
}

sub remove {
    my ($args) = @_;
    my $schema   = $args->{schema};
    my $handler  = $args->{handler};
    my $group_id = $args->{group_id};

    # XXX - BROKEN! finish() returns a HTTP 302 redirect code, which
    # is interpreted as an error message in the caller.
    return finish($handler) unless defined $group_id;

    # Find group
    my $pp_group;my $err;
    try {
        $pp_group = $schema->resultset('Public::PutawayPrepGroup')->find_active_group({
            group_id => $group_id }) or return "No active group with ID '$group_id' found";
        $err = 0;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            $err = $_->error;
        }
        else {
            die $_;
        }
    };
    return $err if $err;

    return "Cannot remove group '$group_id', it is not active" unless $pp_group->can_mark_resolved;

    $pp_group->resolve_problem({ message_factory => $handler->msg_factory });

    return 0; # success
}

sub error {
    my ($handler, $message) = @_;

    xt_warn($message);
    return finish($handler);
}

sub finish {
    my ($handler) = @_;
    # redirect back to Putaway Prep Admin page
    return $handler->redirect_to("/GoodsIn/PutawayPrepAdmin");
}

1;
