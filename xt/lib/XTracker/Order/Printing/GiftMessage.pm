package XTracker::Order::Printing::GiftMessage;

use NAP::policy 'tt', 'class';
use Carp;
use XTracker::Logfile 'xt_logger';
use XTracker::PrintFunctions qw/
    get_printer_by_name
    create_document
    print_document
    log_shipment_document
    path_for_print_document
    print_documents_root_path
/;
use XTracker::Constants::FromDB ':business';
use XTracker::Utilities 'url_encode';
use LWP::UserAgent;
use HTTP::Request::Common;
use XTracker::Config::Local 'config_var';
use HTTP::Cookies;
use IO::File;
use File::Spec::Functions qw/catfile abs2rel/;
use XTracker::Barcode 'create_barcode';

with 'XTracker::Role::WithSchema';

has 'shipment'      => (is => 'ro', 'isa' => 'XTracker::Schema::Result::Public::Shipment', required => 1);
has 'shipment_item' => (is => 'ro', 'isa' => 'XTracker::Schema::Result::Public::ShipmentItem', required => 0);

=head2 print_gift_message

Note: If you want to print gift messages for a shipment invoke
print_gift_message on the I<shipment> schema result object. Please
don't call this function directly.

This function handles printing a specific single gift message for a shipment

=cut

sub print_gift_message {
    my ($self, $printer) = @_;

    my $doc_filename = $self->_generate_document_filename();

    try {
        $self->get_image_path();
    } catch {
        xt_logger->error("Unable to print gift message: $_");
        confess("Unable to print gift message: $_");
    };

    my $config_section = $self->shipment->order->channel->business->config_section;

    my $printer_info = get_printer_by_name($printer);

    my $html = create_document(
        $doc_filename,
        'print/giftmessage.tt', {
            full_img_path => $self->_get_absolute_image_filename(),
            config_section => $config_section
        }
    );

    try {
        print_document(
            $doc_filename,
            $printer_info->{lp_name},
            1, # copies
            undef, # header
            undef, # footer
            1,
            0,
            'A6',
            'Landscape'
        );
    } catch {
        xt_logger->error("Unable to print gift message: $_");
        confess("Unable to print gift message: $_");
    };

    my $desc = 'Gift Message';
    $desc .= " (shipment item: " . $self->shipment_item->id . ")" if defined($self->shipment_item);

    log_shipment_document(
        $self->schema->storage->dbh,
        $self->shipment->id,
        $desc,
        $doc_filename,
        $printer_info->{name}
    );

}

sub _get_absolute_image_filename {
    my $self = shift;
    my $local_filename = $self->_generate_image_filename();
    my $retval = catfile(print_documents_root_path(), $local_filename);
    return $retval;
}

=head2 get_image_path

Given information about a gift message this will return a relative path
to the image. If the image does not exist locally, the function will attempt
to retrieve it from the front-end webservers. If there is a problem performing
this operation, this function may throw an exception.

The typical use-case for this function is when you wish to show the gift image
inside the xtracker application.

=cut

sub get_image_path {
    my $self = shift;

    my $absolute_filename = $self->_get_absolute_image_filename();

    # function checks file via absolute filename but returns a value which is relative
    # to the /print_docs/ directory. (prefered by pages/html embedding the image)
    my $print_docs_dir = config_var('SystemPaths', 'document_dir');
    my $relative_filename = abs2rel($absolute_filename, $print_docs_dir);

    if (-e $absolute_filename) {
        return $relative_filename;
    } else {
        $self->_fetch_image();
        return $relative_filename;
    }
}

=head2 get_image_path_silent

invoke get_image_path and silently supress exception
since template toolkit won't allow me to silence it.

=cut

sub get_image_path_silent {

    return try {
        return shift->get_image_path;
    };

}

