#include <stdio.h>
#include <gsl/gsl_sf_bessel.h>

int
main (void)
{
  double x = 5.0;
  double y = gsl_sf_bessel_J0 (x);
  printf ("J0(%g) = %.18e\n", x, y);
  return 0;
}

// gcc -Wall -c play.c
// gcc -L/usr/local/lib play.o -lgsl -lm
// ./a.out


//  -I/usr/local/Cellar/gsl/2.7/include