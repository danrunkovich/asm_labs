#pragma once
#include <stddef.h>
void process_image_c (const unsigned char* gray_src, unsigned char* gray_dst, const int width, const int height);
void process_image_asm_vector (const unsigned char* gray_src, unsigned char* gray_dst, const int width, const int height);
void process_image_asm_scalar (const unsigned char *gray_src, unsigned char* gray_dst, const int width, const int height);
