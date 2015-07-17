package Test::XT::Flow::Admin;

use NAP::policy "tt",     qw( test role );
requires 'mech';

with 'Test::XT::Flow::AutoMethods';

=head1 NAME

Test::XT::Flow::Fulfilment

=head1 DESCRIPTION

Flow convenience methods for pages living in the Admin section.

=head1 METHODS

=head2 flow_mech__admin__sticky_pages'

Retrieves the Admin -> Sticky Pages page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin__sticky_pages',
    page_description => 'Sticky Pages Admin',
    page_url         => '/Admin/StickyPages',
);

=head2 flow_mech__admin__remove_sticky_pages(\@operator_ids)

Remove sticky pages for the given operator ids.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__admin__remove_sticky_pages',
    form_name        => 'remove_sticky_pages',
    form_button      => 'submit',
    form_description => 'Remove sticky pages',
    assert_location  => qr{^/Admin/StickyPages$},
    transform_fields => sub {
        my $operator_ids = (grep { $_ && m{array}i } ref $_[1]) ? $_[1] : [$_[1]];
        return { map {; "remove_$_" => $_ } @$operator_ids };
    },
);

=head2 flow_mech__admin__fraud_rules

Gets the 'Admin->Fraud Rules' page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin__fraud_rules',
    page_description => 'Fraud Rules Admin',
    page_url         => '/Admin/FraudRules',
);

=head2 flow_mech__admin__fraud_rules_flip_switch

    $framework->flow_mech__admin__fraud_rules_flip_switch( {
        $channel_id => $position,       # 'on', 'off' or 'parallel'
        ...
    } );

Will Flip the Switch for Sales Channels to the given Position.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__admin__fraud_rules_flip_switch',
    form_name        => 'fraud_rules_admin',
    form_button      => 'submit',
    form_description => 'Flip Fraud Engine Switch',
    assert_location  => qr{^/Admin/FraudRules$},
    transform_fields => sub {
        my ( $mech, $args ) = @_;

        my %fields  = map {
            'switch_channel_' . $_ => $args->{ $_ },
        } keys %{ $args };

        return \%fields;
    },
);

=head2 flow_mech__admin__user_profile

    $framework->flow_mech__admin__user_profile( $operator_id );

Will go to the 'User Profile' page for the Specified Operator.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin__user_profile',
    page_description => 'User Profile',
    page_url         => '/Admin/UserAdmin/Profile?operator_id_selected=',
    required_param   => 'Operator Id',
);

=head2 flow_mech__admin__user_profile_update

    $framework->flow_mech__admin__user_profile_update( {
        # fields to update
    } );

This will update the User's profile.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__admin__user_profile_update',
    form_name        => 'useprofile',
    form_button      => 'submit',
    form_description => 'Update User Profile',
    assert_location  => qr{^/Admin/UserAdmin/Profile},
    transform_fields => sub {
        my ( $self, $args ) = @_;

        # need to select the FORM for ticking checkboxes
        my $mech = $self->mech;
        $mech->form_name('useprofile');

        FIELD:
        foreach my $field ( keys %{ $args } ) {
            # find any checkbox fields that need
            # will need to be ticked/unticked
            next FIELD  if ( !grep { /^${field}/ } qw(
                                disabled
                                print_barcode
                                use_acl_for_main_nav
                                auth_
                              ) );

            # remove the field from the HASH and based
            # on the value either tick or untick it
            my $action = ( delete $args->{ $field } ? 'tick' : 'untick' );
            $mech->$action( $field, 1 );
        }

        return $args;
    },
);

=head2 flow_mech__admin__acl_admin

    $framework->flow_mech__admin__acl_admin;

Will go to the 'ACL Admin' page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin__acl_admin',
    page_description => 'ACL Admin',
    page_url         => '/Admin/ACLAdmin',
);

=head2 flow_mech__admin__acl_admin_update

    $framework->flow_mech__admin__acl_admin_update( {
        # fields to update
    } );

This will update the settings on the ACL Admin page.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__admin__acl_admin_update',
    form_name        => 'acl_admin_setting',
    form_button      => 'submit',
    form_description => 'Update ACL Admin page',
    assert_location  => qr{^/Admin/ACLAdmin},
    transform_fields => sub {
        my ( $self, $args ) = @_;

        # need to select the FORM for ticking checkboxes
        my $mech = $self->mech;
        $mech->form_name('acl_admin_setting');

        FIELD:
        foreach my $field ( keys %{ $args } ) {
            # find any checkbox fields that need
            # will need to be ticked/unticked
            next FIELD  if ( !grep { $_ eq $field } qw(
                                setting_build_main_nav
                              ) );

            # remove the field from the HASH and based
            # on the value either tick or untick it
            my $action = ( delete $args->{ $field } ? 'tick' : 'untick' );
            $mech->$action( $field, 1 );
        }

        return $args;
    },
);

=head2 flow_mech__admin__userroles

    $framework->flow_mech__admin__userroles();

Gets /Admin/UserRoles

=cut

__PACKAGE__->create_fetch_method(
    method_name         => 'flow_mech__admin__userroles',
    page_description    => 'Admin UserRoles',
    page_url            => '/Admin/UserRoles',
);

