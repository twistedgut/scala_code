package XT::DC::Messaging::ConsumerBase::LogReceipt;
use Moose::Role;
use MooseX::Types::Moose qw/Str Bool/;
use MooseX::Types::Path::Class qw/Dir/;
use NAP::Messaging::Serialiser;
use NAP::Messaging::Catalyst::Utils qw(extract_jms_headers);
use Time::HiRes ();
use File::Temp ();
use Net::Stomp::Frame;
use Clone 'clone';

has dump_receipt => (
    is => 'rw',
    isa => Bool,
    required => 0,
    default => 0,
);

has receipt_dir => (
    is          => 'ro',
    isa         => Dir,
    required    => 0,
    coerce      => 1,
);

sub BUILD {
    my ($self) = @_;
    $self->receipt_dir->mkpath
        if $self->receipt_dir;
};

around _wrap_code => sub {
    my ($orig,$self_consumer,@args) = @_;

    my $code = $self_consumer->$orig(@args);

    return sub {
        my ($controller, $ctxt) = @_;

        my ($orig_msg,$orig_hdrs) = (
            clone($ctxt->req->data),
            extract_jms_headers($ctxt),
        );

        $code->($controller,$ctxt);

        return unless $self_consumer->dump_receipt
            && $self_consumer->receipt_dir;

        my $errors = $ctxt->error;
        my $status = $ctxt->response->status;
        my $destination = $orig_hdrs->{destination};

        my ($temp_fh, $temp_filename) = $self_consumer->_temp_file($destination);

        my $frame = Net::Stomp::Frame->new({
            command => 'MESSAGE',
            headers => $orig_hdrs,
            body => NAP::Messaging::Serialiser->serialise({
                destination => $destination,
                body => $orig_msg,
                headers => $orig_hdrs,
                response_status => $status,
                errors => $errors,
            }),
        });

        binmode $temp_fh;
        print $temp_fh $frame->as_string;
        close $temp_fh;

        return;
    };
};

sub _temp_file {
    my ($self,$destination) = @_;

    # Massage the destination name to be write-safe
    $destination =~ s{^\W+}{};
    $destination =~ s{\W+}{_}g;

    my $template=sprintf '%0.5f-%05d-XXXX',
        Time::HiRes::time(),$$;

    return File::Temp::tempfile(
        $template,
        SUFFIX => "_$destination",
        DIR => $self->receipt_dir->stringify
    );
}

1;
