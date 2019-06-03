#include <stdio.h>
#include <inttypes.h>

#define CHUNK 6144

int main(){
  int c;
  int last[CHUNK];
  int n = 0;
  int x;
  while ( (c=getchar()) != EOF ){
     if (n < CHUNK) {
        x = c;
     } else {
        x = c ^ last[n % CHUNK];
     }
     putchar(x);
     last[n % CHUNK] = c;
     n++;
  }
  return 0;
}
