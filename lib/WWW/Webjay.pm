package WWW::Webjay;

use 5.008004;
use strict;
use warnings;
use Carp;
use Getopt::Std;
use Data::Dumper;
use HTML::Entities;
use HTTP::Cookies;
use LWP::UserAgent;
use URI::Escape;

our $VERSION = '0.1_1';
our $VERSION = eval $VERSION;

# For creation of a new Webjay object.
sub new {
	my ($class, %params) = @_;
	my $self = {};

	croak "Client description not set with client_page param!" unless $params{client_page};

	$self->{DEBUG} = 0;
	$self->{COOKIEJAR} = ".webjaycookies";

	# Create the User Agent:
	$self->{UA} = LWP::UserAgent->new || die "Unable to create LWP::UserAgent";
	$self->{UA}->agent($params{client_page});
	$self->{UA}->cookie_jar(HTTP::Cookies->new(file => $self->{COOKIEJAR}, autosave => 1));
	
	$self->{USERNAME} = $params{username};
	$self->{PASSWORD} = $params{password};
	$self->{CLIENTPAGE} = $params{client_page};
	
	bless ($self, $class);
	return $self;
}

# Set or retrieve the client description page.
sub client_page	{
	my $self = shift;
	if (@_)	{ $self->{CLIENTPAGE} = shift	}
	return $self->{CLIENTPAGE};
}

# Set or retrieve the username.
sub username	{
	my $self = shift;
	if (@_)	{ $self->{USERNAME} = shift	}
	return $self->{USERNAME};
}

# Set the password (cannot retrieve).
sub password	{
	my $self = shift;
	if (@_)	{ $self->{PASSWORD} = shift	}
	return undef;
}

###########################################################
# To Create A Playlist
#
# If the URI of the playlist is not set,
# and there is a title in the GET arguments,
# create a playlist by that title and return the short-name.
# 
# Args:
# 	title			text [MAX LENGTH 255] [REQUIRED]
# 	public			public OR private [default: public] [REQUIRED]
# 	description		text [MAX LENGTH 255] [OPTIONAL]
# 	m3u				Newline separated list of URLs of playlist entries [MAX LENGTH 40K] [OPTIONAL]
#
# Returns:
# 	201	on success
# 	4xx on failure
# 	5xx on failure
#
sub create_playlist	{
	my ($self, %params) = @_;
	my $title = $params{title};
	my $public = $params{public};
	my $description = $params{description};
	my $m3u = $params{m3u};

	# Return "bad request" status code on missing params
	$public = "public" unless $public;
	confess "The 'title' parameter is REQUIRED." unless ($title);

	my $req = HTTP::Request->new(POST => 'http://webjay.org/api/new/playlists');
	$req->content_type('application/x-www-form-urlencoded');
	$req->authorization_basic($self->username(), $self->password());
	$req->content('title=' . uri_escape(encode_entities($title)) .
				'&public=' . uri_escape($public).
				'&description=' . uri_escape(encode_entities($description)).
				'&m3u=' . uri_escape($m3u).
				'');
	
	my $res = $self->{UA}->request($req);
	if (($res->code / 100) == 4 || ($res->code / 100) == 5)	{
		carp "HTTP Error: " . $res->code;
	}
	return $res->code;
}

###########################################################
# To Modify A Playlist
#
# POST to the API URL (for example:
#  http://webjay.org/api/by/yourname/short-name
# ) of the playlist that you want to change.
# 
# Args:
# 	shortname		Short-name of the playlist
# 	title			text [MAX LENGTH 255]
# 	public			public OR private [MAX LENGTH 255]
# 	description		text [MAX LENGTH 255]
# 	m3u				Newline-separated list of URLs of playlist entries [MAX LENGTH 40K]
#
# Returns:
# 	200	on success
# 	4xx on failure
# 	5xx on failure
#
sub modify_playlist	{
	my ($self, %params) = @_;
	my $shortname = $params{shortname};
	my $title = $params{title};
	my $public = $params{public};
	my $description = $params{description};
	my $m3u = $params{m3u};

	# Return "bad request" status code on missing params
	confess "The 'shortname' parameter is REQUIRED." unless ($shortname);
	
	my $req = HTTP::Request->new(POST => 'http://webjay.org/api/by/' .
		$self->username() . '/' . $shortname);
	$req->content_type('application/x-www-form-urlencoded');
	$req->authorization_basic($self->username(), $self->password());
	$req->content('title=' . uri_escape(encode_entities($title)) .
				'&public=' . uri_escape($public).
				'&description=' . uri_escape(encode_entities($description)).
				'&m3u=' . uri_escape($m3u).
				'');
	
	my $res = $self->{UA}->request($req);
	if (($res->code / 100) == 4 || ($res->code / 100) == 5)	{
		carp "HTTP Error: " . $res->code;
	}
	return $res->code();
}

