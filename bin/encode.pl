#! /usr/bin/perl -w

# version 1.0, 2005-01-28

use strict;
use English;

my $tmp = "/tmp";
my $mm = "/mm/samling";

my $do_aac = 0;

# overordna mål:
#
# 1) skal ha nok informasjon til at ein ikkje skal måtte leite fram
#    platene igjen, mao. (så godt som) tapsfri handtering.
#
# 2) små MP3- eller AAC-filer er nyttig for mobiltelefonen.  dessverre
#    støttar Nokia 6230 kun MPEG2-AAC med "Low Complexity"-koding.
#
# 3) politisk korrektheit gjer at eg vil bruke Ogg heime.  kanskje
#    like greit å bruke Ogg FLAC i staden for ein kombinasjon av
#    Vorbis og delta-FLAC.
#
# skal liggje på disken i ei form som gjer databaser overflødig.  skal
# vere mogleg å importere data i ein database relativt greit seinare
# om det skulle vere hensiktsmessig.
#
# filer og trestruktur:
#
# /mm/flac/ARTIST/ÅR_ALBUM/SPORNUMMER_SONGNAMN.flac (1+ linkar)
# /mm/samling/meta/GENRE/CDDBID/SPORNUMMER.flac             (same fil)
#
# /mm/samling/aac/ARTIST/ÅR_ALBUM/SPORNUMMER_SONGNAMN.aac (1+ linkar)
#
# /mm/samling/meta/GENRE/CDDBID/info.SPORNUMMER
#     alle nyttige tags, som REPLAYGAIN_TRACK_GAIN, ARTIST etc.
#     format er enkelt, som Vorbis-kommentarar.  i dataverdien er LF
#     erstatta av \n, og \ av \\.  informasjon om evt. stillheit som
#     er fjerna ligg i taggen STRIPNULS_SUPPRESSED_SILENCE
#
# /mm/musikk/ARTIST/ÅR_ALBUM/SPORNUMMER_SONGNAMN.flac
#     symlink -- laga av eit anna skript.  lagar berre katalogar for
#     artistar som er "av interesse", dvs. eg har eit heilt album med
#     dei, over eit dusin songar, eller andre kriterium.
#
# prosentsekvensar frå Grip:
#
#    b  The bitrate that files are being encoded at.
#    c  The CDrom device being used.
#    C  The generic scsi device being used (note that this will be
#       substituted with the CDrom device if no generic scsi device
#       has been specified).
#  * w  The filename of the wave file being ripped.
#    m  The filename of the file being encoded.
#  * t  The track number,beginning at 1, and zero-filled (ie: '03' for
#       the third track).
#    s  The start sector of the track.
#    e  The end sector of the track.
#  * n  The name of the track.
#  * a  The artist name for the track.
#  * A  The artist name for the disc.
#  * d  The name of the disc.
#  * i  The disc database id (in hex) for the disc.
#  * y  The year of the disc.
#    g  The ID3 genre id of the disc.
#  * G  The ID3 genre string of the disc.
#  * r  The recommended replay gain for the track (in dB). Note that
#       this is only applicable if you have enabled gain
#       calculation. You can find more information on this gain
#       adjustment at www.replaygain.org
#  * R  The recommended replay gain for the entire album (in dB). This
#       value is only valide after an entire disc has been ripped (it
#       is designed to be used with the disc filter command).
#    x  The encoded file extension (ie "mp3")
#
# Vorbis-tags skil ikkje mellom store og små bokstavar.  her er lista
# over dei vanlege taggane, henta frå
#     http://xiph.org/ogg/vorbis/doc/v-comment.html
#
# dei som eg brukar er markert med ei stjerne.
#
# * TITLE
#       Track/Work name
# * VERSION
#       The version field may be used to differentiate multiple
#       versions of the same track title in a single collection.
#       (e.g. remix # info)
# * ALBUM
#       The collection name to which this track belongs 
# * TRACKNUMBER
#       The track number of this piece if part of a specific larger
#       collection or album
# * ARTIST
#       The artist generally considered responsible for the work. In
#       popular music this is usually the performing band or singer.
#       For classical music it would be the composer.  For an audio
#       book it would be the author of the original text.
# * PERFORMER
#       The artist(s) who performed the work.  In classical music this
#       would be the conductor, orchestra, soloists.  In an audio book
#       it would be the actor who did the reading.  In popular music
#       this is typically the same as the ARTIST and is omitted.
#   COPYRIGHT
#       Copyright attribution
#   LICENSE
#       License information, eg, 'All Rights Reserved'
#   ORGANIZATION
#       Name of the organization producing the track (i.e. the 'record
#       label')
#   DESCRIPTION
#       A short text description of the contents 
# * GENRE
#       A short text indication of music genre 
# * DATE
#       Date the track was recorded 
#   LOCATION
#       Location where track was recorded 
#   CONTACT
#       Contact information for the creators or distributors
#   ISRC
#       ISRC number for the track; see the ISRC intro page for more
#       information on ISRC numbers.
#
# i tillegg kjem desse:
#
# * REPLAYGAIN_ALBUM_GAIN
#   REPLAYGAIN_ALBUM_PEAK
# * REPLAYGAIN_TRACK_GAIN
#   REPLAYGAIN_TRACK_PEAK
#
# for å ha tilgang til REPLAYGAIN_ALBUM_GAIN må ein vente med koding
# til heile plata er rippa.  ein må også rippe heile plata på nytt
# sjølv om det berre er eitt spor det er feil på.
#
# mine konvensjonar:
#
#    teiknsettet er UTF-8
#
#    artist-verdiar kan gjerast til lister ved å skilje artistane med
#    semikolon.
#
#    samleplater har albumartist "Various".
#
#    plater utan nokon naturleg felles artist, og som ikkje eigentlege
#    samleplater, kan bruke albumartist "Individual".  for desse vil
#    albumartisten verte ignorert fullstendig.
#
#    der ein har oppgjeve artistar for både album og for sporet, vert
#    desse lagt saman med sporet fyrst.  evt. duplikat vert fjerna.
#
#    startar artistnamnet for sporet med "=", vert artisten for albumet
#    ignorert.
#
#    kun dei elleve CDDB-sjangrane vert brukt:
#        blues classical country data folk jazz misc newage reggae
#        rock soundtrack
#    (det er ein dårleg idé å endre sjangeren FreeDB har gitt albumet,
#    sidan det er ein del av databasenøkkelen.)
#
#    viss sjangeren er "classical", er fyrste artistnamn komponisten
#    (ARTIST), og resten er artistane som framfører verket
#    (PERFORMER).  for andre sjangrar brukar eg kun ARTIST.  for
#    "classical" har track artist presedens, så om ein oppgir dette,
#    MÅ fyrste namnet vere komponisten.  dette gjeld også for disc
#    artist, om ein kun oppgir denne.
#
#    remiks-namn står i [].  (VERSION)
#
#    nokre teikn i songtitlar vert endra i filnamnet:
#       /  => --
#       "  => ''
#
#    DATE har formatet YYYY[-MM[-DD]], i praksis kun YYYY.
#
# Grip-innstillingar:
#
#    ripfileformat /cmm/tmp/%i_%t.wav
#    mp3fileformat /tmp/%i_%t.%x
#    mp3extension flac
#    mp3cmdline %w %t %n %a %A %d %i %y %G


