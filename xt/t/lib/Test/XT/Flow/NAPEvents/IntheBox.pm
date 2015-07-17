package Test::XT::Flow::NAPEvents::IntheBox;

=head1 NAME

Test::XT::Flow::NapEvents::IntheBox

=head1 DESCRIPTION

Flow methods to test Marketing Promotion - In the Box
functionality

=cut


use NAP::policy "tt", 'test';
use warnings;

use Carp;
use Data::Dump qw(pp);
use Moose::Role;


use Test::XT::Flow;

with 'Test::XT::Flow::AutoMethods';


__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__inthebox_create',
    page_description => 'In the Box create page',
    page_url         => '/NAPEvents/InTheBox/Create',
    params           => [],
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__inthebox_summary',
    page_description => 'In the box summary page',
    page_url         => '/NAPEvents/InTheBox',
    params           => [],
);

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__inthebox__create_link',
    link_description => 'In the box - create link',
    find_link        => { text => 'Create' },
    assert_location  => qr!^/NAPEvents/InTheBox!,
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__inthebox__create_promotion_submit',
    form_name         => 'promotion_form',
    form_description  => 'Promotion creation form',
    assert_location   => qr{/NAPEvents/InTheBox/Create},
    transform_fields  => sub {
        my ($self, $fields) = @_;

        # if Options have been asked for such as Designers, Countries etc.
        if ( my $options = delete $fields->{options} ) {
            my $form    = $self->mech->form_name('promotion_form');

            foreach my $option ( keys %{ $options } ) {
                # the fields we are immitating are created dynamically by JavaScript
                # and so they need to be created manualy and pushed into the FORM
                $form->push_input( 'hidden', { name => "${option}_list", value => $options->{ $option } } );
            }
        }

        return $fields;
    },
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__inthebox__edit_promotion_link',
    form_name         =>  sub {
        my ($self, $fields) = @_;
        return  'edit_promo_'. $fields->{promotion_id};
    },
    form_description  => 'Promotion Edit Icon',
    assert_location   => qr!^/NAPEvents/InTheBox!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;
    },
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__inthebox__edit_form_promotion_submit',
    form_name         => 'promotion_form',
    form_description  => 'Promotion Edit form',
    assert_location   => qr!^/NAPEvents/InTheBox!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        # if Options have been asked for such as Designers, Countries etc.
        if ( my $options = delete $fields->{options} ) {
            my $form    = $self->mech->form_name('promotion_form');

            foreach my $option ( keys %{ $options } ) {
                # the fields we are immitating are created dynamically by JavaScript
                # and so they need to be created manualy and pushed into the FORM
                $form->push_input( 'hidden', { name => "${option}_list", value => $options->{ $option } } );
            }
        }

        return $fields;

    },
);


__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__inthebox__enable_disable_promotion_submit',
    form_name         =>  sub {
        my ($self, $fields) = @_;
        return  'toggle_promo_'. $fields->{promotion_id};
    },
    form_description  => 'Promotion Disable Icon',
    assert_location   => qr!^/NAPEvents/InTheBox!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;

    },
);


__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customer_segment_summary',
    page_description => 'In the box Customer Segment Summary page',
    page_url         => '/NAPEvents/InTheBox/CustomerSegment',
    params           => [],
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customer_segment__create_link',
    page_description => 'In the box Create Customer Segment  page',
    page_url         => '/NAPEvents/InTheBox/CustomerSegment/Create',
    params           => [],
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__inthebox__create_customer_segment_submit',
    form_name         => 'customer_segment_form',
    form_description  => 'Customer Segment creation form',
    assert_location   => qr{/NAPEvents/InTheBox/CustomerSegment},
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;

    },
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__inthebox__enable_disable_segment_submit',
    form_name         =>  sub {
        my ($self, $fields) = @_;
        return  'toggle_'. $fields->{segment_id};
    },
    form_description  => 'Segment Disable Icon',
    assert_location   => qr!^/NAPEvents/InTheBox/CustomerSegment!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;

    },
);

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__inthebox__edit_segment_link',
    form_name         =>  sub {
        my ($self, $fields) = @_;
        return  'edit_'. $fields->{segment_id};
    },
    form_description  => 'Customer Segment Edit Icon',
    assert_location   => qr!^/NAPEvents/InTheBox/CustomerSegment!,
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;

    },
);