###########################################################
# To Modify Metadata For A Song
#
# Update metadata related to a playlist entry,
# using the URL of the entry as a key.
# 
# Metadata for an audio URL applies to all instances
# of that URL within your playlists.
# If you do not set a value for the image, description,
# or site parameter, a blank value will be used.
# 
# Args:
# 	song			[URL of an audio resource in one of your playlists] [REQUIRED]
# 	description		text [MAX LENGTH 255] [REQUIRED]
# 	image			URL of a GIF [MAX LENGTH 255] [REQUIRED]
# 	site			URL related to audio resource [MAX LENGTH 255] [REQUIRED]
#
# Returns:
# 	200	on success
# 	4xx on failure
# 	5xx on failure
#
sub modify_metadata	{
	my ($self, %params) = @_;
	my $song = $params{song};
	my $description = $params{description};
	my $image = $params{image};
	my $site = $params{site};

	# Return "bad request" status code on missing params
	confess "The 'song' parameter is REQUIRED." unless ($song);
	confess "The 'description' parameter is REQUIRED." unless ($description);
	confess "The 'image' parameter is REQUIRED." unless ($image);
	confess "The 'site' parameter is REQUIRED." unless ($site);
	
	my $req = HTTP::Request->new(POST => 'http://webjay.org/api/songmetadata/' .
		$self->username() . '/short-name?audio=' . $song);
	$req->content_type('application/x-www-form-urlencoded');
	$req->authorization_basic($self->username(), $self->password());
	$req->content('description=' . uri_escape(encode_entities($description)) .
				'&image=' . uri_escape($image).
				'&site=' . uri_escape(encode_entities($site)).
				'');
	
	my $res = $self->{UA}->request($req);
	if (($res->code / 100) == 4 || ($res->code / 100) == 5)	{
		carp "HTTP Error: " . $res->code;
	}
	return $res->code();
}

###########################################################
# To Get A Listing Of Your Playlists
#
# Fetch a listing of user playlists.
# 
# Returns a list: playlist1, playlist2, ...
#
sub list_playlists	{
	my $self = shift;
	my $req = HTTP::Request->new(GET => 'http://webjay.org/api/shortname/' . $self->username());
	$req->authorization_basic($self->username(), $self->password());
	my $res = $self->{UA}->request($req);

	if (($res->code / 100) == 4 || ($res->code / 100) == 5)	{
		carp "HTTP Error: " . $res->code;
	}
	return split /\n/, $res->content;
}

###########################################################
# To Get The Short-Name Of A Playlist
#
# Given a playlist title, fetch the short-name.
# 
# Args:
# 	title			entity-encoded string [MAX LENGTH 255]
#
# Returns shortname
#
sub get_shortname	{
	my ($self, %params) = @_;
	my $title = $params{title};
	
	# Return "bad request" status code on missing params
	confess "The 'title' parameter is REQUIRED." unless ($title);

	my $req = HTTP::Request->new(GET => 'http://webjay.org/api/shortname/' .
		$self->username() . '?title=' . $title);
	$req->authorization_basic($self->username(), $self->password());
	my $res = $self->{UA}->request($req);

	if (($res->code / 100) == 4 || ($res->code / 100) == 5)	{
		carp "HTTP Error: " . $res->code;
	}
	return $res->content;
}

###########################################################
# To Fetch Playlist Content
#
# Get the actual content of a playlist.
# 
# Args:
# 	shortname		Short-name of the playlist.
# 	
# Returns playlist in xspf
#
sub fetch_playlist	{
	my ($self, %params) = @_;
	my $shortname = $params{shortname};
	
	# Return "bad request" status code on missing params
	confess "The 'shortname' parameter is REQUIRED." unless ($shortname);

	my $req = HTTP::Request->new(GET => 'http://webjay.org/api/xspf/' .
		$self->username() . '/' . $shortname);
	$req->authorization_basic($self->username(), $self->password());
	my $res = $self->{UA}->request($req);

	if (($res->code / 100) == 4 || ($res->code / 100) == 5)	{
		carp "HTTP Error: " . $res->code;
	}
	return $res->content;
}

