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

sub _page2treebuilder {
    my ($self, $path) = @_;

    my $url = $self->_get_uri($path);
    my $content = $self->request_ok(HTTP::Request->new("GET", $url));

    my $builder = HTML::TreeBuilder->new();
    $builder->parse_content($content);
    return $builder;
}

sub _parse_link {
    my ($self, $builder) = @_;
    my $link = $builder->look_down('_tag', 'a');
    die "Not a link" if !$link;
    my $content = $link->{_content}[0];
    $content =~ s/^\s+//g;
    return { url => $link->{href}, content => $content };
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

sub parse_forum {
    my $self = shift;
    my $id = shift;

    my $builder = $self->_page2treebuilder("forum/$id");

    my %results;
    foreach my $group ($builder->look_down('_tag', 'div')) {
        my $class_name = $group->attr('class');
        next if !defined $class_name || $class_name ne 'mb2';

        # Subfora
        $results{subfora} = $self->_parse_subforum_tree($group) if !$results{subfora};
        my @types = qw(sticky open gesloten centrale);

        foreach my $type (@types) {
            next if defined $results{$type};
            $results{$type} = $self->_parse_subforum_topics(ucfirst($type), $group);
        }
    }
    return \%results;
}

sub parse_forum_index {
    my $self = shift;
    my $builder = $self->_page2treebuilder('index/forumindex');

    my %results;
    foreach my $group ($builder->look_down('_tag', 'div')) {
        my $name;
        my $class_name = $group->attr('class');
        next if !defined $class_name || $class_name ne 'mb2';

        foreach my $th ($group->look_down('_tag', 'th')) {
            $class_name = $th->attr('class');
            if ($class_name eq 'iHoofdgroep') {
                if ($th->{_content}[0] eq 'Overig') {
                    # Bookmarks and archives
                    $name = 'Overig';
                    $results{$name}{url} = undef;
                }
                else {
                    my $link = $self->_parse_link($th);
                    $name = $link->{content};
                    $results{$name}{url} = $link->{url};
                }
            }
        }

        foreach my $tr ($group->look_down('_tag', 'tr')) {
            my $short_name;
            foreach my $td ($tr->look_down('_tag', 'td')) {
                my $class_name = $td->attr('class');
                next unless $class_name;
                if ($class_name eq 'tFolder') {
                    my $link = $self->_parse_link($td);
                    $short_name = $link->{content};
                }
                next unless $short_name;

                if ($class_name eq 'iForum') {
                    my $link = $self->_parse_link($td);
                    $results{$name}{fora}{$short_name}{long_name} = $link->{content};
                    $results{$name}{fora}{$short_name}{url} = $link->{url};
                }
                elsif ($class_name eq 'iTopics') {
                    $results{$name}{fora}{$short_name}{topics} = $td->{_content}[0];
                }
                elsif ($class_name eq 'iPosts') {
                    $results{$name}{fora}{$short_name}{posts} = $td->{_content}[0];
                }
                elsif ($class_name eq 'iLastPost') {
                    $results{$name}{fora}{$short_name}{last_post} = $td->{_content}[0];
                }
                elsif ($class_name eq 'iMod') {
                    $results{$name}{fora}{$short_name}{moderator} = $td->{_content}[0];
                }
            }
        }
    }

    return \%results;
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
