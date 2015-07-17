package Test::Role::SystemConfig;

use NAP::policy     qw( test );

use Moose::Role;
requires 'get_schema';

=head1 NAME

Test::Role::SystemConfig - a Moose role to do System Config Related stuff
in tests. Such as removing a Group & Settings or creating them.

=head1 SYNOPSIS

    package Test::Foo;

    with 'Test::Role::SystemConfig';

    __PACKAGE__->remove_config_group;
    __PACKAGE__->create_config_group;
    __PACKAGE__->set_delivery_signature_threshold;

=cut


=head1 METHODS

=head2 remove_config_group

    __PACKAGE__->remove_config_group( $group_name, $channel );

Will remove all Config Groups with the name $group_name, if past a Channel will
only remove them for that channel, else the lot will go.

=cut

sub remove_config_group {
    my ( $self, $group_name, $channel ) = @_;

    my $config_group    = $self->_config_group;

    my $args    = {
            name => $group_name,
        };
    if ( $channel ) {
        $args->{channel_id} = $channel->id;
    }
    my @groups  = $config_group->search( $args )->all;
    foreach my $group ( @groups ) {
        $group->config_group_settings->delete;
        $group->delete;
    }

    return;
}

=head2 create_config_group

    __PACKAGE__->create_config_group( $group_name, {
                                        channel => $channel,
                                        settings => [
                                            { setting => $setting, value => $value }
                                        ]
                                    );

Will create a Config Group for the Channel (if passed) and also create all of the settting (if passed).

=cut

sub create_config_group {
    my ( $self, $group_name, $args )    = @_;

    my $channel     = $args->{channel};
    my $settings    = $args->{settings};

    # create the Group
    my $create_args = {
            name    => $group_name,
            active  => 1,
        };
    if ( $channel ) {
        $create_args->{channel_id} = $channel->id;
    }
    my $config_group= $self->_config_group;
    my $group       = $config_group->create( $create_args );

    # create the Settings if wanted
    if ( $settings ) {
        foreach my $setting ( @{ $settings } ) {
            $group->create_related( 'config_group_settings', $setting );
        }
    }

    return $group->discard_changes;
}


=head2 set_delivery_signature_threshold

    $int    = set_delivery_signature_threshold( $channel, $currency, 2134.45 );

This will remove any existing Config Groups for 'No_Delivery_Signature_Credit_Hold_Threshold'
and then create a new one for the Channel, Currency & Amount specified.

=cut

sub set_delivery_signature_threshold {
    my ( $self, $channel, $currency, $amount )      = @_;

    $self->remove_config_group( 'No_Delivery_Signature_Credit_Hold_Threshold' );
    $self->create_config_group( 'No_Delivery_Signature_Credit_Hold_Threshold', {
                                                            channel => $channel,
                                                            settings => [
                                                                {
                                                                    setting => $currency->currency,
                                                                    value   => $amount,
                                                                },
                                                            ],
                                                        } );
    return $amount;
}

=head2 set_pre_order_discount_settings

    __PACKAGE__->set_pre_order_discount_settings( $channel, {
        can_apply_discount  => 1,
        max_discount        => 30,
        discount_increment  => 5,
        # use this key to set-up the 'PreOrderDiscountCategory' group
        set_category => {
            'EIP'         => 10,
            'EIP Premium' => 10,
        },
            or
        # this will remove the 'PreOrderDiscountCategory' completely
        set_category => undef,
    } );

Sets the various settings required for Pre-Order Discounts for a Sales Channel.

The setting 'is_active' is always set to '1' unless specifically passed in the
arguments.

WARNING: This will remove all Config Groups regardless of channel for
         'PreOrder' and 'PreOrderDiscountCategory' so it's advised
         to use this in a transaction.

=cut

sub set_pre_order_discount_settings {
    my ( $self, $channel, $args ) = @_;

    $args //= {};

    if ( exists( $args->{set_category} ) ) {
        my $set_category = delete $args->{set_category};
        $self->remove_config_group( 'PreOrderDiscountCategory' );
        if ( $set_category ) {
            my @settings = map {
                { setting => $_, value => $set_category->{ $_ } }
            } keys %{ $set_category };

            $self->create_config_group( 'PreOrderDiscountCategory', {
                channel  => $channel,
                settings => \@settings,
            } );
        }
    }

    # if there is still something to set after
    # the 'PreOrderDiscountCategory' stuff
    if ( keys %{ $args } ) {
        # default 'is_active' to being TRUE
        $args = {
            is_active => 1,
            %{ $args },
        };

        # get all the Settings
        my @settings = map {
            { setting => $_, value => $args->{ $_ } }
        } keys %{ $args };

        # create the Config Group & Settings
        $self->remove_config_group( 'PreOrder' );
        $self->create_config_group( 'PreOrder', {
            channel  => $channel,
            settings => \@settings,
        } );
    }

    return;
}

=head2 save_config_group_state

    __PACKAGE__->save_config_group_state( 'ConfigGroupName' );

Saves the State of a given Config Group so that it can be restores later
using 'restore_conifg_group_state'.

=cut

my $_CONFIG_GROUP_STATE = {};

sub save_config_group_state {
    my ( $self, $config_group_name ) = @_;

    my $config_group = $self->_config_group;
    my @groups = $config_group->search( { name => $config_group_name }, { order_by => 'id' } )->all;

    if ( @groups ) {
        my @save;
        foreach my $group ( @groups ) {
            my %save_group = $group->get_columns;
            my @settings = $group->config_group_settings->search( {}, { order_by => 'id' } )->all;
            foreach my $setting ( @settings ) {
                my %save_setting = $setting->get_columns;
                push @{ $save_group{settings} }, \%save_setting;
            }
            push @save, \%save_group;
        }

        push @{ $_CONFIG_GROUP_STATE->{ $config_group_name } }, \@save;
    }

    return;
}

=head2 restore_config_group_state

    __PACKAGE__->restore_config_group_state( 'ConfigGroupName' );

Restores the State of a Config Group that was previously save by 'save_config_group_state'.

=cut

sub restore_config_group_state {
    my ( $self, $config_group_name ) = @_;

    if ( exists( $_CONFIG_GROUP_STATE->{ $config_group_name } ) ) {
        if ( my $restore = pop @{ $_CONFIG_GROUP_STATE->{ $config_group_name } } ) {

            $self->remove_config_group( $config_group_name );
            my $config_group = $self->_config_group;

            foreach my $group ( @{ $restore } ) {
                my $settings = delete $group->{settings};

                # restore the Group
                my $group_rec = $config_group->create( $group );

                # restore all the Group's Settings
                foreach my $setting ( @{ $settings } ) {
                    $group_rec->create_related( 'config_group_settings', $setting );
                }
            }
        }

        # if there's no further restores that can be done
        # for this group then remove the key completely
        delete $_CONFIG_GROUP_STATE->{ $config_group_name }
                        if ( !scalar( @{ $_CONFIG_GROUP_STATE->{ $config_group_name } } ) );
    }

    return;
}

#---------------------------------------------------

# helper method to get the 'SystemConfig::ConfigGroup' Class
sub _config_group {
    my $self    = shift;

    return $self->get_schema->resultset('SystemConfig::ConfigGroup');
}

1;
