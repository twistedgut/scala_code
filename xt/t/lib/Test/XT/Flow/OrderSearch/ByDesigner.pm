package Test::XT::Flow::OrderSearch::ByDesigner;

use NAP::policy     qw( test role );

requires 'mech';
requires 'note_status';
requires 'config_var';

with 'Test::XT::Flow::AutoMethods';

=head1 METHODS

=head2 flow_mech__customercare__ordersearch__by_designer

Go to the 'Customer Search->Order Search by Designer' page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__customercare__ordersearch__by_designer',
    page_description => 'Order Search by Designer',
    page_url         => '/CustomerCare/OrderSearchbyDesigner',
);


=head2 flow_mech__customercare__ordersearch__by_designer__search

    __PACKAGE__->flow_mech__customercare__ordersearch__by_designer__search(
        $designer_id,
        $channel_id,
    );

POST a Search from the Search page.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__customercare__ordersearch__by_designer__search',
    form_name        => 'search_by_designer',
    form_description => 'Submit Order Search by Designer',
    assert_location  => qr!^/CustomerCare/OrderSearchbyDesigner!,
    transform_fields => sub {
        my ( $self, $designer_id, $channel_id ) = @_;

        return {
            channel_id  => $channel_id  // '',
            designer_id => $designer_id // '',
        };
    },
);

=head2 flow_mech__customercare__ordersearch__by_designer__show_results

    __PACKAGE__->flow_mech__customercare__ordersearch__by_designer__show_results( $result_file_name );

Will click on the link in the Search Results that matches the Result File name passed in.

=cut

__PACKAGE__->create_link_method(
   method_name      => 'flow_mech__customercare__ordersearch__by_designer__show_results',
   link_description => 'Order Search by Designer Results File',
   transform_fields => sub {
            my ( $self, $file_name ) = @_;

            # get rid of any file extension
            $file_name =~ s/\.txt//g;

            return {
                url_regex => qr{.*/Results/${file_name}/summary},
            };
        },
   assert_location  => qr!^/CustomerCare/OrderSearchbyDesigner!,
);

