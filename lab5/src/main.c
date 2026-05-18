#include <stdio.h>
#include <string.h>
#include <time.h>
#include "process/proc.h"

#define STB_IMAGE_IMPLEMENTATION
#include "../extern/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "../extern/stb_image_write.h"

#ifndef OPT_FLAGS
    #define OPT_FLAGS "unknown"
#endif

#ifdef USE_ASM
    #define PROCESS_FUNC process_image_asm
    const char* impl_name = "ASM x86-64";
#else
    #define PROCESS_FUNC process_image_c
    const char* impl_name = "C";
#endif


int main (int argc, char** argv) {
    if (argc < 3) {
        printf ("Ошибка : мало параметров\n");
        return 1;
    }

    const char* input_path = argv[1];
    const char* output_path = argv[2];
    int use_max = 1;
    if (argc > 3) use_max = (strcmp (argv [3], "min") == 0) ? 0 : 1;


    printf ("Загрузка изображения\n");
    int width, height, channels;
    unsigned char* img_data = stbi_load(input_path, &width, &height, &channels, 0); // передаем ластовым аргументом 0, чтобы
    // не менять никак изображение и получить нужное крооличесвто каналов через channels

    if (img_data == NULL) {
        fprintf (stderr, "Ошибка : не удалось загрузить изображение -> %s\n", input_path);
        return 1;
    }

    printf ("\tИзображение -> %d * %d\n\tКаналов -> %d", width, height, channels);
    printf ("\n--------------------------\nИспользуемая реалиазция -> %s\n", impl_name);
    printf ("Алгоритм -> %s\n--------------------------\n\n", use_max ? "MAX (R, G, B)" : "MIN(R, G, B)");

    struct timespec start, end;
    clock_gettime (CLOCK_MONOTONIC, &start);

    PROCESS_FUNC (img_data, width, height, channels, use_max);

    clock_gettime (CLOCK_MONOTONIC, &end);

    double elapsed = (end.tv_nsec - start.tv_nsec) / 1000;

    printf ("======Время обработки -> %.15lf ms======\n", elapsed);

    printf ("Сохранение изображения -> %s\n", output_path);

    FILE* f = fopen("timing/results_timing.txt", "a");
    if (f) {
        // Если файл пустой, можно записать заголовок
        fseek(f, 0, SEEK_END);
        if (ftell(f) == 0) {
            fprintf(f, "| Реализация | Оптимизация | Время (милисек) |\n");
            fprintf(f, "|------------|-------------|-----------------|\n");
        }
        fprintf(f, "| %-10s | %-11s | %-15.6f |\n", impl_name, OPT_FLAGS, elapsed); // (-11) это выравнивание по левому краю
        // + 11 минимальное количесвто символов (если <11 то будет дополняться пробелами)
        fclose(f);
    }
    if (!stbi_write_jpg(output_path, width, height, channels, img_data, 1500)) {
        fprintf (stderr, "Ошибка : не удалось сохранить изображение -> %s\n", output_path);
        stbi_image_free(img_data);
        return 1;
    }

    stbi_image_free(img_data);
    return 0;
}