sub usage {
    print STDERR "Usage: $0 %w %t %n %a %A %d %i %y %G\n";
    exit(64);
}

usage() unless @ARGV == 9;

my ($wavfile, $tr_no, $tr_name, $tr_artist, $d_artist, $d_name,
    $d_id, $d_date, $d_id3genre) = @ARGV;

# dette er ganske teit, men eg forutset altså at eg har ein cache på
# heimeområdet mitt der eg kan titte etter CDDB-sjangeren.  Grip vil
# kun gi meg ID3-sjangeren.

my $d_genre = get_genre($d_id);

# viss Grip allereie har rippa plata, vil replaygain-verdien ikkje
# reknast ut på nytt.  derfor brukar vi wavegain-programmet sjølve.

my $metafile = "$mm/meta/$d_genre/$d_id/info.$tr_no";
my ($tr_gain, $tr_peak, $d_gain) = get_gain_values($wavfile, $d_genre, $d_id, $tr_no);
my $stripnuls_tag = "";

if (open(META, $metafile)) {
    while(<META>) {
	chomp;
	if (/^STRIPNULS_SUPPRESSED_SILENCE=/) {
	    $stripnuls_tag = $POSTMATCH;
	    last;
	}
    }
    close(META);
}

my %artists = ();
my $pri = 1;
my $include_disc_artist = 1;

