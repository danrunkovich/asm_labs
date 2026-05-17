#pragma once
#include <stddef.h>
void process_image_c (unsigned char* data, int width, int height, int channels, int use_max);
void process_image_asm (unsigned char* data, int width, int height, int channels, int use_max);
