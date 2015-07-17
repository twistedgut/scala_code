package XT::JQ::DC::Receive::Event::GenerateCoupons;
# vim: ts=8 sts=4 et sw=4 sr sta
use Moose;

use MooseX::Types::Moose qw(Str Int HashRef);
use MooseX::Types::Structured qw(Dict);

use XT::Domain::Promotion;
use XTracker::Logfile qw(xt_logger);

extends 'XT::JQ::Worker';

has payload => (
    is  => 'rw',
    isa => Dict[
        event_id => Int,
    ],
    required => 1,
);

has promotion_id => (
    is      => 'rw',
    isa     => Int,
    reader  => 'get_promotion_id',
    writer  => 'set_promotion_id',
);

has promotion_domain => (
    is  => 'rw',
    isa => 'XT::Domain::Promotion',
    reader  => 'get_promotion_domain',
    writer  => 'set_promotion_domain',
);

use namespace::clean -except => 'meta';

sub do_the_task {
    my ($self, $job) = @_;

    $self->prepare_domain($job);

    # INITIALLY COPIED FROM XT::JobQueue::Promotion::GenerateCoupons::start_work()
    my ($promotion_domain);

    # get the domain
    $promotion_domain = $self->get_promotion_domain();

    # let the logs know that something is actually happening
    xt_logger->info(
          'Generating coupons for promotion #'
        . $self->get_promotion_id
        . "\n"
    );

    # 1. we need to 'freeze' the list of custards for the
    # promotion
    $promotion_domain->freeze_customers_in_groups(
        $self->get_promotion_id,
    );


    # 2. we need to generate coupons for each custard
    # (unless it's generic, and we just generate one coupon)
    $promotion_domain->generate_coupons(
        $self->get_promotion_id,
    );

    return;
    # END COPIED FROM
}

# initially copied from XT::JobQueue::Promotion::prepare_domain()
sub prepare_domain {
    my $self    = shift;
    my $job     = shift;
    my ($schema, $promotion_domain);

    # make sure someone tells us what the promo is
    if (not defined $job->arg->{payload}{event_id}) {
        $job->failed('promotion-id not specified');
    }

    # store the promotion-id
    $self->set_promotion_id( $job->arg->{payload}{event_id} );

    # get the promotion
    eval {
        $promotion_domain = XT::Domain::Promotion->new(
            { schema => $self->schema }
        );
    };
    if ($@) {
        my $error = $@; # so we don't lost it
        warn $error;
        $job->failed($error);
        die $error;
    }

    if (not defined $promotion_domain) {
        $job->failed('could not create new instance of XT::Domain::Promotion');
        return;
    }

    # save the promotion_domain as an object attribute
    $self->set_promotion_domain( $promotion_domain );

    return;
}


sub check_job_payload {
    my ($self, $job) = @_;

    return ();
}

1;
__END__

=pod

=head1 NAME

XT::JQ::DC::Send::Event::ToWebsite - Push promotions to the website

=head1 DESCRIPTION

To follow.

=head1 PAYLOAD

Just event_id:

  {
    event_id => 123456,
  }

=cut