sub _fetch_image {
    my $self = shift;

    my $generator_url = $self->_get_image_generating_url();

    my $local_file = $self->_get_absolute_image_filename();

    my $user_agent = LWP::UserAgent->new();
    $user_agent->agent('XTracker Gift Message Downloader');
    $user_agent->cookie_jar({});

    xt_logger->info("Attempting to fetch gift message text from URL: $generator_url");

    try {

        my $request = HTTP::Request->new(GET => $generator_url);
        $request->header('Accept' => '*/*');

        my $response = $user_agent->request($request);

        confess("Didnt get successful response. Got: ". $response->status_line)
            if (!$response->is_success());

        my $fh = IO::File->new($local_file, '>');
        $fh->binmode();
        $fh->print($response->content);
        $fh->close();
        xt_logger->info("Written gift message image to $local_file");

    } catch {
        my $err = sprintf("Unable to save gift message. url=%s, file=%s, error:%s",
            $generator_url,
            $local_file,
            $_
        );

        xt_logger->error($err);
        confess("Unable to retrieve gift image from frontend: $err");
    };

}

=head replace_existing_image

This function is used by customer care if they wish to regenerate
a new gift message image because the already downloaded gift message
image is inaccurate after the text has changed.

If the new image cannot be fetched from the front-end, the exception
is silently ignored.

=cut

sub replace_existing_image {
    my $self = shift;

    # get local file.
    my $local_file = $self->_get_absolute_image_filename();

    if (-e $local_file) {
        # delete it if it exists
        xt_logger->info("Deleting file: $local_file");
        unlink $local_file;
    }

    # attempt to regenate image. dont worry if fail.
    try {
        $self->_fetch_image();
    };

}

# This returns the appropriate URL for the frontend webserver that will generate the text required.
sub _get_image_generating_url {
    my $self = shift;

    my $config_section = $self->shipment->order->channel->business->config_section;
    my $url = config_var('GiftMessageImageGenerator', $config_section);
    my $enc_gm = url_encode($self->get_message_text());
    $url =~ s/__TEXT__/$enc_gm/;

    return $url;
}

=head2 get_message_text

Returns the gift message text for the gift message

=cut

sub get_message_text {
    my $self = shift;

    if (defined($self->shipment_item)) {
        return $self->shipment_item->gift_message;
    } else {
        return $self->shipment->gift_message;
    }
}

# This returns the filename for the png file the front-end webserver will give us
# The file itself may not exist yet. External callers should use get_image_path()
# function.
sub _generate_image_filename {
    my $self = shift;

    my $id = 'gift_message_image_shipment-' . $self->shipment->id;
    $id .= "-" . $self->shipment_item->id if defined($self->shipment_item);

    my $filename = XTracker::PrintFunctions::path_for_print_document({
        document_type           => 'gift_message_images',
        id                      => $id,
        extension               => 'png',
        relative                => 1,
        ensure_directory_exists => 1
    });

    return $filename;
}

# This is the name of the html document that is fed into Webkit for the PDF.
sub _generate_document_filename {
    my $self = shift;

    my $filename = "giftmessage-" . $self->shipment->id;
    $filename .= "-" . $self->shipment_item->id if defined($self->shipment_item);
    return $filename;
}

# print a warning message so the packer know they're
# supposed to manually create the gift message
sub print_gift_message_warning {
    my ($self, $printer) = @_;

    my $printer_info = get_printer_by_name( $printer );
    return unless %{$printer_info||{}};

    my $order = $self->shipment->orders->first;
    return unless $order;

    my $order_nr = $order->order_nr;

    # Let's BARCODE this badboy... This will create a PNG file with a
    #     # predictable name, which will be rendered in the resulting HTML
    #         # document, and our rasterizer will use (in theory)
    #
    create_barcode(
        sprintf('giftmessagewarning%s', $order_nr ),
        $order_nr,
        'small',
        3,
        1,
        undef, # don't pass a height, and it will be set automatically (WHM-3160)
    );

    my $filename = "giftmessagewarning-" . $self->shipment->id;
    $filename .= "-" . $self->shipment_item->id if defined($self->shipment_item);

    my $html = create_document(
        $filename,
        'print/giftmessagewarning.tt', {
            gift_message => $self->get_message_text(),
            order_nr => $order_nr
        }
    );

    my $result = print_document(
        $filename,
        $printer_info->{lp_name},
        1 # copies
    );

}

