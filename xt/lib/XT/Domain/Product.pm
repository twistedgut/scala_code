package XT::Domain::Product;

use strict;
use warnings;

use Class::Std;

use XTracker::Comms::FCP qw( create_fcp_related_product delete_fcp_related_product );

use base qw/ XT::Domain /;

{

    sub product_season {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Public::Season')->season_list();
    }

    sub product_active_season {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $self->product_season->search(
            { active => 1 }
        );
    }

    sub product_designer {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Public::Designer')->designer_list();
    }

    sub product_type {
        my($self) = @_;
        my $schema = $self->get_schema;

        return $schema->resultset('Public::ProductType')->producttype_list();
    }

    sub fcp_switch {
        my ( $self, $dbh_fcp, $product_id, $slot ) = @_;

        my $schema         = $self->get_schema;
        my $recommended_rs = $schema->resultset('Public::RecommendedProduct');

        my $slot_product_rs = $recommended_rs->search( {
            product_id => $product_id,
            slot       => $slot
        } );

        while ( my $slot_product = $slot_product_rs->next ) {
            if ( $slot_product->product->live ) {
                delete_fcp_related_product(
                    $dbh_fcp,
                    {
                        product_id         => $slot_product->product_id,
                        related_product_id => $slot_product->recommended_product_id,
                        type_id            => 'Recommended',
                    }
                );
            }
        }

        $slot_product_rs->reset;

        while ( my $slot_product = $slot_product_rs->next ) {
            if ( $slot_product->product->live ) {
                create_fcp_related_product(
                    $dbh_fcp,
                    {
                        product_id         => $slot_product->product_id,
                        related_product_id => $slot_product->recommended_product_id,
                        type_id            => 'Recommended',
                        sort_order         => $slot_product->sort_order,
                        position           => $slot_product->slot,
                    }
                );
            }
        }
        return;
    }
}

1;

__END__

=pod

=head1 NAME

XT::Domain::Product;

=head1 AUTHOR

Chisel Wright

Jason Tang

=cut