=head2 flow_mech__admin__userroles_update_roles

    $framework->flow_mech__admin__userroles_update_roles(
        [ qw( app_my_role app_my_role2 ) ]
    );

=cut

__PACKAGE__->create_form_method(
    method_name         => 'flow_mech__admin__userroles_update_roles',
    form_name           => 'userroles',
    form_description    => 'Update User Roles',
    assert_location     => qr{^/Admin/UserRoles$},
    transform_fields    => sub {
        my ($mech, $roles) = @_;
        die "Roles must be passed as an array ref" unless ref $roles eq 'ARRAY';

        return { newroles => [ $roles, 1 ] };
    },
);

=head2 flow_mech__admin__acl_main_nav_info

    $framework->flow_mech__admin__acl_main_nav_info;

Will go to the 'ACL Main Nav Info' page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin__acl_main_nav_info',
    page_description => 'ACL Main Nav Info Page',
    page_url         => '/Admin/ACLMainNavInfo',
);

__PACKAGE__->create_form_method(
   method_name      => 'flow_mech__admin__acl_main_nav_info_role_submit',
   form_name        => 'form__aclnavinfo',
   form_button      => 'roles_submit',
   form_description => 'Show Navigation for User Roles',
   assert_location  => qr{^/Admin/ACLMainNavInfo},
   transform_fields => sub {
        my ($self, $fields) = @_;
        return $fields;

    },
);


=head2 flow_mech__admin__email_templates

Gets the 'Admin->Email Templates'

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin__email_templates',
    page_description => 'Email Templates Admin',
    page_url         => '/Admin/EmailTemplates',
);

=head2 flow_mech__admin__edit_email_templates

Click email template links

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__admin__edit_email_templates',
    link_description => 'Template Edit Link',
    transform_fields => sub {
                    my ( $mech, $text )   = @_;
                    return { text => $text };
                },
    assert_location  => qr!^/Admin/EmailTemplates!,
);


=head2 flow_mech__admin__edit_email_template_submit

Submits  /Admin/EmailTemplates/Edit page

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__admin__edit_email_template_submit',
    form_name        => 'useprofile',
    form_button      => 'submit',
    form_description => 'Edit Email Template Page',
    assert_location  => qr{^/Admin/EmailTemplates/Edit/\d+$},
    transform_fields  => sub {
        my ($self, $fields) = @_;

        return $fields;
    },
);

=head2 flow_mech__admin_create_shipment_box

     $framework->flow_mech__admin_create_shipment_box('boxes')
     $framework->flow_mech__admin_create_shipment_box('inner_boxes')

Retrieves the Shipment Box Admin page

=cut


__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin_create_shipment_box',
    page_description => 'Shipment Box Admin',
    page_url         => '/Admin/PackingBoxAdmin/',
    required_param   => 'Box Type',
);

=head2 flow_mech__admin_create_shipment_box_submit

     $framework->flow_mech__admin_create_shipment_box_submit(channel_id, box_type, box_name)

Create a named box or inner box for the given channel

=cut

__PACKAGE__->create_form_method(
   method_name      => 'flow_mech__admin_create_shipment_box_submit',
   form_name        => sub {
                my ( $self, $channel_id, $box_type )  = @_;
                return "new_${box_type}_box-${channel_id}";
            },
   form_button      => 'submit',
   form_description => 'Create Shipment Box',
   assert_location  => qr{^/Admin/PackingBoxAdmin},
   transform_fields => sub {
        my ($self, $channel_id, $box_type, $box_name) = @_;
        return {
            box_name => $box_name,
        },
    },
);

=head2 flow_mech__admin_edit_shipment_box_outer

     $framework->flow_mech__admin_edit_shipment_box_outer(box_id)

Retrieve the page with the edit box form for a particular box

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin_edit_shipment_box_outer',
    page_description => 'Edit Outer Box',
    page_url         => '/Admin/PackingBoxAdmin/edit/boxes/',
    required_param   => 'Box Id',
);

=head2 flow_mech__admin_edit_shipment_box_inner

     $framework->flow_mech__admin_edit_shipment_box_inner(inner_box_id)

Retrieve the page with the edit inner box form for a particular inner box

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__admin_edit_shipment_box_inner',
    page_description => 'Edit Inner Box',
    page_url         => '/Admin/PackingBoxAdmin/edit/inner_boxes/',
    required_param   => 'Box Id',
);

=head2 flow_mech__admin_edit_shipment_box_submit

     $framework->flow_mech__admin_edit_shipment_box_submit('outer', box_weight)
     $framework->flow_mech__admin_edit_shipment_box_submit('inner', sort_order)

Update a parameter on the database for a particular box / inner box

=cut

__PACKAGE__->create_form_method(
   method_name      => 'flow_mech__admin_edit_shipment_box_submit',
   form_name        => sub {
                my ( $self, $box_type )  = @_;
                return "edit_${box_type}_box";
            },
   form_button      => 'submit',
   form_description => 'Edit Shipment Box',
   assert_location  => qr{^/Admin/PackingBoxAdmin/edit},
   transform_fields => sub {
        my ($self, $box_type, $field_value) = @_;
        my $field_name = $box_type eq 'outer' ? 'weight' : 'grouping_id';
        return {
            $field_name => $field_value
        },
    },
);

1;
