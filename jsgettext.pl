#!/usr/bin/perl

use strict;
use warnings;

use Encode;
use Getopt::Long;
use Locale::PO;
use Time::Local;

my $options = {};
GetOptions($options, 'o=s', 'b=s', 'p=s') or die "unable to parse options\n";

my $dirs = [@ARGV];

die "no directory specified\n" if !scalar(@$dirs);

foreach my $dir (@$dirs) {
    die "no such directory '$dir'\n" if ! -d $dir;
}

my $projectId = $options->{p} || die "missing project ID\n";

my $basehref = {};
if (my $base = $options->{b}) {
    my $aref = Locale::PO->load_file_asarray($base) ||
	die "unable to load '$base'\n";

    my $charset;
    my $hpo = $aref->[0] || die "no header";
    my $header = $hpo->dequote($hpo->msgstr);
    if ($header =~ m|^Content-Type:\s+text/plain;\s+charset=(\S+)$|im) {
	$charset = $1;
    } else {
	die "unable to get charset\n" if !$charset;
    }

    foreach my $po (@$aref) {
	my $qmsgid = decode($charset, $po->msgid);
	my $msgid = $po->dequote($qmsgid);
	$basehref->{$msgid} = $po;
    }
}

sub find_js_sources {
    my ($base_dirs) = @_;

    my $find_cmd = 'find ';
    # shell quote heuristic, with the (here safe) assumption that the dirs don't contain single-quotes
    $find_cmd .= join(' ', map { "'$_'" } $base_dirs->@*);
    $find_cmd .= ' -name "*.js"';
    open(my $find_cmd_output, '-|', "$find_cmd | sort") or die "Failed to execute command: $!";

    my $sources = [];
    while (my $line = <$find_cmd_output>) {
	chomp $line;
	print "F: $line\n";
	push @$sources, $line;
    }
    close($find_cmd_output);

    return $sources;
}

my $header = <<'__EOD';
Proxmox message catalog.

Copyright (C) Proxmox Server Solutions GmbH

This file is free software: you can redistribute it and/or modify it under the terms of the GNU
Affero General Public License as published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
-- Proxmox Support Team <support\@proxmox.com>
__EOD

my $ctime = scalar localtime;

my $href = {
    '' => Locale::PO->new(
	-msgid => '',
	-comment => $header,
	-fuzzy => 1,
	-msgstr => "Project-Id-Version: $projectId\n"
	    ."Report-Msgid-Bugs-To: <support\@proxmox.com>\n"
	    ."POT-Creation-Date: $ctime\n"
	    ."PO-Revision-Date: YEAR-MO-DA HO:MI +ZONE\n"
	    ."Last-Translator: FULL NAME <EMAIL\@ADDRESS>\n"
	    ."Language-Team: LANGUAGE <support\@proxmox.com>\n"
	    ."MIME-Version: 1.0\n"
	    ."Content-Type: text/plain; charset=UTF-8\n"
	    ."Content-Transfer-Encoding: 8bit\n",
    ),
};

sub extract_msg {
    my ($filename, $linenr, $line) = @_;

    my $count = 0;

    while(1) {
	my $text;
	if ($line =~ m/\bgettext\s*\((("((?:[^"\\]++|\\.)*+)")|('((?:[^'\\]++|\\.)*+)'))\)/g) {
	    $text = $3 || $5;
	}
	last if !$text;
	return if $basehref->{$text};
	$count++;

	my $ref = "$filename:$linenr";

	if (my $po = $href->{$text}) {
	    $po->reference($po->reference() . " $ref");
	} else {
	    $href->{$text} = Locale::PO->new(-msgid=> $text, -reference=> $ref, -msgstr=> '');
	}
    }
    die "can't extract gettext message in '$filename' line $linenr\n" if !$count;
    return;
}

my $sources = find_js_sources($dirs);

foreach my $s (@$sources) {
    open(my $SRC_FH, '<', $s) || die "unable to open file '$s' - $!\n";
    while(defined(my $line = <$SRC_FH>)) {
	if ($line =~ m/gettext\s*\(/ && $line !~ m/^\s*function gettext/) {
	    extract_msg($s, $., $line);
	}
    }
    close($SRC_FH);
}

my $filename = $options->{o} // "messages.pot";
Locale::PO->save_file_fromhash($filename, $href);

