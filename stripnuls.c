#include <stdio.h>
#include <math.h>

static char nuls[4096];

#define BLOCKS_PER_SECOND ((long) 2*2*44100/sizeof(nuls))
static const int threshold = 1 * BLOCKS_PER_SECOND;
static int bytecount = 0;

int
emit_nuls (int zeroes)
{
	int removed = 0;

	if (zeroes > threshold) {
		int newsize = 
			sqrt (zeroes / BLOCKS_PER_SECOND)
			* BLOCKS_PER_SECOND;
		fprintf (stderr, "shrunk %d (%.1fs) into %d (%.1fs) at %.1fs\n",
			 zeroes,
			 zeroes * sizeof (nuls) / 2/2/44100.0,
			 newsize,
			 newsize * sizeof (nuls) / 2/2/44100.0,
			 bytecount / 2/2/44100.0);
		removed = zeroes - newsize;
		zeroes = newsize;
	}
	
	while (zeroes--)
		write (1, nuls, sizeof (nuls));

	return (removed);
}

int
main (int argc, char **argv)
{
	int removed = 0;
	int zeroes = 0;
	int n;
	int samples = sizeof (nuls) / sizeof (short);
	signed short buf[samples];

	while ((n = read (0, buf, sizeof (buf)))) {

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

		write (1, buf, sizeof (buf));
	}
	if (zeroes)
		removed += emit_nuls (zeroes);

	return (0);
}
