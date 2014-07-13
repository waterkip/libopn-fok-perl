package OPN::Fok::UA;
use Moose;

use HTML::Entities;
use HTML::TreeBuilder;
use HTTP::Cookies;
use HTTP::Date;
use HTTP::Request;
use HTTP::Response;
use LWP::UserAgent;
use URI;

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

has cookie_jar => (
    is      => 'ro',
    isa     => 'HTTP::Cookies',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return HTTP::Cookies->new({}, autosave => 1);
    }
);

has username => (
    is       => 'rw',
    isa      => 'Str',
);

has password => (
    is       => 'rw',
    isa      => 'Str',
);

has base_url => (
    is      => 'ro',
    default => 'http://forum.fok.nl',
    isa     => 'Str',
);

has _uri => (
    is => 'ro',
    isa => 'URI',
    default => sub {
        my $self = shift;
        return URI->new($self->base_url);
    },
    lazy => 1,
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
        die sprintf("Response is not succesful: %s", $response->status_line());
    }

    $self->cookie_jar->save();
    return $response->content;
}

sub _get_uri {
    my $self = shift;
    return URI->new_abs(shift, $self->base_url);
}

sub login {
    my $self = shift;

    return if ($self->logged_in);

    my $url = $self->_get_uri('user/login');

    my $request  = HTTP::Request->new("GET", $url);
    my @text     = split("\n", $self->request_ok($request));

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

    return $self->request_ok($req);
}

sub logged_in {
    my $self = shift;
    return 0;
}

