package OPN::Fok::UA;
use Moose;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use HTTP::Cookies;
use HTTP::Date;

has ua => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return LWP::UserAgent->new(
            requests_redirectable => ["GET", "HEAD", "POST"],
            agent                 => "OpFokRss/0.2",
            cookie_jar            => $self->cookie_jar,
        );
    },
);

has cookiejar => (
    is      => 'ro',
    isa     => 'HTTP::Cookie',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return HTTP::Cookies->new({}, autosave => 1);
    }
);

has username => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has password => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has base_url => (
    is      => 'ro',
    default => 'http://forum.fok.nl',
    isa     => 'Str',
);


#my $self = {
#    user   => "slacker_nl",
#    passwd => "your_secret_password",
#    url    => "http://forum.fok.nl/",
#    jar    => HTTP::Cookies->new(
#        file => $jar
#        ? $jar
#        : "$ENV{HOME}/.opfokrss.cookiejar",
#        autosave => 1
#    ),
#    re_sid    => qr/name="sid"/,
#    re_sessid => qr/name="sessid"/,
#    re_value  => qr/value="(\w+)"/,
#    re_http   => qr/^\s*https?:\/\/\w+.*/,
#    re_topic  => qr/^\s*(?:\w+)?topic\((.*)\)./,
#    re_title  => qr/\s*\<title\>(.*)\<\/title\>/,
#    re_fok    => qr/FOK!forum \/\s+/,
#    am_here   => qr#href="http://i.fok.nl/templates/fokforum_(?:light|dark)/#,
#    ua        => undef,
#};

sub request_ok {
    my ($self, $request) = @_;

    my $response = $self->ua->request($request);
    $self->cookie_jar->extract_cookies($response);

    if (!$response->is_success()) {
        die sprintf("Response is not succesful: %s", $response->statusline());
    }

    $self->cookie_jar->save();
    return $response;
}

sub login {
    my $self = shift;

    return if ($self->logged_in);

    my $url = URI->new($self->base_url)->new_abs('user/login');

    my $request  = HTTP::Request->new("GET", $url);
    my $response = $self->request_ok($request);

    my @text     = split("\n", $response->content);

    my %post = (
        referer     => $self->base_url,
        Save_login  => "TRUE",
        Username    => $self->username,
        Password    => $self->password,
        location    => $self->ua->agent,
        Expire_time => 28800,
        submit      => "Inloggen",
    );

    my $req = HTTP::Request->new("POST", $url);
    $req->content_type('application/x-www-form-urlencoded');
    $req->content(\%post);

    $response = $self->request_ok($req);
    return $self->($response->content);
}

sub logged_in {
    my $self = shift;
    return 0;
}

sub assert_session_id {
    my $self = shift;
    my $response = shift;

    my ($re_sid, $re_value, $re_sessid);

    # sid and sessid are both found in the source
    my ($found) = grep(/$re_sid/, @$response);
    if ($found =~ m/$re_value/) {
        $post{sid} = $1;
    }
    ($found) = grep(/$re_sessid/, @$response);
    if ($found =~ m/$re_value/) {
        $post{sessid} = $1;
    }
    # check if cookie has the same session id
    return 1;
}

#sub get_topics_url {
#    my ($self, $url) = @_;
#    my $re_http = $self->{re_http};
#    my $page    = $self->send_request("GET",
#        $url =~ /$re_http/ ? $url : $self->{url} . $url);
#
#
#    my $re_topic = $self->{re_topic};
#    my $re_title = $self->{re_title};
#    my $re_fok   = $self->{re_fok};
#
#    my @topics;
#    foreach my $line (@$page) {
#        next unless $line;
#        chomp($line);
#        $line = decode("iso-8859-15", $line);
#        $line = decode_entities($line);
#        if ($line =~ /$re_topic/) {
#            push(@topics, $1);
#            next;
#        }
#        elsif ($line =~ /$re_title/) {
#            my $title = $1;
#            $title =~ s/$re_fok//;
#            push(@topics, $title);
#            next;
#        }
#    }
#
#    #print Dumper \@topics;
#    return wantarray ? @topics : \@topics;
#}
#

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OPN::Fok::UA - A Fok UserAgent client

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head1 AUTHOR

Wesley Schwengle wesley at schwengle dot net

=head1 COPYRIGHT and LICENCE

Wesley Schwengle, 2009 - 2014
