package XT::Service::Promotion::Summary;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw(pp);
use Data::FormValidator;
use Data::FormValidator::Constraints qw(:closures);
use DateTime;

use XT::Domain::Promotion;
use XT::Domain::Product;
use XT::JQ::DC;

#use XT::Data::Promotion::CreateEdit;

use XTracker::Promotion::Common qw( construct_left_nav );
use XTracker::Constants::FromDB qw( :promotion_status :promotion_website);
use XTracker::DFV qw( :promotions );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);
use XTracker::Session;
use XTracker::Promotion::Coupon;

use base qw/ XT::Service /;

use Class::Std;
{

    # object attributes
    my %promo_domain_of     :ATTR( get => 'promo_domain',                               set => 'promo_domain' );
    my %product_domain_of   :ATTR( get => 'product_domain',                             set => 'product_domain' );

    sub START {
        my($self) = @_;
        my $schema = $self->get_schema;

        $self->set_promo_domain(
             XT::Domain::Promotion->new({ schema => $schema })
        );
        $self->set_product_domain(
             XT::Domain::Product->new({ schema => $schema })
        );
    }

    sub process {
        my($self) = @_;
        my $handler = $self->get_handler();
        my $schema = $handler->{schema};

        # create objects that provide access to the tiers we want
        my $promotion = $self->get_promo_domain;

        # we always want a list of promotions
        $handler->{data}{promotions} = $promotion->promotion_summary(
              {
                    'detail_websites.website_id'    => { in  => [
                        $PROMOTION_WEBSITE__APAC,
                        $PROMOTION_WEBSITE__INTL,
                        $PROMOTION_WEBSITE__AM,
                    ] },
                }
        );

        # having the left-nav is always useful
        construct_left_nav($handler);

        # FIXME - we should extend checks to make sure that people can't
        # subvert actions that are currently only moderated through the UI
        # (e.g. when you can enable/disable promos)

        # request a push out to the PWS database?
        if (defined $handler->{param_of}{push_to_pws}) {
            # XXX we don't do it this way any more!
            xt_warn( q{we don't do it this way any more!} );
        }

        # deal with POST requests
        if (
            defined $handler->{param_of}{'action'}
                and
            q{POST} eq $handler->{request}->method
        ) {
            # generate a single coupon
            # XXX old way, generic only - should be replaced with the
            # job-queue
            if (q{generate_coupon} eq $handler->{param_of}{'action'}) {
                return $self->_generate_coupon($handler, $promotion);
            }

            # generate coupon(s) via the job-queue
            elsif (q{generate_coupons} eq $handler->{param_of}{'action'}) {
                return $self->_generate_coupons($handler, $promotion);
            }

            # freeze customer(s) via the job-queue
            elsif (q{freeze_customers} eq $handler->{param_of}{'action'}) {
                return $self->_freeze_customers($handler, $promotion);
            }

            # send information to Lyris via the job-queue
            elsif (q{send_to_lyris} eq $handler->{param_of}{'action'}) {
                return $self->_export_to_lyris($handler, $promotion);
            }

            # send information to the customer website(s) via the job-queue
            elsif (q{export_to_pws} eq $handler->{param_of}{'action'}) {
                return $self->_export_to_pws($handler, $promotion);
            }

            # send information to the customer website(s) via the job-queue
            elsif (q{disable_promotion} eq $handler->{param_of}{'action'}) {
                return $self->_disable_promotion($handler, $promotion);
            }

            # deal with unknown actions
            else {
                xt_warn(qq{Unknown POST action: $handler->{param_of}{'action'}});
                return '/NAPEvents/Manage';
            }
        }


#        # maybe we'd like to disable an exported promo
#        if (defined $handler->{param_of}{disable}) {
#            # get the promotion
#            my $record = $promotion->retrieve_promotion( $handler->{param_of}{disable} );
#            if (defined $record) {
#                # disable the promotion
#                $record->update(
#                    {
#                        enabled     =>  0,
#                        status_id   => $PROMOTION_STATUS__DISABLED,
#                    }
#                );
#                # export the promotion
#                $record->export_to_pws( $handler->{data}{operator_id} );
#                xt_info(q{"} . $record->title . q{" disabled and exported to PWS database});
#
#                # clear the URL of evil params by redirecting
#                return '/NAPEvents/Manage';
#            }
#            else {
#                xt_warn(q{Can't find promotion with id=} .  $handler->{param_of}{disable})
#            }
#        }


        return;
    }

    sub _notify_if_jobqueue_not_running {
        my $self        = shift;
        my $job_queue   = shift;

        my ($queue, $retval, $queue_ptr);
        eval {
            $queue      = XT::JQ::DC->new({ funcname => '' });
            $retval     = $queue->{queue}->is_running;
            $$queue_ptr = $queue->{queue};
        };

        # -1 or 0 means it's not running
        if ($@ or not defined $retval) {
            xt_info(
                q{NOTICE: The job-queue processor does not appear to be running.}
            );
        }

=pod
        # raise a notice/warning to to user if we don't appear to be running
        if (not $job_queue->is_running) {
            xt_info(
                q{NOTICE: The job-queue processor does not appear to be running.}
            );
        }
=cut
        return;
    }

    sub _disable_promotion {
        my $self        = shift;
        my $handler     = shift;
        my $promotion   = shift;

        # disabling a promotion should happen real-time (i.e. not be
        # job-queued)
        $promotion->disable(
            $handler->{param_of}{promotion_id}
        );

        return;
    }

    sub _export_to_lyris {
        my $self        = shift;
        my $handler     = shift;
        my $promotion   = shift;
        my ($record, $queuer);

        # fetch the id of the promotion we want to mangle XXX factor out
        $record = $promotion->retrieve_promotion(
            $handler->{param_of}{promotion_id}
        );
        if (not defined $record) {
            xt_warn(q{Can't find promotion with id=} .  $handler->{param_of}{promotion_id});
            return;
        }

        $queuer = XT::JQ::DC->new({funcname => 'Receive::Event::LyrisExport'});
        $queuer->set_feedback_to({operators => [ $handler->operator_id ]});
        $queuer->set_payload({event_id => $record->id});
        $queuer->send_job;
=pod
        $queuer->insert_job(
            'Promotion::LyrisExport',
            {
                promotion_id    => $record->id,
                feedback_to     => { operators => [ $handler->operator_id ] },
            }
        );
=cut
        $record->update(
            {
                status_id => $PROMOTION_STATUS__JOB_QUEUED,
            }
        );
        xt_info('Job Queued: Export data to Lyris');
        $self->_notify_if_jobqueue_not_running($queuer);

        # make the page refresh itself after X seconds
        $handler->session_stash()->{meta_refresh} = 15;
        # redirect us to the summary, to lost the POST request
        return '/NAPEvents/Manage';
    }

    sub _export_to_pws {
        my $self        = shift;
        my $handler     = shift;
        my $promotion   = shift;
        my ($record, $queuer);

        # fetch the id of the promotion we want to mangle XXX factor out
        $record = $promotion->retrieve_promotion(
            $handler->{param_of}{promotion_id}
        );
        if (not defined $record) {
            xt_warn(q{Can't find promotion with id=} .  $handler->{param_of}{promotion_id});
            return;
        }

        $queuer = XT::JQ::DC->new({funcname => 'Send::Event::ToWebsite'});
        $queuer->set_feedback_to({operators => [ $handler->operator_id ]});
        $queuer->set_payload({event_id => $record->id});
        $queuer->send_job;
=pod
        $queuer = XT::JQ::DC->new;
        $queuer->insert_job(
            #'Promotion::ExportPWS',
            'Send::Event::ToWebsite',
            {
                promotion_id    => $record->id,
                feedback_to     => { operators => [ $handler->operator_id ] },
            },
        );
=cut
        $record->update(
            {
                status_id => $PROMOTION_STATUS__JOB_QUEUED,
            }
        );
        xt_info('Job Queued: Export data to customer website(s)');
        $self->_notify_if_jobqueue_not_running($queuer);

        # make the page refresh itself after X seconds
        $handler->session_stash()->{meta_refresh} = 15;
        # redirect us to the summary, to lost the POST request
        return '/NAPEvents/Manage';
    }

    sub _freeze_customers {
        my $self        = shift;
        my $handler     = shift;
        my $promotion   = shift;
        my ($record, $queuer);

        # fetch the id of the promotion we want to mangle XXX factor out
        $record = $promotion->retrieve_promotion(
            $handler->{param_of}{promotion_id}
        );
        if (not defined $record) {
            xt_warn(q{Can't find promotion with id=} .  $handler->{param_of}{promotion_id});
            return;
        }

        $queuer = XT::JQ::DC->new({funcname => 'Receive::Event::FreezeCustomers'});
        $queuer->set_feedback_to({operators => [ $handler->operator_id ]});
        $queuer->set_payload({event_id => $record->id});
        $queuer->send_job;
=pod
        $queuer = XT::JQ::DC->new;
        $queuer->insert_job(
            #'Promotion::FreezeCustomers',
            'Receive::Event::FreezeCustomers',
            {
                promotion_id    => $record->id,
                feedback_to     => { operators => [ $handler->operator_id ] },
            }
        );
=cut
        $record->update(
            {
                status_id => $PROMOTION_STATUS__JOB_QUEUED,
            }
        );
        xt_info('Job Queued: Freeze Customer Groups');
        $self->_notify_if_jobqueue_not_running($queuer);

        # make the page refresh itself after X seconds
        $handler->session_stash()->{meta_refresh} = 15;
        # redirect us to the summary, to lost the POST request
        return '/NAPEvents/Manage';
    }

    sub _generate_coupons {
        my $self        = shift;
        my $handler     = shift;
        my $promotion   = shift;
        my ($record, $queuer);

        # fetch the id of the promotion we want to mangle XXX factor out
        $record = $promotion->retrieve_promotion(
            $handler->{param_of}{promotion_id}
        );
        if (not defined $record) {
            xt_warn(q{Can't find promotion with id=} .  $handler->{param_of}{promotion_id});
            return;
        }

        # if it's specific ... add to the job queue
        if ($record->is_specific_coupon) {
            $queuer = XT::JQ::DC->new({funcname => 'Receive::Event::GenerateCoupons'});
            $queuer->set_feedback_to({operators => [ $handler->operator_id ]});
            $queuer->set_payload({event_id => $record->id});
            $queuer->send_job;
=pod
            $queuer = XT::JQ::DC->new;
            $queuer->insert_job(
                #'Promotion::GenerateCoupons',
                'Receive::Event::GenerateCoupons',
                {
                    promotion_id    => $record->id,
                    feedback_to     => { operators => [ $handler->operator_id ] },
                }
            );
=cut
            $record->update(
                {
                    status_id => $PROMOTION_STATUS__JOB_QUEUED,
                }
            );
            xt_info('Job Queued: Generate Specific Coupons');
            $self->_notify_if_jobqueue_not_running($queuer);

            # make the page refresh itself after X seconds
            $handler->session_stash()->{meta_refresh} = 15;
            # redirect us to the summary, to lost the POST request
            return '/NAPEvents/Manage';
        }
        else {
            xt_warn( 'Not sure what I should be doing: generate_coupons, NOT specific' );
        }

        return;
    }

    # XXX old way to generate one generic coupon
    # XXX it would probably make sense to factor this into _generate_coupons()
    sub _generate_coupon {
        my $self        = shift;
        my $handler     = shift;
        my $promotion   = shift;
        my $schema      = $self->get_schema;
        my ($record, $coupon, $suffix_list);

        # fetch the id of the promotion we want to mangle XXX factor out
        $record = $promotion->retrieve_promotion(
            $handler->{param_of}{promotion_id}
        );
        if (not defined $record) {
            xt_warn(q{Can't find promotion with id=} .  $handler->{param_of}{promotion_id});
            return;
        }

        # is it one of those generic tinkers?
        if ($record->is_generic_coupon) {
            $coupon = XTracker::Promotion::Coupon->new(
                {
                    prefix => $record->coupon_prefix(),
                }
            );
            $suffix_list
                = $coupon->generate_suffix_list(1);

            # loop through all (one) suffixes and add coupon(s)
            foreach my $suffix (@{$suffix_list}) {
                my $new_coupon_data;

                # the data we'll always set
                $new_coupon_data = {
                    prefix              => $coupon->get_prefix,
                    suffix              => $suffix,

                    event_id           => $record->id(),
                    valid               => 1,
                };

                # any coupon restrictions?
                if (defined $record->coupon_restriction) {
                    $new_coupon_data->{usage_limit}   = $record->coupon_restriction->usage_limit();
                    $new_coupon_data->{usage_type_id} = $record->coupon_restriction->group_id();
                }

                # TODO - use Jason's Way
                $schema->resultset('Promotion::Coupon')->create(
                    $new_coupon_data
                );
            }
            xt_info(
                q{Generic coupon generated for promotion '}
                . q{<a href="/NAPEvents/Manage/Edit?id=}
                . $record->id()
                . q{">}
                . $record->internal_title()
                . q{</a>}
                . q{': }
                . $coupon->coupon_list->[0]
            );

            # make the page refresh itself after X seconds
            #$handler->session_stash()->{meta_refresh} = 15;
            # redirect us to the summary, to lost the POST request
            return '/NAPEvents/Manage';
        }
        else {
            xt_warn( 'Not sure what I should be doing: generate_coupon, NOT generic' );
        }

        return;
    }
}

1;
