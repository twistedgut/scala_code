package XT::DC::Controller::Markup;
use NAP::policy "tt", 'class';
use XTracker::Markup;
BEGIN { extends 'Catalyst::Controller::REST' }

sub html_for_markup :Local :ActionClass('REST') {
}

sub html_for_markup_POST {
    my ($self,$c) = @_;

    my $schema = $c->model('DB')->schema;

    my $ret;

    try {
        my $markup     = $c->req->data->{markup};
        my $product_id = $c->req->data->{product_id};
        my $channel_id = $c->req->data->{channel_id};
        my $site       = $c->req->data->{site};

        my $markup_processor = XTracker::Markup->new({
            schema => $schema,
            product_id => $product_id,
        });

        # TODO Bit of a hack, possibly change the XTracker::Markup API
        # to take channel_id only
        if (defined $channel_id && !defined $site) {
            my $channel = $schema->resultset('Public::Channel')->find($channel_id);
            given (lc $channel->web_name) {
                when (/intl/) {
                    $site = 'intl';
                }
                when (/am/) {
                    $site = 'am';
                }
            }
        }

        my $output;
        for my $type (keys %$markup) {
        given ($type) {
            when ("editors_comments") {
                $ret->{editors_comments} = $markup_processor->editors_comments({
                    editors_comments => $markup->{editors_comments},
                    site => $site,
                });
            }
            when ("long_description") {
                $ret->{long_description} = $markup_processor->long_description({
                    long_description => $markup->{long_description},
                    site => $site,
                });
            }
            when ("size_fit") {
                $ret->{size_fit} = $markup_processor->size_fit({
                    size_fit => $markup->{size_fit},
                    site => $site,
                });
            }
            when ("related_facts") {
                $ret->{related_facts} = $markup_processor->related_facts({
                    related_facts => $markup->{related_facts},
                    site => $site,
                });
            }
            default {
                die "Don't know how to transform markup of type: $type";
            }
        }
    }
        $self->status_ok(
            $c,
            entity => $ret,
        );
    }
    catch {
        $self->status_bad_request(
            $c,
            message => "Problems: $_",
        );
    };
    return;

}
