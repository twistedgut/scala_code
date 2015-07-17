#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => ['$distribution_centre'];
use Test::XTracker::Mechanize;
use Test::XTracker::Data::Email;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw( :correspondence_templates );

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{mech}   = Test::XTracker::Mechanize->new;
    $self->{mech}->do_login;
}

sub setup: Test(setup => 2) {
    my $self = shift;

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 2,
        how_many_variants => 2,
    });

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        attrs => [
            { price => 100.00 },
            { price => 250.00 },
        ],
    });

    # set the customer language to be French so
    # that localised email addresses will be used
    my $customer    = $order->customer;
    $customer->set_language_preference('fr');
    $self->{expect_from_email}  = Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'returns_email', 'fr_FR' );

    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
    Test::XTracker::Data->set_department('it.god', 'Customer Care');

    my $order_nr =  $order->order_nr;
    $self->{mech}->order_nr($order_nr);

    ok(my $shipment = $order->shipments->first, "Sanity check: the order has a shipment");
    note "Shipment Id: ".$shipment->id;
    $self->{shipment} = $shipment;
    $self->{order} = $order;

    $shipment->shipment_email_logs->delete;
}

sub teardown: Test(teardown) {
    my $self    = shift;

    Test::XTracker::Data::Email->cleanup_localised_email_addresses;
}

sub _test_correspondence_log {
    my $self           = shift;
    my $template_id    = shift;

    my $log_rs = $self->{shipment}->shipment_email_logs->search({
            correspondence_templates_id => $template_id,
     });

    cmp_ok ( $log_rs->count , '==', 1, "Correspondence log has data");

}
sub test_create_rma_for_return_with_html_content : Tests {
    my $self = shift;

    my $return;

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Create Return - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
this is a html body text
</form>
</body>
</html>
</textarea>
still the text can go on
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF

    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'html',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_create_rma($self->{shipment}, undef, undef, undef, $args);
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE);

}

sub test_create_rma_for_return_with_text_content : Tests {
    my $self = shift;

    my $return;

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Create Return - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
this is text content
adding few more lines
and more
and moreeee.....
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF
    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'text',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_create_rma( $self->{shipment}, undef, undef, undef, $args );
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE);


}
sub test_create_rma_for_exchange : Tests {
    my $self = shift;

    my $return;

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Create Return - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
</body></html></textarea>
email content appears here for testing:
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF

    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'html',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_create_rma( $self->{shipment}, 'exchange', undef, 1, $args );
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE);
}


sub test_cancel_rma_for_return : Tests {
    my $self = shift;

    my $return;
    $self->{mech}->test_create_rma($self->{shipment});

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Cancel Return - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
<b> this is email content
<tr></tr>
</table>
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF

    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'text',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_cancel_rma($self->{shipment}->returns->first, undef, $args);
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__CANCEL_RETURN);
}

sub test_cancel_rma_for_exchange : Tests {
    my $self = shift;

    my $return;
    $self->{mech}->test_create_rma($self->{shipment},'exchange');

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Cancel Return - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
<b> this is email content
<tr></tr>
</table>
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF

    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'html',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_cancel_rma($self->{shipment}->returns->first, 'exchange', $args);
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__CANCEL_RETURN);
}


sub test_add_rma_item : Tests {
    my $self = shift;

    my $return;
    $self->{mech}->test_create_rma($self->{shipment});

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Add Item - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
<b> this is email content
<tr></tr>
</table>
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF

    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'html',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_add_rma_items($self->{shipment}->returns->first,undef, undef, $args);
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__ADD_RETURN_ITEM);

}

sub test_remove_rma_item : Tests {
    my $self = shift;

    my $return;

    $self->{mech}->test_create_rma($self->{shipment})
                  ->test_add_rma_items($return = $self->{shipment}->returns->first);

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Remove Item - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
<b> this is email content
<tr></tr>
</table>
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF


    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'html',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;


    $self->{mech}->test_remove_rma_items($return->return_items->not_cancelled->first, $args);
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__REMOVE_RETURN_ITEM);
}

sub test_convert_from_exchange : Tests {
    my $self = shift;

    my $return;
    $self->{mech}->test_create_rma($self->{shipment},'exchange');

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Convert From Exchange - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
<b> this is email content
<tr></tr>
</table>
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF

    my $args;
    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'html',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_convert_from_exchange($self->{shipment}->returns->first, $args);
    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__CANCEL_EXCHANGE);

}

sub test_convert_to_exchange : Tests {
    my $self = shift;

    my $return;
    $self->{mech}->test_create_rma($self->{shipment});

    my $b_name  = $self->{order}->channel->business->config_section;
    my $tt_name = 'RMA - Convert To Exchange - '.$b_name;

    my $template = $self->{schema}->resultset('Public::CorrespondenceTemplate')->find({
        name => $tt_name,
    });

    my $content = <<EOF;
<b> this is email content
<tr></tr>
</table>
TEST data created by 't/30-functional/cando/order/cms_rma.t', this should NOT appear in any other test!!!
EOF

    my $args;

    $args = {
        content         => $content,
        template_id     => $template->id,
        content_type    => 'html',
        email_from      => $self->{expect_from_email}->localised_email_address,
        email_replyto   => $self->{expect_from_email}->localised_email_address,
        update_content  => 1,
    } if $template;

    $self->{mech}->test_convert_to_exchange($self->{shipment}->returns->first, $args);

    $self->_test_correspondence_log($CORRESPONDENCE_TEMPLATES__CONVERT_TO_EXCHANGE);

}

Test::Class->runtests;
