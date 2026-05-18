#include "../proc.h"


void process_image_c(unsigned char *data, int width, int height, int channels, int use_max) {
    if (channels < 3) return;

    size_t pixel_count = (size_t) (width * height);

    for (size_t i = 0; i < pixel_count; i ++) {

        unsigned char* pixel_data = data + (i * channels);

        unsigned char r = pixel_data [0];
        unsigned char g = pixel_data [1];
        unsigned char b = pixel_data [2];

        unsigned char grey;

        if (use_max) {
            grey = r;
            if (g > grey) grey = g;
            if (b > grey) grey = b;
        }
        else {
            grey = r;
            if (g < grey) grey = g;
            if (b < grey) grey = b;
        }

        pixel_data [0] = grey;
        pixel_data [1] = grey;
        pixel_data [2] = grey;
    }
}