if ($tr_artist =~ /^=/) {
    $tr_artist = $POSTMATCH; #'
    $include_disc_artist = 0;
}

if ($include_disc_artist &&
    $d_artist ne "Various" &&
    $d_artist ne "Individual") {
    for $a (split(/;\s*/, $d_artist)) {
	next if $a eq "";
	$artists{$a} ||= $pri++;
    }
}

# For classical music, the composer MUST be listed first for each
# track, *or* the disc artist must be "composer; performer" with no
# track artist(s) specified!
#
# The artist with lowest priority value will be used as the composer
# (ie. ARTIST), the rest are considered performers (ie. PERFORMER).

my $is_classical = $d_genre eq "classical" || $d_id3genre eq "Classical";
$pri = -99 if $is_classical;

for $a (split(/;\s*/, $tr_artist)) {
    next if $a eq "";
    $artists{$a} ||= $pri++;
}

if ($tr_artist =~ /\(?feat\. (.*?)\)?/) {
    my $featuring = $1;
    for $a (split(/\s*(?:\&|,)\s*/, $featuring)) {
	$artists{$a} ||= $pri++;
    }
}

my @artists = sort { $artists{$a} <=> $artists{$b} } keys(%artists);
my $d_year = $d_date;
$d_year = $1 if $d_date =~ /^(\d+)-/;

# putt meta-informasjonen i høvelege strukturar

my @id3tags = ("-a" . artist_list(@artists),
	       "-A$d_name",
	       "-s$tr_name",
	       "-y$d_year",
	       "-t$tr_no",
	       "-g$d_genre");

my @vorbis_comments = (["ALBUM", $d_name],
		       ["TRACKNUMBER", $tr_no],
		       ["GENRE", $d_genre],
		       ["DATE", $d_date],
		       ["REPLAYGAIN_ALBUM_GAIN", $d_gain],
		       ["REPLAYGAIN_TRACK_GAIN", $tr_gain],
		       ["REPLAYGAIN_TRACK_PEAK", $tr_peak]);

if ($tr_name =~ /\s\[(.+?)\]($|\s)/) {
    push(@vorbis_comments, ["VERSION", $1]);
    my $vorbis_title = $tr_name;
    $vorbis_title =~ s/\s\[.+?\]($|\s)/$1/;
    push(@vorbis_comments, ["TITLE", $vorbis_title]);
} else {
    push(@vorbis_comments, ["TITLE", $tr_name]);
}