sub assert_session_id {
    my $self = shift;
    my $response = shift;

    my ($re_sid, $re_value, $re_sessid);
    my %post;

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

sub _parse_subforum_tree {
    my ($self, $builder) = @_;
    my %subfora;
    foreach my $table ($builder->look_down('_tag', 'table')) {
        my $id = $table->attr('id');
        next if !$id || $id ne 'subforums' ;
        my $fora;
        foreach my $td ($table->look_down('_tag', 'td')) {
            my $class_name = $td->attr('class');
            next unless $class_name;
            if ($class_name eq 'tTitel') {
                my $link = $td->look_down('_tag', 'a');
                next unless $link;
                $fora = $link->{_content}[0];
                $subfora{$fora}{url} = $link->{href};
            }
            elsif ($class_name eq 'tPages') {
                $subfora{$fora}{topics} = $td->{_content}[0];
            }
            elsif ($class_name eq 'tPosts') {
                $subfora{$fora}{topics} = $td->{_content}[0];
            }
            elsif ($class_name eq 'tViews') {
                $subfora{$fora}{views} = $td->{_content}[0];
            }
            elsif ($class_name eq 'tLastreply') {
                $subfora{$fora}{last_reply} = $td->{_content}[0];
            }
        }
    }
    return \%subfora;
}

sub _parse_subforum_topics {
    my ($self, $type, $builder) = @_;
    my $result;
    foreach my $table ($builder->look_down('_tag', 'table')) {
        my $id = $table->attr('id');
        next if !$id || $id ne $type ;
        my $fora;
        foreach my $td ($table->look_down('_tag', 'td')) {
            my $class_name = $td->attr('class');
            next unless $class_name;
            if ($class_name eq 'tTitel') {
                my $link = $self->_parse_link($td);
                $fora = $link->{content};
                $result->{$fora}{url} = $link->{url};
            }
            elsif ($class_name eq 'tPages') {
                $result->{$fora}{topics} = $td->{_content}[0];
            }
            elsif ($class_name eq 'tPosts') {
                $result->{$fora}{reacties} = $td->{_content}[0];
            }
            elsif ($class_name eq 'tViews') {
                $result->{$fora}{views} = $td->{_content}[0];
            }
            elsif ($class_name eq 'tTopicstarter') {
                my $link = $self->_parse_link($td);
                $result->{$fora}{ts}{profile} = $link->{url};
                $result->{$fora}{ts}{username} = $link->{content};
            }
            elsif ($class_name eq 'tLastreply') {
                my $link = $self->_parse_link($td);
                $result->{$fora}{last_reply}{url} = $link->{url};
                $result->{$fora}{last_reply}{date} = $link->{content};
            }
        }
    }
    return $result;
}

sub _parse_link {
    my $self = shift;
    my $builder = shift;
    my $link = $builder->look_down('_tag', 'a');
    die "Not a link" if !$link;
    my $content = $link->{_content}[0];
    $content =~ s/^\s+//g;
    return { url => $link->{href}, content => $content };
}

sub parse_forum {
    my $self = shift;
    my $id = shift;
    my $url = $self->_get_uri("forum/$id");
    my $content = $self->request_ok(HTTP::Request->new("GET", $url));

    my $builder = HTML::TreeBuilder->new();
    $builder->parse_content($content);

    my %results;
    my %subfora;

    foreach my $group ($builder->look_down('_tag', 'div')) {
        my $class_name = $group->attr('class');
        next if !defined $class_name || $class_name ne 'mb2';

        # Subfora
        $results{subfora} = $self->_parse_subforum_tree($group) if !$results{subfora};
        #my @types = qw(sticky open gesloten centrale);
        my @types = qw(sticky);

        foreach my $type (@types) {
            if (!defined $results{$type}) {
                $results{$type} = $self->_parse_subforum_topics(ucfirst($type), $group)
            }
        }
    }
    return \%results;
}

sub parse_index {
    my $self = shift;

    my $url = $self->_get_uri('index/forumindex');
    my $content = $self->request_ok(HTTP::Request->new("GET", $url));

    use HTML::TreeBuilder;
    my $builder = HTML::TreeBuilder->new();
    $builder->parse_content($content);

    my %meta_fora;
    foreach my $group ($builder->look_down('_tag', 'div')) {
        {
            my $name;
            my $class_name = $group->attr('class');
            next if !defined $class_name || $class_name ne 'mb2';
            foreach my $th ($group->look_down('_tag', 'th')) {
                $class_name = $th->attr('class');
                if ($class_name eq 'iHoofdgroep') {
                    my $link = $th->look_down('_tag', 'a');
                    next unless $link;
                    $name = $link->{_content}[0];
                    $meta_fora{$name}{url} = $link->{href} if $link;
                }
            }

            foreach my $tr ($group->look_down('_tag', 'tr')) {
                my ($short_name, $fora, $topics, $url, $posts, $last_post, $moderator);
                foreach my $td ($tr->look_down('_tag', 'td')) {
                    my $class_name = $td->attr('class');
                    next unless $class_name;
                    my $link = 'bul';
                    if ($class_name eq 'tFolder') {
                        my $link = $td->look_down('_tag', 'a');
                        next unless $link;
                        $short_name = $link->{_content}[0];
                        $short_name =~ s/^\s+//g;
                    }
                    elsif ($class_name eq 'iForum') {
                        my $link = $td->look_down('_tag', 'a');
                        next unless $link;
                        $fora = $link->{_content}[0];
                        $url  = $link->{href};
                    }
                    elsif ($class_name eq 'iTopics') {
                        $topics = $td->{_content}[0];
                    }
                    elsif ($class_name eq 'iPosts') {
                        $posts = $td->{_content}[0];
                    }
                    elsif ($class_name eq 'iLastPost') {
                        $last_post = $td->{_content}[0];
                    }
                    elsif ($class_name eq 'iMod') {
                        $moderator = $td->{_content}[0];
                    }
                }
                next unless $short_name;
                $meta_fora{$name}{fora}{$short_name} = {
                    long_name => $fora,
                    url       => $url,
                    posts     => $posts,
                    last_post => $last_post,
                    moderator => $moderator,
                    topics    => $topics,
                };
            }
        }
    }

    return \%meta_fora;
}


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
