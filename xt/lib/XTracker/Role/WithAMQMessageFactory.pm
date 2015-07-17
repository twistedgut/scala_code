package XTracker::Role::WithAMQMessageFactory;
use NAP::policy "tt", "role";
use XTracker::Config::Local qw(
    config_section_slurp
    get_section_keys
    config_var
);
use NAP::Messaging::Catalyst::MessageQueueAdaptor;
use XT::DC::Messaging::Producer::WMS::AutoProducer;
use XT::DC::Messaging::Producer::PRL::AutoProducer;
with 'XTracker::Role::WithIWSRolloutPhase';

my $msg_factory; # we want a singleton, per process

has msg_factory => (
    is => 'rw',
    lazy_build => 1,
    builder => 'build_msg_factory',
);

sub build_msg_factory {
    return $msg_factory if $msg_factory;

    # let's build a Catalyst Component maybe outside Catalyst

    # get the whole XT configuration
    my $global_config = \%XTracker::Config::Local::config;
    my $msgq_conf = $global_config->{'Model::MessageQueue'};

    # these are needed to fool Catalyst::Component into believing
    # the application is loaded, otherwise it gets confused
    # parsing its arguments
    local $INC{'XT::DC::MessagingStub'}=1;
    local *XT::DC::MessagingStub::isa = sub { $_[1] eq 'Catalyst' ? 1 : 0 };
    local *XT::DC::MessagingStub::config = sub { return $global_config };
    require XTracker::Logfile;
    my $logger = XTracker::Logfile::xt_logger('MessagingStub');
    local *XT::DC::MessagingStub::log = sub { return $logger };

    $msg_factory = NAP::Messaging::Catalyst::MessageQueueAdaptor->COMPONENT('XT::DC::MessagingStub',$msgq_conf);

    # these values will be passed to the constructors of our
    # ::Producer:: / transformers
    $msg_factory->transformer_args->{iws_rollout_phase} =
        config_var('IWS', 'rollout_phase');
    $msg_factory->transformer_args->{prl_rollout_phase} =
        config_var('PRL', 'rollout_phase');

    return $msg_factory;
}
