#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;
use utf8;

use Mojolicious::Lite;
use File::Slurp qw(slurp);
use XML::LibXML;

our $VERSION = '0.0';

my $prefix = '/home/derf/var/gtd';

sub handle_request {
	my $self = shift;

	my $action = $self->param('action');
	my $item   = $self->param('item');
	my $args   = $self->param('args');

	my $items;

	for my $file (qw(later someday todo uni waiting)) {

		my $xml = XML::LibXML->load_xml( location => "${prefix}/${file}" );
		my $xp_note = XML::LibXML::XPathExpression->new('/todo/note');

		for my $note ( $xml->findnodes($xp_note) ) {
			if (not $note->getAttribute('done')) {
				push(@{$items->{$file}}, {
					text => $note->textContent,
					time => $note->getAttribute('time'),
				});
			}
		}
	}

	$self->render( 'main', items => $items );
}

app->config(
	hypnotoad => {
		accepts => 10,
		listen => ['http://127.0.0.1:8094'],
		pid_file => '/tmp/gtd-web.pid',
		workers => 1,
	},
);

get '/' => \&handle_request;

app->start();

__DATA__

@@ main.html.ep
<!DOCTYPE html>
<html>
<head>
	<title>gtd-web</title>
	<meta charset="utf-8">
	<style type="text/css">

	body {
		font-family: Sans-Serif;
	}

	</style>
</head>
<body>
<div>
% for my $file (keys %{$items}) {
<h1><%= $file %></h1>
<ul>
% for my $item (@{$items->{$file}}) {
<li><%= $item->{text} %>
<a class="done" href="?item=<%= $item->{time} %>&amp;action=done">done</a>
</li>
% }
</ul>
% }
</ul>
</div>
</body>
</html>