if ($is_classical) {
    push(@vorbis_comments, ["ARTIST", $artists[0]]);
    for my $p (@artists[1..$#artists]) {
	push(@vorbis_comments, ["PERFORMER", $p]);
    }
} else {
    for my $p (@artists) {
	push(@vorbis_comments, ["ARTIST", $p]);
    }
}

my $meta_flac = "$mm/meta/$d_genre/$d_id/$tr_no.flac";
my $tmp_wav = "$tmp/$d_id-$tr_no-str.wav";

my $retag = 0;
if (-r $wavfile && (stat(_))[7] == 27) {
    # we should reuse the existing rip, only retag it.
    $retag = 1;
} else {
    # okay, på tide å lage nokon filer.  fyrst av alt fjernar vi
    # stillheit.

    open(STRIP, "stripnuls -v $wavfile $tmp_wav|")
	|| die "stripnuls: $!\n";

    while (<STRIP>) {
	chomp;
	$stripnuls_tag .= " " if $stripnuls_tag;
	$stripnuls_tag .= $_;
    }
    close(STRIP) || die "stripnuls: $!";
}

push(@vorbis_comments, ["STRIPNULS_SUPPRESSED_SILENCE", $stripnuls_tag])
    if $stripnuls_tag;

# så lagar vi meta-området og lagrar meta-informasjonen.

make_parent_dir($metafile);

open(TRMETA, ">$metafile") || die "$metafile: $!\n";
for (@vorbis_comments) {
    print TRMETA $_->[0], "=", quote_tag($_->[1]), "\n";
}
close(TRMETA) || die "$metafile";

#
# så lagar vi MPEG2 AAC (LC)
#

my $tmp_aac;
if ($do_aac && !$retag) {
    $tmp_aac = "$tmp/$d_id-$tr_no.aac";

    # diverre er der ein bug i faac som gjer at prosessen henger seg
    # opp på enkelte filer og med enkelte kvalitetsnivå.  buggen kan
    # unngåast ved å slå av mid/side-koding, noko som gjer filene
    # 3-10% større.  dette er likevel mykje mindre bitrate enn MP3 som
    # har ein kvalitet som ein orkar høyre på.

    print STDERR "running faac [", time(), "]\n";
    system("faac", "-q", "60", "--no-midside", "-o", $tmp_aac, $tmp_wav);
    die "faac: $?" if $?>>8;
    system("id3tag", @id3tags, $tmp_aac);
    die "id3tag: $?" if $?>>8;
}

#
# og så FLAC
#
# --ogg krever oppgradering til FLAC 1.1.1.  får heller gjere omkoding
# seinare om ønskjeleg.
#
# test på komprimering og kodingsfart:
#
# quality user    sys     delta%  size        size%
#    1    33.10   2.62            68555169
#    2    44.41   2.62    24.06%  68090096   -0.68%
#    3    39.65   2.58   -11.39%  64509188   -5.26%
#    4    47.13   2.10    14.21%  63448381   -1.64%
#    5    62.34   2.92    24.57%  63228472   -0.35%
#    6    72.67   3.25    14.04%  63164202   -0.10%
#    7   297.81   4.49    74.89%  63027165   -0.22%
#    8   394.66   4.31    24.23%  62789138   -0.38%
#   real 666.00           40.09% 117651788   46.63%
#
# komprimeringsnivå 4 ser ut til å vere best per CPU-sykel (13x fart)

my $tmp_flac = "$tmp/$d_id-$tr_no.flac";
if ($retag) {
    print STDERR "making copy of FLAC for retagging\n";
    $tmp_flac = $meta_flac . ".tmp";
    system("cp", "-p", $meta_flac, $tmp_flac);
    die "cp $tmp_flac: $?" if $?>>8;
} else {
    print STDERR "running flac --silent -4 [", time(), "]\n";
    system("flac", "--silent", "-4", "-o", $tmp_flac, $tmp_wav);
    die "flac: $?" if $?>>8;
}

# viss vi brukar Ogg FLAC i framtida:
#   system("vorbiscomment", "-c", $metafile, $tmp_flac);
#   die "vorbiscomment: $?" if $?>>8;

# i FLAC 1.1.1 er namnet på brytaren endra til --import-tags-from, men
# den gamle brytaren fungerer fram til neste release.

print STDERR "running metaflac [", time(), "]\n";
system("metaflac", "--remove-all-tags", "--import-tags-from=$metafile",
       $tmp_flac);
die "metaflac: $?" if $?>>8;


# no kan vi slette WAV-fila.  kjelde-WAV-fila tek vi vare på i
# tilfelle ein treng å køyre koding på nytt.  desse ryddar ein
# cronjobb opp i.

unlink($tmp_wav);
#   unlink($wavfile);

# alle filene er klare til å kopierast inn.

my $aac_file;
if ($do_aac && !$retag) {
    $aac_file = "$mm/aac/" . fname($artists[0]) . ".aac";
    make_parent_dir($aac_file);
    unlink($aac_file);
    print STDERR "copy to $aac_file\n";
    system("cp", $tmp_aac, $aac_file);
    die "cp aac: $?" if $?>>8;
    unlink($tmp_aac);
}

system("cp", "-p", "$ENV{'HOME'}/.cddb/$d_id",
       "$mm/meta/$d_genre/$d_id/info.cddb");

if ($retag) {
    rename $tmp_flac, $meta_flac;
    print STDERR "retagged $meta_flac\n";
} else {
    unlink($meta_flac); # ignore error
    print STDERR "copy to $meta_flac\n";
    system("cp", $tmp_flac, $meta_flac);
    die "cp flac: $?" if $?>>8;
    unlink($tmp_flac);
}

if (0 && -d "/mm/tmp/cover/$d_id") {
    for my $img ("cover", "inside", "back") {
	my $imgfile = "/mm/tmp/cover/$d_id/$img.png";
	if (-f $imgfile) {
	    # Could be in a different filesystem, so don't use
	    # rename(2).
	    system("mv", $imgfile, "$mm/meta/$d_genre/$d_id");
	}
    }
    rmdir("/mm/tmp/cover/$d_id");
}


my $f;
if ($do_aac) {
    # det er nyttig med ein symlink inn i meta-katalogen, for CDDB-id og
    # -sjanger er ikkje lett tilgjengeleg elles.
    symlink("../../../meta/$d_genre/$d_id",
	    "$mm/aac/" . dname($artists[0]) . "/meta");

    # så alle hardlinkane
    push(@artists, "Various") if $d_artist eq "Various";
    for (1..$#artists) {
	$f = "$mm/aac/" . fname($artists[$_]) . ".aac";
	make_parent_dir($f);
	unlink($f); # ignore error
	print STDERR "link up $f\n";
	link($aac_file, $f) || die "$f";
	my $metalink = "$mm/aac/" . dname($artists[$_]) . "/meta";
	unlink($metalink);
	symlink("../../../meta/$d_genre/$d_id", $metalink);
    }
}

push(@artists, "Various") if $d_artist eq "Various";
for (0..$#artists) {
    $f = "/mm/flac/" . fname($artists[$_]) . ".flac";
    make_parent_dir($f);
    unlink($f); # ignore error
    print STDERR "link up $f\n";
    link($meta_flac, $f) || die "$f";
    symlink("../../meta/$d_genre/$d_id",
	    "/mm/flac/" . dname($artists[$_]) . "/meta");
}

# og vi er ferdige!

exit(0);


########################################################################

sub quote_file {
    my $s = shift;
    $s =~ s,/,--,g;
    $s =~ s,\",'',g;
    return $s;
}

sub quote_tag {
    my $s = shift;
    $s =~ s/\\/\\\\/g;
    $s =~ s/\n/\\n/g;
    return $s;
}

sub dname {
    my ($artist) = @_;
    die "bad year" unless defined($d_year) && $d_year > 1900 && $d_year < 2020;
    die "missing artist or disc name" unless (defined($artist) &&
					      defined($d_name));
    return sprintf("%s/%04d_%s",
		   quote_file($artist), $d_year, quote_file($d_name));
}

sub fname {
    my ($artist) = @_;
    die "missing track number or name" unless (defined($tr_no) &&
					       defined($tr_name));
    return sprintf("%s/%s_%s", dname($artist), $tr_no, quote_file($tr_name));
}

sub make_parent_dir {
    my ($file) = @_;
    my $dir = $file;
    $dir =~ s,/[^/]*$,,;
    unless (-d $dir) {
	system("mkdir", "-p", $dir) && die "mkdir $dir";
    }
}

sub get_genre {
    my ($d_id) = @_;
    my $cddb_file = "$ENV{'HOME'}/.cddb/$d_id";
    open(CDDB, $cddb_file) || die "$cddb_file: $!\n";
    while (<CDDB>) {
	chomp;
	if (/^DGENRE=(.*)/) {
	    return lc($1);
	}
    }
    close(CDDB);
    die "unknown genre for $d_id\n";
}

sub get_gain_values {
    my ($wavfile, $d_genre, $d_id, $tr_no) = @_;
    my $gainfile = "$mm/meta/$d_genre/$d_id/info.gain";
    my ($tr_gain, $tr_peak, $d_gain);

    unless (open(GAIN, $gainfile)) {
	calculate_gain($wavfile, $d_genre, $d_id, $gainfile);
	open(GAIN, $gainfile) || die "$gainfile: calculate_gain failed?: $!\n";
    }
    while (<GAIN>) {
	chomp;
	$tr_gain = $POSTMATCH if /^REPLAYGAIN_TRACK_GAIN\[$tr_no\]=/i;
	$tr_peak = $POSTMATCH if /^REPLAYGAIN_TRACK_PEAK\[$tr_no\]=/i;
	$d_gain = $POSTMATCH if /^REPLAYGAIN_ALBUM_GAIN=/i;
    }
    close(GAIN);

    print STDERR "track $tr_no: $tr_gain dB, album: $d_gain dB\n";
    unless (defined($tr_gain) && defined($tr_peak) && defined($d_gain)) {
	rename($gainfile, "$gainfile.incomplete");
	print STDERR "missing gain in $gainfile, moving it out of the way\n";
	return get_gain_values($wavfile, $d_genre, $d_id, $tr_no)
	  if -r $wavfile;
	die "$wavfile is missing, no use running wavegain\n";
    } else {
	unlink("$gainfile.incomplete");
    }
    return ($tr_gain, $tr_peak, $d_gain);
}

sub calculate_gain {
    my ($wavfile, $d_genre, $d_id, $gainfile) = @_;
    my $lock_file = "$gainfile.lock";

    make_parent_dir($lock_file);

    # viss låsen var satt, vil lock returnere ikkje-0.  vi forutset
    # at vedkomande som hadde låsen har gjort jobben.
    if (lock_file($lock_file)) {
	unlock_file($lock_file);
	return;
    }

    $wavfile =~ s/_\d\d\.wav$/_??.wav/;
    print STDERR "running 'wavegain -a $wavfile'\n";
    open(CALC, "wavegain -a $wavfile 2>&1|") || die "wavegain: $!\n";
    open(GAIN, ">$gainfile.work") || die "write $gainfile.work: $!\n";
    while (<CALC>) {
	chomp;
	if (/^\s+([-+]?\d+\.\d+) dB\s+\|\s+(\d+).*_(\d\d)\.wav$/i) {
	    print GAIN "REPLAYGAIN_TRACK_GAIN[$3]=$1\n";
	    print GAIN "REPLAYGAIN_TRACK_PEAK[$3]=$2\n";
	} elsif (/^.*Album Gain:\s+([-+]?\d+\.\d+) dB/i) {
	    print GAIN "REPLAYGAIN_ALBUM_GAIN=$1\n";
	} elsif (/No Album Gain adjustment required/) {
	    print GAIN "REPLAYGAIN_ALBUM_GAIN=0\n";
	}
    }
    close(CALC);
    close(GAIN) || die "close $gainfile: $!\n";
    rename("$gainfile.work", $gainfile) || die "rename $gainfile.work: $!\n";
    unlock_file($lock_file);
}

sub lock_file {
    my ($file) = @_;
    my $waited = 0;

    open(LOCK, ">$file.$$") || die "$file.$$: temp lock file existed: $!\n";
    print LOCK $$;
    close(LOCK) || die "$file.$$: close failed: $!\n";
    while (1) {
	last if link("$file.$$", $file);
	if (open(LOCK, $file)) {
	    my $pid = <LOCK>;
	    close(LOCK);
	    unless ($pid =~ /^\d+$/ && kill 0, $pid) {
		print STDERR "$file: stale lock ($pid).\n";
		unlink($file);
		# ikkje tel dette som eit forsøk.
		next;
	    }
	}
	print STDERR "waiting for gain values lock\n" unless $waited;
	$waited += sleep(5);
    }
    unlink("$file.$$");
    print STDERR "waited for lock for $waited seconds\n" if $waited;
    return $waited;
}

sub unlock_file {
    my ($file) = @_;
    unlink($file);
}

sub artist_list {
    my (@artists) = @_;
    if (@artists == 1) {
	return $artists[0];
    } elsif (@artists == 2) {
	# hadde vore kjekt å vite språket slik at ein kunne bruke "og"
	# eller "and" eller "und" eller "et".
	return "$artists[0] \& $artists[1]";
    } else {
	return join(", ", @artists);
    }
}

# la grip ta seg av ting, inkl. talet på CPU-ar

# vi får inn ei WAV-fil, og skal gjere det om til Ogg Vorbis @ 192k,
# MP3 --r3mix, MP3 lowlowlow Hz.
# treng tre CPU-ar

# Lars Preben:
# lame --strictly-enforce-ISO -h -v -S -k -B 320 fil.wav fil.mp3
#
# _må_ bruke mono for bitrater under 128 kbps med MP3.
#
# ogg gir akseptabel stereolyd med -q 1 (her 73.8 kb/s), og er utan
# _irriterande_ artifaktar ved -q 2 (88 kb/s)
#
# testa med  With A Smile, Touched/The Birds Lullaby, A Weekend of a Clown
#             (Rainbirds)         (Rachel Smith)      (Cikala Mvta)
# ogg -q 0 ->   57.3 kbps    61.3 kbps     59.0 kbps     59.8 kbps
#     -q 1 ->   73.8 kbps    78.3 kbps     75.6 kbps     77.2 kbps
#     -q 2 ->   88.0 kbps                  90.2 kbps
#     -q 3 ->  101.9 kbps                 105.1 kbps    110.6 kbps
#     -q 5 ->  142.6 kbps   142.1 kbps                  156.1 kbps
#     -q 6 ->  174.2 kbps
#     -q 9 ->  319.5 kbps
# wav      -> 1411.2 kbps  1411.2 kbps   1411.2 kbps   1411.2 kbps
# mp3 lars ->  138.1 kbps   135.6 kbps    143.2 kbps    155.3 kbps
#     r3m  ->  152.0 kbps   148.3 kbps    166.7 kbps    179.5 kbps

