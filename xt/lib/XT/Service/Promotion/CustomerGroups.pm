package XT::Service::Promotion::CustomerGroups;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Class::Std;

use Carp;
use Data::Dump qw(pp);
use Data::FormValidator;
use Readonly;

use XT::Domain::Promotion;

use XTracker::Constants::FromDB qw( :promotion_website );
use XTracker::Database qw(get_database_handle);
use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);
use XTracker::Promotion::Common qw( construct_left_nav );

my Readonly $PG_MAX_INT = 2147483647;

use base qw/ XT::Service /;

my %dfv_profile_for = (
    add_customer => {
        required => [qw(
            add_customers
            customer_group
            website
        )],
    },
    remove_customer => {
        required => [qw(
            cg_select
            remove_customers
        )],
    },
);

{
    my %promo_domain_of     :ATTR( get => 'promo_domain'   , set => 'promo_domain'   );

    sub START {
        my ( $self ) = @_;
        my $schema = $self->get_schema;

        $self->set_promo_domain(
             XT::Domain::Promotion->new({ schema => $schema })
        );
    }

    sub process {
        my ( $self ) = @_;

        my $handler = $self->get_handler();
        my $promo   = $self->get_promo_domain;

        $handler->{data}{section    } = 'Promotion Management System';
        $handler->{data}{subsection } = 'Customer Groups';
        $handler->{data}{cg_rs      } = $promo->customer_group_list;
        $handler->{data}{websites   } = $promo->promotion_website();

        if ( exists $handler->{param_of}{add_customer} ) {
            $self->add_customer;
        }
        elsif ( exists $handler->{param_of}{remove_customer} ) {
            $self->remove_customers;
            # Load remove customers tab
            $handler->{data}{tab_index} = 1;
        }

        construct_left_nav($handler);

        return;
    }

    sub add_customer {
        my ( $self ) = @_;

        my $handler             = $self->get_handler;
        my $schema              = $self->get_schema;
        my $promotion           = $self->get_promo_domain;
        my $customer_input      = $handler->{param_of}{add_customers};
        my $customer_group_id   = $handler->{param_of}{customer_group};

        my $results;

        eval {
            $results = Data::FormValidator->check(
                $handler->{param_of},
                $dfv_profile_for{add_customer},
            );
        };
        if ( $@ ) {
            xt_logger->fatal( $@ );
            xt_die( $@ );
        }

        # Handle invalid form data
        if ( $results->has_invalid or $results->has_missing ) {
            # Process missing elements
            if ($results->has_missing) {
                $handler->{data}{validation}{missing} = $results->missing;
            }
            # Process invalid elements
            if ( $results->has_invalid ) {
                $handler->{data}{validation}{invalid} = scalar($results->invalid);
            }
            # Repopulate form
            $handler->session_stash->{form_data} = $handler->{param_of};
            return;
        }

        my @add_to_website;

        # Check that the inputted customer IDs are valid
        if ( not $self->_valid_cid_list( $customer_input ) ) {
            $handler->session_stash->{form_data} = $handler->{param_of};
            return;
        }

        # Split and place customer IDs in array
        my @customer_list = split /,\s*/, $customer_input;

        # Check that specified website exists, and set array to websites that
        # are to be updated
        if ( $handler->{param_of}{website} ) {
            if (ref($handler->{param_of}{website}) eq 'ARRAY') {
                @add_to_website = @{$handler->{param_of}{website}};
            }
            else {
                push(@add_to_website, $handler->{param_of}{website});
            }
        }
        # Else return an error
        else {
            croak "Expecting intl, am or both as input for website";
        }

        my @customers_added;

        my $duplicate;

        # Add customer to website(s) and create array with customer data
        eval {
            WEBSITE:
            foreach my $website_id ( @add_to_website ) {

                CUSTOMER_ID:
                foreach my $customer_id ( @customer_list ) {

                    # If customer is already in the group
                    if ( $promotion->get_customer_by_join_data(
                            $customer_id,
                            $customer_group_id,
                            $website_id,
                        )
                    ) {
                        push @{ $duplicate->{ $website_id } }, $customer_id;
                        next CUSTOMER_ID;
                    }

                    # Add customer to customer group and add customers to
                    # customers added array
                    push @customers_added,
                        $schema->txn_do(
                            sub {
                                $promotion->_tx_add_customer_to_promotion(
                                    $customer_id,
                                    $customer_group_id,
                                    $website_id,
                                    $handler->{data}{operator_id},
                                );
                            }
                        )
                    ;
                }
            }
        };

        # deal with any transaction errors
        if ($@) {                                   # Transaction failed
            die "something terrible has happened! $@"
                if ($@ =~ /Rollback failed/);       # Rollback failed

            warn(qq{Database transaction failed: $@});

            xt_warn("There was an error adding customer(s): $@");
            return;
        }

        # Tell user the customer was already in the group
        if ( $duplicate ) {
            WEBSITE:
            foreach my $website_id ( keys %{ $duplicate } ) {
                my $website;
                if ( $website_id == $PROMOTION_WEBSITE__INTL ) {
                    $website = 'INTL';
                }
                elsif ( $website_id == $PROMOTION_WEBSITE__AM ) {
                    $website = 'AM';
                }
                elsif ( $website_id == $PROMOTION_WEBSITE__APAC ) {
                    $website = 'APAC';
                }
                else {
                    croak qq{Website $website_id not recognised};
                }
                xt_info(
                      "The following customer ID(s) were already part of the
                      group on the $website website: "
                    . join( q{, }, sort { $a <=> $b } @{ $duplicate->{$website_id} } )
                );
            }
        }

        # If some customers have been added to groups
        if ( @customers_added ) {

            # Get promotions that the customer groups are a part of
            my $group_promotions = $promotion->get_group_promotions( $customer_group_id );

            if ( not $group_promotions->count ) {
                xt_info( 'Nothing updated on website: the customer group is not in any promotions' );
            }
            else {
                # Loop through promotions and update pws for each
                while ( my $gp = $group_promotions->next ) {
                    my $form = 'customer';

                    if ( @customers_added > 1 ) { $form = 'customers'; };

                    xt_info( scalar( @customers_added ) . " $form added to " . $gp->internal_title );

                    $self->_update_pws( $gp );
                }
            }
        }
        else {
            xt_info( 'No customers were added to the customer group' );
        }

        return;
    }

    sub remove_customers {
        my ( $self ) = @_;

        my $handler             = $self->get_handler;
        my $schema              = $self->get_schema;
        my $promotion           = $self->get_promo_domain;
        my $customer_input      = $handler->{param_of}{remove_customers};
        my $customer_group_id   = $handler->{param_of}{cg_select};
        my $results;

        eval {
            $results = Data::FormValidator->check(
                $handler->{param_of},
                $dfv_profile_for{remove_customer},
            );
        };
        if ( $@ ) {
            xt_logger->fatal( $@ );
            xt_die( $@ );
        }

        # Handle invalid form data
        if ( $results->has_invalid or $results->has_missing ) {
            # Process missing elements
            if ($results->has_missing) {
                $handler->{data}{validation}{missing} = $results->missing;
            }
            # Process invalid elements
            if ( $results->has_invalid ) {
                $handler->{data}{validation}{invalid} = scalar($results->invalid);
            }
            # Repopulate form
            $handler->session_stash->{form_data} = $handler->{param_of};
            return;
        }

        # Check that the inputted customer IDs are valid
        if ( not $self->_valid_cid_list( $customer_input ) ) {
            $handler->session_stash->{form_data} = $handler->{param_of};
            return;
        };

        my @customer_list = split /,\s*/, $customer_input;

        my $removed_count = 0;

        CUSTOMERS_TO_REMOVE:
        foreach my $customer_id ( @customer_list ) {
            # Get the customer to be deleted for both websites
            my $customer_rs = $promotion->get_customer_by_cid_cgid(
                $customer_id,
                $customer_group_id,
            );
            if ( not $customer_rs->count ) {
                xt_info( "$customer_id not found in this customer group" );
            }
            elsif ( $customer_rs->delete ) {
                $removed_count++;
            }
            else {
                xt_info( "$customer_id could not be removed" );
            }
        };

        # If some customers have been removed from groups
        if ( $removed_count ) {

            # Gets the promotions that the customer group is a part of
            my $group_promotions = $promotion->get_group_promotions( $customer_group_id );

            # If group is part of a promotion
            if ( $group_promotions->count ) {
                # Loop through the promotions and update the customers on the pws
                while ( my $gp = $group_promotions->next ) {
                    my $form = 'customer';

                    if ( $removed_count > 1 ) { $form = 'customers'; };

                    xt_info( $removed_count . " $form removed from " . $gp->internal_title );

                    $self->_update_pws( $gp );
                }
            }
            else {
                xt_info( 'Nothing updated on website: the customer group is not in any promotions' );
            }
        }

        return
    }

    sub _valid_cid_list {
        my ( $self, $customer_input ) = @_;

        my ( %cid_seen, %error, $count, $error_count );

        my $schema = $self->get_schema;

        # Create an array splitting on whitespace or commas
        my @customer_list = split /,\s*/, $customer_input;

        CUSTOMER_ID:
        foreach my $customer_id ( @customer_list ) {
            # Does it look like a customer id?
            if ( $customer_id !~ m{\A\d+\z} ) {
                push @{$error{not_cid} }, $customer_id;
                $error_count++;
                next CUSTOMER_ID;
            }

            # Have we seen the CID already in this submission?
            if ( $cid_seen{$customer_id} ) {
                push @{ $error{duplicate} }, $customer_id;
                $error_count++;
                next CUSTOMER_ID;
            }

            # Is the CID within PG's integer range?
            if ( $customer_id > $PG_MAX_INT ) {
                push @{$error{out_of_range} }, $customer_id;
                $error_count++;
                next CUSTOMER_ID;
            }

            # Flag the item as seen
            $cid_seen{$customer_id}++;
        }

        # Invalid CIDs
        if ( exists $error{not_cid} ) {
            xt_info(
                  q{The following items do not appear to be valid customer IDs: }
                . join( q{, }, sort @{ $error{not_cid} } )
            );
        }

        # Duplicate entry
        if ( exists $error{duplicate} ) {
            xt_info(
                  q{The following customer IDs were duplicated in the submission: }
                . join( q{, }, sort { $a <=> $b } @{ $error{duplicate} } )
            );
        }

        # Duplicate entry
        if ( exists $error{out_of_range} ) {
            xt_info(
                  q{The following customer IDs were out of range: }
                . join( q{, }, sort { $a <=> $b } @{ $error{out_of_range} } )
            );
        }

        # FAIL!
        return not $error_count;
    }

    sub _update_pws {
        my ( $self, $gp ) = @_;

        my ( $pws_info );

        foreach my $website ($gp->websites) {
            # get the PWS (intl) schema, so we can put stuff into it
            $pws_info->{$website->name}{schema} = get_database_handle(
                {
                    name    => 'pws_schema_' . $website->name,
                }
            );
            $pws_info->{$website->name}{id} = $website->id;

        }
        # Update the pws
        $gp->export_customers_to_pws($pws_info);
    }
}

1;
