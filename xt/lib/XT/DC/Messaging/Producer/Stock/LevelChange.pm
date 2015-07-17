package XT::DC::Messaging::Producer::Stock::LevelChange;
use NAP::policy "tt", 'class';
    with 'XT::DC::Messaging::Role::Producer';

use Scalar::Util qw/blessed/;

sub message_spec {
    return {
        type => '//rec',

        required => {
            current       => '//int',
            delta         => '//int',
            sku           => '//str',
        },
    };
}

=for consideration

Apparently trivially different from Stock::Update, when Stock::Update doesn't include
the summary info that its comments suggest it will, one day.

However, this message is only for communicating stock level changes on SKUs, and nothing else.

Feel free to blend the two messages, if you think it makes sense, and it won't break anything.

Note also that we presume that we've been handed 'current', 'delta' and 'sku' -- we don't
try to work them out from other information lying around on the stack.

Note also also that the topic (a.k.a. queue name) is bundled into $data, and we yoink it out.
To make in-production use more flexible (and to help the test harness, shhh!), we preserve
any C</topic/> or C</queue/> at the start of the topic name, otherwise we prepend '/topic/'.

=cut

has '+type' => ( default => 'StockLevelChange' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my($self, $header, $data) = @_;

    my $channel = (delete $data->{channel})->web_name;

    # if the config does not map the destination, we don't have to send anything
    return unless $self->routes_map->{$channel};

    $header->{destination} = $channel;

    # torch any leading '+' in 'delta' due to crappy recipient parsers not grokking '+'
    $data->{delta} =~ s/^\+//g;

    return ($header, $data);
}


1;
__END__
