#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <limits.h>

int main(int argc, char *argv[]){
  int c;

  int chunk = 6144;
  int max_frames = INT_MAX;

  if (argc > 1) {
     chunk = atoi(argv[1]);
  }

  if (argc > 2) {
     max_frames = atoi(argv[2]);
  }

  fprintf(stderr, "chunk size = %d\n", chunk);
  fprintf(stderr, "max_frames = %d\n", max_frames);


  int total_length = 0;
  int frame_length = 0;

  // Read the first character
  int last = -1;
  int num_chars = 0;
  int num_frames = 0;

  int total_run = 0;
  int run = 0;
  while ( (c=getchar()) != EOF && num_frames < max_frames ) {

     int start_of_frame = (num_chars % chunk) == 0;
     int end_of_frame = (num_chars % chunk) == (chunk - 1);

     if (start_of_frame) {
        run = 1;
        last = c;
     } else if (c == last && run < 255) {
        run++;
     } else {
        // output last, run
        putchar(last);
        putchar(run);
        frame_length += 2;
        total_run += run;
        last = c;
        run = 1;
     }

     if (end_of_frame) {
        // output last, run
        putchar(last);
        putchar(run);
        frame_length += 2;
        total_run += run;

        while ((frame_length & 0xff) != 0) {
           putchar(0);
           putchar(0);
           frame_length += 2;
        }

        fprintf(stderr, "frame %4d = %4d\n", num_frames, frame_length);
        num_frames++;
        total_length += frame_length;
        frame_length = 0;
     }
     num_chars++;
  }
  fprintf(stderr, "num_frames = %d\n", num_frames);
  fprintf(stderr, "num_chars  = %d\n", num_chars);
  fprintf(stderr, "total      = %d\n", total_length);
  fprintf(stderr, "total_run  = %d\n", total_run);
  return 0;
}
