#!/usr/bin/env perl
#
#
#
use strict;
use warnings;

package FokTopic;

use Data::Dumper;
use Text::CSV;
use Text::ParseWords;
use HTML::Entities;
use XML::RSS;
use FokUA;
use List::MoreUtils;
use Encode;

our @ISA     = qw(Exporter);
our $VERSION = 0.1;
our @EXPORT  = qw(get_topics);
our @EXPORT_OK = qw(get_topics);

my $csv = Text::CSV->new(
    {
        quote_char          => "'",
        escape_char         => "\\",
        escape_char         => "\\\'",
        sep_char            => ',',
        eol                 => $\,
        always_quote        => 0,
        binary              => 0,
        keep_meta_info      => 0,
        allow_loose_quotes  => 0,
        allow_loose_escapes => 1,
        allow_whitespace    => 1,
        blank_is_undef      => 1,
        verbatim            => 0,
    }
);


my @types = (
    [
        qw(tid title pi unknown user uid posts views unknown unknown lapo lapo_id lapo_time fipo_time maxmsg pages)

    ],
    [
        qw(tid title pi unknown user uid posts views lapo_user lapo_id lapo_time fipo_time maxmsg pages forum_tla forum_id)
    ],
);

sub get_topics {
    my ( $self, $type, $id ) = @_;

    # Default forum is feedback
    $id = 1 if ( !$id );

    $type = lc($type);

    my $topics;

    # Difference between active/new topics and forum/filter/history topics
    # 0 - forum/filter/history
    # 1 - active/new
    my $parse_type = 0;

    if ( $type eq "filter" ) {
        $topics = $self->get_topics_url("rde/list_forumfilter/$id");
    }
    elsif ( $type eq "at" ) {
        $topics     = $self->get_topics_url("active");
        $parse_type = 1;
    }
    elsif ( $type eq "myat" ) {
        $topics     = $self->get_topics_url("user/active/$id");
        $parse_type = 1;
    }
    elsif ( $type eq "history" ) {
        $topics = $self->get_topics_url("user/history/$id");
    }
    elsif ( $type eq "new" ) {
        $topics     = $self->get_topics_url('rde/list_new_topics');
        $parse_type = 1;
    }
    else {
        $topics = $self->get_topics_url("forum/$id");
    }

    my $rss = XML::RSS->new( version => '2.0' );
    $rss->channel(
        title          => shift(@$topics),
        link           => "http://opperschaap.net/fok/fok.pl",
        language       => 'nl',
        description    => 'Opperschaap.net presents FokForumRss',
        copyright      => 'Copyright 2009, opperschaap.net',
        #pubDate        => time(),
        #lastBuildDate  => time(),
        managingEditor => 'fokrss@opperschaap.net',
        webMaster      => 'fokrss@opperschaap.net'
    );

    my @fields = @{ $types[$parse_type] };
    my $max    = scalar @fields;

    my @topics;

    foreach my $line (@$topics) {
        my $ok  = $csv->parse($line);
        if (!$ok) {
            #print Dumper $line;
            next;
        }
        my @ref = $csv->fields();
        my %topic;
        for ( my $i = 0 ; $i < $max ; $i++ ) {
            my $item = join( " ", quotewords( '\s+', 0, $ref[$i]) );
            $topic{ $fields[$i] } = $item;
        }
        if ($type eq "new") {
            next unless ($topic{forum_id} == $id || $topic{forum_tla} eq uc($id));
        }
        #print Dumper \%topic;
        my $title = exists $topic{forum_tla} ? sprintf( " %s / %s", $topic{forum_tla}, $topic{title}) : $topic{title};
        my $link = "http://forum.fok.nl/topic/" . $topic{tid};
        my $lapo =  $link . "/" . $topic{pages} . "/" . $topic{maxmsg} . "/#" . $topic{lapo_id};

        my $status = "Open";
        $status = "Gesloten" if ($topic{pi} =~ /lock.gif/);
        $status = "Sticky" if ($topic{pi} =~ /faq.?.gif/);

        my $desc = sprintf(
            "TS: %s<br/> Laatste post: <a href='%s'>%s</a><br/> Aantal posts/views: %s/%s<br>Status: %s",
                $topic{user}, $lapo, $topic{lapo_user} ? $topic{lapo_user} :
                $topic{lapo}, $topic{posts}, $topic{views}, $status);

        $rss->add_item(title => $title,
            link  => "http://forum.fok.nl/topic/" . $topic{tid},
            #description => Dumper \%topic,
            description => $desc,
        );

    }
    return $rss->as_string();
    #return wantarray ? @topics : \@topics;
}

1;
