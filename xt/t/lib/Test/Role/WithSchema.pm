package Test::Role::WithSchema;
use NAP::policy "tt", "role";
with "XTracker::Role::WithSchema";

=head2 rs($model_name) : $dbic_rs

Return the ResultSet for $model_name.

The default namespace prefix for $model_name is "Public::". Die if the
$dbic_rs doesn't exist.

=cut

sub rs {
    my ($self, $resultset) = @_;
    $resultset =~ /::/ or $resultset = "Public::$resultset";
    return $self->schema->resultset($resultset);
}

=head2 search($model_name, @search_args) : $dbic_rs

Find the result set for $model_name and return the result of
->search(@search_args).

The default namespace prefix for $model_name is "Public::".

=cut

sub search {
    my ($self, $model_name, @search_args) = @_;
    return $self->rs($model_name)->search(@search_args);
}

=head2 search_one($model_name, @search_args) : $dbic_row | undef

Find the result set for $model_name and return the result of
->search(@search_args)->first.

The default namespace prefix for $model_name is "Public::".

=cut

sub search_one {
    my ($self, $model_name, @search_args) = @_;
    return $self->rs($model_name)->search(@search_args)->first();
}

