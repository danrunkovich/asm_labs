#include "../proc.h"
#include <stdlib.h>


void process_image_c (const unsigned char *gray_src, unsigned char *gray_dst, const int width, const int height) {
    for (int i = 0; i < width * height; i ++) {
        gray_dst [i] = 0;
    }

    for (int y = 1; y < height - 1; y ++) {
        for (int x = 1; x < width - 1; x ++) {
            int g00 = gray_src [(y - 1) * width + x - 1];
            int g01 = gray_src [(y - 1) * width + x];
            int g02 = gray_src [(y - 1) * width + x + 1];

            int g10 = gray_src [y * width + x - 1];
            int g12 = gray_src [y * width + x + 1];

            int g20 = gray_src [(y + 1) * width + x - 1];
            int g21 = gray_src [(y + 1) * width + x];
            int g22 = gray_src [(y + 1) * width + x + 1];

            // sobel gradient gx
            // -1 -2 -1
            // 0  0  0
            // 1  2  1
            int gx = -g00 - 2 * g01 - g02 + g20 + g21 + g22;

            // sobel gradient gy
            // -1 0 1
            // -2 0 2
            // -1 0 1
            int gy = -g00 + g02 - 2 * g10 + 2 * g12 - g20 + g22;

            int mag = abs(gx) + abs(gy); // result
            if (mag > 255) mag = 255;

            gray_dst[y * width + x] = (unsigned char) mag;
        }
    }
}
