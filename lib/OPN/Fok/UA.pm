package OPN::Fok::UA;
use Moose;

use HTML::Entities;
use HTML::TreeBuilder;
use HTTP::Cookies;
use HTTP::Date;
use HTTP::Request;
use HTTP::Request::Common qw(POST GET);
use HTTP::Response;
use LWP::UserAgent;
use URI;

use Data::Dumper;

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
    is      => 'rw',
    isa     => 'Str',
    default => sub { return '' },
);

has password => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { return '' },
);

has base_url => (
    is      => 'ro',
    default => sub { return 'http://forum.fok.nl' },
    isa     => 'Str',
);

has _uri => (
    is      => 'ro',
    isa     => 'URI',
    default => sub {
        my $self = shift;
        return URI->new($self->base_url);
    },
    lazy => 1,
);

has sessid => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { return '' },
);

has sid => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { return '' },
);

sub request_ok {
    my ($self, $request) = @_;

    my $response = $self->ua->request($request);
    $self->cookie_jar->extract_cookies($response);


    if (!$response->is_success) {
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

    my $builder = $self->_page2treebuilder('user/login');
    my $sids    = $self->_get_session_information_from_page($builder);

    foreach (keys %$sids) {
        $self->$_($sids->{$_});
    }

    my $req = POST  $self->_get_uri('user/login'), [
        referer     => "",
        Save_login  => "TRUE",
        Username    => $self->username,
        Password    => $self->password,
        location    => $self->ua->agent,
        Lock_IP     => 0,
        Expire_time => 28800,
        submit      => "Inloggen",
        sessid      => $self->sessid,
        sid         => $self->sid,
    ];

    return $self->_req2builder($req);
}

sub _get_session_information_from_page {
    my ($self, $builder) = @_;

    my $ids = { sessid => '', sid => '' };

    foreach my $input ($builder->look_down('_tag', 'input')) {
        if ($input->attr('name') eq 'sessid') {
            $ids->{sessid} = $input->attr('value');
        }
        if ($input->attr('name') eq 'sid') {
            $ids->{sid} = $input->attr('value');
        }
    }
    return $ids;
}

sub assert_session_id {
    my $self = shift;
    my $ids  = shift;

    return 0 if $ids->{ssid} || '' ne $self->ssid;
    return 0 if $ids->{sid}  || '' ne $self->sid;

    # check if cookie has the same session id
    return 1;
}

sub _assert_error {
    my $self = shift;
    my $builder = shift;

    foreach my $input ($builder->look_down('class', 'bch1')) {
        my $content = $input->{_content}[0];
        if ($content =~ /^error/) {
            foreach my $x ($builder->look_down('class', 'info roundall')) {
                die "Fok returned the following error: $x->{_content}[0]\n";
            }
        }
    }
    return;
}

sub _get_builder {
    my ($self, $content) = @_;
    my $builder = HTML::TreeBuilder->new();
    $builder->parse_content($content) if defined $content;
    $self->_assert_error($builder);
    return $builder;
}

sub _req2builder {
    my ($self, $req) = @_;
    return $self->_get_builder($self->request_ok($req));
}

sub _page2treebuilder {
    my ($self, $path) = @_;
    return $self->_req2builder(HTTP::Request->new("GET", $self->_get_uri($path)));
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
        next if !$id || $id ne 'subforums';
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
        next if !$id || $id ne $type;
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
                $result->{$fora}{ts}{profile}  = $link->{url};
                $result->{$fora}{ts}{username} = $link->{content};
            }
            elsif ($class_name eq 'tLastreply') {
                my $link = $self->_parse_link($td);
                $result->{$fora}{last_reply}{url}  = $link->{url};
                $result->{$fora}{last_reply}{date} = $link->{content};
            }
        }
    }
    return $result;
}

sub parse_forum {
    my $self = shift;
    my $id   = shift;

    die "No ID given" if !$id;

    my $builder = $self->_page2treebuilder("forum/$id");

    my %results;
    foreach my $group ($builder->look_down('_tag', 'div')) {
        my $class_name = $group->attr('class');
        next if !defined $class_name || $class_name ne 'mb2';

        # Subfora
        $results{subfora} = $self->_parse_subforum_tree($group)
            if !$results{subfora};
        my @types = qw(sticky open gesloten centrale);

        foreach my $type (@types) {
            next if defined $results{$type};
            $results{$type}
                = $self->_parse_subforum_topics(ucfirst($type), $group);
        }
    }
    return \%results;
}

sub _parse_forum_index_meta_fora {
    my ($self, $builder) = @_;

    foreach my $th ($builder->look_down('_tag', 'th')) {
        if ($th->attr('class') eq 'iHoofdgroep') {

            # Bookmarks and archives
            if ($th->{_content}[0] eq 'Overig') {
                return ('Overig', undef);
            }
            else {
                my $link = $self->_parse_link($th);
                return ($link->{content}, $link->{url});
            }
        }
    }
}

sub _parse_forum_index_fora {
    my ($self, $builder) = @_;

    my $results = {};
    foreach my $tr ($builder->look_down('_tag', 'tr')) {
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
                $results->{$short_name}{long_name} = $link->{content};
                $results->{$short_name}{url}       = $link->{url};
            }
            elsif ($class_name eq 'iTopics') {
                $results->{$short_name}{topics} = $td->{_content}[0];
            }
            elsif ($class_name eq 'iPosts') {
                $results->{$short_name}{posts} = $td->{_content}[0];
            }
            elsif ($class_name eq 'iLastPost') {
                $results->{$short_name}{last_post} = $td->{_content}[0];
            }
            elsif ($class_name eq 'iMod') {
                $results->{$short_name}{moderator} = $td->{_content}[0];
            }
        }
    }
    return $results;
}

sub parse_forum_index {
    my $self    = shift;
    my $builder = $self->_page2treebuilder('index/forumindex');

    my %results;

    foreach my $group ($builder->look_down('_tag', 'div')) {
        my $class_name = $group->attr('class');
        next if !defined $class_name || $class_name ne 'mb2';
        my ($name, $url) = $self->_parse_forum_index_meta_fora($group);
        next unless $name;
        $results{$name}{url} = $url;

        $results{$name}{fora} = {
            %{ $self->_parse_forum_index_fora($group) },
            %{ $results{$name}{fora} || {} }
        };
    }

    return \%results;
}

sub test {
    my $self = shift;

    print "Just here to entertain you", $/;
}


__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OPN::Fok::UA - A Fok UserAgent client

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head2 assert_session_id

Checks the session id, if this fails you need to login again.

=head2 login

Login to Fok

=head2 parse_forum

Parse a forum

=head2 parse_forum_index

Parse the forum index

=head2 request_ok

Do a request, if it fails, die.

=head2 test

No-op, just here to test some cli script.

=head1 AUTHOR

Wesley Schwengle C<wesley at schwengle dot net>

=head1 COPYRIGHT and LICENCE

Wesley Schwengle, 2009 - 2014
