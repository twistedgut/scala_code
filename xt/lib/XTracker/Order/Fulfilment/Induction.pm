package XTracker::Order::Fulfilment::Induction;
use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;
use NAP::DC::Barcode::Container;
use XT::Data::Fulfilment::InductToPacking;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $return_to_url = "";
    try {
        $return_to_url = _handler($handler) // "";
    }
    catch {
        xt_die("Internal error: $_");
    };

    return $handler->redirect_to( $return_to_url ) if $return_to_url;
    return $handler->process_template;
}

=head2 _handler($handler) : $redirect_url | undef | die

=cut

sub _handler {
    my ($handler) = @_;
    $handler->{data}->{section}       = "Fulfilment";
    $handler->{data}->{subsection}    = "Induction";
    $handler->{data}->{subsubsection} = "";
    $handler->{data}->{content}       = "fulfilment/inductionlist.tt";
    $handler->{data}->{css}           = "/css/induction.css";
    $handler->{data}->{handheld_css}  = "/css/induction.css";
    $handler->{data}->{view}          = $handler->clean_param("view"); # Stay on handheld

    my $induct = XT::Data::Fulfilment::InductToPacking->new({
        schema          => $handler->{schema},
        operator_id     => $handler->operator_id,
        message_factory => $handler->msg_factory,
    });
    $handler->{data}->{induct} = $induct;

    return try {
        $induct->set_return_to_url( $handler->clean_param("return_to_url") );
        $induct->set_is_container_in_cage( $handler->clean_param("is_container_in_cage") );
        $induct->set_is_force( $handler->clean_param("is_force") );

        $induct->set_container_row(
            $handler->clean_param("container_id"),
            $handler->clean_param("container_barcode"),
        ) or return;

        $induct->check_induction_capacity();

        my $is_answered = $induct->set_answer_to_question(
            $handler->clean_param("can_be_conveyed"),
        );
        if ( ! $is_answered ) {
            # Display question
            $handler->{data}{content} = 'fulfilment/inductionoptions.tt';

            my $message = $induct->user_message_ensure_multi_tote_all_present;
            if ($message) {
                xt_info($message);
            }

            return;
        }

        # We have an answer

        my $instruction_text = $induct->induct_containers();
        $instruction_text and xt_info($instruction_text);

        return $induct->return_to_url;
    }
    catch {
        xt_warn($_);
        return;
    };
}

1;
