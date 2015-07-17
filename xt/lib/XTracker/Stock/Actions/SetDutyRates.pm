package XTracker::Stock::Actions::SetDutyRates;
use NAP::policy qw(tt);

use XTracker::Handler;
use XTracker::Database::Channel qw( get_web_channels get_channels );
use XTracker::Database::Duty qw( check_hs_code create_hs_code create_web_hs_code update_duty_rate update_web_duty_rate add_duty_rate add_web_duty_rate );
use XTracker::Database qw( get_database_handle );
use XTracker::Utilities qw( url_encode );
use XTracker::Error;

use XTracker::Logfile qw(xt_logger);
use Data::Dump qw/pp/;

sub handler {
    my $handler     = XTracker::Handler->new(shift);
    my $dbh         = $handler->dbh;
    my $schema      = $handler->schema;
    my $param       = $handler->get_postdata;
    my $msg_factory = $handler->msg_factory;

    # set default redirect url
    my $redirect_url = '/StockControl/DutyRates?return=1';

    try {
        my $guard = $schema->txn_scope_guard;
        my $action_type = $param->{type} // die "Missing type parameter\n";

        # set up web handles for each channel
        my @dbh_web;
        foreach my $channel ( values %{ get_web_channels( $dbh ) } ) {
            push @dbh_web, get_database_handle( { name => 'Web_Live_'.$channel->{config_section}, type => 'transaction' } ) || die "Error: Unable to connect to website DB for channel: $channel->{name}\n";
        }

        my @messages;
        try {
            if ( $action_type eq 'hscode_create' ) {
                # check if hs code already exists
                my $hs_code_id = check_hs_code( $dbh, $param->{hs_code} );
                if ( ! $hs_code_id ) {
                    # create in XT
                    $hs_code_id = create_hs_code( $dbh, $param->{hs_code} );
                    # sync the hs code to FUL
                    push @messages, $msg_factory->transform(
                        'XT::DC::Messaging::Producer::Sync::HSCode',
                        {
                            hs_code => $param->{hs_code},
                        },
                    );
                    # create on web channels
                    foreach my $channel_dbh ( @dbh_web ) {
                        create_web_hs_code( $channel_dbh, $param->{hs_code} );
                    }
                }
                xt_success('HS Code created successfully');
                $redirect_url .= '&hs_code_id='.$hs_code_id;
            }
            elsif ( my $edit_id_field = _action_type_id_field( edit => $action_type ) ) {
                die "Missing $edit_id_field parameter\n" unless defined $param->{$edit_id_field};
                $redirect_url .= "&$edit_id_field=$param->{$edit_id_field}";

                foreach my $key ( keys %{ $param } ) {
                    my ($action, $cdr_id) = split /-/, $key;
                    if ( $action eq 'edit' ) {
                        if ( $param->{$key} > 1 ) {
                            die "Incorrect value for duty rate, please enter a decimal rate.\n";
                        }
                        if ( $param->{'edit-'.$cdr_id} != $param->{'old-'.$cdr_id} ) {
                            # update rate on XT
                            update_duty_rate( $dbh, $cdr_id, $param->{$key} );
                            # Tell the world
                            push @messages, $msg_factory->transform(
                                'XT::DC::Messaging::Producer::Shipping::DutyRate',
                                {
                                    schema => $schema,
                                    cdr_id => $cdr_id,
                                },
                            );
                            # update rates in web channels
                            foreach my $channel_dbh ( @dbh_web ) {
                                update_web_duty_rate( $dbh, $channel_dbh, $cdr_id, $param->{$key} );
                            }
                        }
                    }
                }
                xt_success('Rate updated successfully');
            }
            elsif ( my $add_id_field = _action_type_id_field( add => $action_type ) ) {
                foreach my $key ( keys %{ $param } ) {
                    my ($action, $id) = split /-/, $key;
                    if ( $action eq 'add' ) {
                        $redirect_url .= "&$add_id_field=$id";
                        if ( $param->{$key} > 1 ) {
                            die "Incorrect value for duty rate, please enter a decimal rate.\n";
                        }
                        my %add_args = (
                            # Only one of these will exist, the other will be
                            # overridden by $add_id_field
                            (map { $_ => $param->{$_} } qw(hs_code_id country_id)),
                            $add_id_field => $id,
                        );
                        # add rate on XT
                        add_duty_rate( $dbh, @add_args{qw(hs_code_id country_id)}, $param->{$key} );
                        # Tell the world
                        push @messages, $msg_factory->transform(
                            'XT::DC::Messaging::Producer::Shipping::DutyRate',
                            {
                                schema => $schema,
                                duty_rate => $param->{$key},
                                %add_args,
                            },
                        );
                        # add rate on web channels
                        foreach my $channel_dbh ( @dbh_web ) {
                            add_web_duty_rate( $dbh, $channel_dbh, @add_args{qw(hs_code_id country_id)}, $param->{$key} );
                        }
                        xt_success('Rate added successfully');
                    }
                }
            }

            # commit web handles
            foreach my $channel_dbh ( @dbh_web ) {
                $channel_dbh->commit();
            }
        } catch {
            chomp(my $e = $_);
            # rollback web handles
            foreach my $channel_dbh ( @dbh_web ) {
                $channel_dbh->rollback();
            }
            die "Error updating website channels: $e\n";
        };
        $guard->commit();

        # Updating databases succeded, send queued messages
        my $logger = xt_logger(__PACKAGE__);
        try {
            $msg_factory->send_many(@messages);
        } catch {
            $logger->warn($_);
        };
    } catch {
        chomp(my $e = $_);
        xt_warn("An error occurred: $e");
    };
    return $handler->redirect_to( $redirect_url );
}

sub _action_type_id_field {
    my ($action, $action_type) = @_;

    return unless $action_type =~ /\A(hscode|country)_\Q$action\E\z/;
    # normalise to match parameter names (s///r returns the modified string)
    return ($1 =~ s/\Ahs/hs_/r) . "_id";
}

1;