###########################################################
# To Delete A Playlist
#
# To delete a playlist, use the HTTP DELETE method on the playlist URI.
# Please be careful.
# You will not be prompted,
# and once a playlist is deleted it is not recoverable.
# 
# Args:
# 	shortname		Short-name of the playlist.
#
# Returns:
# 	200	on success
# 	4xx on failure
# 	5xx on failure
#
sub delete_playlist	{
	my ($self, %params) = @_;
	my $shortname = $params{shortname};

	# Return "bad request" status code on missing params
	confess "The 'shortname' parameter is REQUIRED." unless ($shortname);
	
	my $req = HTTP::Request->new(DELETE => 'http://webjay.org/api/by/' .
		$self->username() . '/' . $shortname);
	$req->content_type('application/x-www-form-urlencoded');
	$req->authorization_basic($self->username(), $self->password());
	
	my $res = $self->{UA}->request($req);
	if (($res->code / 100) == 4 || ($res->code / 100) == 5)	{
		carp "HTTP Error: " . $res->code;
	}
	return $res->code();
}

1;

__END__

=head1 NAME

NET::WebJay - Perl extension for the WebJay API v0.0 (Draft June 2, 2004)

=head1 SYNOPSIS

  use NET::WebJay;
  blah blah blah

=head1 DESCRIPTION

The WebJay module is currently at the stage where one can call the functions to get bypass most of the user agent setup, which was the point.  The module has several methods to mirror the API's declaration:

=head1 METHODS

=head2 create_playlist

If the URI of the playlist is not set, and there is a title in the GET arguments, create a playlist by that title and return the short-name.

=head3 Arguments

title: text [MAX LENGTH 255] [REQUIRED]<br />
public: public OR private [default: public] [REQUIRED]<br />
description: text [MAX LENGTH 255] [OPTIONAL]<br />
m3u: Newline separated list of URLs of playlist entries [MAX LENGTH 40K] [OPTIONAL]<br />

=head3 Returns

201 on success<br />
4xx on failure<br />
5xx on failure<br />

=head2 modify_playlist

POST to the API URL (for example: http://webjay.org/api/by/yourname/short-name) of the playlist that you want to change.<br />

=head3 Arguments

shortname: Short-name of the playlist<br />
title: text [MAX LENGTH 255]<br />
public: public OR private [MAX LENGTH 255]<br />
description: text [MAX LENGTH 255]<br />
m3u: Newline-separated list of URLs of playlist entries [MAX LENGTH 40K]<br />

=head3 Returns

200 on success<br />
4xx on failure<br />
5xx on failure<br />

=head2 delete_playlist

To delete a playlist, use the HTTP DELETE method on the playlist URI.<br />
Please be careful.<br />
You will not be prompted, and once a playlist is deleted it is not recoverable.<br />

=head3 Arguments

shortname: Short-name of the playlist.

=head3 Returns

200 on success<br />
4xx on failure<br />
5xx on failure<br />

=head2 fetch_playlist

Get the actual content of a playlist.

=head2 Arguments

shortname: Short-name of the playlist.

=head2 Returns

A full playlist in XPSF.

=head2 modify_metadata

Update metadata related to a playlist entry, using the URL of the entry as a key.<br />
<br />
Metadata for an audio URL applies to all instances of that URL within your playlists.<br />
If you do not set a value for the image, description, or site parameter, a blank value will be used.<br />

=head3 Arguments

song: [URL of an audio resource in one of your playlists] [REQUIRED]<br />
description: text [MAX LENGTH 255] [REQUIRED]<br />
image: URL of a GIF [MAX LENGTH 255] [REQUIRED]<br />
site: URL related to audio resource [MAX LENGTH 255] [REQUIRED]<br />

=head3 Returns

200 on success<br />
4xx on failure<br />
5xx on failure<br />

=head2 list_playlists

Fetch a listing of user playlists.

=head3 Returns

An array of playlist short-names.

=head2 get_shortname

Given a playlist title, fetch the short-name.

=head3 Arguments

title: entity-encoded string [MAX LENGTH 255]

=head3 Returns

A short-name.

=head2 EXPORT

None by default.

=head1 BUGS AND CAVEATS

This is alpha code.  Lots of things aren't implemented yet.

=head1 SEE ALSO

=for html <a href="http://webjay.org/">WebJay</a>, <a href="http://webjay.org/public/webjay_sample">WebJay Perl Sample</a>, <a href="http://webjay.org/api/help">WebJay API</a>, <a href="http://gonze.com/xspf/xspf-draft-8.html">XPSF Draft 8</a>.

=head1 AUTHOR

Adam P. Blinkinsop E<lt>spaceman@spu.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Adam P. Blinkinsop

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut
