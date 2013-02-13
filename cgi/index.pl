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

	my $action = $self->param('action') // q{};
	my $item   = $self->param('item') // q{};
	my $afile  = $self->param('file') // q{};
	my $args   = $self->param('args') // q{};

	my $items;

	if ($action eq 'add') {
		$self->render( 'add', file => $afile );
		return;
	}

	for my $file (qw(later someday todo uni waiting)) {

		my $changed = 0;
		my $xml = XML::LibXML->load_xml( location => "${prefix}/${file}" );
		my $xp_note = XML::LibXML::XPathExpression->new('/todo/note');

		for my $note ( $xml->findnodes($xp_note) ) {
			my $time = $note->getAttribute('time');

			if ($action eq 'done' and $note->getAttribute('time') eq $item) {
				$note->setAttribute('done', time());
				$changed = 1;
			}
			if ($action eq 'edit' and $file eq $afile and $item eq $time) {
				my $text = $note->textContent;
				$text =~ s{^\s+}{};
				$text =~ s{\s+$}{};
				$self->param(tdata => $text);
				$self->render( 'edit', file => $file, item => $item);
				return;
			}
			if (not $note->getAttribute('done')) {
				push(@{$items->{$file}}, {
					text => $note->textContent,
					time => $time,
					link => "?item=$time&file=$file&",
				});
			}
		}

		if ($changed) {
			$xml->toFile("${prefix}/${file}", 0);
		}
	}

	$self->render( 'main', items => $items );
}

get '/_add' => sub {
	my $self = shift;
	my $file = $self->param('file');
	my $str  = $self->param('data');

	my $xml = XML::LibXML->load_xml( location => "${prefix}/${file}" );
	my ($root) = $xml->findnodes('/todo');

	my $new = XML::LibXML::Element->new('note');
	$new->setAttribute('priority', 'medium');
	$new->setAttribute('time', time());
	$new->appendText($str);

	$root->appendChild($new);

	$xml->toFile("${prefix}/${file}", 0);

	$self->redirect_to('/');
};

get '/_edit' => sub {
	my $self = shift;
	my $file = $self->param('file');
	my $item = $self->param('item');
	my $str  = $self->param('tdata');

	my $xml = XML::LibXML->load_xml( location => "${prefix}/${file}" );
	my ($node) = $xml->findnodes("/todo/note[\@time=\"$item\"]");
	my $new = XML::LibXML::Element->new('note');
	$new->setAttribute('priority', 'medium');
	$new->setAttribute('time', $item);
	$new->appendText($str);

	$node->replaceNode($new);

	$xml->toFile("${prefix}/${file}", 0);

	$self->redirect_to('/');
};

app->config(
	hypnotoad => {
		listen => ['http://*:8094'],
		pid_file => '/tmp/gtd-web.pid',
		workers => 1,
	},
);

app->defaults( layout => 'default' );

get '/' => \&handle_request;

app->start();
