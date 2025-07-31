#!/usr/bin/perl

use strict;
use warnings;

use Encode;
use Getopt::Long;
use JSON;
use Locale::PO;

# current limits:
# - we do not support plural. forms
# - no message content support

my $options = {};
GetOptions($options, 't=s', 'o=s', 'v=s') or die "unable to parse options\n";

die "no files specified\n" if !scalar(@ARGV);

#my $filename = shift || die "no po file specified\n";

# like FNV32a, but we only return 31 bits (positive numbers)
sub fnv31a {
    my ($string) = @_;

    my $hval = 0x811c9dc5;

    foreach my $c (unpack('C*', $string)) {
        $hval ^= $c;
        $hval +=
            ((($hval << 1)) + (($hval << 4)) + (($hval << 7)) + (($hval << 8)) + (($hval << 24)));
        $hval = $hval & 0xffffffff;
    }
    return $hval & 0x7fffffff;
}

my $catalog = {};
my $plurals_catalog = {};

my $nplurals = 2;
my $plural_forms = "n!=1";

foreach my $filename (@ARGV) {
    my $href = Locale::PO->load_file_ashash($filename)
        || die "unable to load '$filename'\n";

    my $charset;
    my $hpo = $href->{'""'} || die "no header";
    my $header = $hpo->dequote($hpo->msgstr);
    if ($header =~ m|^Content-Type:\s+text/plain;\s+charset=(\S+)$|im) {
        $charset = $1;
    } else {
        die "unable to get charset\n" if !$charset;
    }

    if ($header =~ m|^Plural-Forms:\s+nplurals\s?=\s?([123456]);\s+plural=(.*);$|im) {
	$nplurals = $1 + 0;
	$plural_forms = $2;
    }

    foreach my $k (keys %$href) {
        my $po = $href->{$k};
        next if $po->fuzzy(); # skip fuzzy entries
        my $ref = $po->reference();

        # skip unused entries
        next if !$ref;

        # skip entries if t is defined (pve/pmg) and the string is
        # not used there or in the widget toolkit
        next if $options->{t} && $ref !~ m/($options->{t}|proxmox)\-/;

        my $qmsgid = decode($charset, $po->msgid);
        my $msgid = $po->dequote($qmsgid);

        my $qmsgid_plural = decode($charset, $po->msgid_plural);
        my $msgid_plural = $po->dequote($qmsgid_plural);

        next if !length($msgid) && !length($msgid_plural); # skip header

        my $digest = fnv31a($msgid);

        die "duplicate digest" if $catalog->{$digest};

        if (defined($po->msgstr)) {
            my $qmsgstr = decode($charset, $po->msgstr);
            my $msgstr = $po->dequote($qmsgstr);

            next if !length($msgstr); # skip untranslated entries
            $catalog->{$digest} = [$msgstr];
        }

        if (defined(my $plurals = $po->msgstr_n)) {
            for my $case (sort { $a <=> $b } keys $plurals->%*) {
                my $qmsgstr_n = decode($charset, $plurals->{$case});
                my $msgstr_n = $po->dequote($qmsgstr_n);

                next if !length($msgstr_n); # skip untranslated entries
                push $plurals_catalog->{$digest}->@*, $msgstr_n;
            }
        }
    }
}

my $json = to_json($catalog, { canonical => 1, utf8 => 1 });
my $plurals_json = to_json($plurals_catalog, { canonical => 1, utf8 => 1 });

my $version = $options->{v} // ("dev-build " . localtime());
my $content = "// $version\n"; # write version to the beginning to better avoid stale cache

my $outfile = $options->{o};

$content .= "// Proxmox Message Catalog: $outfile\n" if $outfile;

$content .= <<__EOD;
__proxmox_i18n_msgcat__ = $json;
__proxmox_i18n_plurals_msgcat__ = $plurals_json;

function fnv31a(text) {
    var len = text.length;
    var hval = 0x811c9dc5;
    for (var i = 0; i < len; i++) {
        var c = text.charCodeAt(i);
        hval ^= c;
        hval += (hval << 1) + (hval << 4) + (hval << 7) + (hval << 8) + (hval << 24);
    }
    hval &= 0x7fffffff;
    return hval;
}

function gettext(buf) {
    var digest = fnv31a(buf);
    var data = __proxmox_i18n_msgcat__[digest];
    if (!data) {
        return buf;
    }
    return data[0] || buf;
}

function ngettext(singular, plural, n) {
    const msg_idx = Number($plural_forms);
    const digest = fnv31a(singular);
    const translation = __proxmox_i18n_plurals_msgcat__[digest];
    if (!translation || msg_idx >= translation.length) {
        if (n === 1) {
            return singular;
        } else {
            return plural;
        }
    }
    return translation[msg_idx];
}
__EOD

if ($outfile) {
    open(my $fh, '>', $outfile)
        || die "unable to open '$outfile' - $!\n";
    print $fh $content;
} else {
    print $content;
}
