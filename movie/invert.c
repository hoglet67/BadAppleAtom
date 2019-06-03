#include <stdio.h>
#include <inttypes.h>


int main(){
  int c;
  while ( (c=getchar()) != EOF ){
     putchar(c ^ 0xff);
  }
  return 0;
}
