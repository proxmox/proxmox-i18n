#!/usr/bin/perl

use strict;
use Time::Local;
use PVE::Tools;
use Data::Dumper;
use Locale::PO;
use Getopt::Std;
use Encode;

my $options = {};

getopts('o:b:p:', $options) ||
    die "unable to parse options\n";

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

my $sources = [];

my $findcmd = [['find', @$dirs, '-name', '*.js'],['sort']];
PVE::Tools::run_command($findcmd, outfunc => sub {
    my $line = shift;
    print "F: $line\n";
    push @$sources, $line;
});

my $header = <<__EOD;
Proxmox message catalog.
Copyright (C) 2011-2020 Proxmox Server Solutions GmbH
This file is free software: you can redistribute it and\/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
Proxmox Support Team <support\@proxmox.com>, 2020.
__EOD

my $ctime = scalar localtime;

my $href = {};
my $po = new Locale::PO(-msgid=> '',
			-comment=> $header,
			-fuzzy=> 1,
			-msgstr=>
			"Project-Id-Version: $projectId\n" .
			"Report-Msgid-Bugs-To: <support\@proxmox.com>\n" .
			"POT-Creation-Date: $ctime\n" .
			"PO-Revision-Date: YEAR-MO-DA HO:MI +ZONE\n" .
			"Last-Translator: FULL NAME <EMAIL\@ADDRESS>\n" .
			"Language-Team: LANGUAGE <support\@proxmox.com>\n" .
			"MIME-Version: 1.0\n" .
			"Content-Type: text/plain; charset=UTF-8\n" .
			"Content-Transfer-Encoding: 8bit\n");

$href->{''} = $po;

sub extract_msg {
    my ($filename, $linenr, $line) = @_;

    my $count = 0;

    while(1) {
	my $text;
	if ($line =~ m/\Wgettext\s*\((("((?:[^"\\]++|\\.)*+)")|('((?:[^'\\]++|\\.)*+)'))\)/g) {
	    $text = $3 || $5;
	}
	
	last if !$text;

	if ($basehref->{$text}) {
	    return;
	}
	
	$count++;

	my $ref = "$filename:$linenr";

	if (my $po = $href->{$text}) {
	    $po->reference($po->reference() . " $ref");
	} else {   
	    my $po = new Locale::PO(-msgid=> $text, -reference=> $ref, -msgstr=> '');
	    $href->{$text} = $po;
	}
    };

    die "can't extract gettext message in '$filename' line $linenr\n"
	if !$count;
}

foreach my $s (@$sources) {
    open(SRC, $s) || die "unable to open file '$s' - $!\n";
    while(defined(my $line = <SRC>)) {
	next if $line =~ m/^\s*function gettext/;
	if ($line =~ m/gettext\s*\(/) {
	    extract_msg($s, $., $line);
	}
    }
    close(SRC);
}

my $filename = $options->{o} // "messages.pot";
Locale::PO->save_file_fromhash($filename, $href);

