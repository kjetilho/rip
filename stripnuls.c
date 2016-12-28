#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

static char nuls[4096];

#define BLOCKS_PER_SECOND ((long) 2*2*44100/sizeof(nuls))
static const int threshold = 1 * BLOCKS_PER_SECOND + 2;
static int bytecount = 0;
static int out;
static int verbose;

int
emit_nuls (int zeroes)
{
	int removed = 0;

	if (zeroes > threshold) {
		int newsize = sqrt (zeroes / BLOCKS_PER_SECOND)
			      * BLOCKS_PER_SECOND;
		fprintf (stdout, "%d:%d@%lud\n",
			 zeroes, newsize, bytecount / sizeof (nuls));
		if (verbose)
			fprintf (stderr,
				 "shrunk %.1fs into %.1fs at %.1fs\n",
				 zeroes * sizeof (nuls) / 2/2/44100.0,
				 newsize * sizeof (nuls) / 2/2/44100.0,
				 bytecount / 2/2/44100.0);
		removed = zeroes - newsize;
		zeroes = newsize;
	}

	while (zeroes--) {
		if (write (out, nuls, sizeof (nuls)) != sizeof (nuls)) {
			perror ("write");
			exit (2);
		}
	}

	return (removed);
}

int
main (int argc, char **argv)
{
	int removed = 0;
	int zeroes = 0;
	int n;
	int in;
	int samples = sizeof (nuls) / sizeof (short);
	signed short buf[samples];
	const char *progname = argv[0];

	if (argc > 1 && strcmp (argv[1], "-v") == 0) {
		verbose = 1;
		++argv; --argc;
	}

	if (argc != 3) {
		fprintf (stderr, "Usage: %s [-v] infile outfile\n",
			 progname);
		exit (64);
	}
	in = open (argv[1], O_RDONLY);
	if (in == -1) {
		perror(argv[1]);
		exit (1);
	}

	out = open (argv[2], O_CREAT | O_WRONLY, 0666);
	if (out == -1) {
		perror(argv[2]);
		exit (1);
	}

	while ((n = read (in, buf, sizeof (buf)))) {

		bytecount += n;

		if (n == sizeof (buf)) {
			int i = 0;
			while (i < samples &&
			       buf[i] > -128 && buf[i] < 128)
				++i;
			if (i == samples) {
				zeroes++;
				continue;
			}
		}
		if (zeroes) {
			removed += emit_nuls (zeroes);
			zeroes = 0;
		}

		if (write (out, buf, n) != n) {
			perror(argv[2]);
			exit (2);
		}
	}
	if (zeroes)
		removed += emit_nuls (zeroes);

	return (0);
}
