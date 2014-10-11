package OPN::Fok::RSS;
use Moose;

has ua => (
    is  => 'ro',
    isa => 'OPN::Fok::UA',
);

has rss => (is => 'ro',);

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

=head1 DESCRIPTION

=head1 SYNOPSIS

    my $ua = OPN::Fok::UA->new();

    $ua->login(); # optional

    my $rss = OPN::Fok::RSS->new(
        ua => $ua,
    );

    $rss->get_index();
    $rss->get_topics();
    $rss->get_active_topics();

=head1 ATTRIBUTES

=head1 METHODS

=head1 AUTHOR

Wesley Schwengle

=head1 LICENSE and COPYRIGHT

Wesley Schwengle, 2009-1014.
